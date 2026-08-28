// Widget tests de las pantallas de detalle agregadas/corregidas en la Fase 1
// (ver AUDITORIA_FRONT.md): que una tarjeta navega a la ruta esperada, que
// las pantallas de detalle renderizan con datos reales, que muestran un
// estado de error con un ID inválido (en vez de reventar), y que una ruta
// protegida por rol no se puede ver sin la sesión correcta.
//
// Usa un [FakeDataStore] en memoria (implementa el mismo contrato
// [DataStore] que [DbService]/Hive) para no depender de plugins nativos en
// el entorno de test — ver lib/services/data_store.dart.
//
// Dos cosas de infraestructura que NO son obvias y sin las cuales estos
// tests cuelgan o revientan:
// 1. `AnimatedLogo` (usado por `AppHeader`/`AppFooter`, o sea por casi toda
//    pantalla) trae un `AnimationController.repeat()` infinito (el barrido
//    de luz de la X — ver animated_logo.dart). `tester.pumpAndSettle()`
//    espera a que YA NO haya animaciones corriendo, así que con esta
//    pantalla montada nunca termina (timeout). Se usa [_settle] (unos
//    pumps con duración fija) en su lugar en vez de pumpAndSettle.
// 2. El tamaño de superficie por defecto de flutter_test (800×600) hace
//    que `AppFooter` desborde (es una pantalla pensada para escritorio
//    ancho) — un error real de layout que corta el pump. Se agranda la
//    superficie con [_wideSurface] antes de cada test que monta el shell
//    completo (todos, salvo que se pruebe un widget aislado).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/main.dart' show EnactusApp;
import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/data_store.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/views/shared/lab_detail_view.dart';
import 'package:enactus_platform/views/shared/user_detail_view.dart';
import 'package:enactus_platform/views/student/course_detail_view.dart';
import 'package:enactus_platform/views/student/student_courses_view.dart';

/// [DataStore] en memoria — mismo contrato que [DbService] (Hive), sin
/// depender de plugins nativos en el entorno de test.
class FakeDataStore implements DataStore {
  final Map<String, Map<String, Map<String, dynamic>>> _boxes = {};

  Map<String, Map<String, dynamic>> _box(String name) =>
      _boxes.putIfAbsent(name, () => {});

  @override
  List<Map<String, dynamic>> getAll(String boxName) =>
      _box(boxName).values.toList();

  @override
  Map<String, dynamic>? get(String boxName, String id) => _box(boxName)[id];

  @override
  Future<void> put(String boxName, String id, Map<String, dynamic> json) async {
    _box(boxName)[id] = json;
  }

  @override
  Future<void> delete(String boxName, String id) async {
    _box(boxName).remove(id);
  }

  @override
  bool get isEmpty => _boxes.values.every((b) => b.isEmpty);

  @override
  Map<String, dynamic> exportAll() => _boxes;

  @override
  Future<void> importAll(Map<String, dynamic> backup) async {}
}

/// Arma un DataProvider con datos reales mínimos: un laboratorio, un curso
/// con progreso parcial de un estudiante, y dos usuarios (un estudiante y
/// un mentor) — suficiente para ejercitar navegación real con IDs reales.
DataProvider _seededData() {
  final store = FakeDataStore();
  final data = DataProvider(store);

  data.saveUser(AppUser(
    id: 'student1',
    name: 'Ana Estudiante',
    email: 'ana@test.co',
    password: 'x',
    role: Roles.student,
    extra: {'university': 'Universidad Test', 'labIds': ['lab1']},
  ));
  data.saveUser(AppUser(
    id: 'mentor1',
    name: 'Marco Mentor',
    email: 'marco@test.co',
    password: 'x',
    role: Roles.mentor,
  ));

  data.saveLab(Laboratory(id: 'lab1', name: 'Laboratorio Test', description: 'Un laboratorio de prueba'));

  data.saveCourse(Course(
    id: 'course1',
    name: 'Curso Test',
    labId: 'lab1',
    modules: [
      CourseModule(id: 'm1', title: 'Módulo 1', lessons: [
        Lesson(id: 'l1', title: 'Lección 1'),
        Lesson(id: 'l2', title: 'Lección 2'),
      ]),
    ],
  ));

  // Ana completó la lección 1 de sus 2 lecciones (50%) — usado para
  // confirmar que CourseDetailView muestra el progreso de ANA, no el de
  // quien esté mirando.
  data.toggleLesson('student1', 'course1', 'l1');

  return data;
}

