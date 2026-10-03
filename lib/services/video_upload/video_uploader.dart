import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import '../api_errors.dart';
import '../api_service.dart';
import 'picked_video.dart';
import 'upload_resume_store.dart';
import 'upload_types.dart';
import 'video_platform.dart' as platform;

/// Sube la portada (un `PUT` simple) a la URL firmada.
typedef CoverSender = Future<void> Function(
    String url, Uint8List bytes, String contentType);

/// Cuánto va de una subida.
class UploadProgress {
  const UploadProgress({
    required this.sentBytes,
    required this.totalBytes,
    this.resumed = false,
    this.remaining,
  });

  final int sentBytes;
  final int totalBytes;

  /// Se retomó una subida anterior: ya había partes en S3.
  final bool resumed;

  /// Lo que falta, estimado por la velocidad reciente. `null` al principio.
  final Duration? remaining;

  double get ratio => totalBytes == 0 ? 0 : (sentBytes / totalBytes).clamp(0, 1);
}

/// Sube un video a una lección, por partes, directo a S3.
///
/// 1. Abre la subida (o retoma la anotada para este archivo y esta lección).
/// 2. Pide las URLs firmadas de las partes que faltan.
/// 3. Sube [concurrency] partes a la vez. Cada parte que falla se reintenta
///    con espera creciente; si la firma venció (403), se pide otra.
/// 4. Sube la portada, si hay. Si falla, el video sigue: se guarda sin ella.
/// 5. Cierra la subida. El servidor revisa las partes contra S3; si dice que
///    falta alguna, se sube esa y se vuelve a cerrar.
///
/// [cancel] corta lo que esté en vuelo y cancela la subida en S3.
class VideoUploader {
  VideoUploader({
    required this.api,
    required this.lessonId,
    required this.video,
    PartSender? sender,
    this.coverSender,
    this.store = const UploadResumeStore(),
    this.concurrency = 3,
    this.maxAttempts = 4,
    Duration Function(int attempt)? backoff,
  })  : _sender = sender ?? platform.sendVideoPart,
        _backoff = backoff ??
            ((intento) => Duration(seconds: math.min(16, 1 << (intento - 1))));

  final ApiService api;
  final String lessonId;
  final PickedVideo video;
  final UploadResumeStore store;
  final int concurrency;
  final int maxAttempts;
  final PartSender _sender;
  /// Para las pruebas; `null` sube con `ApiService.uploadToSignedUrl`.
  final CoverSender? coverSender;
  final Duration Function(int attempt) _backoff;

  final UploadAbort _abort = UploadAbort();
  String? _key;
  String? _uploadId;
  int _partSize = 0;
  int _partCount = 0;
  final Map<int, String> _urls = {};

  String get _base => '/lessons/$lessonId/video-uploads';

  bool get cancelled => _abort.aborted;

