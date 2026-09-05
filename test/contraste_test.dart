// Tinta legible sobre el color del dato.
//
// El rebranding a ámbar dejó ilegible el encabezado de las tarjetas de
// laboratorio y de curso: iban con texto blanco fijo, y blanco sobre #FFC107
// da 1.63:1. Esta suite fija la regla —se elige la tinta que más contrasta— y
// mide el resultado sobre TODA la rampa, no solo sobre el ámbar: la rampa
// mezcla tonos claros y oscuros a propósito, así que una constante nunca iba
// a servir.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enactus_platform/utils/app_theme.dart';

/// Contraste WCAG entre dos colores opacos.
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final alto = la > lb ? la : lb;
  final bajo = la > lb ? lb : la;
  return (alto + 0.05) / (bajo + 0.05);
}

void main() {
  test('el ámbar de marca con texto blanco es ilegible — el motivo de todo esto',
      () {
    // Se deja escrito como número: es la medida que justifica `inkSobre`.
    expect(contraste(Colors.white, AppColors.gold), lessThan(2.0));
    expect(contraste(AppColors.ink, AppColors.gold), greaterThan(7.0));
  });

  test('inkSobre pasa AA sobre toda la rampa de laboratorios', () {
    for (final tono in AppColors.labPalette) {
      final ratio = contraste(inkSobre(tono), tono);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'La tinta elegida para $tono da ${ratio.toStringAsFixed(2)}:1');
    }
  });

  test('inkSobre pasa AA sobre los 17 colores de ODS', () {
    // Las tarjetas del Directorio de Proyectos se pintan con el color del ODS
    // principal, que incluye amarillos tan claros como el acento.
    for (final entry in AppColors.odsColors.entries) {
      final ratio = contraste(inkSobre(entry.value), entry.value);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'ODS ${entry.key}: ${ratio.toStringAsFixed(2)}:1');
    }
  });

  test('elige oscuro sobre claro y blanco sobre oscuro', () {
    expect(inkSobre(AppColors.gold), AppColors.ink);
    expect(inkSobre(const Color(0xFFFFFFFF)), AppColors.ink);
    expect(inkSobre(const Color(0xFF000000)), Colors.white);
    expect(inkSobre(AppColors.background), Colors.white);
  });

  test('la rampa entera termina con tinta oscura, y eso es correcto', () {
    // Contraintuitivo y por eso se deja fijado: hasta el violeta #9085E9, que
    // parece oscuro, contrasta mejor con la tinta (5.81:1) que con blanco
    // (3.13:1). La rampa completa es de tonos medios-claros, así que el
    // encabezado de una tarjeta va SIEMPRE en tinta oscura. Si alguien agrega
    // un tono oscuro a la rampa, esta prueba se pone roja y hay que decidir a
    // conciencia, no descubrirlo en pantalla.
    for (final tono in AppColors.labPalette) {
      expect(inkSobre(tono), AppColors.ink, reason: 'tono $tono');
    }
  });

  group('color por laboratorio', () {
    test('el mismo id da siempre el mismo tono', () {
      const id = 'd88d5053-9545-5ade-96d7-210470d688a8';
      expect(labColorFor(id), labColorFor(id));
    });

    test('ids distintos NO caen todos en el mismo tono', () {
      // La regresión que esto cubre: el mapa anterior tenía claves tipo
      // `lab_ia` mientras la API manda UUID, así que ninguna coincidía y
      // todos los laboratorios se pintaban del acento de marca.
      const ids = [
        'd88d5053-9545-5ade-96d7-210470d688a8',
        '0d4a00d9-8b6c-57c9-b2c3-8e059175f4fe',
        '06cfd993-d62d-590e-83f5-a66e4cd4af82',
        '1f2e3d4c-5b6a-4798-8091-a2b3c4d5e6f7',
        'aa11bb22-cc33-4d44-9e55-f66677788899',
        '9f8e7d6c-5b4a-4392-8180-7f6e5d4c3b2a',
      ];
      final tonos = ids.map(labColorFor).toSet();
      expect(tonos.length, greaterThan(1),
          reason: 'Todos los laboratorios quedaron del mismo color.');
    });

    test('sin laboratorio cae al acento de marca', () {
      // Los cursos de la Ruta National Expo no tienen laboratorio.
      expect(labColorFor(''), AppColors.gold);
    });
  });
}
