import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/widgets/uploaded_lesson_player.dart';
import 'package:enactus_platform/widgets/video_player_dialog.dart';

import 'helpers/fake_api.dart';
import 'helpers/fake_video_player.dart';

/// El video SUBIDO de una lección, de la portada al avance guardado.
///
/// El `VideoPlayerController` es el del paquete; lo falso es la plataforma
/// (`helpers/fake_video_player.dart`) y la API. Los ids tienen forma de uuid:
/// los cuerpos que se mandan quedan en el contrato cliente → servidor.

const _yo = 'a0000000-0000-4000-8000-0000000000a2';
const _curso = 'c0000000-0000-4000-8000-0000000000c2';
const _leccion = 'e0000000-0000-4000-8000-0000000000e2';
const _video = 'https://videos.prueba/lessons/$_leccion/video.mp4?Signature=x';
const _portada = 'https://videos.prueba/lessons/$_leccion/thumb.jpg?Signature=y';

final _subida = Lesson(
  id: _leccion,
  title: 'Clase grabada',
  type: LessonType.video,
  description: 'La clase del martes.',
  videoType: VideoSourceType.uploaded,
  videoS3Key: 'lessons/$_leccion/video.mp4',
  videoDurationSec: 212,
);

Map<String, Object?> _progreso({List<Map<String, Object?>> videos = const []}) => {
      'courseId': _curso,
      'courseName': 'Curso de prueba',
      'totalLessons': 1,
      'completedLessons': 0,
      'ratio': 0.0,
      'isComplete': false,
      'completedLessonIds': <String>[],
      'videoProgress': videos,
    };

FakeApi _api({Map<String, Object?>? progreso, String? portada = _portada}) =>
    FakeApi(routes: {
      '/students/$_yo/course-progress/$_curso': progreso ?? _progreso(),
      '/lessons/$_leccion/video-url': {
        'url': _video,
        'expiresInSeconds': 300,
        'thumbnailUrl': portada,
      },
      '/progress/lessons/$_leccion/video': {
        'lessonId': _leccion,
        'positionSec': 30,
        'furthestSec': 30,
        'durationSec': 212,
        'updatedAt': '2026-10-03T10:00:00.000Z',
      },
      '/progress/lessons/$_leccion/toggle': {
        'lessonId': _leccion,
        'completed': true,
        'course': {
          'courseId': _curso,
          'totalLessons': 1,
          'completedLessons': 1,
          'ratio': 1,
          'isComplete': true,
        },
        'rutaImpact': <Object>[],
      },
    });

