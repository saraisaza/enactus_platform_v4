import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'picked_video.dart';
import 'upload_types.dart';

/// Un video del navegador: un `File`, que es un `Blob`. Cortarlo con `slice`
/// no copia nada — el navegador lee del disco recién al mandarlo.
class WebPickedVideo extends PickedVideo {
  WebPickedVideo(this.file);

  final web.File file;
  String? _url;

  @override
  String get name => file.name;
  @override
  int get sizeBytes => file.size;
  @override
  String get mimeType => file.type;
  @override
  int? get lastModifiedMs => file.lastModified;

  @override
  String? get previewUrl => _url ??= web.URL.createObjectURL(file);

  @override
  Future<Uint8List> readRange(int start, int end) async {
    final buffer = await file.slice(start, end).arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  @override
  void dispose() {
    final url = _url;
    if (url != null) web.URL.revokeObjectURL(url);
    _url = null;
  }
}

/// El selector de archivos del navegador, y no `file_picker`.
///
/// En el navegador `file_picker` entrega el archivo leído entero en memoria
/// (o en base64, peor) o como un stream que solo se lee de corrido. Con 500
/// MB lo primero tumba la pestaña, y con lo segundo no hay vista previa, ni
/// portada, ni forma de retomar una subida desde la mitad. El `File` del
/// navegador da las tres cosas sin leer nada.
Future<PickedVideo?> pickVideoFile() {
  final completer = Completer<PickedVideo?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'video/mp4,.mp4,.m4v';
  input.style.display = 'none';
  web.document.body?.append(input);

  void terminar(PickedVideo? video) {
    if (!completer.isCompleted) completer.complete(video);
    input.remove();
  }

  input.addEventListener(
    'change',
    (web.Event _) {
      final file = input.files?.item(0);
      terminar(file == null ? null : WebPickedVideo(file));
    }.toJS,
  );
  input.addEventListener('cancel', ((web.Event _) => terminar(null)).toJS);
  input.click();
  return completer.future;
}

/// Sube una parte con `XMLHttpRequest`: es lo único del navegador que
/// informa el avance del envío (`fetch` no lo hace en ninguno).
Future<int> sendVideoPart(
  VideoPart part, {
  required void Function(int sentBytes) onProgress,
  required UploadAbort abort,
}) {
  final video = part.video;
  if (video is! WebPickedVideo) {
    throw ArgumentError('En el navegador las partes salen de un File.');
  }
  final completer = Completer<int>();
  final xhr = web.XMLHttpRequest();
  xhr.open('PUT', part.url);
  // Una parte de 8 MiB con una conexión mala tarda; más que esto es que la
  // conexión se murió sin avisar, y se reintenta.
  xhr.timeout = const Duration(minutes: 5).inMilliseconds;

  xhr.upload.addEventListener(
    'progress',
    ((web.ProgressEvent e) => onProgress(e.loaded.toInt())).toJS,
  );
  xhr.addEventListener(
    'load',
    (web.Event _) {
      if (!completer.isCompleted) completer.complete(xhr.status);
    }.toJS,
  );
  void fallar(Object error) {
    if (!completer.isCompleted) completer.completeError(error);
  }

  xhr.addEventListener(
    'error',
    ((web.Event _) => fallar(const PartUploadError(
        'Se cortó la conexión mientras subía el video.'))).toJS,
  );
  xhr.addEventListener(
    'timeout',
    ((web.Event _) => fallar(const PartUploadError(
        'La conexión dejó de responder mientras subía el video.'))).toJS,
  );
  xhr.addEventListener(
    'abort',
    ((web.Event _) => fallar(const UploadCancelled())).toJS,
  );

  final dejar = abort.onAbort(() => xhr.abort());
  xhr.send(video.file.slice(part.start, part.end));
  return completer.future.whenComplete(dejar);
}

/// Duración, tamaño y un fotograma, con un `<video>` que nadie ve.
///
/// Que el navegador lo abra es además la segunda revisión: un archivo que
/// pasó la del formato pero el navegador no puede decodificar, acá falla.
/// Devuelve `null` si no lo pudo abrir.
Future<VideoProbe?> probeVideo(PickedVideo video) async {
  final url = video.previewUrl;
  if (url == null) return null;
  final el = web.HTMLVideoElement()
    ..muted = true
    ..preload = 'auto';
  el.setAttribute('playsinline', '');
  try {
    el.src = url;
    await _evento(el, 'loadedmetadata');
    final segundos = el.duration;
    final ancho = el.videoWidth;
    final alto = el.videoHeight;
    if (ancho == 0 || alto == 0) return null;

    // El 10% del video y no el primer cuadro, que casi siempre es negro.
    final destino = segundos.isFinite && segundos > 0
        ? math.min(math.max(1.0, segundos * 0.1), math.max(0.0, segundos - 0.1))
        : 0.0;
    Uint8List? cuadro;
    try {
      el.currentTime = destino;
      await _evento(el, 'seeked');
      cuadro = await _fotograma(el, ancho, alto);
    } catch (_) {
      cuadro = null; // sin portada automática; el video igual sirve
    }

    return VideoProbe(
      duration: Duration(
          milliseconds: segundos.isFinite ? (segundos * 1000).round() : 0),
      width: ancho,
      height: alto,
      frameJpeg: cuadro,
    );
  } catch (_) {
    return null;
  } finally {
    el.removeAttribute('src');
    el.load();
  }
}

Future<void> _evento(web.HTMLVideoElement el, String nombre) {
  final completer = Completer<void>();
  late final JSFunction ok;
  late final JSFunction error;
  ok = (web.Event _) {
    if (!completer.isCompleted) completer.complete();
  }.toJS;
  error = (web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('el navegador no pudo abrir el video'));
    }
  }.toJS;
  el.addEventListener(nombre, ok);
  el.addEventListener('error', error);
  return completer.future.timeout(const Duration(seconds: 20)).whenComplete(() {
    el.removeEventListener(nombre, ok);
    el.removeEventListener('error', error);
  });
}

