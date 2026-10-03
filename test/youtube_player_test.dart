import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/widgets/video_player_dialog.dart';
import 'package:enactus_platform/widgets/youtube_lesson_player.dart';

import 'helpers/fake_api.dart';
import 'helpers/fake_youtube_webview.dart';

/// El reproductor de YouTube de una lección, de la miniatura al avance
/// guardado.
///
/// Lo que se ejercita es el reproductor DEL PAQUETE —su controlador y su
/// manejador de eventos— contra una página falsa que habla su mismo protocolo
/// (`helpers/fake_youtube_webview.dart`), y el `DataProvider` real contra la
/// API falsa. Lo único que no se puede probar acá es que el iframe pinte en un
/// navegador de verdad con la CSP de producción: eso está anotado en
/// MIGRACION_FRONT.md como verificación pendiente, no dado por hecho.
///
/// Los ids tienen forma de uuid a propósito: los cuerpos que se mandan acá
/// quedan en el contrato cliente → servidor, y el servidor los recibe en
/// `/:id`.

const _yo = 'a0000000-0000-4000-8000-0000000000a1';
const _curso = 'c0000000-0000-4000-8000-0000000000c1';
const _leccion = 'e0000000-0000-4000-8000-0000000000e1';
const _id = 'dQw4w9WgXcQ';

Lesson _youtube({
  VideoSourceType type = VideoSourceType.youtube,
  String? url,
}) =>
    Lesson(
      id: _leccion,
      title: 'Charla de apertura',
      type: LessonType.video,
      description: 'Una charla corta para empezar.',
      videoType: type,
      videoYoutubeId: type == VideoSourceType.youtube ? _id : null,
      videoUrl: url,
    );

Map<String, Object?> _progreso({
  List<Map<String, Object?>> videos = const [],
  List<String> completas = const [],
}) =>
    {
      'courseId': _curso,
      'courseName': 'Curso de prueba',
      'totalLessons': 1,
      'completedLessons': completas.length,
      'ratio': completas.isEmpty ? 0.0 : 1.0,
      'isComplete': completas.isNotEmpty,
      'completedLessonIds': completas,
      'videoProgress': videos,
    };