  /// Sube todo y devuelve la lección como la dejó el servidor.
  Future<Map<String, dynamic>> run({
    required void Function(UploadProgress progress) onProgress,
    Uint8List? cover,
    String coverContentType = 'image/jpeg',
    int? durationSec,
  }) async {
    final total = video.sizeBytes;
    final llegaron = <int, int>{};
    var retomada = false;

    final anotada = await store.find(lessonId);
    if (anotada != null &&
        anotada.fingerprint == video.fingerprint &&
        anotada.sizeBytes == total) {
      try {
        final json = await api.get('$_base/parts',
            query: {'key': anotada.key, 'uploadId': anotada.uploadId});
        for (final p in (json as Map)['parts'] as List) {
          final parte = Map<String, dynamic>.from(p as Map);
          llegaron[(parte['partNumber'] as num).toInt()] =
              (parte['sizeBytes'] as num).toInt();
        }
        _key = anotada.key;
        _uploadId = anotada.uploadId;
        _partSize = anotada.partSizeBytes;
        _partCount = anotada.partCount;
        retomada = true;
      } on NotFoundError {
        // Venció o se canceló en otro lado: se empieza de nuevo.
        await store.clear(lessonId);
      }
    } else if (anotada != null) {
      // Lo anotado es de OTRO archivo: esa subida ya no se va a terminar.
      unawaited(_cancelarEnServidor(anotada.key, anotada.uploadId));
      await store.clear(lessonId);
    }
    _comprobar();

    if (_key == null) {
      final json = Map<String, dynamic>.from(await api.post(_base, body: {
        'fileName': video.name,
        'contentType': 'video/mp4',
        'sizeBytes': total,
      }) as Map);
      _key = json['key'] as String;
      _uploadId = json['uploadId'] as String;
      _partSize = (json['partSizeBytes'] as num).toInt();
      _partCount = (json['partCount'] as num).toInt();
      await store.save(PendingUpload(
        lessonId: lessonId,
        key: _key!,
        uploadId: _uploadId!,
        fingerprint: video.fingerprint,
        fileName: video.name,
        sizeBytes: total,
        partSizeBytes: _partSize,
        partCount: _partCount,
        startedAt: DateTime.now(),
      ));
    }
    _comprobar();

    final pendientes = [
      for (var n = 1; n <= _partCount; n++)
        if (llegaron[n] != _tamano(n, total)) n,
    ];

    var enviados = 0;
    for (var n = 1; n <= _partCount; n++) {
      if (llegaron[n] == _tamano(n, total)) enviados += _tamano(n, total);
    }
    final enVuelo = <int, int>{};
    final velocidad = _Velocidad();
    var ultimoAviso = DateTime.fromMillisecondsSinceEpoch(0);

    void avisar({bool forzar = false}) {
      final ahora = DateTime.now();
      if (!forzar && ahora.difference(ultimoAviso).inMilliseconds < 120) return;
      ultimoAviso = ahora;
      final hecho = enviados + enVuelo.values.fold<int>(0, (a, b) => a + b);
      velocidad.muestra(ahora, hecho);
      onProgress(UploadProgress(
        sentBytes: hecho,
        totalBytes: total,
        resumed: retomada,
        remaining: velocidad.falta(total - hecho),
      ));
    }

    avisar(forzar: true);
    await _firmar(pendientes, total);

    Future<void> subir(int n) async {
      final tamano = _tamano(n, total);
      for (var intento = 1;; intento++) {
        _comprobar();
        try {
          final status = await _sender(
            VideoPart(
              url: _urls[n]!,
              video: video,
              partNumber: n,
              start: (n - 1) * _partSize,
              end: (n - 1) * _partSize + tamano,
            ),
            onProgress: (b) {
              enVuelo[n] = math.min(b, tamano);
              avisar();
            },
            abort: _abort,
          );
          enVuelo.remove(n);
          if (status >= 200 && status < 300) {
            enviados += tamano;
            avisar(forzar: true);
            return;
          }
          if (intento >= maxAttempts) {
            throw PartUploadError(
                'El almacenamiento rechazó una parte del video ($status).');
          }
          // 403: la firma venció (o el reloj del equipo está corrido). Se
          // pide otra; cualquier otro código se reintenta igual.
          if (status == 403) await _firmar([n], total);
        } on UploadCancelled {
          rethrow;
        } on PartUploadError {
          enVuelo.remove(n);
          avisar(forzar: true);
          if (_abort.aborted) throw const UploadCancelled();
          if (intento >= maxAttempts) rethrow;
        }
        await _esperar(_backoff(intento));
      }
    }

    final cola = Queue<int>.of(pendientes);
    Future<void> trabajador() async {
      while (cola.isNotEmpty) {
        _comprobar();
        await subir(cola.removeFirst());
      }
    }

    await Future.wait([
      for (var i = 0; i < math.min(concurrency, math.max(1, pendientes.length)); i++)
        trabajador(),
    ]);
    _comprobar();

    String? portada;
    if (cover != null && cover.isNotEmpty) {
      try {
        portada = await _subirPortada(cover, coverContentType);
      } on UploadCancelled {
        rethrow;
      } catch (_) {
        portada = null; // el video vale más que su portada
      }
    }
    _comprobar();

    Future<Map<String, dynamic>> cerrar() async => Map<String, dynamic>.from(
        await api.post('$_base/complete', body: {
          'key': _key,
          'uploadId': _uploadId,
          'fileName': video.name,
          'sizeBytes': total,
          'durationSec': ?durationSec,
          'thumbnailKey': ?portada,
        }) as Map);

    Map<String, dynamic> leccion;
    try {
      leccion = await cerrar();
    } on ConflictError catch (e) {
      final faltan = e.details['missingParts'];
      if (faltan is! List || faltan.isEmpty) rethrow;
      final numeros = [for (final n in faltan) (n as num).toInt()];
      for (final n in numeros) {
        enviados -= _tamano(n, total);
      }
      await _firmar(numeros, total);
      for (final n in numeros) {
        await subir(n);
      }
      leccion = await cerrar();
    }
    await store.clear(lessonId);
    avisar(forzar: true);
    return leccion;
  }

