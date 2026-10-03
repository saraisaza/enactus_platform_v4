import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/views/lxd/lesson_editor.dart';
import 'package:enactus_platform/widgets/youtube_lesson_player.dart';

import 'helpers/fake_api.dart';
import 'helpers/fake_youtube_webview.dart';

/// El LXD pega un enlace de YouTube en la lección y se guarda SOLO el id.
///
/// Se prueba lo que el LXD ve —la validación mientras escribe y la vista
/// previa— y lo que de verdad viaja a la API: que el cuerpo lleve el id y no
/// el enlace, y que un enlace inválido no llegue a crear una lección a medias.
/// Los ids son uuid porque estos cuerpos quedan en el contrato cliente →
/// servidor.

const _curso = 'c0000000-0000-4000-8000-0000000000c2';
const _modulo = 'd0000000-0000-4000-8000-0000000000d2';
const _leccion = 'e0000000-0000-4000-8000-0000000000e2';
const _id = 'dQw4w9WgXcQ';

const _leccionJson = {
  'id': _leccion,
  'title': 'Charla de apertura',
  'type': 'video',
  'orderIndex': 1,
};

FakeApi _api() => FakeApi(routes: {
      '/modules/$_modulo/lessons': _leccionJson,
      '/lessons/$_leccion': _leccionJson,
      '/lessons/$_leccion/video-youtube': {
        ..._leccionJson,
        'videoType': 'youtube',
        'videoYoutubeId': _id,
      },
      '/lessons/$_leccion/video-external': {
        ..._leccionJson,
        'videoType': 'external',
        'videoUrl': 'https://vimeo.com/76979871',
      },
      '/courses/$_curso': {
        'id': _curso,
        'name': 'Curso de prueba',
        'modules': <Object>[],
      },
    });

Future<void> _abrirEditor(WidgetTester tester, FakeApi fake,
    {Lesson? lesson}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 1000);
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

Finder get _campoVideo => find.byKey(const ValueKey('lesson-video-url'));

Future<void> _escribir(WidgetTester tester, String titulo, String enlace) async {
  await tester.enterText(find.widgetWithText(TextField, 'Título'), titulo);
  await tester.enterText(_campoVideo, enlace);
  await tester.pump();
}

Future<void> _guardar(WidgetTester tester) async {
  await tester.tap(find.text('Guardar'));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // La sesión vive en el almacenamiento seguro del teléfono: sin
    // simularlo, el primer pedido a la API espera una respuesta que no llega.
    useFakeTokenStorage();
    FakeYoutubeWebView.install();
  });

  testWidgets('un enlace de YouTube se reconoce al pegarlo y muestra la vista previa',
      (tester) async {
    await _abrirEditor(tester, _api());
    await _escribir(tester, 'Charla', 'https://youtu.be/$_id?si=rastreo123');

    expect(find.textContaining('Se guarda solo su id ($_id)'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    // La vista previa es el MISMO reproductor que ven los estudiantes, sin
    // seguimiento: así el LXD descubre antes de publicar si el dueño del
    // video no deja verlo fuera de YouTube.
    final vista = tester.widget<YoutubeLessonPlayer>(find.byType(YoutubeLessonPlayer));
    expect(vista.videoId, _id);
    expect(vista.onProgress, isNull);
    expect(vista.onWatched, isNull);
  });

  testWidgets('la vista previa se puede reproducir dentro del diálogo del editor',
      (tester) async {
    // El `AlertDialog` del editor pide medidas intrínsecas a todo su
    // contenido, y el reproductor (la carátula, y el del paquete en
    // Android/iOS) usa `LayoutBuilder`, que no sabe darlas. Antes del arreglo
    // esto tiraba el diálogo entero apenas aparecía la vista previa.
    final web = FakeYoutubeWebView.install();
    await _abrirEditor(tester, _api());
    await _escribir(tester, 'Charla', 'https://youtu.be/$_id');

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump();
    web.page.ready();
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(YoutubePlayer), findsOneWidget);
    expect(web.page.commands.single, contains('"videoId":"$_id"'));
  });

  testWidgets('un canal se rechaza y no se crea ninguna lección', (tester) async {
    final fake = _api();
    await _abrirEditor(tester, fake);
    await _escribir(tester, 'Charla', 'https://www.youtube.com/@canalEducativo');

    // El aviso aparece al escribir, no después de un 400.
    expect(find.textContaining('no de un video'), findsWidgets);
    expect(find.byType(YoutubeLessonPlayer), findsNothing);

    await _guardar(tester);
    // Ni la lección: un enlace malo detectado DESPUÉS de crearla la dejaría
    // guardada sin video.
    expect(fake.requested.where((r) => r.startsWith('POST')), isEmpty);
    expect(find.text('Guardar'), findsOneWidget); // el editor sigue abierto
  });

  testWidgets('al guardar viaja el id y nada más que el id', (tester) async {
    final fake = _api();
    await _abrirEditor(tester, fake);
    await _escribir(tester, 'Charla de apertura',
        'https://www.youtube.com/watch?v=$_id&t=42s&list=PL123');
    await _guardar(tester);

    expect(fake.requested, containsAllInOrder([
      'POST /modules/$_modulo/lessons',
      'POST /lessons/$_leccion/video-youtube',
    ]));
    final i = fake.requested.indexOf('POST /lessons/$_leccion/video-youtube');
    expect(fake.cuerpos[i], {'videoId': _id});
    expect(fake.requested.any((r) => r.contains('video-external')), isFalse);
  });

  testWidgets('al editar una lección de YouTube se ve su enlace, y guarda igual',
      (tester) async {
    final fake = _api();
    await _abrirEditor(
      tester,
      fake,
      lesson: const Lesson(
        id: _leccion,
        title: 'Charla de apertura',
        type: LessonType.video,
        videoType: VideoSourceType.youtube,
        videoYoutubeId: _id,
      ),
    );

    final campo = tester.widget<TextField>(_campoVideo);
    expect(campo.controller?.text, 'https://www.youtube.com/watch?v=$_id');

    await _guardar(tester);
    final i = fake.requested.indexOf('POST /lessons/$_leccion/video-youtube');
    expect(fake.cuerpos[i], {'videoId': _id});
  });

  testWidgets('Vimeo se sigue guardando como enlace', (tester) async {
    final fake = _api();
    await _abrirEditor(tester, fake);
    await _escribir(tester, 'Charla', 'https://vimeo.com/76979871');
    expect(find.textContaining('Enlace de Vimeo'), findsOneWidget);

    await _guardar(tester);
    final i = fake.requested.indexOf('POST /lessons/$_leccion/video-external');
    expect(fake.cuerpos[i], {'url': 'https://vimeo.com/76979871'});
  });
}
