// Widget tests de navegación y de las pantallas de detalle.
//
// Ahora corren contra un cliente HTTP falso que devuelve payloads con la forma
// REAL de la API (ver `helpers/fake_api.dart`), en vez de un almacén en
// memoria. Es a propósito: así se ejercita el `ApiService` de verdad —su
// parseo, su manejo de errores, sus estados de carga— y una prueba que pasa
// significa que la pantalla funciona con lo que el servidor manda, no con lo
// que un doble decidió devolver.
//
// Tres cosas de infraestructura que NO son obvias:
//
// 1. `AnimatedLogo` (que usan `AppHeader`/`AppFooter`, o sea casi toda
//    pantalla) tiene un `AnimationController.repeat()` infinito. `pumpAndSettle`
//    espera a que no queden animaciones, así que nunca termina. Se usa
//    [_settle], unos pumps de duración fija.
// 2. El tamaño por defecto de flutter_test (800×600) hace desbordar al
//    `AppFooter`, que está pensado para escritorio. [_wideSurface] lo agranda.
// 3. Los datos llegan por red aunque sea falsa: hay que dejar correr los
//    microtasks para que el provider pase de `loading` a `data`. Eso también
//    lo cubre [_settle].
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/main.dart' show EnactusApp;
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_service.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/widgets/async_states.dart';
import 'package:enactus_platform/views/shared/lab_detail_view.dart';
import 'package:enactus_platform/views/student/course_detail_view.dart';
import 'package:enactus_platform/views/student/student_courses_view.dart';

import 'helpers/fake_api.dart';

// ---------------------------------------------------------------------------
// Payloads con la forma real de la API
// ---------------------------------------------------------------------------

const _ana = {
  'id': 'student1',
  'name': 'Ana Estudiante',
  'email': 'ana@test.co',
  'role': 'student',
  'studentType': 'enactus',
  'university': 'Universidad Test',
};

const _curso = {
  'id': 'course1',
  'name': 'Curso Test',
  'description': 'Un curso de prueba',
  'level': 'basic',
  'status': 'published',
  'laboratoryId': 'lab1',
  'laboratoryName': 'Laboratorio Test',
  'creatorName': 'Luz LXD',
  'language': 'es',
};

/// Ana completó 1 de sus 2 lecciones. Es la cifra que la prueba de identidad
/// usa para confirmar que se muestra el avance de ELLA y no el de quien mira.
const _progresoDeAna = {
  'courseId': 'course1',
  'courseName': 'Curso Test',
  'totalLessons': 2,
  'completedLessons': 1,
  'ratio': 0.5,
  'isComplete': false,
  'completedLessonIds': ['l1'],
};

const _sinProgreso = {
  'courseId': 'course1',
  'courseName': 'Curso Test',
  'totalLessons': 2,
  'completedLessons': 0,
  'ratio': 0.0,
  'isComplete': false,
  'completedLessonIds': <String>[],
};

const _cursoConLecciones = {
  ..._curso,
  'tags': <String>[],
  'ods': <String>[],
  'objectives': <Map<String, Object?>>[],
  'modules': [
    {
      'id': 'm1',
      'title': 'Módulo 1',
      'lessons': [
        {'id': 'l1', 'title': 'Lección 1', 'type': 'resource'},
        {'id': 'l2', 'title': 'Lección 2', 'type': 'resource'},
      ],
    },
  ],
};

const _laboratorio = {
  'id': 'lab1',
  'name': 'Laboratorio Test',
  'description': 'Un laboratorio de prueba',
  'contentVersion': 1,
  'studentsAssigned': 1,
  'sponsorName': null,
  'mentors': [
    {'id': 'mentor1', 'name': 'Marco Mentor', 'email': 'marco@test.co'},
  ],
  'lxds': <Map<String, Object?>>[],
  'phases': [
    {
      'id': 'f1',
      'orderIndex': 1,
      'title': 'Fase 1',
      'description': '',
      'objectives': <Map<String, Object?>>[],
      'modules': <Map<String, Object?>>[],
      'completedByCount': 0,
    },
  ],
};

const _rutaVacia = {
  'studentId': 'student1',
  'studentName': 'Ana Estudiante',
  'laboratories': <Map<String, Object?>>[],
};

Map<String, Object?> _page(List<Object?> data) => {
      'data': data,
      'page': 1,
      'pageSize': 100,
      'total': data.length,
      'totalPages': 1,
    };

/// El juego de rutas que necesita el portal del estudiante.
FakeApi _api({
  Map<String, Object?> courseProgress = _progresoDeAna,
  Set<String> notFound = const {},
  Duration delay = Duration.zero,
}) =>
    FakeApi(
      notFound: notFound,
      delay: delay,
      routes: {
        '/auth/me': _ana,
        '/courses': _page([
          {..._curso, 'progress': courseProgress},
        ]),
        '/courses/course1': _cursoConLecciones,
        '/laboratories': _page([_laboratorio]),
        '/laboratories/lab1': _laboratorio,
        '/students/student1/ruta-progress': _rutaVacia,
        '/students/student1/course-progress/course1': courseProgress,
        '/submissions': _page([]),
        '/notifications': _page([]),
      },
    );

// ---------------------------------------------------------------------------
// Montaje
// ---------------------------------------------------------------------------

