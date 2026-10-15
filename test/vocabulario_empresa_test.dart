// Las palabras del portal de una empresa.
//
// Una empresa no es una universidad: su gente son empleados, lo que toman
// son capacitaciones y lo que hace su supervisor con una entrega es
// aprobarla. Enactus y Open Learning siguen como siempre.

import 'package:flutter_test/flutter_test.dart';

import 'package:enactus_platform/l10n/textos.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';

import 'helpers/fake_api.dart';
import 'helpers/portal_harness.dart' show conSesionGuardada;

Map<String, Object?> _cuenta({Map<String, Object?>? cliente, String rol = 'student'}) => {
      'id': 'u1',
      'name': 'Ana',
      'email': 'ana@test.co',
      'role': rol,
      'studentType': 'open_learning',
      'clientId': ?cliente?['id'],
      'client': ?cliente,
    };

const _empresa = {
  'id': 'c1',
  'name': 'Nelson Electric',
  'hasLaboratories': false,
};
const _enactus = {
  'id': 'c2',
  'name': 'Enactus',
  'hasLaboratories': true,
};

Future<AuthProvider> _entrar(Map<String, Object?> cuenta) async {
  conSesionGuardada();
  final api = FakeApi(routes: {
    '/auth/me': cuenta,
    '/auth/logout': const <String, Object?>{},
  }).build();
  final auth = AuthProvider(api, DataProvider(api));
  await auth.restoreSession();
  return auth;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(useFakeTokenStorage);
  tearDown(Idioma.instancia.restablecer);

  test('una cuenta de empresa ve empleados, capacitaciones y aprobaciones',
      () async {
    await _entrar(_cuenta(cliente: _empresa));
    expect(Idioma.instancia.deEmpresa, isTrue);
    expect(tr.tabMisCursos, 'Mis capacitaciones');
    expect(tr.rolEstudiante, 'Empleado');
    expect(tr.tabCalificaciones, 'Aprobaciones');
    expect(tr.cursoDocente('Sofía'), 'Instructor: Sofía');
    expect(tr.dashboardCursosActivos(1), '1 capacitación activa');
    expect(tr.dashboardCursosActivos(3), '3 capacitaciones activas');
  });

  test('en inglés también', () async {
    await _entrar(_cuenta(cliente: _empresa));
    await Idioma.instancia.cambiar('en');
    expect(tr.tabMisCursos, 'My trainings');
    expect(tr.rolEstudiante, 'Employee');
    expect(tr.tabCalificaciones, 'Approvals');
    expect(tr.dashboardCursosActivos(2), '2 active trainings');
  });

  test('el supervisor de una empresa, igual', () async {
    await _entrar(_cuenta(cliente: _empresa, rol: 'supervisor'));
    expect(tr.supervisorTabGenteCorto, 'Empleados');
  });

  test('Enactus y Open Learning siguen como siempre', () async {
    await _entrar(_cuenta(cliente: _enactus));
    expect(Idioma.instancia.deEmpresa, isFalse);
    expect(tr.tabMisCursos, 'Mis Cursos');
    expect(tr.rolEstudiante, 'Estudiante');

    await _entrar(_cuenta());
    expect(Idioma.instancia.deEmpresa, isFalse);
    expect(tr.tabCalificaciones, 'Calificaciones');
  });

  test('al cerrar sesión vuelven las palabras de siempre', () async {
    final auth = await _entrar(_cuenta(cliente: _empresa));
    expect(tr.tabMisCursos, 'Mis capacitaciones');
    await auth.logout();
    await Future<void>.delayed(Duration.zero);
    expect(Idioma.instancia.deEmpresa, isFalse);
    expect(tr.tabMisCursos, 'Mis Cursos');
  });
}
