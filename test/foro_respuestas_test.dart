// Las respuestas del foro se ven, y cada una dice QUIÉN respondió.
//
// Dos fallas, una encima de la otra:
//
// 1. La pantalla mostraba el `authorId` de cada respuesta: 36 caracteres de un
//    UUID donde iba el nombre de una persona.
// 2. Debajo de esa había otra peor: el listado del servidor trae cuántas
//    respuestas hay (`replyCount`), no las respuestas —esas vienen con el
//    detalle de la publicación—, y la tarjeta solo miraba las del listado.
//    Ninguna respuesta se veía nunca y el contador decía siempre «0».
//
// Por eso esta prueba arma los datos con la forma REAL de la API: el conteo en
// el listado y la respuesta en el detalle. Inyectarla en el listado, como hacía
// antes, probaba un servidor que no existe.

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

const _idAutora = 'dddddddd-0000-4000-8000-000000000001';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    cargarFixtures();
  });

  testWidgets('la respuesta muestra el nombre de quien respondió',
      (tester) async {
    conSesionGuardada();
    fijarTamano(tester, const Size(1440, 900));

    final base = fakeDe(Roles.student);
    final pagina = Map<String, Object?>.from(base.routes['/forum-posts'] as Map);
    final posts = (pagina['data'] as List).cast<Map>();
    final post = Map<String, Object?>.from(posts.first);
    pagina['data'] = [
      {...post, 'replyCount': 1},
      ...posts.skip(1),
    ];
    final detalle = {
      ...post,
      'replies': [
        {
          'id': 'dddddddd-0000-4000-8000-000000000002',
          'authorId': _idAutora,
          'authorName': 'Marta Respondona',
          'authorRole': Roles.student,
          'body': 'Gracias por compartir.',
          'createdAt': '2026-09-20T15:00:00.000Z',
        },
      ],
    };

    final api = FakeApi(
      routes: {
        ...base.routes,
        '/forum-posts': pagina,
        '/forum-posts/${post['id']}': detalle,
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

    final barra = find.descendant(
        of: find.byType(PortalShell), matching: find.byType(ListView));
    await tester.tap(
        find.descendant(of: barra.first, matching: find.text('Foro')).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    // El listado dice cuántas hay...
    expect(find.text('1 respuesta'), findsOneWidget,
        reason: 'El contador no usa el conteo que manda el servidor.');
    // ...y al abrir la conversación aparecen, con su autora.
    await tester.ensureVisible(find.text('1 respuesta'));
    await tester.pump();
    await tester.tap(find.text('1 respuesta'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.text('Gracias por compartir.'), findsOneWidget,
        reason: 'La respuesta no se ve al abrir la conversación.');
    expect(find.textContaining('Marta Respondona'), findsWidgets,
        reason: 'La respuesta no dice quién la escribió.');
    expect(find.textContaining(_idAutora), findsNothing,
        reason: 'La respuesta muestra el identificador interno del autor.');
  });
}
