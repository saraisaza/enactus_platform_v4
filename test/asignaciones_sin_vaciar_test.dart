// Asignar NUNCA puede quitar en silencio lo que ya estaba asignado.
//
// Los dos diálogos de esta suite guardan REEMPLAZANDO la lista completa
// (`PUT .../students`, `PUT .../members`). Los dos leían "quién está hoy"
// una sola vez, al abrir, sin esperar al servidor: si la respuesta todavía no
// había llegado, arrancaban con todo desmarcado, y marcar a UNA persona y
// guardar dejaba el laboratorio (o el equipo) solo con ella.
//
// Con red lenta —un teléfono, un wifi de campus— ese "todavía no había
// llegado" es lo normal. Por eso la API falsa responde con demora: la prueba
// abre el diálogo antes de que lleguen los datos, que es justo el caso que
// fallaba.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_service.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/views/admin/admin_management.dart';
import 'package:enactus_platform/views/admin/lab_ruta_editor.dart';

import 'helpers/fake_api.dart';

// UUID de verdad: el contrato cliente->servidor reenvía estos cuerpos al
// endpoint real, que rechaza cualquier otra forma.
const _idLab = 'bbbbbbbb-0000-4000-8000-000000000001';
const _idGrupo = 'bbbbbbbb-0000-4000-8000-000000000002';
const _idAna = 'bbbbbbbb-0000-4000-8000-000000000003';
const _idBeto = 'bbbbbbbb-0000-4000-8000-000000000004';

const _demora = Duration(milliseconds: 600);

Map<String, Object?> _page(List<Object?> data) => {
      'data': data,
      'page': 1,
      'pageSize': 100,
      'total': data.length,
      'totalPages': 1,
    };

Map<String, Object?> _persona(String id, String nombre) => {
      'id': id,
      'name': nombre,
      'email': '$nombre@ejemplo.co'.toLowerCase(),
      'role': Roles.student,
    };

Future<FakeApi> _montar(
  WidgetTester tester,
  Map<String, Object?> rutas,
  Widget pantalla,
) async {
  useFakeTokenStorage();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1400, 1000);
  addTearDown(tester.view.reset);

  final fake = FakeApi(routes: rutas, delay: _demora);
  final api = fake.build();
  final data = DataProvider(api);
  final auth = AuthProvider(api, data);
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<ApiService>.value(value: api),
      ChangeNotifierProvider.value(value: data),
      // El encabezado del editor lee la sesión; sin sesión no dibuja cuenta.
      ChangeNotifierProvider.value(value: auth),
    ],
    child: MaterialApp(home: Scaffold(body: pantalla)),
  ));
  return fake;
}

Future<void> _esperar(WidgetTester tester, Duration cuanto) async {
  final pasos = cuanto.inMilliseconds ~/ 100 + 1;
  for (var i = 0; i < pasos; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Después de guardar, el provider recarga lo que cambió y la API falsa
/// responde con demora: hay que dejar que esas respuestas lleguen antes de
/// terminar, o la prueba termina con temporizadores vivos.
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await _esperar(tester, _demora * 3);
}

ElevatedButton _guardar(WidgetTester tester) => tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, 'Guardar'));

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets(
      'estudiantes de un laboratorio: no deja guardar hasta saber quién está, '
      'y no quita a nadie al agregar', (tester) async {
    final fake = await _montar(
      tester,
      {
        '/laboratories/$_idLab': {
          'id': _idLab,
          'name': 'Laboratorio Prueba',
          'description': '',
          'studentsAssigned': 1,
          'mentors': const <Object>[],
          'lxds': const <Object>[],
          'phases': const <Object>[],
        },
        // Ana es la asignada hoy. La misma respuesta sirve para la consulta
        // por laboratorio y para la de todos los estudiantes: lo que se mide es
        // si el diálogo la espera, no cómo filtra el servidor.
        '/laboratories': _page(const []),
        '/users': _page([_persona(_idAna, 'Ana')]),
        '/laboratories/$_idLab/students': const <String, Object?>{},
      },
      const LabRutaEditorView(labId: _idLab),
    );
    await _esperar(tester, _demora * 2);

    await tester.tap(find.textContaining('Estudiantes ('));
    await tester.pump(const Duration(milliseconds: 100));

    // Todavía no llegó nada: guardar ahora sería guardar una lista vacía.
    expect(_guardar(tester).onPressed, isNull,
        reason: 'Guardar quedó habilitado antes de saber quién está asignado.');

    await _esperar(tester, _demora * 2);

    final casilla = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Ana'));
    expect(casilla.value, isTrue,
        reason: 'Ana está asignada y el diálogo la mostró desmarcada: '
            'guardar la habría quitado del laboratorio.');
    expect(_guardar(tester).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await _esperar(tester, _demora * 2);

    final i = fake.requested.indexOf('PUT /laboratories/$_idLab/students');
    expect(i, isNonNegative, reason: 'No se envió la asignación.');
    expect(fake.cuerpos[i]['ids'], [_idAna]);
    await _desmontar(tester);
  });

  testWidgets(
      'integrantes de un equipo: arranca con los que ya están y no los borra '
      'al guardar', (tester) async {
    final grupo = Group.fromJson(const {
      'id': _idGrupo,
      'name': 'Equipo Prueba',
      'members': <Object>[],
    });
    final fake = await _montar(
      tester,
      {
        '/groups/$_idGrupo': {
          'id': _idGrupo,
          'name': 'Equipo Prueba',
          'members': [
            {
              'userId': _idAna,
              'name': 'Ana',
              'roleInProject': 'leader',
            },
          ],
        },
        '/groups': _page(const []),
        '/users': _page([_persona(_idAna, 'Ana'), _persona(_idBeto, 'Beto')]),
        '/groups/$_idGrupo/members': const <String, Object?>{},
      },
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showGroupMembersDialog(context, grupo),
          child: const Text('abrir'),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_guardar(tester).onPressed, isNull,
        reason: 'Guardar quedó habilitado antes de cargar los integrantes.');

    await _esperar(tester, _demora * 3);
    expect(_guardar(tester).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await _esperar(tester, _demora * 2);

    final i = fake.requested.indexOf('PUT /groups/$_idGrupo/members');
    expect(i, isNonNegative, reason: 'No se enviaron los integrantes.');
    expect(fake.cuerpos[i]['members'], [
      {'userId': _idAna, 'roleInProject': 'leader'},
    ], reason: 'El equipo se guardó sin la integrante que ya tenía.');
    await _desmontar(tester);
  });
}
