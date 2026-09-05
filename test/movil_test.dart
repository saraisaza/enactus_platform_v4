// La versión de teléfono: lo que "no se visualiza bien".
//
// `portals_render_test.dart` ya monta los ocho portales a 390 px, pero solo
// puede ver lo que Flutter reporta como excepción — un `RenderFlex` que
// desborda. Los defectos de esta pantalla no eran de esos: el texto se
// dibujaba sin quejarse, ilegible sobre el acento, y el título se partía a la
// mitad de la palabra. Ninguna excepción, todo mal.
//
// Es el mismo patrón que ya costó caro en esta suite: afirmar sobre el
// continente ("no hubo error") y no sobre el contenido.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enactus_platform/utils/app_theme.dart';
import 'package:enactus_platform/widgets/portal_shell.dart';

/// Monta un [ContentScreenShell] con el título dado, al ancho dado.
Future<void> montarShell(
  WidgetTester tester,
  String titulo,
  Size tamano,
) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = tamano;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: ContentScreenShell(
      eyebrow: 'Prueba',
      title: titulo,
      bodyBuilder: (_, _, _) => const SizedBox(height: 200),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Alto que ocupa el título ya dibujado.
double altoDelTitulo(WidgetTester tester, String titulo) =>
    tester.getSize(find.text(titulo.toUpperCase())).height;

void main() {
  // Sin esto la medida no significa nada: `flutter_test` dibuja con una
  // fuente de prueba en la que todos los glifos miden lo mismo y son mucho
  // más anchos que Oswald, que es condensada. Con la fuente falsa el título
  // "se parte" incluso cuando en un navegador entra de sobra.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('Oswald')
      ..addFont(Future.value(
          File('assets/media/oswald/Oswald-Bold.ttf').readAsBytesSync().buffer.asByteData()));
    await loader.load();
  });

  // "LABORATORIOS" son 12 letras en una sola palabra: si no entra, no hay
  // salto de línea posible que salve, se parte en "LABORATORIO / S".
  const largo = 'Laboratorios';

  testWidgets('el título de pantalla entra en una línea a 390 px',
      (tester) async {
    await montarShell(tester, largo, const Size(390, 1400));
    // Una línea del título compacto mide ~38 px de alto; dos, más de 70.
    expect(altoDelTitulo(tester, largo), lessThan(60),
        reason: 'El título se partió en dos líneas a 390 px.');
  });

  testWidgets('también a 360 px, que es lo que trae un Android común',
      (tester) async {
    await montarShell(tester, largo, const Size(360, 1400));
    expect(altoDelTitulo(tester, largo), lessThan(60));
  });

  testWidgets('en escritorio el título conserva su tamaño grande',
      (tester) async {
    // La otra mitad: achicarlo en todas partes sería tan malo como no
    // achicarlo nunca. A 1440 px sigue siendo el titular de 58 px.
    await montarShell(tester, largo, const Size(1440, 1400));
    final estilo = tester
        .widget<Text>(find.text(largo.toUpperCase()))
        .style;
    expect(estilo?.fontSize, 58);
  });

  testWidgets('a 390 px el título usa el tamaño compacto', (tester) async {
    await montarShell(tester, largo, const Size(390, 1400));
    final estilo = tester
        .widget<Text>(find.text(largo.toUpperCase()))
        .style;
    expect(estilo?.fontSize, lessThan(58));
  });

  test('el acento de marca nunca lleva texto blanco encima', () {
    // Resumen de lo que arregló la pantalla de laboratorios: el encabezado
    // iba en blanco fijo sobre el color del laboratorio.
    expect(inkSobre(AppColors.gold), isNot(Colors.white));
  });
}
