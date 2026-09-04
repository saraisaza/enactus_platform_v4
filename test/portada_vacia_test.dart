// La portada con los textos vacíos.
//
// Así está una instalación recién montada: `heroSubtitle`, `bannerText` y
// `aboutText` en blanco hasta que alguien los escriba desde "Contenido página".
// Los fixtures son una captura del sembrado, con todos los campos llenos, así
// que ninguna prueba pasaba nunca por este estado — y en producción se veía
// una tarjeta vacía suelta entre los contadores y los laboratorios.
//
// La causa: la `Column` de la portada centra, y ese contenedor no fija ancho.
// Sin texto no desaparece, se encoge a su propio relleno.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:enactus_platform/utils/constants.dart';

import 'helpers/portal_harness.dart';

const _sobreNosotros = Key('landing-sobre-nosotros');

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    cargarFixtures();
  });

  testWidgets('sin texto de "sobre nosotros" no queda una tarjeta vacía',
      (tester) async {
    fijarTamano(tester, const Size(1440, 900));
    await montar(
      tester,
      appPublica(AppRoutes.landing, contenidoDelSitio: const {
        'aboutText': '',
        'heroSubtitle': '',
        'bannerText': '',
      }),
    );

    expect(find.byKey(_sobreNosotros), findsNothing);
  });

  testWidgets('con texto, el bloque aparece y ocupa el ancho', (tester) async {
    // La otra mitad: esconderlo siempre sería peor que mostrarlo vacío.
    fijarTamano(tester, const Size(1440, 900));
    await montar(
      tester,
      appPublica(AppRoutes.landing, contenidoDelSitio: const {
        'aboutText': 'Conectamos estudiantes, mentores y empresas.',
      }),
    );

    expect(find.byKey(_sobreNosotros), findsOneWidget);
    expect(find.text('Conectamos estudiantes, mentores y empresas.'),
        findsOneWidget);

    // Un texto corto no puede dejar una tarjeta angosta en el medio: es un
    // panel, no una etiqueta. La caja medida incluye el margen lateral, así
    // que ocupar el ancho de la ventana es exactamente lo que se espera; sin
    // `width: double.infinity` se encogería al ancho de esta frase.
    final ancho = tester.getSize(find.byKey(_sobreNosotros)).width;
    expect(ancho, 1440);
  });

  testWidgets('sin subtítulo, la portada no deja un hueco de aire',
      (tester) async {
    fijarTamano(tester, const Size(1440, 900));
    await montar(
      tester,
      appPublica(AppRoutes.landing, contenidoDelSitio: const {
        'heroSubtitle': '',
      }),
    );

    // El título y el botón siguen ahí; lo que no queda es la línea vacía con
    // sus 18 + 28 px de separación.
    expect(find.text('EDUXACTION COLOMBIA'), findsOneWidget);
    expect(find.text('Entrar a la plataforma'), findsOneWidget);
    expect(find.text(''), findsNothing);
  });
}
