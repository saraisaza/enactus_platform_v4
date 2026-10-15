// El Manager / Supervisor y los cursos exclusivos, del lado de la app
// (etapa 4).
//
// - El supervisor entra a SU portal, con la marca de su empresa.
// - En el panel, un supervisor exige la empresa y se guarda con ella.
// - Al asignar cursos, no se ofrecen los exclusivos de OTRA empresa: el
//   servidor los rechazaría.
// - Un LXD de una empresa crea cursos de Open Learning, sin laboratorio: el
//   servidor los marca como exclusivos de su empresa.
//
// Quién ve qué lo decide el servidor (`backend/tests/supervisor.test.ts`);
// acá se mide que la app no ofrezca lo que el servidor va a rechazar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/l10n/textos.dart';
import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/utils/app_theme.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/utils/marca.dart';
import 'package:enactus_platform/views/admin/admin_users.dart';
import 'package:enactus_platform/views/admin/student_assignments_dialog.dart';
import 'package:enactus_platform/widgets/portal_shell.dart';
import 'package:enactus_platform/views/lxd/course_editor_view.dart';

import 'helpers/fake_api.dart';
import 'helpers/portal_harness.dart';

const _azul = Color(0xFF1A73E8);
const _idAndino = '2f8d4b61-9c0a-4e7b-8d12-5a6b7c8d9e02';
const _idNorte = '6b5a4c3d-2e1f-4a0b-9c8d-7e6f5a4b3c21';

/// Ids reales del sembrado: el contrato reenvía los cuerpos al servidor, que
/// rechaza lo que no es un UUID.
const _cursoGeneral = 'f5883732-7819-58a7-bc9a-e67556e5dc2d';
const _cursoAndino = 'bbbbbbbb-0000-4000-8000-0000000000a1';
const _cursoNorte = 'bbbbbbbb-0000-4000-8000-0000000000b2';
const _idAna = 'aaaaaaaa-0000-4000-8000-0000000000a9';

Map<String, Object?> _marcaAndino() => {
      'clientId': _idAndino,
      'client': {
        'id': _idAndino,
        'name': 'Banco Andino',
        'logoUrl': null,
        'logoWidth': null,
        'logoHeight': null,
        'logoLightPlate': false,
        'primaryColor': '#1A73E8',
        'secondaryColor': '#0B5394',
        'hasLaboratories': false,
      },
    };

