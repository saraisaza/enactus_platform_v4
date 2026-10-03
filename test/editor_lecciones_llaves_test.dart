// Quitar una pregunta o una opción no puede correr los textos de las demás.
//
// Los campos del editor de quiz eran `TextFormField(initialValue: ...)` sin
// llave dentro de una lista. Flutter reutiliza el estado por POSICIÓN: al
// quitar el elemento 1, el campo que quedaba en la posición 1 seguía
// mostrando el texto del borrado, y lo que se escribía ahí iba a parar al
// elemento siguiente. Nada fallaba: el quiz se guardaba con las preguntas
// cruzadas.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_service.dart';
import 'package:enactus_platform/views/lxd/lesson_editor.dart';

import 'helpers/fake_api.dart';

const _idCurso = 'cccccccc-0000-4000-8000-000000000001';
const _idModulo = 'cccccccc-0000-4000-8000-000000000002';

Future<void> _abrirQuizNuevo(WidgetTester tester) async {
  useFakeTokenStorage();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1400, 1000);
  addTearDown(tester.view.reset);

  // Una lección nueva no debería pedir nada; si pide algo, que no tumbe la
  // prueba: lo que se mide acá es el formulario.
  final api =
      FakeApi(fallback: (_) => const <String, Object?>{}).build();
  final data = DataProvider(api);
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<ApiService>.value(value: api),
      ChangeNotifierProvider.value(value: data),
      ChangeNotifierProvider.value(value: AuthProvider(api, data)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLessonEditor(context,
                courseId: _idCurso, moduleId: _idModulo),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ChoiceChip, 'Quiz'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('quitar la primera pregunta deja a la vista el texto de la '
      'segunda', (tester) async {
    await _abrirQuizNuevo(tester);
    final agregar = find.widgetWithText(OutlinedButton, 'Pregunta');
    await tester.tap(agregar);
    await tester.pump();
    await tester.tap(agregar);
    await tester.pump();

    final enunciados = find.widgetWithText(TextFormField, 'Enunciado');
    await tester.enterText(enunciados.at(0), 'Primera pregunta');
    await tester.enterText(enunciados.at(1), 'Segunda pregunta');

    await tester.tap(find.byTooltip('Quitar pregunta').first);
    await tester.pump();

    expect(find.text('Segunda pregunta'), findsOneWidget,
        reason: 'Al quitar la primera, la segunda perdió su texto.');
    expect(find.text('Primera pregunta'), findsNothing,
        reason: 'El texto de la pregunta borrada sigue en pantalla.');
  });

  testWidgets('quitar la primera opción deja a la vista el texto de la '
      'segunda', (tester) async {
    await _abrirQuizNuevo(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Pregunta'));
    await tester.pump();
    final agregarOpcion = find.widgetWithText(TextButton, 'Opción');
    await tester.tap(agregarOpcion);
    await tester.pump();
    await tester.tap(agregarOpcion);
    await tester.pump();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Opción 1'), 'Bogotá');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Opción 2'), 'Medellín');

    await tester.tap(find.byTooltip('Quitar opción').first);
    await tester.pump();

    expect(find.text('Medellín'), findsOneWidget,
        reason: 'Al quitar la primera opción, la segunda perdió su texto.');
    expect(find.text('Bogotá'), findsNothing,
        reason: 'El texto de la opción borrada sigue en pantalla.');
  });
}