Future<DataProvider> _abrir(
  WidgetTester tester,
  FakeApi fake, {
  bool trackProgress = true,
  Size size = const Size(1440, 900),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final data = DataProvider(fake.build())..setCurrentUser(_yo);
  data.courseProgress(_curso);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: data,
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => VideoPlayerDialog.show(context, _subida,
                courseId: _curso, trackProgress: trackProgress),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.tap(find.text('abrir'));
  await _settle(tester);
  return data;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Toca «reproducir» y espera a que el video quede listo.
Future<int> _reproducir(WidgetTester tester, FakeVideoPlayer video) async {
  await tester.tap(find.bySemanticsLabel(RegExp('Reproducir el video «Clase grabada»|Seguir viendo')));
  await _settle(tester);
  return video.ultimo;
}

Finder get _portadaImg => find.byWidgetPredicate(
    (w) => w is Image && w.image is NetworkImage && (w.image as NetworkImage).url == _portada);

void main() {
  late FakeVideoPlayer video;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    video = FakeVideoPlayer.install();
  });

  testWidgets('antes de tocar: la portada y la duración, sin cargar el video',
      (tester) async {
    final fake = _api();
    await _abrir(tester, fake);

    expect(_portadaImg, findsOneWidget);
    expect(find.text('3:32'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(video.urls, isEmpty);
  });

  testWidgets('sin portada se ve el fondo genérico, igual de prolijo', (tester) async {
    await _abrir(tester, _api(portada: null));
    expect(_portadaImg, findsNothing);
    expect(find.byIcon(Icons.smart_display_outlined), findsOneWidget);
  });

  testWidgets('al tocar carga la URL firmada, retoma donde quedó y reproduce',
      (tester) async {
    await _abrir(
      tester,
      _api(progreso: _progreso(videos: [
        {'lessonId': _leccion, 'positionSec': 125, 'furthestSec': 125, 'durationSec': 212},
      ])),
    );
    await _settle(tester);
    expect(find.text('Seguir desde 2:05'), findsOneWidget);

    await _reproducir(tester, video);
    expect(video.urls, [_video]);
    expect(video.llamadas, containsAllInOrder(['seek 125', 'play']));
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(find.byTooltip('Pausar (K)'), findsOneWidget);
  });

  testWidgets('pausar guarda la posición, con la duración del video', (tester) async {
    final fake = _api();
    await _abrir(tester, fake);
    final id = await _reproducir(tester, video);

    video.posicion(id, const Duration(seconds: 47));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.byTooltip('Pausar (K)'));
    await _settle(tester);

    final i = fake.requested.indexOf('PUT /progress/lessons/$_leccion/video');
    expect(i, isNot(-1));
    expect(fake.cuerpos[i], {'positionSec': 47, 'durationSec': 212});
  });

  testWidgets('pasar el 90% completa la lección una sola vez', (tester) async {
    final fake = _api();
    await _abrir(tester, fake);
    final id = await _reproducir(tester, video);

    video.posicion(id, const Duration(seconds: 192));
    await tester.pump(const Duration(milliseconds: 150));
    video.posicion(id, const Duration(seconds: 200));
    await tester.pump(const Duration(milliseconds: 150));
    await _settle(tester);

    expect(
        fake.requested.where((r) => r == 'POST /progress/lessons/$_leccion/toggle').length,
        1);
  });

  testWidgets('el teclado: espacio pausa, → adelanta 5 s, M silencia', (tester) async {
    await _abrir(tester, _api());
    final id = await _reproducir(tester, video);
    video.posicion(id, const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 150));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(video.llamadas, contains('seek 35'));

    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    expect(video.llamadas, contains('volume 0.0'));

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await _settle(tester);
    expect(video.llamadas.last, 'pause');
  });

  testWidgets('la velocidad va de 0,5× a 2×', (tester) async {
    await _abrir(tester, _api());
    await _reproducir(tester, video);

    await tester.tap(find.byTooltip('Velocidad de reproducción'));
    await _settle(tester);
    for (final etiqueta in ['0,5×', '0,75×', 'Normal (1×)', '1,25×', '1,5×', '1,75×', '2×']) {
      expect(find.text(etiqueta), findsOneWidget, reason: etiqueta);
    }
    await tester.tap(find.text('1,5×'));
    await _settle(tester);
    expect(video.llamadas, contains('speed 1.5'));
  });

  testWidgets('pantalla completa con F, y se sale con el mismo botón', (tester) async {
    await _abrir(tester, _api());
    await _reproducir(tester, video);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await _settle(tester);
    expect(find.byTooltip('Salir de pantalla completa (F)'), findsOneWidget);
    // Un solo lugar a la vez para el video.
    expect(find.byType(VideoPlayer), findsOneWidget);

    await tester.tap(find.byTooltip('Salir de pantalla completa (F)'));
    await _settle(tester);
    expect(find.byTooltip('Pantalla completa (F)'), findsOneWidget);
    // Volver no cierra el diálogo de la lección, y el teclado sigue andando.
    expect(find.text('Clase grabada'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await _settle(tester);
    expect(video.llamadas.last, 'pause');
  });

  testWidgets('cerrar el diálogo guarda lo último que vio', (tester) async {
    final fake = _api();
    await _abrir(tester, fake);
    final id = await _reproducir(tester, video);
    video.posicion(id, const Duration(seconds: 61));
    await tester.pump(const Duration(milliseconds: 150));

    await tester.tap(find.byTooltip('Cerrar'));
    // La animación de salida del diálogo, y después el `dispose`.
    for (var k = 0; k < 10; k++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final i = fake.requested.lastIndexOf('PUT /progress/lessons/$_leccion/video');
    expect(i, isNot(-1));
    expect(fake.cuerpos[i]['positionSec'], 61);
    expect(video.llamadas, contains('dispose'));
  });

  testWidgets('el equipo mirando un curso no escribe avance', (tester) async {
    final fake = _api();
    await _abrir(tester, fake, trackProgress: false);
    final id = await _reproducir(tester, video);
    video.posicion(id, const Duration(seconds: 200));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.byTooltip('Pausar (K)'));
    await _settle(tester);
    expect(fake.requested.where((r) => r.contains('/progress/')), isEmpty);
  });

  testWidgets('si no carga, lo dice y «Reintentar» pide una URL nueva', (tester) async {
    final fake = _api();
    await _abrir(tester, fake);
    video.fallarAlCrear = true;
    await _reproducir(tester, video);

    expect(find.text('No se pudo cargar el video'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await _settle(tester);
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(video.urls.length, 2);
  });

  testWidgets('el buffer se ve como una ruedita sobre el video', (tester) async {
    await _abrir(tester, _api());
    final id = await _reproducir(tester, video);
    video.evento(id, VideoEvent(eventType: VideoEventType.bufferingStart));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    video.evento(id, VideoEvent(eventType: VideoEventType.bufferingEnd));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('16:9 con tope de 960 px en una pantalla grande', (tester) async {
    await _abrir(tester, _api(), size: const Size(2560, 1440));
    final caja = tester.getRect(find.byType(UploadedLessonPlayer));
    expect(caja.width, VideoPlayerDialog.maxVideoWidth);
    expect(caja.width / caja.height, closeTo(16 / 9, 0.01));
  });

  testWidgets('en un teléfono va de borde a borde', (tester) async {
    await _abrir(tester, _api(), size: const Size(390, 844));
    final caja = tester.getRect(find.byType(UploadedLessonPlayer));
    expect(caja.width, 390);
    expect(caja.height, closeTo(390 * 9 / 16, 0.5));
  });
}
