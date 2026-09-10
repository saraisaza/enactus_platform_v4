// El diálogo de asignar material a un estudiante.
//
// Lo que se mide acá no es que el diálogo se dibuje, sino que ofrezca LO QUE
// CORRESPONDE a cada tipo de cuenta y que mande la lista correcta al guardar.
// La distinción importa: laboratorios y cursos son excluyentes en el servidor
// —`student_course_access` mira una tabla u otra según el tipo— así que un
// diálogo que ofreciera lo contrario dejaría guardar algo que no surte ningún
// efecto, sin error visible.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/views/admin/student_assignments_dialog.dart';

import 'helpers/fake_api.dart';

/// Los ids son UUID de verdad, tomados del sembrado.
///
/// Antes eran `'c1'`. El doble de la API acepta cualquier cosa, así que la
/// prueba pasaba — pero el servidor rechaza eso con «Invalid UUID», y la
/// forma que se estaba probando no existe en producción. Lo encontró
/// `backend/tests/contrato-cliente.test.ts` al reenviar al endpoint real el
/// cuerpo que esta prueba hacía emitir.
const _idCurso = 'f5883732-7819-58a7-bc9a-e67556e5dc2d';

const _idOl = 'aaaaaaaa-0000-4000-8000-000000000001';
const _idEnactus = 'aaaaaaaa-0000-4000-8000-000000000002';

AppUser _estudiante(String id, String tipo) => AppUser.fromJson({
      'id': id,
      'name': tipo == StudentType.openLearning ? 'Camila Rivas' : 'Ana Torres',
      'email': 'quien@ejemplo.co',
      'role': Roles.student,
      'studentType': tipo,
    });

Map<String, Object?> _curso(String id, String name,
        {bool openLearning = false,
        String status = 'published',
        bool visible = true}) =>
    {
      'id': id,
      'name': name,
      'isOpenLearning': openLearning,
      'status': status,
      'visible': visible,
    };

Map<String, Object?> _lab(String id, String name) =>
    {'id': id, 'name': name, 'description': '', 'phases': const []};

/// Monta el diálogo ya abierto, con la API falsa detrás.
Future<DataProvider> montarDialogo(
  WidgetTester tester,
  AppUser estudiante,
  FakeApi fake,
) async {
  useFakeTokenStorage();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1400, 1000);
  addTearDown(tester.view.reset);

  final data = DataProvider(fake.build());

  await tester.pumpWidget(
    ChangeNotifierProvider<DataProvider>.value(
      value: data,
      child: MaterialApp(
        // El `Scaffold` no es decorativo: `ScaffoldMessenger` necesita uno
        // registrado para dibujar un `SnackBar`. En la app real lo pone
        // `PortalShell`; sin él acá, el aviso se emitiría y no se vería.
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showStudentAssignmentsDialog(context, estudiante),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('abrir'));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  return data;
}

void main() {
  testWidgets('a un Open Learning le ofrece CURSOS, no laboratorios',
      (tester) async {
    final fake = FakeApi(routes: {
      '/users/$_idOl/assignments': {
        'studentId': _idOl,
        'studentName': 'Camila Rivas',
        'studentType': StudentType.openLearning,
        'laboratoryIds': const <String>[],
        'courseIds': const <String>[],
      },
      '/courses': {
        'data': [
          _curso(_idCurso, 'Marketing Digital', openLearning: true),
          _curso('c2', 'Gestión Hídrica'),
        ],
        'total': 2,
        'page': 1,
        'pageSize': 100,
      },
    });

    await montarDialogo(tester, _estudiante(_idOl, StudentType.openLearning),
        fake);

    expect(find.text('Marketing Digital'), findsOneWidget);
    expect(find.text('Gestión Hídrica'), findsOneWidget);
    // No pidió laboratorios: no son lo que esta cuenta puede recibir.
    expect(fake.requested.any((r) => r.contains('/laboratories')), isFalse);
  });

  testWidgets('a un eduXaction le ofrece LABORATORIOS, no cursos',
      (tester) async {
    final fake = FakeApi(routes: {
      '/users/$_idEnactus/assignments': {
        'studentId': _idEnactus,
        'studentName': 'Ana Torres',
        'studentType': StudentType.enactus,
        'laboratoryIds': ['l1'],
        'courseIds': const <String>[],
      },
      '/laboratories': {
        'data': [_lab('l1', 'Laboratorio de IA'), _lab('l2', 'Agua')],
        'total': 2,
        'page': 1,
        'pageSize': 100,
      },
    });

    await montarDialogo(
        tester, _estudiante(_idEnactus, StudentType.enactus), fake);

    expect(find.text('Laboratorio de IA'), findsOneWidget);
    expect(find.text('Agua'), findsOneWidget);
    expect(fake.requested.any((r) => r.contains('GET /courses')), isFalse);
  });

  testWidgets('la selección arranca en lo YA asignado, no vacía',
      (tester) async {
    // Sin esto, abrir el diálogo y guardar sin tocar nada borraría todo lo
    // que la persona tenía: la escritura reemplaza la lista completa.
    final fake = FakeApi(routes: {
      '/users/$_idEnactus/assignments': {
        'studentId': _idEnactus,
        'studentName': 'Ana Torres',
        'studentType': StudentType.enactus,
        'laboratoryIds': ['l1'],
        'courseIds': const <String>[],
      },
      '/laboratories': {
        'data': [_lab('l1', 'Laboratorio de IA'), _lab('l2', 'Agua')],
        'total': 2,
        'page': 1,
        'pageSize': 100,
      },
      '/users/$_idEnactus/laboratories': {
        'studentId': _idEnactus,
        'laboratoryIds': ['l1'],
      },
    });

    await montarDialogo(
        tester, _estudiante(_idEnactus, StudentType.enactus), fake);

    final marcadas = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .where((c) => c.value == true)
        .length;
    expect(marcadas, 1, reason: 'el laboratorio ya asignado tiene que venir marcado');
  });

  testWidgets('avisa cuáles cursos no verá todavía en vez de callarlo',
      (tester) async {
    final fake = FakeApi(routes: {
      '/users/$_idOl/assignments': {
        'studentId': _idOl,
        'studentName': 'Camila Rivas',
        'studentType': StudentType.openLearning,
        'laboratoryIds': const <String>[],
        'courseIds': const <String>[],
      },
      '/courses': {
        'data': [_curso(_idCurso, 'Marketing Digital', status: 'draft')],
        'total': 1,
        'page': 1,
        'pageSize': 100,
      },
      '/users/$_idOl/courses': {
        'studentId': _idOl,
        'courseIds': [_idCurso],
        'notReady': [
          {'id': _idCurso, 'name': 'Marketing Digital'},
        ],
      },
    });

    await montarDialogo(
        tester, _estudiante(_idOl, StudentType.openLearning), fake);

    // El curso en borrador se marca como tal ANTES de asignarlo.
    expect(find.text('Borrador'), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    // Se guardó, y se dijo que todavía no lo verá. Un "✓ Asignado" a secas
    // dejaría a alguien esperando un curso que nunca le aparece.
    expect(fake.requested, contains('PUT /users/$_idOl/courses'));
    expect(find.textContaining('no está publicado'), findsOneWidget);
  });
}