FakeApi _api({Map<String, Object?>? progreso}) => FakeApi(routes: {
      '/students/$_yo/course-progress/$_curso': progreso ?? _progreso(),
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

/// Monta una pantalla con un botón que abre el diálogo, como lo abre la
/// lista de lecciones. Devuelve el provider para mirar su estado.
Future<DataProvider> _abrir(
  WidgetTester tester,
  FakeApi fake, {
  Lesson? lesson,
  bool trackProgress = true,
  Size size = const Size(1440, 900),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final data = DataProvider(fake.build())..setCurrentUser(_yo);
  // El progreso del curso ya está cargado cuando alguien abre una lección:
  // lo pidió la pantalla del curso.
  data.courseProgress(_curso);

  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: data,
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => VideoPlayerDialog.show(
              context,
              lesson ?? _youtube(),
              courseId: _curso,
              trackProgress: trackProgress,
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.tap(find.text('abrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return data;
}

/// Toca «reproducir» y deja que el reproductor del paquete arranque contra
/// la página falsa.
Future<FakeYoutubePage> _reproducir(
  WidgetTester tester,
  FakeYoutubeWebView web,
) async {
  await tester.tap(find.byIcon(Icons.play_arrow_rounded));
  await tester.pump();
  await tester.pump();
  final page = web.page..videoId = _id;
  page.ready();
  await tester.pump();
  await tester.pump();
  return page;
}

/// Unos pumps cortos: alcanzan para que respondan la API falsa y los
/// futures del reproductor.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder get _miniatura => find.byWidgetPredicate((w) =>
    w is Image &&
    w.image is NetworkImage &&
    (w.image as NetworkImage).url ==
        'https://i.ytimg.com/vi/$_id/hqdefault.jpg');

void main() {
  late FakeYoutubeWebView web;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    web = FakeYoutubeWebView.install();
  });

  group('antes de tocar: solo la miniatura', () {
    testWidgets('muestra la miniatura y el botón, sin crear el reproductor',
        (tester) async {
      await _abrir(tester, _api());

      expect(_miniatura, findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('YouTube'), findsOneWidget);
      // Ni el reproductor ni su WebView existen todavía: YouTube no sabe
      // nada de quien abrió la lección sin mirar el video.
      expect(find.byType(YoutubePlayer), findsNothing);
      expect(web.pages, isEmpty);
    });

    testWidgets('con avance guardado ofrece seguir desde donde quedó',
        (tester) async {
      await _abrir(
        tester,
        _api(
          progreso: _progreso(videos: [
            {'lessonId': _leccion, 'positionSec': 125, 'furthestSec': 150, 'durationSec': 212},
          ]),
        ),
      );
      await _settle(tester);

      expect(find.text('Seguir desde 2:05'), findsOneWidget);
      expect(find.text('Visto 71%'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Seguir viendo «Charla de apertura» desde 2:05')),
          findsOneWidget);
    });

    testWidgets('una lección vieja con el ENLACE de YouTube usa el mismo reproductor',
        (tester) async {
      await _abrir(
        tester,
        _api(),
        lesson: _youtube(
          type: VideoSourceType.external,
          url: 'https://www.youtube.com/watch?v=$_id&t=12s',
        ),
      );
      expect(_miniatura, findsOneWidget);
      expect(find.text('Abrir video'), findsNothing);
    });
  });

  group('al tocar: reproduce, retoma y guarda', () {
    testWidgets('arranca desde la posición guardada', (tester) async {
      await _abrir(
        tester,
        _api(
          progreso: _progreso(videos: [
            {'lessonId': _leccion, 'positionSec': 125, 'furthestSec': 125, 'durationSec': 212},
          ]),
        ),
      );
      await _settle(tester);
      final page = await _reproducir(tester, web);

      expect(find.byType(YoutubePlayer), findsOneWidget);
      final cue = page.commands.firstWhere((c) => c.contains('cueVideoById'));
      expect(cue, contains('"videoId":"$_id"'));
      expect(cue, contains('"startSeconds":125'));

      // Listo para reproducir: se le pide play UNA vez (si el navegador no
      // lo permite, queda el botón de YouTube a la vista).
      page.state(5);
      await tester.pump();
      page.state(5);
      await tester.pump();
      expect(page.commands.where((c) => c.contains('playVideo')).length, 1);
    });

    testWidgets('pausar guarda la posición, con la duración del video',
        (tester) async {
      final fake = _api();
      await _abrir(tester, fake);
      final page = await _reproducir(tester, web);

      page.state(1); // reproduciendo: el paquete pide la duración
      await _settle(tester);
      page.position(30.4);
      page.state(2); // pausa
      await _settle(tester);

      final i = fake.requested.indexOf('PUT /progress/lessons/$_leccion/video');
      expect(i, isNot(-1));
      expect(fake.cuerpos[i], {'positionSec': 30, 'durationSec': 212});
    });

    testWidgets('pasar el 90% completa la lección una sola vez', (tester) async {
      final fake = _api();
      await _abrir(tester, fake);
      final page = await _reproducir(tester, web);

      page.state(1);
      await _settle(tester);
      page.position(150);
      await _settle(tester);
      expect(find.text('Lección completada'), findsNothing);

      page.position(191); // 191 / 212 = 90.1%
      await _settle(tester);
      page.position(200);
      page.state(0); // y además termina
      await _settle(tester);

      expect(
        fake.requested.where((r) => r == 'POST /progress/lessons/$_leccion/toggle'),
        hasLength(1),
        reason: 'un segundo toggle la DESMARCARÍA',
      );
      expect(find.text('Lección completada'), findsOneWidget);
    });

    testWidgets('si ya estaba completa no la toca', (tester) async {
      final fake = _api(progreso: _progreso(completas: [_leccion]));
      await _abrir(tester, fake);
      await _settle(tester);
      final page = await _reproducir(tester, web);

      page.state(1);
      await _settle(tester);
      page.position(205);
      page.state(0);
      await _settle(tester);

      expect(fake.requested.where((r) => r.endsWith('/toggle')), isEmpty);
    });

    testWidgets('cerrar el diálogo guarda lo último que vio', (tester) async {
      final fake = _api();
      final data = await _abrir(tester, fake);
      final page = await _reproducir(tester, web);

      page.state(1);
      await _settle(tester);
      page.position(47);
      await _settle(tester);
      expect(fake.requested.where((r) => r.startsWith('PUT')), isEmpty);

      await tester.tap(find.byTooltip('Cerrar'));
      // La transición de salida del diálogo, y recién después el `dispose`
      // del reproductor, que es el que guarda.
      await _settle(tester);
      await _settle(tester);

      final puts = [
        for (var i = 0; i < fake.requested.length; i++)
          if (fake.requested[i] == 'PUT /progress/lessons/$_leccion/video')
            fake.cuerpos[i],
      ];
      expect(puts, [
        {'positionSec': 47, 'durationSec': 212},
      ]);
      // La lista de lecciones lo ve sin pedir nada al servidor.
      expect(data.myVideoProgress(_leccion)?.positionSec, 47);
    });

    testWidgets('sin seguimiento (el equipo mirando un curso) no escribe nada',
        (tester) async {
      final fake = _api();
      await _abrir(tester, fake, trackProgress: false);
      final page = await _reproducir(tester, web);

      page.state(1);
      await _settle(tester);
      page.position(200);
      page.state(2);
      page.state(0);
      await _settle(tester);
      await tester.tap(find.byTooltip('Cerrar'));
      await _settle(tester);

      expect(fake.requested.where((r) => r.contains('/progress/')), isEmpty);
      expect(find.textContaining('Tu avance se guarda'), findsNothing);
    });
  });

  group('cuando no se puede ver', () {
    testWidgets('si el reproductor no carga, lo dice y ofrece verlo en YouTube',
        (tester) async {
      // Es lo que pasaría en el navegador con la CSP bloqueando el script de
      // YouTube: el reproductor nunca avisa que está listo.
      await _abrir(tester, _api());
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(find.text('Cargando el video…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 21));
      expect(find.text('No se pudo cargar el reproductor'), findsOneWidget);
      expect(find.text('Ver en YouTube'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      // El paquete espera su "listo" 30 s antes de rendirse: se deja correr
      // para no dejar temporizadores vivos al terminar la prueba.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('un video que su dueño no deja embeber se explica',
        (tester) async {
      await _abrir(tester, _api());
      final page = await _reproducir(tester, web);

      page.send('PlayerError', 150);
      await _settle(tester);

      expect(find.text('Este video solo se puede ver en YouTube'), findsOneWidget);
      expect(find.text('Ver en YouTube'), findsOneWidget);
      // Reintentar no cambia la decisión del dueño del video.
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('un video borrado lo dice, sin botones que no sirven',
        (tester) async {
      await _abrir(tester, _api());
      final page = await _reproducir(tester, web);

      page.send('PlayerError', 100);
      await _settle(tester);

      expect(find.text('Este video ya no está disponible'), findsOneWidget);
      expect(find.text('Ver en YouTube'), findsNothing);
    });
  });

  group('16:9 en cualquier pantalla', () {
    Future<Rect> rectDelVideo(WidgetTester tester, Size size) async {
      await _abrir(tester, _api(), trackProgress: false, size: size);
      final rect = tester.getRect(find.byType(YoutubeLessonPlayer));
      expect(rect.width / rect.height, closeTo(16 / 9, 0.01));
      return rect;
    }

    testWidgets('teléfono vertical: de borde a borde, sin esquinas redondeadas',
        (tester) async {
      final rect = await rectDelVideo(tester, const Size(390, 844));
      expect(rect.width, 390);
      expect(rect.left, 0);
      final clip = tester.widget<ClipRRect>(find.descendant(
          of: find.byType(YoutubeLessonPlayer), matching: find.byType(ClipRRect)));
      expect(clip.borderRadius, BorderRadius.zero);
    });

    testWidgets('teléfono acostado: entra entero a lo alto', (tester) async {
      final rect = await rectDelVideo(tester, const Size(844, 390));
      expect(rect.bottom, lessThanOrEqualTo(390));
      expect(rect.width, lessThan(844));
    });

    testWidgets('laptop apaisada: el límite es el alto, no el ancho',
        (tester) async {
      // Un diálogo que solo mirara el ancho dejaría los controles del
      // reproductor debajo del borde de la pantalla.
      final rect = await rectDelVideo(tester, const Size(1366, 657));
      expect(rect.bottom, lessThanOrEqualTo(657));
      expect(rect.top, greaterThanOrEqualTo(0));
    });

    testWidgets('escritorio grande: crece, pero con tope', (tester) async {
      final rect = await rectDelVideo(tester, const Size(1920, 1080));
      expect(rect.width, VideoPlayerDialog.maxVideoWidth);
      expect(rect.bottom, lessThanOrEqualTo(1080));
    });
  });
}
