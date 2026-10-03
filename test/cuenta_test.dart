// «Eliminar mi cuenta» y lo demás que las tiendas buscan en el menú de la
// cuenta (App Store, guía 5.1.1(v); Google Play: eliminación de cuenta).
//
// Un revisor de la tienda abre el menú, busca la opción, la usa y comprueba
// que la sesión se cierra. Eso es lo que se prueba, con lo que la app envía.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:enactus_platform/main.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_service.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/widgets/portal_shell.dart';

import 'helpers/fake_api.dart';
import 'helpers/portal_harness.dart';

const _ruta = '/auth/me/deletion-request';

Future<(FakeApi, ApiService)> _montar(
  WidgetTester tester, {
  String role = Roles.student,
  Map<String, Object?> rutas = const {},
  Map<String, int> estados = const {},
}) async {
  conSesionGuardada();
  fijarTamano(tester, const Size(1440, 900));
  final base = fakeDe(role);
  final fake = FakeApi(
    routes: {...base.routes, ...rutas},
    statuses: {...base.statuses, ...estados},
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
  return (fake, api);
}

Future<void> _pasos(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _abrirEliminar(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Mi cuenta'));
  await _pasos(tester, 4);
  await tester.tap(find.text('Eliminar mi cuenta'));
  await _pasos(tester, 4);
}

Future<void> _confirmarCon(WidgetTester tester, String clave) async {
  await tester.enterText(find.widgetWithText(TextField, 'Contraseña'), clave);
  await tester.pump();
  await tester.tap(find.widgetWithText(ElevatedButton, 'Eliminar mi cuenta'));
  await _pasos(tester, 6);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    cargarFixtures();
  });

  for (final role in [Roles.student, Roles.company, Roles.admin]) {
    testWidgets('${Roles.label(role)}: el menú de la cuenta tiene lo que '
        'piden las tiendas', (tester) async {
      await _montar(tester, role: role);
      await tester.tap(find.byTooltip('Mi cuenta'));
      await _pasos(tester, 4);
      expect(find.text('Eliminar mi cuenta'), findsOneWidget);
      expect(find.text('Política de privacidad'), findsOneWidget);
      expect(find.text('Acerca de eduXaction'), findsOneWidget);
    });
  }

  testWidgets('en un teléfono de 360 dp los diálogos de la cuenta caben',
      (tester) async {
    await _montar(tester);
    fijarTamano(tester, const Size(360, 780));
    await _pasos(tester, 4);

    await _abrirEliminar(tester);
    expect(find.text('Esto es lo que pasa si elimina su cuenta:'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar'));
    await _pasos(tester, 4);

    await tester.tap(find.byTooltip('Mi cuenta'));
    await _pasos(tester, 4);
    await tester.tap(find.text('Acerca de eduXaction'));
    await _pasos(tester, 4);
    expect(find.text('Licencias de software'), findsOneWidget);
    // Cualquier desborde habría hecho fallar la prueba antes de llegar acá.
  });

  testWidgets('con la contraseña equivocada lo dice y la sesión sigue',
      (tester) async {
    final (_, api) = await _montar(tester, rutas: {
      _ruta: {
        'error': {
          'code': 'forbidden',
          'message': 'La contraseña no es correcta.',
        },
      },
    }, estados: {
      _ruta: 403,
    });

    await _abrirEliminar(tester);
    await _confirmarCon(tester, 'clave-equivocada');

    expect(find.text('La contraseña no es correcta.'), findsOneWidget);
    expect(await api.tokens.readAccess(), isNotNull,
        reason: 'Una contraseña equivocada cerró la sesión.');
  });

  testWidgets('con la correcta: solicitud recibida, sesión cerrada, y al ingreso',
      (tester) async {
    final (fake, api) = await _montar(tester, rutas: {
      _ruta: {'status': 'pending', 'days': 30},
    }, estados: {
      _ruta: 202,
    });

    await _abrirEliminar(tester);
    // Nunca la contraseña de una cuenta sembrada: este cuerpo queda en el
    // contrato que el servidor reenvía con la sesión del superadmin.
    await _confirmarCon(tester, 'clave-de-prueba');

    final i = fake.requested.indexOf('POST $_ruta');
    expect(i, isNot(-1), reason: 'La solicitud no llegó al servidor.');
    expect(fake.cuerpos[i], {'password': 'clave-de-prueba'});

    expect(find.text('Solicitud recibida'), findsOneWidget);
    expect(find.textContaining('30 días'), findsOneWidget);
    expect(await api.tokens.readAccess(), isNull,
        reason: 'Después de eliminar la cuenta quedó la sesión guardada.');

    await tester.tap(find.text('Entendido'));
    await _pasos(tester, 8);
    expect(find.byType(PortalShell), findsNothing);
    expect(find.text('Ingresar'), findsOneWidget,
        reason: 'No volvió a la pantalla de ingreso.');
  });

  testWidgets('el equipo ve la solicitud y borra los datos', (tester) async {
    const id = 'ffffffff-0000-4000-8000-000000000001';
    final hace5 = DateTime.now()
        .subtract(const Duration(days: 5))
        .toUtc()
        .toIso8601String();
    final (fake, _) = await _montar(tester, role: Roles.admin, rutas: {
      '/users/deletion-requests': {
        'data': [
          {
            'id': id,
            'name': 'Pedro Pérez',
            'email': 'pedro@correo.co',
            'role': Roles.donor,
            'requestedAt': hace5,
          },
        ],
      },
      '/users/$id/purge': {'id': id, 'purged': true},
    });

    final barra = find.descendant(
        of: find.byType(PortalShell), matching: find.byType(ListView));
    await tester.tap(
        find.descendant(of: barra.first, matching: find.text('Usuarios')).first);
    await _pasos(tester, 8);

    expect(find.text('1 solicitud de eliminación de cuenta'), findsOneWidget);
    expect(find.textContaining('quedan 25 días'), findsOneWidget);

    await tester.tap(find.text('Borrar datos'));
    await _pasos(tester, 4);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar'));
    await _pasos(tester, 6);
    expect(fake.requested, contains('POST /users/$id/purge'));
  });
}
