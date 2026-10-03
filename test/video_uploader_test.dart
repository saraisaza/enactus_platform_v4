import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enactus_platform/services/api_errors.dart';
import 'package:enactus_platform/services/video_upload/picked_video.dart';
import 'package:enactus_platform/services/video_upload/upload_resume_store.dart';
import 'package:enactus_platform/services/video_upload/upload_types.dart';
import 'package:enactus_platform/services/video_upload/video_uploader.dart';

import 'helpers/fake_api.dart';

/// El motor de subida contra la API falsa y un "S3" que es una función.
///
/// Las partes no pasan por la API —van directo a S3 con su URL firmada—, así
/// que acá las recibe [_S3]: anota qué rango de bytes llegó y puede fallar a
/// pedido, para probar reintentos, firmas vencidas y cancelaciones.

const _leccion = '8f2b6a1e-3c4d-4e5f-9a0b-1c2d3e4f5a6b';
const _base = '/lessons/$_leccion/video-uploads';
const _parte = 1000; // la API falsa dice partes de 1000 bytes

final _video = MemoryPickedVideo(
  'clase 1.mp4',
  Uint8List.fromList(List.generate(2500, (i) => i % 251)),
);

Map<String, dynamic> _firmas(int partes) => {
      'parts': [
        for (var n = 1; n <= partes; n++)
          {'partNumber': n, 'url': 'https://s3.prueba/parte/$n'},
      ],
      'expiresInSeconds': 3600,
    };

FakeApi _api({Map<String, Object?> extra = const {}, Set<String>? notFound}) =>
    FakeApi(
      routes: {
        _base: {
          'key': 'lessons/$_leccion/video.mp4',
          'uploadId': 'subida-1',
          'partSizeBytes': _parte,
          'partCount': 3,
        },
        '$_base/sign': _firmas(3),
        '$_base/complete': {'id': _leccion, 'videoType': 'uploaded'},
        '/lessons/$_leccion/video-thumbnail-upload-url': {
          'key': 'lessons/$_leccion/thumb-1.jpg',
          'uploadUrl': 'https://s3.prueba/portada',
        },
        ...extra,
      },
      notFound: notFound,
    );

class _S3 {
  final Map<int, List<int>> recibidas = {};
  final List<int> intentos = [];

  /// Por parte: cuántas veces falla antes de aceptar, y con qué.
  final Map<int, List<Object>> fallas = {};
  int enVuelo = 0;
  int maxEnVuelo = 0;
  void Function(VideoPart parte)? alEmpezar;

  Future<int> enviar(
    VideoPart parte, {
    required void Function(int) onProgress,
    required UploadAbort abort,
  }) async {
    intentos.add(parte.partNumber);
    alEmpezar?.call(parte);
    enVuelo++;
    maxEnVuelo = enVuelo > maxEnVuelo ? enVuelo : maxEnVuelo;
    try {
      await Future<void>.delayed(Duration.zero);
      if (abort.aborted) throw const UploadCancelled();
      final pendientes = fallas[parte.partNumber];
      if (pendientes != null && pendientes.isNotEmpty) {
        final falla = pendientes.removeAt(0);
        if (falla is int) return falla;
        throw falla;
      }
      onProgress(parte.sizeBytes ~/ 2);
      final bytes = await parte.video.readRange(parte.start, parte.end);
      onProgress(parte.sizeBytes);
      recibidas[parte.partNumber] = bytes;
      return 200;
    } finally {
      enVuelo--;
    }
  }
}

