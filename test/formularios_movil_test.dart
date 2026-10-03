// En el teléfono, un toque accidental no puede borrar lo que alguien escribió.
//
// Los formularios del estudiante —quiz, encuesta, entregas, perfil— eran
// `AlertDialog` sueltos: el botón atrás de Android, el gesto de iOS o tocar
// fuera del recuadro los cerraban y se perdían las respuestas. Ahora pasan
// por `AdaptiveFormShell`, que pide confirmación cuando hay algo sin guardar.
// Esta suite fija ese comportamiento, que comparten todos.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enactus_platform/widgets/common.dart';

Future<void> _abrir(WidgetTester tester, {required bool dirty}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(360, 780);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => AdaptiveFormShell(
              title: 'Entregar actividad',
              dirty: dirty,
              onCancel: () => Navigator.pop(dialogContext),
              onSave: () {},
              child: const Text('CONTENIDO DEL FORMULARIO'),
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Future<void> _atras(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('en el teléfono el formulario ocupa toda la pantalla',
      (tester) async {
    await _abrir(tester, dirty: false);
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.getSize(find.byType(Dialog)).width, 360,
        reason: 'A 360 dp el formulario debería ser de pantalla completa.');
  });

  testWidgets('sin cambios, "atrás" cierra sin preguntar', (tester) async {
    await _abrir(tester, dirty: false);
    await _atras(tester);
    expect(find.text('CONTENIDO DEL FORMULARIO'), findsNothing);
    expect(find.text('Descartar cambios'), findsNothing);
  });

  testWidgets('con cambios, "atrás" pregunta antes de descartar',
      (tester) async {
    await _abrir(tester, dirty: true);
    await _atras(tester);
    expect(find.text('Descartar cambios'), findsOneWidget,
        reason: 'Atrás descartó lo escrito sin preguntar.');
    expect(find.text('CONTENIDO DEL FORMULARIO'), findsOneWidget);

    // "Cancelar" en la pregunta: se queda en el formulario.
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar').last);
    await tester.pumpAndSettle();
    expect(find.text('CONTENIDO DEL FORMULARIO'), findsOneWidget);

    // "Confirmar": ahora sí sale.
    await _atras(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar'));
    await tester.pumpAndSettle();
    expect(find.text('CONTENIDO DEL FORMULARIO'), findsNothing);
  });

  testWidgets('con cambios, la X también pregunta', (tester) async {
    await _abrir(tester, dirty: true);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar cambios'), findsOneWidget);
  });
}
