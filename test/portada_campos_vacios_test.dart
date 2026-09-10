import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/widgets/async_states.dart';

import 'helpers/portal_harness.dart';

/// La portada con cada campo vacío, uno por uno.
///
/// `portada_vacia_test.dart` cubre el caso «todo en blanco», que es el de una
/// instalación recién montada. Falta el de en medio, que es el que se da de
/// verdad: alguien escribió el título y el banner pero todavía no el «sobre
/// nosotros», o borró un texto y guardó.
///
/// Ese estado intermedio no lo recorría nadie porque
/// `test/fixtures/api_payloads.json` es una **captura del sembrado**, con
/// todos los campos llenos — la tercera regla del documento de auditoría:
/// *«lo que el sembrado siempre llena, la suite nunca lo prueba vacío»*.
///
/// De ahí salió la tarjeta suelta de la portada: el bloque «Sobre nosotros»
/// no tenía su `if (isNotEmpty)`, así que sin texto se encogía a su propio
/// relleno y dejaba una caja con fondo y nada dentro. El banner de arriba, en
/// el mismo archivo, sí lo tenía.
void main() {
  setUpAll(cargarFixtures);

  // Los textos que un administrador puede dejar en blanco desde el panel.
  // Los numéricos y las listas van aparte, abajo.
  const textos = <String>[
    'heroTitle',
    'heroSubtitle',
    'bannerText',
    'aboutText',
    'meetingLink',
  ];

  for (final campo in textos) {
    testWidgets('la portada aguanta $campo en blanco', (tester) async {
      await montar(tester, appPublica(AppRoutes.landing,
          contenidoDelSitio: {campo: ''}));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ErrorState), findsNothing,
          reason: 'la portada cayó en estado de error con $campo vacío');
      expect(tester.takeException(), isNull,
          reason: '$campo vacío lanzó una excepción');

      // Que no truene no basta: tiene que seguir mostrando la página. Sin
      // esto, una portada en blanco pasaría los dos `expect` de arriba.
      expect(find.byType(Scaffold), findsWidgets);
      final textosVisibles = find
          .byWidgetPredicate((w) => w is Text && (w.data ?? '').trim().isNotEmpty)
          .evaluate()
          .length;
      expect(textosVisibles, greaterThan(5),
          reason: 'con $campo vacío la portada quedó prácticamente en blanco '
              '($textosVisibles textos)');
    });
  }

  testWidgets('los contadores en cero no rompen la portada', (tester) async {
    await montar(tester, appPublica(AppRoutes.landing, contenidoDelSitio: {
      'statStudents': 0,
      'statProjects': 0,
      'statLabs': 0,
      'statUniversities': 0,
    }));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ErrorState), findsNothing);
    expect(tester.takeException(), isNull);
    // Una organización que arranca tiene ceros de verdad; no es un error.
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('sin laboratorios ni galería, la portada sigue en pie', (tester) async {
    await montar(tester, appPublica(AppRoutes.landing, contenidoDelSitio: {
      'laboratories': <Object?>[],
      'galleryImages': <Object?>[],
      'gallery': <Object?>[],
    }));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ErrorState), findsNothing);
    expect(tester.takeException(), isNull);
    final textosVisibles = find
        .byWidgetPredicate((w) => w is Text && (w.data ?? '').trim().isNotEmpty)
        .evaluate()
        .length;
    expect(textosVisibles, greaterThan(5));
  });
}
