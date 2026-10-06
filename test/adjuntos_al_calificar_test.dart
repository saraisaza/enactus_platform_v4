// Quien revisa una entrega ve el archivo que el estudiante adjuntó.
//
// El LXD y el Mentor veían la tarea, el autor y el comentario, pero no los
// adjuntos: sus tarjetas no los dibujaban, y el listado del servidor tampoco
// los mandaba. Se calificaba sin poder abrir lo entregado. El permiso para
// abrirlos sí existía (`/files/download-url` lo autoriza a ambos).

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

const _archivo = 'propuesta del equipo.pdf';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    cargarFixtures();
  });

  for (final (role, pestana) in [
    (Roles.lxd, 'Calificaciones'),
    (Roles.mentor, 'Entregas'),
  ]) {
    testWidgets('${Roles.label(role)} ve el adjunto en «$pestana»',
        (tester) async {
      conSesionGuardada();
      fijarTamano(tester, const Size(1440, 900));

      // La forma real del listado: cada entrega con su lista `files`.
      final base = fakeDe(role);
      final pagina =
          Map<String, Object?>.from(base.routes['/submissions'] as Map);
      final entregas = (pagina['data'] as List).cast<Map>();
      pagina['data'] = [
        {
          ...entregas.first,
          'files': [
            {
              'id': 'eeeeeeee-0000-4000-8000-000000000001',
              's3Key': 'submissions/est1/propuesta.pdf',
              'fileName': _archivo,
              'contentType': 'application/pdf',
              'sizeBytes': 2048,
            },
          ],
        },
        ...entregas.skip(1),
      ];

      final api = FakeApi(
        routes: {...base.routes, '/submissions': pagina},
        statuses: base.statuses,
      ).build();
      final data = DataProvider(api);
      await tester.pumpWidget(EnactusApp(
        api: api,
        data: data,
        auth: AuthProvider(api, data),
        initialRoute: AppRoutes.forRole(role),
      ));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      final barra = find.descendant(
          of: find.byType(PortalShell), matching: find.byType(ListView));
      await tester.tap(
          find.descendant(of: barra.first, matching: find.text(pestana)).first);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(find.text(entregas.first['taskName'] as String), findsWidgets,
          reason: 'La entrega no aparece: la prueba no llegó a la pestaña.');
      expect(find.text(_archivo), findsOneWidget,
          reason: 'La tarjeta no muestra el archivo que se entregó.');
    });
  }
}