Widget _wrap(Widget child, {DataProvider? data, String? loginUserId}) {
  final d = data ?? _seededData();
  final auth = AuthProvider(d);
  if (loginUserId != null) {
    final u = d.userById(loginUserId)!;
    auth.login(u.email, 'x');
  }
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: d),
      ChangeNotifierProvider.value(value: auth),
    ],
    // Scaffold extra: ContentScreenShell (StudentCoursesView, etc.) da por
    // sentado que ya está dentro de uno (normalmente el de PortalShell) —
    // sin esto, su TextField de búsqueda revienta por falta de un
    // ancestro Material. Redundante e inofensivo para UserDetailView/
    // LabDetailView/CourseDetailView, que ya traen su propio Scaffold.
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// Superficie de escritorio ancha — evita el overflow real de `AppFooter`
/// (pensado para escritorio) que se ve con el tamaño 800×600 por defecto
/// de flutter_test. Se revierte sola al terminar el test.
void _wideSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Sustituto de `pumpAndSettle()`: el logo anima en loop infinito (ver nota
/// de cabecera), así que "esperar a que no haya más animaciones" nunca
/// pasa. Unos pocos pumps de duración fija alcanzan para que se asiente
/// todo lo que sí es de una sola vez (transiciones de ruta, `Entrance`, …).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('UserDetailView', () {
    testWidgets('con un ID real muestra los datos reales del usuario',
        (tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_wrap(
        const UserDetailView(userId: 'student1'),
        loginUserId: 'mentor1',
      ));
      await _settle(tester);

      expect(find.text('Ana Estudiante'), findsOneWidget);
    });

    testWidgets('con un ID inexistente muestra el estado de error, no revienta',
        (tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_wrap(
        const UserDetailView(userId: 'no-existe-123'),
        loginUserId: 'mentor1',
      ));
      await _settle(tester);

      expect(find.textContaining('ya no existe'), findsOneWidget);
      // Ningún error de Flutter (excepción no capturada) durante el pump.
      expect(tester.takeException(), isNull);
    });
  });

  group('LabDetailView', () {
    testWidgets('con un ID real muestra los datos reales del laboratorio',
        (tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_wrap(
        const LabDetailView(labId: 'lab1'),
        loginUserId: 'mentor1',
      ));
      await _settle(tester);

      expect(find.text('LABORATORIO TEST'), findsOneWidget);
      expect(find.text('Un laboratorio de prueba'), findsOneWidget);
    });

    testWidgets('con un ID inexistente muestra el estado de error, no revienta',
        (tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_wrap(
        const LabDetailView(labId: 'no-existe-123'),
        loginUserId: 'mentor1',
      ));
      await _settle(tester);

      expect(find.textContaining('ya no existe'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CourseDetailView — bug de identidad (AUDITORIA_FRONT.md § 1.2)', () {
    testWidgets(
        'con studentId de otro usuario, muestra el progreso de ESE estudiante '
        'y el banner de solo lectura, no el de quien mira', (tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_wrap(
        const CourseDetailView(courseId: 'course1', studentId: 'student1'),
        loginUserId: 'mentor1', // el mentor mira el curso de Ana
      ));
      await _settle(tester);

      // Banner de solo lectura con el nombre real de la estudiante.
      expect(find.textContaining('Estás viendo el progreso de Ana Estudiante'),
          findsOneWidget);
      // 1 de 2 lecciones completadas = 50%, el progreso real de Ana (el
      // mentor nunca tomó el curso; antes del fix esto mostraba 0%) — cifra
      // visible en la barra de progreso (ThinProgressBar), no un tooltip.
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('sin studentId (el propio estudiante), no muestra el banner de solo lectura',
        (tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_wrap(
        const CourseDetailView(courseId: 'course1'),
        loginUserId: 'student1',
      ));
      await _settle(tester);

      expect(find.textContaining('modo de solo lectura'), findsNothing);
    });
  });

  group('Navegación real desde una tarjeta', () {
    testWidgets('la tarjeta de un curso en Mis Cursos navega a su CourseDetailView real',
        (tester) async {
      _wideSurface(tester);
      final data = _seededData();
      final student = data.userById('student1')!;
      // isRutaExpo/labId ya asignan el curso automáticamente vía labIds.
      await tester.pumpWidget(_wrap(
        const StudentCoursesView(),
        data: data,
        loginUserId: student.id,
      ));
      await _settle(tester);

      expect(find.text('CURSO TEST'), findsOneWidget);
      await tester.tap(find.text('CURSO TEST'));
      await _settle(tester);

      // Aterrizó en el detalle real del curso (título en el AppHeader/appbar
      // del detalle, distinto del título en mayúsculas de la tarjeta).
      expect(find.text('Curso Test'), findsWidgets);
    });
  });

  group('Permisos por rol bloquean el acceso donde deben', () {
    testWidgets('una ruta de portal sin sesión activa muestra el login, no el portal',
        (tester) async {
      _wideSurface(tester);
      final data = _seededData();
      final auth = AuthProvider(data);
      await tester.pumpWidget(EnactusApp(
        data: data,
        auth: auth,
        initialRoute: AppRoutes.admin,
      ));
      await _settle(tester);

      // _RoleGuard debe caer a LoginView, nunca al Dashboard de Admin.
      expect(find.text('BIENVENIDO DE NUEVO'), findsOneWidget);
      expect(find.text('Dashboard General'), findsNothing);
    });

    testWidgets('con la sesión de otro rol, tampoco se ve un portal ajeno',
        (tester) async {
      _wideSurface(tester);
      final data = _seededData();
      final auth = AuthProvider(data);
      auth.login('ana@test.co', 'x'); // Ana es student, no admin
      await tester.pumpWidget(EnactusApp(
        data: data,
        auth: auth,
        initialRoute: AppRoutes.admin,
      ));
      await _settle(tester);

      expect(find.text('BIENVENIDO DE NUEVO'), findsOneWidget);
      expect(find.text('Dashboard General'), findsNothing);
    });
  });
}
