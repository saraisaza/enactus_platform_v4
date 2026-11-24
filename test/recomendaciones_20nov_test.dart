// Recomendaciones de diseño del 20 de noviembre: lo que no se ve en una
// captura pero se puede romper sin que nadie lo note.
//
// - Un solo interruptor claro/oscuro, en el encabezado, para toda la
//   plataforma; la portada y el ingreso van siempre en oscuro.
// - El menú lateral se pliega y «Cerrar sesión» está al pie.
// - El inicio del estudiante: sin «Actividad reciente», con el acceso al
//   calendario y los pendientes como alertas, de a nueve con «Ver más».
// - Las tarjetas de una fila miden lo mismo.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:enactus_platform/l10n/textos.dart';
import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/services/reporte_admin.dart';
import 'package:enactus_platform/utils/app_theme.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/utils/tema.dart';
import 'package:enactus_platform/views/student/student_calendar_view.dart';
import 'package:enactus_platform/widgets/calendar_view.dart';
import 'package:enactus_platform/widgets/common.dart';
import 'package:enactus_platform/widgets/interruptor_tema.dart';
import 'package:enactus_platform/widgets/recorte_de_foto.dart';
import 'package:enactus_platform/widgets/social_icons.dart';

import 'helpers/portal_harness.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    cargarFixtures();
  });
  setUp(conSesionGuardada);
  tearDown(Tema.instancia.restablecer);

  group('el modo claro', () {
    testWidgets('el interruptor del encabezado cambia toda la plataforma',
        (tester) async {
      fijarTamano(tester, const Size(1440, 900));
      await montar(tester, appDe(Roles.admin));
      expect(Tema.oscuro, isTrue, reason: 'la primera vez, oscuro');
      final fondoOscuro = AppColors.background;

      await tester.tap(find.byKey(InterruptorTema.clave));
      // Un cuadro para que arranque el cambio de tema y otro para que termine.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(Tema.oscuro, isFalse);
      expect(AppColors.background, isNot(fondoOscuro));
      // El tema de Material también: los diálogos y campos lo siguen.
      final tema = Theme.of(tester.element(find.byType(Scaffold).first));
      expect(tema.brightness, Brightness.light);
    });

    testWidgets('la portada va siempre en oscuro, sin tocar la preferencia',
        (tester) async {
      fijarTamano(tester, const Size(1440, 900));
      await Tema.instancia.usar(oscuro: false);
      await montar(tester, appPublica(AppRoutes.landing));
      expect(Tema.oscuro, isTrue);
      expect(Tema.instancia.esOscuro, isFalse,
          reason: 'lo que eligió la persona se conserva');
    });
  });

  group('el menú lateral', () {
    testWidgets('se pliega a solo íconos y vuelve', (tester) async {
      fijarTamano(tester, const Size(1440, 900));
      await montar(tester, appDe(Roles.admin));
      expect(find.text(tr.tabUsuarios), findsWidgets);
      await tester.tap(find.byKey(const Key('plegar-menu')));
      await tester.pump(const Duration(milliseconds: 300));
      // Plegado, los rótulos pasan a ser la ayuda de cada ícono.
      expect(find.byTooltip(tr.tabUsuarios), findsOneWidget);
      await tester.tap(find.byKey(const Key('plegar-menu')));
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('«Cerrar sesión» está al pie del menú', (tester) async {
      fijarTamano(tester, const Size(1440, 900));
      await montar(tester, appDe(Roles.student));
      final cerrar = tester.getRect(find.text(tr.comunCerrarSesion).last);
      expect(cerrar.bottom, greaterThan(900 - 80));
    });
  });

  group('el inicio del estudiante', () {
    testWidgets('sin «Actividad reciente», y «Ver calendario» lo abre',
        (tester) async {
      fijarTamano(tester, const Size(1440, 900));
      await montar(tester, appDe(Roles.student));
      expect(find.text(tr.dashboardActividadReciente.toUpperCase()),
          findsNothing);
      await tester.tap(find.byKey(const ValueKey('inicio-ver-calendario')));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(find.byType(StudentCalendarView), findsOneWidget);
    });
  });

  group('«Ver más»', () {
    Future<void> lista(WidgetTester tester, int cuantos) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListaConVerMas(children: [
                for (var i = 0; i < cuantos; i++) Text('item $i'),
              ]),
            ),
          ),
        ));

    testWidgets('muestra nueve y despliega el resto', (tester) async {
      await lista(tester, 14);
      expect(find.textContaining('item '), findsNWidgets(9));
      expect(find.text(tr.comunVerMasN(5)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ver-mas')));
      await tester.pump();
      expect(find.textContaining('item '), findsNWidgets(14));
      expect(find.text(tr.comunVerMenos), findsOneWidget);
    });

    testWidgets('con nueve o menos, sin botón', (tester) async {
      await lista(tester, 9);
      expect(find.byKey(const ValueKey('ver-mas')), findsNothing);
    });
  });

  testWidgets('las tarjetas de una fila miden lo mismo', (tester) async {
    fijarTamano(tester, const Size(1000, 800));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RejillaDeTarjetas(anchoMinimo: 300, children: [
          const ColoredBox(
              key: ValueKey('corta'), color: Colors.red, child: Text('una')),
          ColoredBox(
              key: const ValueKey('larga'),
              color: Colors.blue,
              child: Text('una\ndos\ntres\ncuatro')),
          const ColoredBox(
              key: ValueKey('tercera'), color: Colors.green, child: Text('x')),
        ]),
      ),
    ));
    final corta = tester.getSize(find.byKey(const ValueKey('corta')));
    final larga = tester.getSize(find.byKey(const ValueKey('larga')));
    expect(corta.height, larga.height);
    expect(corta.width, larga.width);
  });

  group('el enlace de un evento', () {
    test('Meet y Zoom son reuniones; lo demás, un enlace', () {
      expect(esEnlaceDeReunion('https://meet.google.com/abc-defg-hij'), isTrue);
      expect(esEnlaceDeReunion('meet.google.com/abc-defg-hij'), isTrue,
          reason: 'pegado sin https://');
      expect(esEnlaceDeReunion('https://us02web.zoom.us/j/123456'), isTrue);
      expect(esEnlaceDeReunion('https://zoom.us/j/123456'), isTrue);
      expect(esEnlaceDeReunion('https://docs.google.com/forms/x'), isFalse);
      expect(esEnlaceDeReunion('https://zoom.us.engano.com/j/1'), isFalse);
    });

    test('lo que no es un enlace no se acepta', () {
      expect(enlaceNormalizado(''), isNull);
      expect(enlaceNormalizado('reunión el martes'), isNull);
      expect(enlaceNormalizado('ftp://archivo.com/x'), isNull);
      expect(enlaceNormalizado('meet.google.com/abc').toString(),
          'https://meet.google.com/abc');
    });

    for (final (enlace, texto) in [
      ('https://meet.google.com/abc-defg-hij', 'Unirse a la reunión'),
      ('https://www.enactus.org/agenda', 'Abrir enlace'),
    ]) {
      testWidgets('«$texto» para $enlace', (tester) async {
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(body: BotonDeEnlace(enlace: enlace))));
        expect(find.text(texto), findsOneWidget);
      });
    }

    testWidgets('sin enlace no hay botón', (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: BotonDeEnlace(enlace: '  '))));
      expect(find.byKey(const ValueKey('boton-del-enlace')), findsNothing);
    });
  });

  testWidgets('la foto de perfil se recorta al cuadrado del centro',
      (tester) async {
    await tester.runAsync(() async {
      // Una foto horizontal de 300×200.
      final grabadora = ui.PictureRecorder();
      Canvas(grabadora).drawRect(const Rect.fromLTWH(0, 0, 300, 200),
          Paint()..color = const Color(0xFF3366CC));
      final foto = await grabadora.endRecording().toImage(300, 200);
      final png = (await foto.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();

      final recortada = await recortarAlCuadrado(png);
      final codec = await ui.instantiateImageCodec(recortada);
      final imagen = (await codec.getNextFrame()).image;
      expect(imagen.width, 200);
      expect(imagen.height, 200, reason: 'cuadrada: entra justa en el círculo');
    });
  });

  testWidgets('el reporte del tablero sale en PDF, con sus cifras',
      (tester) async {
    await tester.runAsync(() async {
      final pdf = await ReporteAdmin.armar(
        metricas: const ImpactMetrics(
            counts: PlatformCounts(students: 12, projects: 3, courses: 5)),
        graficas: const {},
        proyectosPorFase: const [('Ideación', 2), ('Piloto', 1)],
      );
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
      expect(pdf.length, greaterThan(1000));
    });
  });

  testWidgets('el tablero del admin tiene el botón del reporte',
      (tester) async {
    fijarTamano(tester, const Size(1440, 900));
    await montar(tester, appDe(Roles.admin));
    expect(find.byKey(const ValueKey('descargar-reporte')), findsOneWidget);
    expect(find.byTooltip(tr.reporteDescargarGrafica), findsNWidgets(2));
  });

  test('el logo de WhatsApp se lee entero y llena su caja de 24×24', () {
    // Un trazo mal leído (una bandera de arco pegada, «01») deja el dibujo
    // cortado o corrido: el contorno debe ocupar casi toda la caja.
    final caja = trazoSvg(
            'M12.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 '
            '5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005'
            'c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z')
        .getBounds();
    expect(caja.left, closeTo(0, 0.2));
    expect(caja.top, closeTo(0, 0.2));
    expect(caja.right, closeTo(24, 0.3));
    expect(caja.bottom, closeTo(24, 0.3));
  });

  testWidgets('el botón de WhatsApp lleva el logo', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: WhatsAppIcon(size: 24, color: Color(0xFFFFFFFF))),
    ));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(WhatsAppIcon)), const Size(24, 24));
  });

  for (final ancho in [1440.0, 1280.0, 900.0, 390.0]) {
    testWidgets('las cifras del panel del admin son 3 × 3 a $ancho px',
        (tester) async {
      // Antes eran dos filas de cuatro y, en una pantalla mediana, la cuarta
      // de cada fila quedaba sola abajo (3, 1, 3, 1).
      fijarTamano(tester, Size(ancho, 1000));
      await montar(tester, appDe(Roles.admin));
      final cifras = find.descendant(
          of: find.byKey(const ValueKey('cifras-del-panel')),
          matching: find.byType(StatTile));
      expect(cifras, findsNWidgets(9));
      final rects = [
        for (var i = 0; i < 9; i++) tester.getRect(cifras.at(i)),
      ];
      // Agrupadas con medio píxel de tolerancia: 645,5 no es otra columna.
      int grupos(Iterable<double> v) {
        final orden = v.toList()..sort();
        var n = 1;
        for (var i = 1; i < orden.length; i++) {
          if (orden[i] - orden[i - 1] > 1) n++;
        }
        return n;
      }

      expect(grupos(rects.map((r) => r.top)), 3);
      expect(grupos(rects.map((r) => r.left)), 3);
      // Todas del mismo tamaño.
      expect(grupos(rects.map((r) => r.width)), 1);
      expect(grupos(rects.map((r) => r.height)), 1);
      expect(tester.takeException(), isNull);
    });
  }

  test('las filas de cifras se reparten parejas, sin una sola abajo', () {
    // Pantalla mediana (entre 700 y 1100): antes 4 cifras eran 3 + 1.
    expect(StatRow.columnasParejas(4, 900), 4);
    expect(StatRow.columnasParejas(5, 900), 3); // 3 + 2
    // Teléfono: 4 → 2 × 2; 3 → una fila de 3 (antes 2 + 1).
    expect(StatRow.columnasParejas(4, 360), 2);
    expect(StatRow.columnasParejas(3, 360), 3);
    // Ancha: todo en una fila.
    expect(StatRow.columnasParejas(5, 1300), 5);
  });
}