  /// Corta lo que esté en vuelo y cancela la subida en S3.
  Future<void> cancel() async {
    _abort.abort();
    await store.clear(lessonId);
    final key = _key;
    final id = _uploadId;
    if (key != null && id != null) await _cancelarEnServidor(key, id);
  }

  Future<void> _cancelarEnServidor(String key, String uploadId) async {
    try {
      await api.delete(_base, query: {'key': key, 'uploadId': uploadId});
    } on ApiException {
      // Si no se pudo avisar, la regla de ciclo de vida del bucket la borra.
    }
  }

  int _tamano(int n, int total) =>
      n < _partCount ? _partSize : total - _partSize * (_partCount - 1);

  Future<void> _firmar(List<int> partes, int total) async {
    for (var i = 0; i < partes.length; i += 100) {
      final lote = partes.sublist(i, math.min(i + 100, partes.length));
      final json = await api.post('$_base/sign', body: {
        'key': _key,
        'uploadId': _uploadId,
        'sizeBytes': total,
        'partNumbers': lote,
      });
      for (final p in (json as Map)['parts'] as List) {
        final parte = Map<String, dynamic>.from(p as Map);
        _urls[(parte['partNumber'] as num).toInt()] = parte['url'] as String;
      }
    }
  }

  Future<String> _subirPortada(Uint8List bytes, String contentType) async {
    final json = Map<String, dynamic>.from(await api.post(
      '/lessons/$lessonId/video-thumbnail-upload-url',
      body: {'contentType': contentType, 'sizeBytes': bytes.length},
    ) as Map);
    final url = json['uploadUrl'] as String;
    final enviar = coverSender;
    if (enviar != null) {
      await enviar(url, bytes, contentType);
    } else {
      await api.uploadToSignedUrl(
          uploadUrl: url, bytes: bytes, contentType: contentType);
    }
    return json['key'] as String;
  }

  void _comprobar() {
    if (_abort.aborted) throw const UploadCancelled();
  }

  /// Espera, pero se despierta si cancelan.
  Future<void> _esperar(Duration d) {
    final completer = Completer<void>();
    final timer = Timer(d, () {
      if (!completer.isCompleted) completer.complete();
    });
    final dejar = _abort.onAbort(() {
      timer.cancel();
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future.whenComplete(dejar);
  }
}

/// Velocidad de los últimos segundos, para estimar cuánto falta.
class _Velocidad {
  final List<(DateTime, int)> _muestras = [];

  void muestra(DateTime cuando, int bytes) {
    _muestras.add((cuando, bytes));
    while (_muestras.length > 2 &&
        cuando.difference(_muestras.first.$1) > const Duration(seconds: 8)) {
      _muestras.removeAt(0);
    }
  }

  Duration? falta(int bytes) {
    if (_muestras.length < 2) return null;
    final (t0, b0) = _muestras.first;
    final (t1, b1) = _muestras.last;
    final ms = t1.difference(t0).inMilliseconds;
    if (ms < 1500 || b1 <= b0) return null;
    final porMs = (b1 - b0) / ms;
    return Duration(milliseconds: (bytes / porMs).round());
  }
}
