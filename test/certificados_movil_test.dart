// "Mis Certificados" en el teléfono: los dos botones se ven y funcionan sin
// mouse.
//
// "Descargar" solo aparecía —y solo estaba habilitado— al pasar el mouse por
// encima de la tarjeta. En un teléfono no hay mouse: el botón no existía. Y a
// 360 dp la fila desbordaba y el texto se partía letra por letra.

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

  for (final (nombre, ancho) in const [('teléfono', 360.0), ('escritorio', 1440.0)]) {
    testWidgets('en $nombre los dos botones del certificado están a la vista',
        (tester) async {
      conSesionGuardada();
      fijarTamano(tester, Size(ancho, 900));
      final errores = <String>[];
      final anterior = FlutterError.onError;
      FlutterError.onError = (d) => errores.add('${d.exception}');
      // Se restaura antes de los `expect` (ver `movil_360_test.dart`).
      var restaurado = false;
      void restaurar() {
        if (restaurado) return;
        restaurado = true;
        FlutterError.onError = anterior;
      }
      addTearDown(restaurar);

      final base = fakeDe(Roles.student);
      final yo = usuarioDe(Roles.student);
      final api = FakeApi(
        routes: {
          ...base.routes,
          '/certificates': {
            'data': [
              {
                'id': 'eeeeeeee-0000-4000-8000-000000000001',
                'code': 'EDX-2026-0001',
                'hours': 40,
                'issuedAt': '2026-09-20T15:00:00.000Z',
                'studentId': yo['id'],
                'studentNameSnapshot': yo['name'],
                'laboratoryId': 'eeeeeeee-0000-4000-8000-000000000002',
                'laboratoryNameSnapshot': 'Laboratorio de Economía Circular',
                'issuerNameSnapshot': 'Coordinación eduXaction',
              },
            ],
            'page': 1,
            'pageSize': 100,
            'total': 1,
            'totalPages': 1,
          },
        },
        statuses: base.statuses,
      ).build();
      final data = DataProvider(api);
      await tester.pumpWidget(EnactusApp(
        api: api,
        data: data,
        auth: AuthProvider(api, data),
        initialRoute: AppRoutes.forRole(Roles.student),
      ));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      // Ir a "Certificados": por "Más" en la barra inferior del teléfono, por
      // la barra lateral en escritorio.
      final menu = find.byTooltip('Más opciones');
      if (menu.evaluate().isNotEmpty) {
        await tester.tap(menu.first);
        // Pasos fijos, no `pumpAndSettle`: el portal tiene animaciones
        // infinitas (el brillo del logo) y nunca "se asienta".
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }
        await tester.tap(find.descendant(
            of: find.byType(Drawer), matching: find.text('Certificados')));
      } else {
        final barra = find.descendant(
            of: find.byType(PortalShell), matching: find.byType(ListView));
        await tester.tap(find
            .descendant(of: barra.first, matching: find.text('Certificados'))
            .first);
      }
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      restaurar();
      final ver = find.widgetWithText(OutlinedButton, 'Ver PDF');
      final compartir = find.widgetWithText(ElevatedButton, 'Compartir');
      expect(ver, findsOneWidget);
      expect(compartir, findsOneWidget,
          reason: 'El botón para descargar/compartir no está a la vista.');
      expect(tester.widget<ElevatedButton>(compartir).onPressed, isNotNull,
          reason: 'El botón existe pero está deshabilitado sin mouse.');
      expect(errores.where((e) => e.contains('overflowed')), isEmpty,
          reason: 'La tarjeta del certificado desborda a ${ancho.round()} dp.');
    });
  }
}