Future<Uint8List?> _fotograma(web.HTMLVideoElement el, int ancho, int alto) async {
  final escala = ancho > 1280 ? 1280 / ancho : 1.0;
  final w = (ancho * escala).round();
  final h = (alto * escala).round();
  final canvas = web.HTMLCanvasElement()
    ..width = w
    ..height = h;
  final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
  if (ctx == null) return null;
  ctx.drawImage(el, 0, 0, w, h);
  final completer = Completer<web.Blob?>();
  canvas.toBlob(
    ((web.Blob? blob) => completer.complete(blob)).toJS,
    'image/jpeg',
    0.85.toJS,
  );
  final blob = await completer.future.timeout(const Duration(seconds: 10));
  if (blob == null) return null;
  final buffer = await blob.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

class _WebDropListener implements VideoDropListener {
  _WebDropListener(this._quitar);
  final void Function() _quitar;
  @override
  void dispose() => _quitar();
}

bool _traeArchivos(web.DragEvent e) {
  final tipos = e.dataTransfer?.types.toDart ?? const <JSString>[];
  return tipos.any((t) => t.toDart == 'Files');
}

/// Archivos soltados sobre la página, mientras el panel de subida está a la
/// vista. Se escucha la ventana entera: el editor es un diálogo modal, así
/// que cualquier cosa que se suelte va para él — y sin esto, soltar un video
/// fuera de la zona haría que el navegador lo abra y se pierda lo editado.
VideoDropListener listenForVideoDrops({
  required void Function(bool dragging) onDragging,
  required void Function(PickedVideo video) onDrop,
}) {
  final sobre = (web.DragEvent e) {
    if (!_traeArchivos(e)) return;
    e.preventDefault();
    e.dataTransfer?.dropEffect = 'copy';
    onDragging(true);
  }.toJS;
  final sale = (web.DragEvent e) {
    // Sale de la ventana (no de un elemento a otro): no hay a dónde.
    if (e.relatedTarget == null) onDragging(false);
  }.toJS;
  final suelta = (web.DragEvent e) {
    if (!_traeArchivos(e)) return;
    e.preventDefault();
    onDragging(false);
    final file = e.dataTransfer?.files.item(0);
    if (file != null) onDrop(WebPickedVideo(file));
  }.toJS;

  web.window.addEventListener('dragover', sobre);
  web.window.addEventListener('dragleave', sale);
  web.window.addEventListener('drop', suelta);
  return _WebDropListener(() {
    web.window.removeEventListener('dragover', sobre);
    web.window.removeEventListener('dragleave', sale);
    web.window.removeEventListener('drop', suelta);
  });
}
