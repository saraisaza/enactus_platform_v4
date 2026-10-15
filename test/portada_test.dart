// La portada: qué es eduXaction, para empresas, con Enactus como cliente y
// la invitación a agendar una demo.
//
// Antes el formulario de la portada decía «¡Mensaje enviado!» y el mensaje no
// salía del navegador. Estas pruebas fijan que ahora llega al servidor.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:enactus_platform/l10n/textos.dart';
import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/services/contact_service.dart';
import 'package:enactus_platform/utils/constants.dart';

import 'helpers/portal_harness.dart';

/// La portada se mueve siempre (las partículas, los avisos que flotan):
/// `pumpAndSettle` nunca terminaría. Se deja pasar un rato.
Future<void> _asentar(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    cargarFixtures();
  });

  Future<List<String>> abrir(WidgetTester tester,
      {Size tamano = const Size(1440, 900), Map<String, Object?>? contenido}) async {
    fijarTamano(tester, tamano);
    return montar(
        tester, appPublica(AppRoutes.landing, contenidoDelSitio: contenido));
  }

  testWidgets('dice qué es eduXaction y ofrece agendar una demo', (tester) async {
    await abrir(tester);
    expect(find.textContaining(tr.portadaTitulo2.toUpperCase(), findRichText: true),
        findsOneWidget);
    expect(find.text(tr.portadaEyebrow.toUpperCase()), findsOneWidget);
    expect(find.byKey(const ValueKey('portada-agendar')), findsOneWidget);
  });

  testWidgets('Enactus aparece como cliente, con las cifras del admin',
      (tester) async {
    await abrir(tester,
        contenido: const {'statStudents': 238, 'statUniversities': 33},
        tamano: const Size(1440, 4400));
    // Las cifras cuentan desde cero al aparecer.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const ValueKey('cliente-enactus')), findsOneWidget);
    expect(find.text('ENACTUS COLOMBIA'), findsOneWidget);
    expect(find.text(tr.portadaClientesEyebrow.toUpperCase()), findsOneWidget);
    expect(find.text('238'), findsOneWidget);
    expect(find.text('33'), findsOneWidget);
  });

  testWidgets('el anuncio solo aparece si el admin escribió uno', (tester) async {
    await abrir(tester, contenido: const {'bannerText': '', 'bannerTextEn': ''});
    expect(find.text('Convocatoria National Expo 2026 abierta'), findsNothing);
    await abrir(tester, contenido: const {'bannerText': 'Nuevo: certificados con QR'});
    expect(find.text('Nuevo: certificados con QR'), findsOneWidget);
  });

  testWidgets('en un teléfono angosto nada se sale de la pantalla',
      (tester) async {
    final errores = await abrir(tester, tamano: const Size(360, 5200));
    expect(errores, isEmpty);
  });

  testWidgets('«Agendar una demo» le llega al servidor, con la empresa',
      (tester) async {
    final enviados = <http.Request>[];
    ContactService.cliente = () => MockClient((request) async {
          enviados.add(request);
          return http.Response('{"ok":true}', 202);
        });
    addTearDown(() => ContactService.cliente = http.Client.new);

    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('portada-agendar')));
    await _asentar(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, tr.comunNombre), 'Laura Gómez');
    await tester.enterText(
        find.widgetWithText(TextFormField, tr.ingresoCorreo), 'laura@empresa.co');
    await tester.enterText(
        find.widgetWithText(TextFormField, tr.contactoEmpresa), 'Empresa Andina');
    await tester.enterText(find.widgetWithText(TextFormField, tr.contactoMensaje),
        'Queremos capacitar al equipo de ventas.');
    await tester.tap(find.text(tr.contactoEnviar));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await _asentar(tester);

    expect(enviados, hasLength(1));
    expect(enviados.single.url.path, '/contact');
    expect(jsonDecode(enviados.single.body), {
      'name': 'Laura Gómez',
      'email': 'laura@empresa.co',
      'company': 'Empresa Andina',
      'message': 'Queremos capacitar al equipo de ventas.',
      'website': '',
    });
    expect(find.text(tr.contactoEnviado), findsOneWidget);
  });

  testWidgets('si el servidor no lo recibe, lo dice', (tester) async {
    ContactService.cliente =
        () => MockClient((_) async => http.Response('{}', 500));
    addTearDown(() => ContactService.cliente = http.Client.new);

    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('portada-agendar')));
    await _asentar(tester);
    await tester.enterText(
        find.widgetWithText(TextFormField, tr.comunNombre), 'Ana');
    await tester.enterText(
        find.widgetWithText(TextFormField, tr.ingresoCorreo), 'ana@x.co');
    await tester.enterText(
        find.widgetWithText(TextFormField, tr.contactoMensaje), 'Hola');
    await tester.tap(find.text(tr.contactoEnviar));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await _asentar(tester);
    expect(find.text(tr.contactoError), findsOneWidget);
    expect(find.text(tr.contactoEnviado), findsNothing);
  });

  test('al admin le llega el aviso con los datos de quien escribió', () {
    final aviso = AppNotification.fromJson({
      'id': 'a1',
      'title': 'Nuevo contacto desde la portada',
      'body': '…',
      'kind': 'contacto',
      'params': {
        'nombre': 'Laura Gómez',
        'correo': 'laura@empresa.co',
        'empresa': 'Empresa Andina',
        'mensaje': 'Queremos capacitar al equipo de ventas.',
      },
      'createdAt': '2026-10-15T10:00:00Z',
    });
    expect(aviso.tituloVisible, tr.avisoContactoTitulo);
    expect(aviso.cuerpoVisible, contains('Laura Gómez (Empresa Andina)'));
    expect(aviso.cuerpoVisible, contains('laura@empresa.co'));
    expect(aviso.cuerpoVisible, contains('Queremos capacitar al equipo de ventas.'));
  });
}
