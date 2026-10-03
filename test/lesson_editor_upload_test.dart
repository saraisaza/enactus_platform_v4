import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/video_upload/picked_video.dart';
import 'package:enactus_platform/services/video_upload/upload_types.dart';
import 'package:enactus_platform/services/video_upload/video_upload_controller.dart';
import 'package:enactus_platform/views/lxd/lesson_editor.dart';

import 'helpers/fake_api.dart';
import 'helpers/fake_video_player.dart';
import 'helpers/mp4_sintetico.dart';

/// «Subir video» en el editor de lección: una opción aparte de YouTube.
///
/// Lo que el LXD ve (la zona para soltar, la revisión del archivo, la
/// portada, la barra) y lo que viaja: la lección, la subida por partes y el
/// cierre con duración y portada. El archivo, el selector, el navegador que
/// lo abre y S3 son dobles; el editor, el `DataProvider` y el motor de subida
/// son los de verdad. Ids con forma de uuid: estos cuerpos van al contrato.

const _curso = 'c0000000-0000-4000-8000-0000000000c3';
const _modulo = 'd0000000-0000-4000-8000-0000000000d3';
const _leccion = 'e0000000-0000-4000-8000-0000000000e3';
const _subidas = '/lessons/$_leccion/video-uploads';

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

const _leccionJson = {
  'id': _leccion,
  'title': 'Clase grabada',
  'type': 'video',
  'orderIndex': 1,
};

FakeApi _api({Map<String, Object?> extra = const {}}) => FakeApi(routes: {
      '/modules/$_modulo/lessons': _leccionJson,
      '/lessons/$_leccion': _leccionJson,
      _subidas: {
        'key': 'lessons/$_leccion/video.mp4',
        'uploadId': 'subida-1',
        'partSizeBytes': 1000,
        'partCount': 3,
      },
      '$_subidas/sign': {
        'parts': [
          for (var n = 1; n <= 3; n++)
            {'partNumber': n, 'url': 'https://s3.prueba/parte/$n'},
        ],
        'expiresInSeconds': 3600,
      },
      '$_subidas/complete': {
        ..._leccionJson,
        'videoType': 'uploaded',
        'videoS3Key': 'lessons/$_leccion/video.mp4',
      },
      '/lessons/$_leccion/video-thumbnail-upload-url': {
        'key': 'lessons/$_leccion/thumb-1.jpg',
        'uploadUrl': 'https://s3.prueba/portada',
      },
      '/lessons/$_leccion/video-thumbnail': _leccionJson,
      '/lessons/$_leccion/video-url': {
        'url': 'https://videos.prueba/lessons/$_leccion/video.mp4?Signature=x',
        'expiresInSeconds': 300,
        'thumbnailUrl': null,
      },
      '/courses/$_curso': {
        'id': _curso,
        'name': 'Curso de prueba',
        'modules': <Object>[],
      },
      ...extra,
    });

/// Un MP4 de 2500 bytes que pasa la revisión (H.264 con AAC).
PickedVideo _bueno({String nombre = 'clase 1.mp4'}) {
  final base = mp4(audio: entradaMp4a(), datos: 100);
  final bytes = Uint8List(2500)..setRange(0, base.length, base);
  // El resto del archivo son "datos": se agranda la caja mdat para cubrirlo.
  return MemoryPickedVideo(nombre, _conTamano(bytes, base.length));
}

/// Estira la última caja (`mdat`) para que el archivo entero sea válido.
Uint8List _conTamano(Uint8List bytes, int usados) {
  final mdatInicio = usados - (8 + 100);
  final nuevo = bytes.length - mdatInicio;
  bytes.setRange(mdatInicio, mdatInicio + 4, u32(nuevo));
  return bytes;
}

PickedVideo _hevc() => MemoryPickedVideo('iphone.mp4', mp4(video: 'hvc1', audio: entradaMp4a()));

class _Dobles {
  PickedVideo? siguiente;
  final List<int> partes = [];
  final List<String> portadas = [];
  Completer<int>? retener;
  int fallasPorParte = 0;

