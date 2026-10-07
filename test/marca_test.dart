// La marca de la plataforma: la de eduXaction o la de un cliente.
//
// Tres cosas que esta suite fija:
//
// 1. **Con la marca de eduXaction, nada cambió.** Los colores de marca dejaron
//    de ser constantes para poder seguir al cliente, y el primer riesgo de ese
//    cambio es mover un tono sin querer. Acá están escritos como número.
// 2. **Con la marca de un cliente, todo texto de marca se lee.** No se prueba
//    con un color elegido a mano: se recorre una grilla de cientos de tonos,
//    claros, medios y oscuros, porque el cliente elige el que quiera.
// 3. **La marca cambia con la app abierta**, y vuelve a la de eduXaction sin
//    recargar — que es lo que pasa al iniciar y al cerrar sesión.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:enactus_platform/utils/app_theme.dart';
import 'package:enactus_platform/utils/marca.dart';
import 'package:enactus_platform/widgets/common.dart';

import 'helpers/portal_harness.dart';

/// El azul del ejemplo con el que se pidió la función.
const _azul = Color(0xFF1A73E8);

/// Tonos de prueba: 24 matices × 9 luminosidades × 3 saturaciones, más grises.
List<Color> _grilla() => [
      for (var h = 0; h < 360; h += 15)
        for (final s in const [0.35, 0.7, 1.0])
          for (final l in const [0.08, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.92])
            HSLColor.fromAHSL(1, h.toDouble(), s, l).toColor(),
      for (var g = 0; g <= 255; g += 15) Color.fromARGB(255, g, g, g),
    ];

