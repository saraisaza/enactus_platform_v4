// Capturas de pantalla de toda la plataforma, para comparar antes y después.
//
// No es una prueba de comportamiento: es una regla para medir cambios de
// aspecto. Toma una imagen de cada pestaña de los nueve portales en
// escritorio, de cada portal en teléfono, de las pantallas públicas y del
// modo claro del estudiante, y las compara contra las de una corrida anterior.
//
// Se usa así:
//
//   # 1. En el código de partida, se guardan las imágenes de referencia:
//   flutter test test/capturas --run-skipped --update-goldens
//   # 2. Con el cambio aplicado, se compara contra ellas:
//   flutter test test/capturas --run-skipped
//
// Una diferencia de un solo píxel hace fallar la captura, y Flutter deja la
// imagen de la diferencia en `test/capturas/failures/`.
//
// **Por qué está saltada en la suite normal (`dart_test.yaml`).** La imagen
// depende de cómo cada sistema dibuja las letras: las de referencia hechas en
// un Mac no coinciden píxel a píxel con las de Linux, que es donde corre CI.
// Por eso las imágenes tampoco se guardan en el repositorio (`.gitignore`):
// se generan y se comparan en la misma máquina.
//
// Las fuentes son las de verdad (Oswald, DM Sans, Manrope e íconos): con la
// fuente de prueba de `flutter_test`, cada letra es un rectángulo y una
// captura no le sirve a nadie que la quiera mirar.
@Tags(['capturas'])
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/widgets/portal_shell.dart';

import '../helpers/portal_harness.dart';

/// Carga todas las familias declaradas en el `FontManifest.json` del bundle
/// de pruebas: las de `pubspec.yaml` y los íconos de Material.
Future<void> _cargarFuentes() async {
  final manifiesto =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final familia in manifiesto.cast<Map<String, dynamic>>()) {
    final cargador = FontLoader(familia['family'] as String);
    for (final fuente
        in (familia['fonts'] as List).cast<Map<String, dynamic>>()) {
      cargador.addFont(rootBundle.load(fuente['asset'] as String));
    }
    await cargador.load();
  }
}

/// Nombre de archivo sin tildes ni espacios.
String _nombre(String texto) {
  const tildes = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ñ': 'n'};
  final minusculas = texto.toLowerCase();
  final sinTildes = minusculas.split('').map((c) => tildes[c] ?? c).join();
  return sinTildes
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

Future<void> _esperar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _capturar(String archivo) => expectLater(
    find.byType(MaterialApp), matchesGoldenFile('goldens/$archivo.png'));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    cargarFixtures();
    await _cargarFuentes();
  });

  group('públicas', () {
    for (final (etiqueta, tamano) in const [
      ('escritorio', Size(1440, 900)),
      ('telefono', Size(390, 844)),
    ]) {
      for (final (nombre, ruta) in const [
        ('portada', AppRoutes.landing),
        ('ingreso', AppRoutes.login),
      ]) {
        testWidgets('$nombre en $etiqueta', (tester) async {
          fijarTamano(tester, tamano);
          await montar(tester, appPublica(ruta));
          await _capturar('publica_${nombre}_$etiqueta');
        });
      }
    }
  });

  group('teléfono', () {
    setUp(conSesionGuardada);
    for (final role in rolesDePortal) {
      testWidgets('${Roles.label(role)}: pestaña inicial', (tester) async {
        fijarTamano(tester, const Size(390, 844));
        await montar(tester, appDe(role));
        await _capturar('telefono_$role');
      });
    }
  });

  group('escritorio, todas las pestañas', () {
    setUp(conSesionGuardada);
    for (final role in rolesDePortal) {
      testWidgets(Roles.label(role), (tester) async {
        fijarTamano(tester, const Size(1440, 900));
        await montar(tester, appDe(role));

        final barra = find.descendant(
            of: find.byType(PortalShell), matching: find.byType(ListView));
        expect(barra, findsWidgets,
            reason: 'Sin barra lateral no hay pestañas que recorrer.');
        final rotulos = rotulosDeBarraLateral(tester, barra);
        expect(rotulos.length, greaterThan(1));

        for (final (indice, rotulo) in rotulos.indexed) {
          await tester.tap(
              find.descendant(of: barra.first, matching: find.text(rotulo)).first,
              warnIfMissed: false);
          await _esperar(tester);
          final base =
              'escritorio_${role}_${indice.toString().padLeft(2, '0')}_${_nombre(rotulo)}';
          await _capturar(base);

          // Las pestañas con selector de tema propio también se miran en
          // claro: ahí el acento de marca se oscurece para seguir legible, y
          // es el primer lugar donde se notaría un error de color.
          final aClaro = find.byIcon(Icons.light_mode_outlined);
          if (role == Roles.student && aClaro.evaluate().isNotEmpty) {
            await tester.tap(aClaro.first, warnIfMissed: false);
            await _esperar(tester);
            await _capturar('${base}_claro');
            await tester.tap(find.byIcon(Icons.dark_mode_outlined).first,
                warnIfMissed: false);
            await _esperar(tester);
          }
        }
      });
    }
  });
}