  VideoUploadController crear() => VideoUploadController(
        picker: () async => siguiente,
        prober: (video) async => VideoProbe(
          duration: const Duration(seconds: 754),
          width: 1280,
          height: 720,
          frameJpeg: _png,
        ),
        sender: (parte, {required onProgress, required abort}) async {
          final retenida = retener;
          if (retenida != null) {
            final quitar = abort.onAbort(() {
              if (!retenida.isCompleted) retenida.completeError(const UploadCancelled());
            });
            try {
              return await retenida.future;
            } finally {
              quitar();
            }
          }
          if (fallasPorParte > 0) {
            fallasPorParte--;
            throw const PartUploadError('Se cortó la conexión mientras subía el video.');
          }
          onProgress(parte.sizeBytes);
          partes.add(parte.partNumber);
          return 200;
        },
        coverSender: (url, bytes, type) async => portadas.add('$url $type'),
      );
}

Future<void> _abrir(WidgetTester tester, FakeApi fake, {Lesson? lesson}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 1100);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: DataProvider(fake.build()),
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLessonEditor(context,
                courseId: _curso, moduleId: _modulo, lesson: lesson),
            child: const Text('editar'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('editar'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _settle(WidgetTester tester, {int veces = 8}) async {
  for (var i = 0; i < veces; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _elegirSubir(WidgetTester tester) async {
  await tester.tap(find.text('Subir video'));
  await tester.pump();
}

Future<void> _elegirArchivo(WidgetTester tester) async {
  await tester.tap(find.text('Elegir video'));
  await _settle(tester);
}

void main() {
  late _Dobles dobles;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // La sesión vive en el almacenamiento seguro del teléfono: sin
    // simularlo, el primer pedido a la API espera una respuesta que no llega.
    useFakeTokenStorage();
    FakeVideoPlayer.install();
    dobles = _Dobles();
    VideoUploadController.debugCreate = dobles.crear;
  });
  tearDown(() => VideoUploadController.debugCreate = null);

  testWidgets('«Subir video» es una opción aparte de «Pegar link de YouTube»',
      (tester) async {
    await _abrir(tester, _api());
    expect(find.text('Pegar link de YouTube'), findsOneWidget);
    expect(find.text('Subir video'), findsOneWidget);
    expect(find.byKey(const ValueKey('lesson-video-url')), findsOneWidget);

    await _elegirSubir(tester);
    expect(find.byKey(const ValueKey('lesson-video-url')), findsNothing);
    expect(find.text('Arrastre el video aquí'), findsOneWidget);
    expect(find.text('Elegir video'), findsOneWidget);
    expect(find.text('MP4 (H.264 con audio AAC) · hasta 500 MB'), findsOneWidget);
  });

  testWidgets('un video que no sirve se explica, y no deja crear la lección',
      (tester) async {
    final fake = _api();
    await _abrir(tester, fake);
    await tester.enterText(find.widgetWithText(TextField, 'Título'), 'Clase');
    await _elegirSubir(tester);
    dobles.siguiente = _hevc();
    await _elegirArchivo(tester);

    expect(find.textContaining('H.265 (HEVC)'), findsWidgets);
    expect(find.text('Elegir otro video'), findsOneWidget);

    await tester.tap(find.text('Guardar'));
    await _settle(tester);
    expect(fake.requested.where((r) => r.startsWith('POST /modules/')), isEmpty);
  });

  testWidgets('elige, revisa, completa la duración y sube al guardar',
      (tester) async {
    final fake = _api();
    await _abrir(tester, fake);
    await tester.enterText(find.widgetWithText(TextField, 'Título'), 'Clase grabada');
    await _elegirSubir(tester);
    dobles.siguiente = _bueno();
    await _elegirArchivo(tester);

    expect(find.textContaining('clase 1.mp4', findRichText: true), findsOneWidget);
    expect(find.textContaining('12:34', findRichText: true), findsWidgets);
    expect(find.text('Portada tomada del video'), findsOneWidget);
    // 754 s → 13 minutos, sin que nadie lo escriba.
    expect(find.widgetWithText(TextField, '13'), findsOneWidget);

    await tester.tap(find.text('Guardar'));
    await _settle(tester, veces: 20);

    final pedidos = fake.requested;
    expect(pedidos, containsAllInOrder([
      'POST /modules/$_modulo/lessons',
      'POST $_subidas',
      'POST $_subidas/sign',
      'POST /lessons/$_leccion/video-thumbnail-upload-url',
      'POST $_subidas/complete',
    ]));
    expect(dobles.partes..sort(), [1, 2, 3]);
    expect(dobles.portadas, ['https://s3.prueba/portada image/jpeg']);
    expect(fake.cuerpos[pedidos.indexOf('POST /modules/$_modulo/lessons')]['durationMin'], 13);
    expect(fake.cuerpos[pedidos.indexOf('POST $_subidas/complete')], {
      'key': 'lessons/$_leccion/video.mp4',
      'uploadId': 'subida-1',
      'fileName': 'clase 1.mp4',
      'sizeBytes': 2500,
      'durationSec': 754,
      'thumbnailKey': 'lessons/$_leccion/thumb-1.jpg',
    });
    // Se cerró el diálogo: quedó guardada.
    expect(find.text('Nueva lección'), findsNothing);
  });

  testWidgets('cancelar la subida no deja la lección nueva a medias',
      (tester) async {
    final fake = _api();
    await _abrir(tester, fake);
    await tester.enterText(find.widgetWithText(TextField, 'Título'), 'Clase');
    await _elegirSubir(tester);
    dobles.siguiente = _bueno();
    await _elegirArchivo(tester);
    dobles.retener = Completer<int>();

    await tester.tap(find.text('Guardar'));
    await _settle(tester);
    expect(find.textContaining('Subiendo el video…'), findsOneWidget);
    expect(find.text('No cierre esta ventana hasta que termine.'), findsOneWidget);

    // El de las acciones del diálogo, siempre a la vista (el del panel puede
    // quedar abajo, fuera de la parte visible).
    await tester.tap(find.text('Cancelar subida').last);
    await _settle(tester, veces: 12);

    expect(fake.requested, contains('DELETE $_subidas'));
    expect(fake.requested, contains('DELETE /lessons/$_leccion'));
    expect(fake.requested, isNot(contains('POST $_subidas/complete')));
    expect(find.textContaining('Se canceló la subida'), findsOneWidget);
    // El diálogo sigue abierto: puede elegir otro archivo o cerrar.
    expect(find.text('Nueva lección'), findsOneWidget);
  });

  testWidgets('si se corta, guardar de nuevo retoma sin crear otra lección',
      (tester) async {
    final fake = _api(extra: {
      '$_subidas/parts': {
        'parts': [
          {'partNumber': 1, 'sizeBytes': 1000},
        ],
      },
    });
    await _abrir(tester, fake);
    await tester.enterText(find.widgetWithText(TextField, 'Título'), 'Clase');
    await _elegirSubir(tester);
    dobles.siguiente = _bueno();
    await _elegirArchivo(tester);
    dobles.fallasPorParte = 100; // ninguna parte llega

    await tester.tap(find.text('Guardar'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(seconds: 1)); // las esperas entre reintentos
    }
    expect(find.textContaining('No se pudo terminar la subida'), findsOneWidget);
    expect(find.textContaining('guarde de nuevo y sigue desde donde iba'), findsOneWidget);

    dobles.fallasPorParte = 0;
    await tester.tap(find.text('Guardar'));
    await _settle(tester, veces: 20);

    expect(fake.requested.where((r) => r == 'POST /modules/$_modulo/lessons').length, 1);
    expect(fake.requested, contains('PATCH /lessons/$_leccion'));
    expect(fake.requested, contains('GET $_subidas/parts'));
    // La 1 ya estaba en S3: solo suben la 2 y la 3.
    expect(dobles.partes..sort(), [2, 3]);
    expect(fake.requested, contains('POST $_subidas/complete'));
  });

  testWidgets('una lección con video subido abre en «Subir video», con su video',
      (tester) async {
    await _abrir(
      tester,
      _api(),
      lesson: Lesson(
        id: _leccion,
        title: 'Clase grabada',
        type: LessonType.video,
        videoType: VideoSourceType.uploaded,
        videoS3Key: 'lessons/$_leccion/video.mp4',
        videoDurationSec: 754,
        videoOriginalName: 'clase-martes.mp4',
        videoSizeBytes: 245 * 1024 * 1024,
      ),
    );
    await _settle(tester);
    expect(find.textContaining('Video actual: clase-martes.mp4 · 245 MB · 12:34'),
        findsOneWidget);
    expect(find.text('Para reemplazarlo, arrastre otro video aquí'), findsOneWidget);
    expect(find.text('Ponerle portada'), findsOneWidget);
    expect(find.byKey(const ValueKey('lesson-video-url')), findsNothing);
  });
}
