// El video en la app instalada: el teléfono puede girarse mientras se ve.
//
// En el teléfono la app es vertical (`utils/orientacion.dart`): girada, el
// diseño pasaba al de tablet en una pantalla de 360 dp de alto. Pero un video
// se ve acostado. Estas pruebas fijan el trato: al abrir el video se permite
// cualquier orientación, y al cerrarlo el teléfono vuelve a vertical.
//
// Corren fuera del navegador, como la app. El reproductor en sí lo prueban
// `video_player_test.dart`, `youtube_player_test.dart` y
// `uploaded_player_test.dart`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/widgets/video_player_dialog.dart';

import 'helpers/fake_api.dart';

const _leccion = Lesson(
  id: 'lec-1',
  title: 'Cómo validar una idea',
  type: LessonType.video,
  orderIndex: 1,
);

/// Lo que la app le pide al sistema sobre la orientación, en orden.
List<List<String>> _orientaciones(WidgetTester tester) {
  final pedidas = <List<String>>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (llamada) async {
      if (llamada.method == 'SystemChrome.setPreferredOrientations') {
        pedidas.add((llamada.arguments as List).cast<String>());
      }
      return null;
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return pedidas;
}

Future<void> _abrir(WidgetTester tester) async {
  useFakeTokenStorage();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final data = DataProvider(FakeApi().build());
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: data,
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => VideoPlayerDialog.show(context, _leccion),
            child: const Text('ver'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('ver'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('con el video abierto, el teléfono puede girar', (tester) async {
    final pedidas = _orientaciones(tester);
    await _abrir(tester);

    expect(find.text('Cómo validar una idea'), findsOneWidget);
    expect(pedidas, isNotEmpty, reason: 'Abrir el video no tocó la orientación.');
    expect(pedidas.last, hasLength(DeviceOrientation.values.length),
        reason: 'Con el video abierto el teléfono seguía fijo en vertical.');
  });

  testWidgets('al cerrar el video, el teléfono vuelve a vertical',
      (tester) async {
    final pedidas = _orientaciones(tester);
    await _abrir(tester);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    expect(find.text('ver'), findsOneWidget);
    expect(pedidas.last, ['DeviceOrientation.portraitUp'],
        reason: 'Después del video, la app quedó girando libre en el teléfono.');
  });
}
