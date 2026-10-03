// Abrir la app sin señal no es lo mismo que no tener sesión.
//
// Antes, con la sesión guardada y sin red, la app mostraba la portada —como si
// la persona hubiera cerrado sesión—, sin aviso y sin forma de reintentar; y
// al volver la señal seguía "afuera". En el teléfono es el caso más común del
// mundo: abrir la app en el metro.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:enactus_platform/main.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_service.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/views/public/sin_conexion_view.dart';
import 'package:enactus_platform/widgets/portal_shell.dart';

import 'helpers/portal_harness.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    cargarFixtures();
  });

  /// La API real del estudiante, salvo que mientras [hayRed] sea falso toda
  /// petición falla como falla un teléfono sin señal.
  Future<void Function(bool)> montar(WidgetTester tester) async {
    conSesionGuardada();
    fijarTamano(tester, const Size(1440, 900));
    var hayRed = false;
    final real = fakeDe(Roles.student).build();
    final api = ApiService(
      client: MockClient((request) async {
        if (!hayRed) {
          throw http.ClientException("Failed host lookup: 'api'");
        }
        // Se reenvía al doble real con las mismas rutas del estudiante.
        return _reenviar(real, request);
      }),
    );
    final data = DataProvider(api);
    await tester.pumpWidget(
        EnactusApp(api: api, data: data, auth: AuthProvider(api, data)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    return (v) => hayRed = v;
  }

  testWidgets('sin red al abrir: "Sin conexión" y no la portada',
      (tester) async {
    await montar(tester);
    expect(find.byType(SinConexionView), findsOneWidget,
        reason: 'Sin red, la app no avisó que no había conexión.');
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byType(PortalShell), findsNothing);
  });

  testWidgets('"Reintentar" con la red de vuelta entra al portal',
      (tester) async {
    final redDisponible = await montar(tester);
    redDisponible(true);
    await tester.tap(find.text('Reintentar'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.byType(SinConexionView), findsNothing);
    expect(find.byType(PortalShell), findsOneWidget,
        reason: 'Con la red de vuelta, reintentar no recuperó la sesión.');
  });

  testWidgets('al volver a primer plano reintenta sola', (tester) async {
    final redDisponible = await montar(tester);
    redDisponible(true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.byType(PortalShell), findsOneWidget,
        reason: 'Al volver a la app con señal, siguió mostrando '
            '"Sin conexión".');
  });
}

/// Pasa la petición al doble de la API y devuelve su respuesta.
Future<http.Response> _reenviar(ApiService real, http.Request request) async {
  final path = request.url.path;
  try {
    final body = await real.get(path,
        query: request.url.queryParameters.isEmpty
            ? null
            : request.url.queryParameters,
        authenticated: false);
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  } catch (_) {
    return http.Response('{}', 404,
        headers: {'content-type': 'application/json'});
  }
}