void main() {
  tearDown(Marca.instancia.restablecer);

  group('con la marca de eduXaction, los colores de siempre', () {
    test('acento, relleno, hover y tinta sobre el acento', () {
      expect(AppColors.gold, const Color(0xFFFFC107));
      expect(AppColors.relleno, const Color(0xFFFFC107));
      expect(AppColors.goldBright, const Color(0xFFFFCF3D));
      expect(AppColors.acentoHover, const Color(0xFFFFCF3D));
      expect(AppColors.ink, const Color(0xFF21120A));
      expect(AppColors.secundario, const Color(0xFFFFC107));
      expect(AppColors.secundarioTinta, const Color(0xFFFFC107));
    });

    test('el acento de las pestañas con modo claro y oscuro', () {
      expect(ContentColors.dark.goldInk, const Color(0xFFFFC107));
      expect(ContentColors.dark.goldSoft, const Color(0x29FFC107));
      expect(ContentColors.light.goldInk, const Color(0xFF8A6A00));
      expect(ContentColors.light.goldSoft, const Color(0x3DFFC107));
    });

    test('el tema de Material', () {
      final tema = buildAppTheme();
      expect(tema.colorScheme.primary, const Color(0xFFFFC107));
      expect(tema.colorScheme.onPrimary, const Color(0xFF21120A));
    });
  });

  group('la paleta de un cliente', () {
    test('el azul del ejemplo: botón con su color exacto y texto aclarado', () {
      final p = PaletaMarca.desde(primario: _azul);
      expect(p.primario, _azul, reason: 'El relleno usa el color elegido.');
      expect(p.sobrePrimario, Colors.white,
          reason: 'Sobre un azul medio se lee mejor el blanco (4.51:1).');
      // Como texto sobre el gris de la plataforma el azul da 2.74:1. La
      // variante legible queda en el mismo tono, apenas más clara.
      expect(contraste(_azul, PaletaMarca.fondoOscuroMasClaro), lessThan(3));
      expect(
          contraste(p.tintaSobreOscuro, PaletaMarca.fondoOscuroMasClaro),
          greaterThanOrEqualTo(4.5));
      expect(HSLColor.fromColor(p.tintaSobreOscuro).hue,
          closeTo(HSLColor.fromColor(_azul).hue, 1),
          reason: 'Se aclara el azul, no se cambia por otro color.');
      // Sobre el blanco ya llegaba a 4.51:1, pero el fondo claro más oscuro
      // de la plataforma es #E9E7E3: ahí hay que oscurecerlo un poco.
      expect(contraste(p.tintaSobreClaro, PaletaMarca.fondoClaroMasOscuro),
          greaterThanOrEqualTo(4.5));
    });

    test('sin secundario, se usa el primario', () {
      expect(PaletaMarca.desde(primario: _azul).secundario, _azul);
      expect(
          PaletaMarca.desde(primario: _azul, secundario: const Color(0xFF00897B))
              .secundario,
          const Color(0xFF00897B));
    });

    test('un color transparente se vuelve opaco: se escribe encima', () {
      final p = PaletaMarca.desde(primario: _azul.withValues(alpha: 0.3));
      expect(p.primario.a, 1);
    });

    final grilla = _grilla();
    test('CUALQUIER color deja todo texto de marca en AA (${grilla.length} tonos)',
        () {
      final fallas = <String>[];
      void exigir(String uso, Color tinta, Color fondo, Color elegido) {
        final r = contraste(tinta, fondo);
        if (r < 4.5) {
          fallas.add('$elegido → $uso: ${r.toStringAsFixed(2)}:1');
        }
      }

      for (final c in grilla) {
        // El secundario, del lado opuesto del círculo: así cada vuelta prueba
        // dos tonos distintos.
        final opuesto = HSLColor.fromColor(c);
        final p = PaletaMarca.desde(
            primario: c,
            secundario: opuesto.withHue((opuesto.hue + 180) % 360).toColor());
        exigir('texto sobre el botón', p.sobrePrimario, p.primario, c);
        exigir('texto sobre el botón con el mouse encima', p.sobrePrimario,
            p.primarioBrillante, c);
        exigir('texto de un botón con borde, con el mouse encima',
            p.tintaSobreOscuroBrillante, const Color(0xFF35343A), c);
        // Los fondos oscuros y claros de la plataforma, todos.
        for (final fondo in const [
          Color(0xFF35343A), // página
          Color(0xFF26262A), // paneles
          Color(0xFF17171A), // tarjetas
        ]) {
          exigir('texto de marca sobre $fondo', p.tintaSobreOscuro, fondo, c);
          exigir('insignia sobre $fondo', p.secundarioSobreOscuro, fondo, c);
        }
        for (final fondo in const [
          Color(0xFFF4F2EF), // página clara
          Color(0xFFFFFFFF), // tarjeta clara
          Color(0xFFE9E7E3), // panel claro
        ]) {
          exigir('texto de marca sobre $fondo', p.tintaSobreClaro, fondo, c);
          exigir('insignia sobre $fondo', p.secundarioSobreClaro, fondo, c);
        }
      }
      expect(fallas, isEmpty, reason: fallas.take(20).join('\n'));
    });

    test('un color que ya se lee no se toca', () {
      // El ámbar sobre el gris da 7.56:1: no hay nada que corregir.
      final p = PaletaMarca.desde(primario: const Color(0xFFFFC107));
      expect(p.tintaSobreOscuro, const Color(0xFFFFC107));
    });
  });

  group('cambiar de marca', () {
    test('cambia el acento, el tema y las pestañas de una vez', () {
      Marca.instancia.aplicar(PaletaMarca.desde(primario: _azul));
      // Los fondos llevan el color exacto; el texto y los íconos sobre el
      // gris, la versión que se lee.
      expect(AppColors.relleno, _azul);
      expect(AppColors.gold, Marca.instancia.paleta.tintaSobreOscuro);
      expect(contraste(AppColors.gold, AppColors.background), greaterThanOrEqualTo(4.5));
      expect(AppColors.ink, Colors.white);
      expect(buildAppTheme().colorScheme.primary, _azul);
      expect(ContentColors.dark.goldInk,
          Marca.instancia.paleta.tintaSobreOscuro);

      Marca.instancia.restablecer();
      expect(AppColors.gold, const Color(0xFFFFC107));
      expect(ContentColors.light.goldInk, const Color(0xFF8A6A00));
    });

    test('la paleta de las pestañas es la misma instancia mientras no cambie',
        () {
      // Quien compare `colors == ContentColors.dark` tiene que seguir
      // obteniendo `true`, como cuando era una constante.
      expect(identical(ContentColors.dark, ContentColors.dark), isTrue);
      Marca.instancia.aplicar(PaletaMarca.desde(primario: _azul));
      expect(identical(ContentColors.dark, ContentColors.dark), isTrue);
    });

    test('la tinta de los colores de dato no sigue a la marca', () {
      // `inkSobre` elige entre la tinta oscura y el blanco para pintar sobre
      // el color de un laboratorio o de un ODS. Si usara la tinta de la
      // marca, con un cliente de acento oscuro las dos opciones serían blanco.
      Marca.instancia.aplicar(PaletaMarca.desde(primario: _azul));
      expect(inkSobre(const Color(0xFFFFC107)), AppColors.tintaOscura);
    });

    testWidgets('con la app abierta, sin recargar, y de vuelta', (tester) async {
      await initializeDateFormatting('es');
      cargarFixtures();
      conSesionGuardada();
      fijarTamano(tester, const Size(1440, 900));
      await montar(tester, appDe('student'));

      Color franja() => tester
          .widget<ColoredBox>(find.descendant(
              of: find.byType(ColombiaFlagBar).first,
              matching: find.byType(ColoredBox)))
          .color;
      expect(franja(), const Color(0xFFFFC107));

      // Es un widget `const` en el código de partida: sin el redibujado de
      // `Marca.aplicar`, se quedaría en ámbar aunque el tema cambiara.
      Marca.instancia.aplicar(PaletaMarca.desde(primario: _azul));
      await tester.pump();
      expect(franja(), _azul);

      Marca.instancia.restablecer();
      await tester.pump();
      expect(franja(), const Color(0xFFFFC107));
    });
  });

  test('el logo de eduXaction no lee el acento de la marca', () {
    // El logo nunca cambia de color: su destello usa el ámbar FIJO. Se mira
    // el código porque el destello es una animación y en una captura puede
    // tocar justo un cuadro en el que no se ve.
    final codigo = File('lib/widgets/animated_logo.dart').readAsStringSync();
    expect(codigo.contains('AppColors.gold'), isFalse);
    expect(codigo.contains('AppColors.ambarEduXaction'), isTrue);
    expect(AppColors.ambarEduXaction, const Color(0xFFFFC107));
  });
}
