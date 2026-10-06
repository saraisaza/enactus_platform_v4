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
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:enactus_platform/l10n/textos.dart';
import 'package:enactus_platform/utils/app_theme.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/utils/marca.dart';
import 'package:enactus_platform/widgets/portal_shell.dart';
import 'package:enactus_platform/widgets/vista_previa_marca.dart';

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

/// Un logo de prueba: un círculo y una palabra en azul marino, con fondo
/// transparente. Oscuro a propósito: es el caso que pide la placa clara.
Future<Uint8List> _logoDePrueba() async {
  final grabadora = ui.PictureRecorder();
  final lienzo = Canvas(grabadora);
  const tinta = Color(0xFF0B2D5B);
  lienzo.drawCircle(const Offset(60, 60), 44, Paint()..color = tinta);
  final parrafo = (ui.ParagraphBuilder(ui.ParagraphStyle(
          fontFamily: AppFonts.display, fontSize: 84))
        ..pushStyle(ui.TextStyle(color: tinta, fontWeight: FontWeight.w700))
        ..addText('NORTE'))
      .build()
    ..layout(const ui.ParagraphConstraints(width: 400));
  lienzo.drawParagraph(parrafo, const Offset(122, 4));
  final imagen = await grabadora.endRecording().toImage(420, 120);
  final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
  return datos!.buffer.asUint8List();
}

Future<void> _esperar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Toma la captura, después de dejar que terminen de cargar las imágenes.
///
/// Las fotos (la galería de la portada) se decodifican en tiempo REAL, no en
/// el reloj falso de la prueba: con la máquina cargada —la suite entera
/// corriendo— a veces no alcanzaban, y la captura salía distinta sin que nada
/// hubiera cambiado. Una regla de medir que falla sola no mide nada.
Future<void> _capturar(WidgetTester tester, String archivo) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)));
  await tester.pump();
  await expectLater(
      find.byType(MaterialApp), matchesGoldenFile('goldens/$archivo.png'));
}

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
          await _capturar(tester, 'publica_${nombre}_$etiqueta');
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
        await _capturar(tester, 'telefono_$role');
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

        for (final rotulo in rotulos) {
          await tester.tap(
              find.descendant(of: barra.first, matching: find.text(rotulo)).first,
              warnIfMissed: false);
          await _esperar(tester);
          // Sin el número de la pestaña: una pestaña nueva correría el de
          // todas las siguientes y cada una se compararía con otra.
          final base = 'escritorio_${role}_${_nombre(rotulo)}';
          await _capturar(tester, base);

          // Las pestañas con selector de tema propio también se miran en
          // claro: ahí el acento de marca se oscurece para seguir legible, y
          // es el primer lugar donde se notaría un error de color.
          final aClaro = find.byIcon(Icons.light_mode_outlined);
          if (role == Roles.student && aClaro.evaluate().isNotEmpty) {
            await tester.tap(aClaro.first, warnIfMissed: false);
            await _esperar(tester);
            await _capturar(tester, '${base}_claro');
            await tester.tap(find.byIcon(Icons.dark_mode_outlined).first,
                warnIfMissed: false);
            await _esperar(tester);
          }
        }
      });
    }
  });

  group('el editor de clientes', () {
    setUp(conSesionGuardada);
    for (final (etiqueta, tamano) in const [
      ('escritorio', Size(1440, 1100)),
      ('tablet', Size(1024, 1300)),
      ('telefono', Size(390, 844)),
    ]) {
      testWidgets('editar un cliente con colores, en $etiqueta', (tester) async {
        fijarTamano(tester, tamano);
        await montar(tester, appDe(Roles.admin));
        // En el teléfono la pestaña vive en «Más», en la barra de abajo.
        if (etiqueta == 'telefono') {
          await tester.tap(find.text(tr.portalMas));
          await _esperar(tester);
        }
        await tester.tap(find.text(tr.tabClientes).last, warnIfMissed: false);
        await _esperar(tester);
        // La segunda tarjeta: Banco Andino, con primario y secundario.
        await tester.tap(find.text(tr.comunEditar).at(1), warnIfMissed: false);
        await _esperar(tester);
        await _capturar(tester, 'editor_cliente_$etiqueta');
      });
    }
  });

  group('la vista previa con un logo', () {
    for (final placa in [false, true]) {
      testWidgets(placa ? 'con placa clara' : 'sin placa', (tester) async {
        fijarTamano(tester, const Size(720, 330));
        final logo = await tester.runAsync(_logoDePrueba);
        final imagen = MemoryImage(logo!);
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: VistaPreviaMarca(
                paleta: PaletaMarca.desde(
                    primario: const Color(0xFF0B2D5B),
                    secundario: const Color(0xFFE8A93D)),
                nombre: 'Banco Norte',
                logo: imagen,
                placaClara: placa,
                ladoALado: true,
              ),
            ),
          ),
        ));
        // La imagen se decodifica de verdad, fuera del reloj falso.
        await tester.runAsync(() => precacheImage(
            imagen, tester.element(find.byType(VistaPreviaMarca))));
        await _esperar(tester);
        await _capturar(tester, 'vista_previa_logo_${placa ? 'con' : 'sin'}_placa');
      });
    }
  });

  group('el selector de color', () {
    setUp(conSesionGuardada);
    testWidgets('abierto sobre el primario', (tester) async {
      fijarTamano(tester, const Size(1440, 1100));
      await montar(tester, appDe(Roles.admin));
      await tester.tap(find.text(tr.tabClientes).last, warnIfMissed: false);
      await _esperar(tester);
      await tester.tap(find.text(tr.comunEditar).at(1), warnIfMissed: false);
      await _esperar(tester);
      await tester.tap(
          find.byTooltip(tr.clientesAbrirSelector(tr.clientesColorPrimario)).last,
          warnIfMissed: false);
      await _esperar(tester);
      await _capturar(tester, 'selector_de_color');
    });
  });
}
