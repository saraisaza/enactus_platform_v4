// Moderación del foro en la app: lo que App Store revisa (guía 1.2) antes de
// publicar una app donde las personas publican.
//
// Se prueba lo que una persona hace y lo que la app ENVÍA: que pueda reportar
// lo de otros y no lo propio, que no pueda bloquear al equipo que modera, que
// acepte las normas antes de su primera publicación, y que el equipo vea y
// atienda la cola.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enactus_platform/main.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/widgets/common.dart';
import 'package:enactus_platform/widgets/portal_shell.dart';

import 'helpers/fake_api.dart';
import 'helpers/portal_harness.dart';

// Publicaciones de los fixtures (backend sembrado).
const _deValentina = 'Compartiendo un logro';
const _idValentina = 'a7a99d8d-ff58-55fc-a4ff-7b6c5eb0d054';
const _deLaAdmin = '¡Bienvenidos al foro';
const _propia = '¿Alguien ha usado modelos de IA';

Future<FakeApi> _montarForo(
  WidgetTester tester, {
  String role = Roles.student,
  Map<String, Object?> rutas = const {},
}) async {
  conSesionGuardada();
  fijarTamano(tester, const Size(1440, 900));
  final base = fakeDe(role);
  final fake = FakeApi(
    routes: {...base.routes, ...rutas},
    statuses: base.statuses,
  );
  final api = fake.build();
  final data = DataProvider(api);
  await tester.pumpWidget(EnactusApp(
    api: api,
    data: data,
    auth: AuthProvider(api, data),
    initialRoute: AppRoutes.forRole(role),
  ));
  await _pasos(tester, 8);
  final barra = find.descendant(
      of: find.byType(PortalShell), matching: find.byType(ListView));
  await tester
      .tap(find.descendant(of: barra.first, matching: find.text('Foro')).first);
  await _pasos(tester, 10);
  return fake;
}