VideoUploader _uploader(FakeApi api, _S3 s3, {List<String>? portadas}) =>
    VideoUploader(
      api: api.build(),
      lessonId: _leccion,
      video: _video,
      sender: s3.enviar,
      coverSender: (url, bytes, type) async => portadas?.add('$url $type ${bytes.length}'),
      backoff: (_) => Duration.zero,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sube cada parte con su rango exacto y cierra con todo lo que importa',
      () async {
    final api = _api();
    final s3 = _S3();
    final portadas = <String>[];
    final avances = <double>[];

    final leccion = await _uploader(api, s3, portadas: portadas).run(
      onProgress: (p) => avances.add(p.ratio),
      cover: Uint8List.fromList([1, 2, 3]),
      durationSec: 754,
    );

    expect(leccion['videoType'], 'uploaded');
    expect(s3.recibidas.keys.toList()..sort(), [1, 2, 3]);
    expect(s3.recibidas[1], _video.bytes.sublist(0, 1000));
    expect(s3.recibidas[3], _video.bytes.sublist(2000, 2500));
    // Tres a la vez como máximo, y de verdad en paralelo.
    expect(s3.maxEnVuelo, greaterThan(1));
    expect(s3.maxEnVuelo, lessThanOrEqualTo(3));

    expect(portadas, ['https://s3.prueba/portada image/jpeg 3']);
    final i = api.requested.indexOf('POST $_base/complete');
    expect(api.cuerpos[i], {
      'key': 'lessons/$_leccion/video.mp4',
      'uploadId': 'subida-1',
      'fileName': 'clase 1.mp4',
      'sizeBytes': 2500,
      'durationSec': 754,
      'thumbnailKey': 'lessons/$_leccion/thumb-1.jpg',
    });
    expect(api.cuerpos[api.requested.indexOf('POST $_base')], {
      'fileName': 'clase 1.mp4',
      'contentType': 'video/mp4',
      'sizeBytes': 2500,
    });

    // El avance nunca retrocede y termina en 1.
    for (var k = 1; k < avances.length; k++) {
      expect(avances[k], greaterThanOrEqualTo(avances[k - 1]));
    }
    expect(avances.last, 1);
    // Terminada, no queda nada para retomar.
    expect(await const UploadResumeStore().find(_leccion), isNull);
  });

  test('una parte que falla se reintenta, y la subida sigue', () async {
    final s3 = _S3()
      ..fallas[2] = [
        const PartUploadError('se cortó'),
        const PartUploadError('se cortó otra vez'),
      ];
    await _uploader(_api(), s3).run(onProgress: (_) {});
    expect(s3.intentos.where((n) => n == 2).length, 3);
    expect(s3.recibidas.keys.toList()..sort(), [1, 2, 3]);
  });

  test('una firma vencida (403) se pide de nuevo', () async {
    final api = _api();
    final s3 = _S3()..fallas[3] = [403];
    await _uploader(api, s3).run(onProgress: (_) {});
    expect(api.requested.where((r) => r == 'POST $_base/sign').length, 2);
    expect(api.cuerpos[api.requested.lastIndexOf('POST $_base/sign')]['partNumbers'], [3]);
  });

  test('si una parte no llega nunca, falla y deja anotado para retomar', () async {
    final s3 = _S3()
      ..fallas[1] = List.filled(4, const PartUploadError('sin conexión'), growable: true);
    await expectLater(
      _uploader(_api(), s3).run(onProgress: (_) {}),
      throwsA(isA<PartUploadError>()),
    );
    final anotada = await const UploadResumeStore().find(_leccion);
    expect(anotada?.uploadId, 'subida-1');
    expect(anotada?.fingerprint, _video.fingerprint);
  });

  test('retoma: con el mismo archivo, sube solo las partes que faltaban', () async {
    await const UploadResumeStore().save(PendingUpload(
      lessonId: _leccion,
      key: 'lessons/$_leccion/video.mp4',
      uploadId: 'subida-vieja',
      fingerprint: _video.fingerprint,
      fileName: _video.name,
      sizeBytes: 2500,
      partSizeBytes: _parte,
      partCount: 3,
      startedAt: DateTime.now(),
    ));
    final api = _api(extra: {
      '$_base/parts': {
        'parts': [
          {'partNumber': 1, 'sizeBytes': 1000},
          {'partNumber': 3, 'sizeBytes': 500},
        ],
      },
    });
    final s3 = _S3();
    UploadProgress? primero;

    await _uploader(api, s3).run(onProgress: (p) => primero ??= p);

    expect(s3.intentos, [2]);
    expect(api.requested, isNot(contains('POST $_base')));
    expect(primero!.resumed, isTrue);
    expect(primero!.sentBytes, 1500);
    final cerrar = api.cuerpos[api.requested.indexOf('POST $_base/complete')];
    expect(cerrar['uploadId'], 'subida-vieja');
  });

  test('lo anotado de OTRO archivo se cancela y se empieza de nuevo', () async {
    await const UploadResumeStore().save(PendingUpload(
      lessonId: _leccion,
      key: 'lessons/$_leccion/otro.mp4',
      uploadId: 'subida-de-otro',
      fingerprint: 'otro.mp4|99|1',
      fileName: 'otro.mp4',
      sizeBytes: 99,
      partSizeBytes: _parte,
      partCount: 1,
      startedAt: DateTime.now(),
    ));
    final api = _api(extra: {_base: <String, dynamic>{
      'key': 'lessons/$_leccion/video.mp4',
      'uploadId': 'subida-1',
      'partSizeBytes': _parte,
      'partCount': 3,
    }});
    await _uploader(api, _S3()).run(onProgress: (_) {});
    expect(api.requested, contains('DELETE $_base'));
    expect(api.requested, contains('POST $_base'));
  });

  test('si la subida anotada ya no existe en S3, empieza de cero', () async {
    await const UploadResumeStore().save(PendingUpload(
      lessonId: _leccion,
      key: 'lessons/$_leccion/video.mp4',
      uploadId: 'vencida',
      fingerprint: _video.fingerprint,
      fileName: _video.name,
      sizeBytes: 2500,
      partSizeBytes: _parte,
      partCount: 3,
      startedAt: DateTime.now(),
    ));
    final api = _api(notFound: {'$_base/parts'});
    final s3 = _S3();
    await _uploader(api, s3).run(onProgress: (_) {});
    expect(api.requested, contains('POST $_base'));
    expect(s3.recibidas.keys.toList()..sort(), [1, 2, 3]);
  });

  test('cancelar corta lo que está en vuelo, avisa al servidor y no deja nada anotado',
      () async {
    final api = _api();
    final s3 = _S3();
    final uploader = _uploader(api, s3);
    s3.alEmpezar = (parte) {
      if (parte.partNumber == 2) uploader.cancel();
    };
    await expectLater(
      uploader.run(onProgress: (_) {}),
      throwsA(isA<UploadCancelled>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(api.requested, contains('DELETE $_base'));
    expect(api.requested, isNot(contains('POST $_base/complete')));
    expect(await const UploadResumeStore().find(_leccion), isNull);
  });

  test('si al cerrar el servidor dice que falta una parte, la sube y vuelve a cerrar',
      () async {
    final api = _api();
    api.statuses['$_base/complete'] = 409;
    api.routes['$_base/complete'] = {
      'error': {
        'code': 'conflict',
        'message': 'Faltan 1 de 3 partes del video.',
        'details': {
          'missingParts': [2],
        },
      },
    };
    final s3 = _S3();
    s3.alEmpezar = (parte) {
      // La segunda vez que llega la parte 2, el servidor ya tiene todo.
      if (s3.intentos.where((n) => n == 2).length == 2) {
        api.statuses.remove('$_base/complete');
        api.routes['$_base/complete'] = {'id': _leccion, 'videoType': 'uploaded'};
      }
    };
    final leccion = await _uploader(api, s3).run(onProgress: (_) {});
    expect(leccion['videoType'], 'uploaded');
    expect(s3.intentos.where((n) => n == 2).length, 2);
    expect(api.requested.where((r) => r == 'POST $_base/complete').length, 2);
  });

  test('un 409 que no es por partes faltantes no se reintenta', () async {
    final api = _api();
    api.statuses['$_base/complete'] = 409;
    api.routes['$_base/complete'] = {
      'error': {'code': 'conflict', 'message': 'Esa subida no corresponde a esta lección.'},
    };
    await expectLater(
      _uploader(api, _S3()).run(onProgress: (_) {}),
      throwsA(isA<ConflictError>()),
    );
  });
}