/// Monta un widget con la sesión ya iniciada como Ana, sin pasar por el
/// ingreso: se fija el usuario directamente en los dos providers.
Widget _wrap(Widget child, {FakeApi? fake, bool loggedIn = true}) {
  final api = (fake ?? _api()).build();
  final data = DataProvider(api);
  final auth = AuthProvider(api, data);
  if (loggedIn) data.setCurrentUser('student1');

  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: api),
      ChangeNotifierProvider.value(value: data),
      ChangeNotifierProvider.value(value: auth),
    ],
    // Scaffold extra: `ContentScreenShell` da por sentado que ya está dentro
    // de uno (normalmente el de `PortalShell`).
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void _wideSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Sustituto de `pumpAndSettle`: el logo anima en loop infinito, así que
/// "esperar a que no queden animaciones" nunca ocurre. Estos pumps alcanzan
/// para que se resuelvan los futures de la red falsa y las transiciones.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUp(useFakeTokenStorage);

  group('LabDetailView', () {
    testWidgets('con un ID real muestra los datos del laboratorio',
        (tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_wrap(const LabDetailView(labId: 'lab1')));
      await _settle(tester);

      expect(find.text('LABORATORIO TEST'), findsOneWidget);
      expect(find.text('Un laboratorio de prueba'), findsOneWidget);
      // Los mentores vienen CON el laboratorio: la pantalla no lista usuarios.
      expect(find.text('Marco Mentor'), findsOneWidget);
    });

    testWidgets('con un ID inexistente muestra el error, no revienta',
        (tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_wrap(
        const LabDetailView(labId: 'no-existe'),
        fake: _api(notFound: {'/laboratories/no-existe'}),
      ));
      await _settle(tester);

      expect(find.textContaining('No encontramos'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mientras carga muestra el indicador, no una pantalla vacía',
        (tester) async {
      _wideSurface(tester);
      // Con la red falsa respondiendo al instante, el estado de carga se
      // pierde entre dos `pump`. Se le pone un retraso para poder verlo.
      await tester.pumpWidget(_wrap(
        const LabDetailView(labId: 'lab1'),
        fake: _api(delay: const Duration(milliseconds: 200)),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(BrandLoader), findsWidgets);

      // Y cuando llega la respuesta, el indicador se va y aparecen los datos.
      await _settle(tester);
      expect(find.byType(BrandLoader), findsNothing);
      expect(find.text('LABORATORIO TEST'), findsOneWidget);
    });
  });

  group('CourseDetailView — bug de identidad (AUDITORIA_FRONT.md § 1.2)', () {
    testWidgets(
        'con studentId de otro usuario muestra el banner de solo lectura',
        (tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_wrap(
        const CourseDetailView(courseId: 'course1', studentId: 'otro'),
        fake: FakeApi(routes: {
          '/auth/me': _ana,
          '/courses/course1': _cursoConLecciones,
          // El progreso que se pide es el de OTRO estudiante, no el propio.
          '/students/otro/course-progress/course1': _progresoDeAna,
          '/submissions': _page([]),
          '/notifications': _page([]),
        }),
      ));
      await _settle(tester);

      expect(find.textContaining('modo de solo lectura'), findsOneWidget);
      // 1 de 2 lecciones = 50%: el avance de la persona observada. Antes del
      // arreglo la pantalla mostraba el de quien miraba, que era 0%.
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('pide el progreso del estudiante observado, no el propio',
        (tester) async {
      _wideSurface(tester);
      final fake = FakeApi(routes: {
        '/auth/me': _ana,
        '/courses/course1': _cursoConLecciones,
        '/students/otro/course-progress/course1': _progresoDeAna,
        '/submissions': _page([]),
        '/notifications': _page([]),
      });
      await tester.pumpWidget(_wrap(
        const CourseDetailView(courseId: 'course1', studentId: 'otro'),
        fake: fake,
      ));
      await _settle(tester);

      // La comprobación de fondo del bug: la URL lleva el id observado.
      expect(fake.requested,
          contains('GET /students/otro/course-progress/course1'));
      expect(
          fake.requested.any((r) => r.contains('/students/student1/course-progress')),
          isFalse);
    });

    testWidgets('sin studentId no muestra el banner de solo lectura',
        (tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_wrap(
        const CourseDetailView(courseId: 'course1'),
        fake: _api(courseProgress: _sinProgreso),
      ));
      await _settle(tester);

      expect(find.textContaining('modo de solo lectura'), findsNothing);
    });
  });

  group('Navegación real desde una tarjeta', () {
    testWidgets('la tarjeta de un curso navega a su detalle', (tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_wrap(const StudentCoursesView()));
      await _settle(tester);

      expect(find.text('CURSO TEST'), findsOneWidget);
      await tester.tap(find.text('CURSO TEST'));
      await _settle(tester);

      // Aterrizó en el detalle: el título va sin mayúsculas forzadas.
      expect(find.text('Curso Test'), findsWidgets);
    });
  });

  group('Permisos por rol bloquean el acceso donde deben', () {
    testWidgets('una ruta de portal sin sesión muestra el ingreso',
        (tester) async {
      _wideSurface(tester);
      final api = _api().build();
      final data = DataProvider(api);
      final auth = AuthProvider(api, data);

      await tester.pumpWidget(EnactusApp(
        api: api,
        data: data,
        auth: auth,
        initialRoute: AppRoutes.admin,
      ));
      await _settle(tester);

      // El guardia de rol cae al ingreso, nunca al panel de Admin.
      expect(find.text('BIENVENIDO DE NUEVO'), findsOneWidget);
      expect(find.text('Dashboard General'), findsNothing);
    });
  });
}