Future<void> _pasos(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Abre el menú ⋮ de la tarjeta que contiene [texto].
Future<void> _abrirMenuDe(WidgetTester tester, String texto) async {
  final tarjeta = find.ancestor(
    of: find.textContaining(texto),
    matching: find.byType(HoverBuilder),
  );
  final menu = find.descendant(
      of: tarjeta.first, matching: find.byTooltip('Más acciones'));
  await tester.ensureVisible(menu.first);
  await tester.pump();
  await tester.tap(menu.first);
  await _pasos(tester, 4);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    cargarFixtures();
  });

  testWidgets('lo de otra persona se reporta, y viaja el motivo',
      (tester) async {
    const ruta = '/forum-posts/c71c41b9-d169-5259-b57e-76a283b780d8/report';
    final fake = await _montarForo(tester, rutas: {
      ruta: {'reported': true, 'duplicate': false},
    });

    await _abrirMenuDe(tester, _deValentina);
    await tester.tap(find.text('Reportar'));
    await _pasos(tester, 4);
    expect(find.text('Reportar publicación'), findsOneWidget);

    await tester.tap(find.text('Es spam o publicidad'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Reportar'));
    await _pasos(tester, 4);

    final i = fake.requested.indexOf('POST $ruta');
    expect(i, isNot(-1), reason: 'Reportar no llegó al servidor.');
    expect(fake.cuerpos[i], {'reason': 'Es spam o publicidad'});
    expect(find.textContaining('El equipo de Enactus revisará'), findsOneWidget);
  });

  testWidgets('en un teléfono de 360 dp el reporte cabe', (tester) async {
    await _montarForo(tester);
    fijarTamano(tester, const Size(360, 780));
    await _pasos(tester, 4);
    await _abrirMenuDe(tester, _deValentina);
    await tester.tap(find.text('Reportar'));
    await _pasos(tester, 4);
    expect(find.text('Bloquear también a Valentina López'), findsOneWidget);
  });

  testWidgets('en lo propio no aparece «Reportar» ni «Bloquear»',
      (tester) async {
    await _montarForo(tester);
    await _abrirMenuDe(tester, _propia);
    expect(find.text('Eliminar'), findsOneWidget);
    expect(find.text('Reportar'), findsNothing);
    expect(find.textContaining('Bloquear'), findsNothing);
  });

  testWidgets('al equipo que modera se le reporta, pero no se le bloquea',
      (tester) async {
    await _montarForo(tester);
    await _abrirMenuDe(tester, _deLaAdmin);
    expect(find.text('Reportar'), findsOneWidget);
    expect(find.textContaining('Bloquear'), findsNothing);
  });

  testWidgets('bloquear pide confirmación y envía a quién', (tester) async {
    final fake = await _montarForo(tester, rutas: {
      '/forum-posts/blocks': {'data': <Object>[]},
    });

    await _abrirMenuDe(tester, _deValentina);
    await tester.tap(find.text('Bloquear a Valentina López'));
    await _pasos(tester, 4);
    expect(find.textContaining('No se le avisará'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar'));
    await _pasos(tester, 6);

    final i = fake.requested.indexOf('POST /forum-posts/blocks');
    expect(i, isNot(-1), reason: 'Bloquear no llegó al servidor.');
    expect(fake.cuerpos[i], {'userId': _idValentina});
  });

  testWidgets('la primera publicación pide aceptar las normas, una sola vez',
      (tester) async {
    final fake = await _montarForo(tester);
    final compositor = find.widgetWithText(
        TextField, '¿Qué quiere compartir con la comunidad?');

    Future<void> publicar(String texto) async {
      await tester.enterText(compositor, texto);
      await tester.pump();
      // Al centro de la pantalla: arriba del todo queda debajo del
      // encabezado fijo de la sección, y el toque no le llega.
      await Scrollable.ensureVisible(tester.element(find.text('Publicar')),
          alignment: 0.5);
      await tester.pump();
      await tester.tap(find.text('Publicar'));
      await _pasos(tester, 4);
    }

    // Sin aceptar, no se publica.
    await publicar('Primera publicación');
    expect(find.text('Normas de la comunidad'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await _pasos(tester, 4);
    expect(fake.requested, isNot(contains('POST /forum-posts')));

    // Aceptando, sí.
    await publicar('Primera publicación');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Acepto'));
    await _pasos(tester, 6);
    expect(fake.requested, contains('POST /forum-posts'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().any((k) => k.startsWith('enactus.foro.normas')),
        isTrue);

    // La segunda vez no vuelve a preguntar.
    await publicar('Segunda publicación');
    expect(find.text('Normas de la comunidad'), findsNothing);
  });

  testWidgets('quien modera ve los reportes pendientes y los atiende',
      (tester) async {
    const idReporte = 'eeeeeeee-0000-4000-8000-000000000001';
    final fake = await _montarForo(tester, role: Roles.admin, rutas: {
      '/forum-posts/reports': {
        'data': [
          {
            'id': idReporte,
            'postId': 'c71c41b9-d169-5259-b57e-76a283b780d8',
            'replyId': null,
            'reason': 'Es spam o publicidad',
            'createdAt': '2026-10-01T15:00:00.000Z',
            'reporterName': 'Sara Nieto',
            'body': 'Compren mis rifas',
            'authorId': _idValentina,
            'authorName': 'Valentina López',
            'contentRemoved': false,
          },
        ],
      },
      '/forum-posts/reports/$idReporte/resolve': {
        'id': idReporte,
        'resolution': 'removed',
      },
    });

    expect(find.text('Hay 1 reporte sin atender.'), findsOneWidget);
    await tester.tap(find.text('Revisar'));
    await _pasos(tester, 6);
    expect(find.text('Reportes del foro'), findsOneWidget);
    expect(find.text('Compren mis rifas'), findsOneWidget);

    await tester.tap(find.text('Quitar del foro'));
    await _pasos(tester, 4);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar'));
    await _pasos(tester, 6);

    const ruta = 'POST /forum-posts/reports/$idReporte/resolve';
    final i = fake.requested.indexOf(ruta);
    expect(i, isNot(-1), reason: 'Atender el reporte no llegó al servidor.');
    expect(fake.cuerpos[i], {'action': 'remove'});
  });
}
