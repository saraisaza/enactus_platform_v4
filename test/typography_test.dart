import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:enactus_platform/utils/app_theme.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/widgets/portal_shell.dart';

import 'helpers/portal_harness.dart';

/// Las dos fuentes del diseño se usan **de verdad**, en cada texto.
///
/// Declararlas en `pubspec.yaml` y apuntar `AppFonts` a ellas no alcanza: un
/// `TextStyle` que fije su propia `fontFamily`, o un `Text` fuera del alcance
/// del `Theme`, sigue pintándose con otra cosa y no lo delata nada — ni el
/// análisis estático, ni el build, ni las pruebas de maquetación. La única
/// forma de saberlo es mirar el árbol ya renderizado.
///
/// Se inspecciona el `RichText` que construye cada `Text`: su `TextSpan` trae
/// el estilo YA resuelto, después de mezclarse con el `DefaultTextStyle` del
/// tema. Eso es exactamente lo que se pinta.
///
/// Familias permitidas y por qué:
/// - **Knockout** — títulos (`AppFonts.display`).
/// - **SpaceGrotesk** — todo el resto de la interfaz (`AppFonts.ui`).
/// - **Manrope** — SOLO el wordmark "eduXaction", por reglas de marca
///   (`AppFonts.logo`, ver `assets/media/README.md`).
/// - **MaterialIcons / CupertinoIcons** — los íconos son glifos de fuente;
///   no son texto.

const _permitidas = {
  AppFonts.display,
  AppFonts.ui,
  AppFonts.logo,
  'MaterialIcons',
  'CupertinoIcons',
  'packages/cupertino_icons/CupertinoIcons',
};

/// Familia resuelta de cada texto en pantalla, con una muestra del contenido
/// para poder encontrarlo cuando falla.
Map<String, String> _familiasEnPantalla(WidgetTester tester) {
  final fuera = <String, String>{};

  void revisar(InlineSpan? span) {
    if (span == null) return;
    if (span is TextSpan) {
      final familia = span.style?.fontFamily;
      final texto = span.text;
      if (texto != null && texto.trim().isNotEmpty) {
        // Sin familia es tan grave como con la equivocada: hereda la del
        // sistema, que en cada navegador es una distinta.
        final clave = familia ?? '(sin familia)';
        if (!_permitidas.contains(clave)) {
          fuera.putIfAbsent(clave, () => texto.trim());
        }
      }
      for (final hijo in span.children ?? const <InlineSpan>[]) {
        revisar(hijo);
      }
    }
  }

  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    revisar(richText.text);
  }
  return fuera;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    cargarFixtures();
  });

  setUp(conSesionGuardada);

  test('el tema apunta a las dos fuentes del diseño', () {
    // Si alguien vuelve a poner una sustituta, esto lo dice en una línea en
    // vez de dejar que se descubra mirando la pantalla.
    expect(AppFonts.display, 'Knockout');
    expect(AppFonts.ui, 'SpaceGrotesk');
  });

  test('Knockout es de un solo corte: no se le pide un peso sintético', () {
    // Knockout 92 no tiene eje de peso. Pedirle 600 o 700 hace que Flutter
    // engrose los trazos por software y cierre las contraformas.
    expect(AppWeights.display, FontWeight.w400);
  });

  for (final role in rolesDePortal) {
    testWidgets('${Roles.label(role)}: todo su texto usa las fuentes del tema',
        (tester) async {
      fijarTamano(tester, const Size(1440, 900));
      await montar(tester, appDe(role));

      final fuera = _familiasEnPantalla(tester);
      expect(fuera, isEmpty,
          reason: 'Texto con una fuente que no es del tema en '
              '${Roles.label(role)}:\n'
              '${fuera.entries.map((e) => '  · ${e.key} → "${e.value}"').join('\n')}');
    });
  }

  /// Las pantallas públicas no son portales y quedaban fuera del recorrido.
  ///
  /// La portada y el ingreso son lo PRIMERO que ve alguien: si la tipografía
  /// falla ahí, falla en la primera impresión. Además la portada tiene su
  /// propio encabezado y el logotipo animado, que es el único lugar con una
  /// tercera familia permitida.
  for (final (nombre, ruta) in const [
    ('la portada', AppRoutes.landing),
    ('el ingreso', AppRoutes.login),
  ]) {
    testWidgets('$nombre también usa las fuentes del tema', (tester) async {
      fijarTamano(tester, const Size(1440, 900));
      await montar(tester, appPublica(ruta));
      // Sin sesión no puede haber portal: si apareciera, se estaría midiendo
      // otra pantalla.
      expect(find.byType(PortalShell), findsNothing);

      final fuera = _familiasEnPantalla(tester);
      expect(fuera, isEmpty,
          reason: 'Texto con una fuente que no es del tema en $nombre:\n'
              '${fuera.entries.map((e) => '  · ${e.key} → "${e.value}"').join('\n')}');
    });
  }

  testWidgets('y también en las pestañas de adentro, no solo en la primera',
      (tester) async {
    // El Admin es el portal con más pestañas (11): si alguna escribe su propia
    // fuente, es la que más probabilidades tiene de tenerla.
    fijarTamano(tester, const Size(1440, 900));
    await montar(tester, appDe(Roles.admin));

    final barra = find.descendant(
        of: find.byType(PortalShell), matching: find.byType(ListView));
    expect(barra, findsWidgets);
    final rotulos = rotulosDeBarraLateral(tester, barra);
    expect(rotulos.length, greaterThan(1));

    final fuera = <String, String>{};
    for (final rotulo in rotulos) {
      final destino =
          find.descendant(of: barra.first, matching: find.text(rotulo));
      if (destino.evaluate().isEmpty) continue;
      await tester.tap(destino.first, warnIfMissed: false);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      _familiasEnPantalla(tester).forEach((familia, muestra) {
        fuera.putIfAbsent(familia, () => '[$rotulo] $muestra');
      });
    }

    expect(fuera, isEmpty,
        reason: 'Texto con una fuente que no es del tema:\n'
            '${fuera.entries.map((e) => '  · ${e.key} → "${e.value}"').join('\n')}');
  });
}
