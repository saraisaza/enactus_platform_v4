// Volver a la app trae el avance que se hizo en otro dispositivo.
//
// Un estudiante reportó que el avance no coincidía entre el teléfono y el
// computador. La app solo volvía a preguntar al servidor si había estado más
// de cinco minutos en segundo plano: quien vio un video en el computador y
// tomó el teléfono un minuto después seguía viendo la lección pendiente y la
// siguiente con candado.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:enactus_platform/main.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/widgets/portal_shell.dart';

import 'helpers/fake_api.dart';
import 'helpers/portal_harness.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    cargarFixtures();
  });

  Future<(FakeApi, DataProvider, void Function(Duration))> montarApp(
      WidgetTester tester) async {
    conSesionGuardada();
    fijarTamano(tester, const Size(390, 844));
    final fake = fakeDe(Roles.student);
    final api = fake.build();
    var ahora = DateTime(2026, 10, 15, 9);
    final data = DataProvider(api)..reloj = () => ahora;
    await tester.pumpWidget(
        EnactusApp(api: api, data: data, auth: AuthProvider(api, data)));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.byType(PortalShell), findsOneWidget);
    return (fake, data, (d) => ahora = ahora.add(d));
  }

  Future<void> salirYVolver(
      WidgetTester tester, void Function(Duration) pasa, Duration afuera) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    pasa(afuera);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  int pedidosDeCursos(FakeApi fake) =>
      fake.requested.where((r) => r == 'GET /courses').length;

  testWidgets('tras un minuto en otro dispositivo, vuelve a preguntar el avance',
      (tester) async {
    final (fake, _, pasa) = await montarApp(tester);
    final antes = pedidosDeCursos(fake);
    expect(antes, greaterThan(0));

    await salirYVolver(tester, pasa, const Duration(minutes: 1));
    expect(pedidosDeCursos(fake), greaterThan(antes),
        reason: 'al volver, el avance de los cursos se tiene que pedir de nuevo');
  });

  testWidgets('en el computador, volver a la ventana del navegador también',
      (tester) async {
    // La ventana quedó a la vista (no se ocultó) mientras usaba el teléfono.
    final (fake, _, pasa) = await montarApp(tester);
    final antes = pedidosDeCursos(fake);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    pasa(const Duration(minutes: 3));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(pedidosDeCursos(fake), greaterThan(antes));
  });

  testWidgets('un vistazo de dos segundos a otra app no pide nada',
      (tester) async {
    final (fake, _, pasa) = await montarApp(tester);
    final antes = fake.requested.length;
    await salirYVolver(tester, pasa, const Duration(seconds: 2));
    expect(fake.requested.length, antes);
  });
}