Future<void> _pasos(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    cargarFixtures();
  });
  setUp(conSesionGuardada);
  tearDown(Marca.instancia.restablecer);

  testWidgets('el supervisor entra a su portal, con la marca de su empresa',
      (tester) async {
    fijarTamano(tester, const Size(1440, 900));
    await montar(tester, appDe(Roles.supervisor));
    expect(find.byType(PortalShell), findsOneWidget);
    expect(AppColors.relleno, _azul);
    for (final pestana in [
      tr.supervisorTabGenteCorto,
      tr.tabCalificaciones,
      // «Capacitaciones», no «Mis…»: el supervisor no las crea.
      tr.supervisorTabCapacitaciones,
      tr.tabCertificados,
    ]) {
      expect(find.text(pestana), findsWidgets, reason: pestana);
    }
  });

  group('el formulario de cuentas', () {
    testWidgets('un supervisor exige su empresa, y se guarda con ella',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 1400);
      addTearDown(tester.view.reset);
      final api = FakeApi(routes: {
        '/clients': {
          'data': [
            {'id': 'enactus', 'name': 'Enactus', 'hasLaboratories': true, 'active': true},
            {'id': _idAndino, 'name': 'Banco Andino', 'hasLaboratories': false, 'active': true},
          ],
        },
        '/universities': {'data': <Object>[]},
        'POST /users': {
          'id': 'dddddddd-0000-4000-8000-0000000000d1',
          'name': 'Laura',
          'email': 'laura@bancoandino.co',
          'role': Roles.supervisor,
          'clientId': _idAndino,
          'canGradeOpenLearning': true,
        },
      }, fallback: (_) => {'data': <Object>[]});
      final data = DataProvider(api.build());
      await tester.pumpWidget(ChangeNotifierProvider<DataProvider>.value(
        value: data,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showUserDialog(context,
                      creatableRoles: const [Roles.supervisor],
                      isSuperAdmin: false),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text(tr.usuariosSupervisorAyuda), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextField, tr.usuariosNombreCompleto), 'Laura');
      await tester.enterText(find.widgetWithText(TextField, tr.ingresoCorreo),
          'laura@bancoandino.co');
      await tester.enterText(
          find.widgetWithText(TextField, tr.ingresoContrasena), 'Clave123');

      // Sin empresa, no guarda: un supervisor sin empresa no tendría a quién
      // acompañar (y la base tampoco lo deja).
      await tester.tap(find.text(tr.comunGuardar));
      await tester.pump();
      expect(find.text(tr.usuariosEligaEmpresa), findsOneWidget);
      expect(api.requested.where((r) => r == 'POST /users'), isEmpty);

      await tester.tap(find.text(tr.usuariosEmpresaCliente));
      await tester.pumpAndSettle();
      // Enactus no se ofrece: su red tiene a sus mentores.
      expect(find.text('Enactus'), findsNothing);
      await tester.tap(find.text('Banco Andino').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.comunGuardar));
      await _pasos(tester);

      final i = api.requested.indexOf('POST /users');
      expect(i, isNot(-1), reason: 'pidió: ${api.requested}');
      expect(api.cuerpos[i]['role'], Roles.supervisor);
      expect(api.cuerpos[i]['clientId'], _idAndino);
    });
  });

  group('asignar cursos', () {
    testWidgets('no ofrece los cursos exclusivos de otra empresa',
        (tester) async {
      useFakeTokenStorage();
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1400, 1000);
      addTearDown(tester.view.reset);

      Map<String, Object?> curso(String id, String nombre, String? cliente) => {
            'id': id,
            'name': nombre,
            'isOpenLearning': true,
            'status': 'published',
            'visible': true,
            'clientId': cliente,
          };
      final api = FakeApi(routes: {
        '/users/$_idAna/assignments': {
          'studentId': _idAna,
          'studentName': 'Ana',
          'studentType': StudentType.openLearning,
          'laboratoryIds': const <String>[],
          'courseIds': const <String>[],
        },
        '/courses': {
          'data': [
            curso(_cursoGeneral, 'Liderazgo', null),
            curso(_cursoAndino, 'Riesgo bancario', _idAndino),
            curso(_cursoNorte, 'Crédito del Norte', _idNorte),
          ],
          'total': 3,
          'page': 1,
          'pageSize': 100,
        },
      });
      final ana = AppUser.fromJson({
        'id': _idAna,
        'name': 'Ana',
        'email': 'ana@bancoandino.co',
        'role': Roles.student,
        'studentType': StudentType.openLearning,
        'clientId': _idAndino,
      });
      await tester.pumpWidget(ChangeNotifierProvider<DataProvider>.value(
        value: DataProvider(api.build()),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showStudentAssignmentsDialog(context, ana),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(find.text('Liderazgo'), findsOneWidget);
      expect(find.text('Riesgo bancario'), findsOneWidget);
      expect(find.text(tr.asignarExclusivo), findsOneWidget);
      expect(find.text('Crédito del Norte'), findsNothing);
    });
  });

  group('un LXD de una empresa', () {
    testWidgets('crea cursos de Open Learning para su empresa',
        (tester) async {
      fijarTamano(tester, const Size(1440, 900));
      late FakeApi api;
      await montar(
        tester,
        appDe(Roles.lxd, cambios: _marcaAndino(), conApi: (falsa) {
          api = falsa;
          // Responde con un curso del sembrado: después de crear, la app
          // abre su editor, y ese curso tiene todas sus respuestas.
          falsa.routes['POST /courses'] = (falsa.routes['/courses'] as Map)['data'][0];
        }),
      );

      await tester.tap(find.text(tr.tabMisCursos).first);
      await _pasos(tester);
      await tester.tap(find.text(tr.lxdNuevoCurso).first);
      await _pasos(tester);
      expect(find.text(tr.lxdCursoDeEmpresa('Banco Andino')), findsOneWidget);
      // Ni la opción de Open Learning ni la de laboratorio: no son suyas.
      expect(find.text(tr.lxdCursoOpenLearning), findsNothing);
      expect(find.text(tr.lxdLaboratorioOpcional), findsNothing);

      await tester.enterText(
          find.widgetWithText(TextField, tr.lxdNombreDelCurso), 'Crédito');
      await tester.tap(find.text(tr.lxdCrearAbrir));
      await _pasos(tester);

      final i = api.requested.indexOf('POST /courses');
      expect(i, isNot(-1), reason: 'pidió: ${api.requested}');
      expect(api.cuerpos[i]['isOpenLearning'], isTrue);
      expect(api.cuerpos[i]['laboratoryId'], isNull);
    });

    testWidgets('un LXD de eduXaction sigue eligiendo', (tester) async {
      fijarTamano(tester, const Size(1440, 900));
      await montar(tester, appDe(Roles.lxd));
      await tester.tap(find.text(tr.tabMisCursos).first);
      await _pasos(tester);
      await tester.tap(find.text(tr.lxdNuevoCurso).first);
      await _pasos(tester);
      expect(find.text(tr.lxdCursoOpenLearning), findsOneWidget);
      expect(find.textContaining('Banco Andino'), findsNothing);
    });
  });

  group('una cuenta de empresa no pide lo que es de Enactus', () {
    // Laboratorios, proyectos y equipos: el servidor se los niega a una
    // cuenta de empresa (etapa 5). Si la app los pidiera igual, la pestaña
    // mostraría un error en vez de no estar.
    bool esDeEnactus(String pedido) =>
        RegExp(r' /(laboratories|projects|groups)(/|$)').hasMatch(pedido);

    Future<FakeApi> recorrer(WidgetTester tester, String rol) async {
      fijarTamano(tester, const Size(1440, 900));
      late FakeApi api;
      await montar(
        tester,
        appDe(rol, cambios: _marcaAndino(), conApi: (falsa) => api = falsa),
      );
      final barra = find.descendant(
          of: find.byType(PortalShell), matching: find.byType(ListView));
      for (final rotulo in rotulosDeBarraLateral(tester, barra)) {
        await tester.tap(
            find.descendant(of: barra.first, matching: find.text(rotulo)).first,
            warnIfMissed: false);
        await _pasos(tester);
      }
      return api;
    }

    testWidgets('el LXD de la empresa, en todo su portal y en el editor',
        (tester) async {
      final api = await recorrer(tester, Roles.lxd);
      expect(find.text(tr.tabProyectosCorto), findsNothing);
      expect(find.text(tr.tabCertificaciones), findsNothing);

      await tester.tap(find.text(tr.tabMisCursos).first);
      await _pasos(tester);
      await tester.tap(find.text(tr.lxdConstructor).first);
      await _pasos(tester);
      expect(find.byType(CourseEditorView), findsOneWidget);

      expect(api.requested.where(esDeEnactus), isEmpty,
          reason: 'pidió: ${api.requested.where(esDeEnactus).toSet()}');
    });

    testWidgets('el supervisor, en todo su portal', (tester) async {
      final api = await recorrer(tester, Roles.supervisor);
      expect(api.requested.where(esDeEnactus), isEmpty,
          reason: 'pidió: ${api.requested.where(esDeEnactus).toSet()}');
    });
  });
}
