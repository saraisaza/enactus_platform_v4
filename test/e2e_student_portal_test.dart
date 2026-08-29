// Recorrido de punta a punta contra el BACKEND REAL.
//
// Acá no hay ningún doble: `ApiService` y `DataProvider` son los de verdad y
// las peticiones salen por HTTP a la base sembrada. Si un endpoint cambia de
// forma, si una pantalla pide algo que no existe o si un rol no tiene permiso,
// esta prueba falla — que es justo lo que un `flutter build` que compila no
// puede decir.
//
// **Por qué no usa `testWidgets`**: dentro de `testWidgets` el tiempo es
// falso, así que una petición de red real nunca completa y la prueba se cuelga
// para siempre (comprobado). Lo que se verifica acá es la capa de datos contra
// el servidor; el dibujo de las pantallas está cubierto en
// `navigation_test.dart`, con payloads de la misma forma que devuelve este
// backend.
//
// Se salta sola si el backend está apagado, en vez de fallar: no debería
// romperle la suite a quien solo corre `flutter test`.
//
//   cd backend && npm run db:reset && npm run dev
//   flutter test test/e2e_student_portal_test.dart
@Tags(['e2e'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_errors.dart';
import 'package:enactus_platform/services/api_service.dart';

const _enactus = 'estudiante1@uniandes.edu.co';
const _openLearning = 'camila.rivas@gmail.com';
const _otroEstudiante = 'estudiante3@unal.edu.co';
const _clave = 'Est123';

bool up = false;

/// Sesiones compartidas por cuenta.
///
/// El backend limita los intentos de ingreso a 10 por IP y correo cada 5
/// minutos —una defensa real contra fuerza bruta— así que una suite que entra
/// en cada prueba se bloquea sola. Se entra UNA vez por cuenta y se reusa.
final Map<String, Session> _sessions = {};

Future<bool> _backendUp() async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final req = await client.getUrl(Uri.parse('${ApiService.baseUrl}/health'));
    final res = await req.close();
    await res.drain<void>();
    client.close();
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}

typedef Session = ({
  ApiService api,
  DataProvider data,
  AuthProvider auth,
  AppUser user
});

Future<Session> signIn(String email) async {
  final cached = _sessions[email];
  if (cached != null) return cached;

  final api = ApiService();
  final data = DataProvider(api);
  final auth = AuthProvider(api, data);
  final user = await auth.login(email, _clave);
  expect(user, isNotNull,
      reason: 'No se pudo entrar con $email: ${auth.loginError?.message}');
  final session = (api: api, data: data, auth: auth, user: user!);
  _sessions[email] = session;
  return session;
}

/// Lee un getter perezoso del provider y espera a que llegue su dato.
///
/// Los getters disparan su pedido al primer acceso y notifican al responder;
/// acá no hay widgets escuchando, así que se sondea.
Future<T> load<T>(dynamic Function() read) async {
  for (var i = 0; i < 80; i++) {
    final state = read();
    final error = state.errorOrNull as ApiException?;
    if (error != null) throw error;
    final value = state.valueOrNull as T?;
    if (value != null) return value;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('El dato nunca llegó (8 s).');
}

/// Espera a que un getter falle, y devuelve el error.
Future<ApiException> loadError(dynamic Function() read) async {
  for (var i = 0; i < 80; i++) {
    final error = read().errorOrNull as ApiException?;
    if (error != null) return error;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Se esperaba un error y nunca llegó.');
}

void main() {
  setUpAll(() async {
    // `flutter_test` reemplaza `HttpClient` por uno falso que responde 400 a
    // TODO, para que una prueba de unidad no salga a la red sin querer. Esta
    // sí quiere: se quita el reemplazo a propósito y de forma explícita.
    HttpOverrides.global = null;
    up = await _backendUp();
    if (!up) {
      // ignore: avoid_print
      print('\n⚠️  Backend apagado en ${ApiService.baseUrl} — se saltan estas '
          'pruebas.\n   Levantalo con: cd backend && npm run dev\n');
    }
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('entra con una cuenta real y trae equipo y patrocinador', () async {
    if (!up) return;
    final s = await signIn(_enactus);

    expect(s.user.role, 'student');
    expect(s.user.isEnactusStudent, isTrue);
    // Lo que antes salía de `extra['groupId']`, una denormalización de Hive.
    expect(s.user.team, isNotNull, reason: '/auth/me no trajo el equipo');
    expect(s.user.team!.projectName, isNotEmpty);
    expect(s.user.team!.groupName, isNotEmpty);
    // Y el patrocinador ya resuelto: `companyId` solo no sirve para mostrarlo.
    expect(s.user.sponsorName, isNotNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('los cursos llegan con su avance y el nombre de su laboratorio',
      () async {
    if (!up) return;
    final s = await signIn(_enactus);

    final courses = await load<List<Course>>(() => s.data.courses);
    expect(courses, isNotEmpty, reason: 'un estudiante Enactus tiene cursos');

    // El nombre del laboratorio viene CON el curso: sin eso la grilla haría
    // una petición por tarjeta.
    expect(courses.any((c) => c.laboratoryName != null), isTrue);

    // Y el avance viene en la misma respuesta (`include=progress`), así que
    // leerlo no dispara nada nuevo.
    final progress = s.data.courseProgress(courses.first.id).valueOrNull;
    expect(progress, isNotNull,
        reason: 'el avance debía venir con la lista, sin otra petición');
    expect(progress!.courseId, courses.first.id);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('la Ruta de Impacto llega calculada por el servidor', () async {
    if (!up) return;
    final s = await signIn(_enactus);

    final ruta = await load<dynamic>(() => s.data.rutaProgress);
    expect(ruta.laboratories, isNotEmpty);

    final lab = ruta.laboratories.first;
    expect(lab.phases, isNotEmpty, reason: 'la Ruta llegó sin fases');

    // El desbloqueo lo decide el servidor: la primera fase siempre abierta,
    // y las siguientes solo si la anterior está completa.
    expect(lab.phases.first.isUnlocked, isTrue);
    for (var i = 1; i < lab.phases.length; i++) {
      if (!lab.phases[i - 1].isComplete) {
        expect(lab.phases[i].isUnlocked, isFalse,
            reason: 'la fase ${i + 1} no debería estar abierta');
      }
    }

    // Una sola fuente para el anillo de avance y para cada tarjeta.
    expect(lab.moduleProgress.done,
        lessThanOrEqualTo(lab.moduleProgress.total));
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('el quiz lo califica el SERVIDOR', () async {
    if (!up) return;
    final s = await signIn(_enactus);
    final courses = await load<List<Course>>(() => s.data.courses);

    Lesson? quiz;
    for (final c in courses) {
      final detail = await load<Course>(() => s.data.courseById(c.id));
      for (final module in detail.modules) {
        for (final lesson in module.lessons) {
          if (lesson.quiz.isNotEmpty) quiz = lesson;
        }
      }
      if (quiz != null) break;
    }
    expect(quiz, isNotNull, reason: 'el seed tiene al menos un quiz');
    expect(quiz!.quiz.first.question, isNotEmpty);

    final result = await s.data.submitQuiz(quiz.id, {
      for (final q in quiz.quiz) q.id: q.kind == 'multiple' ? 0 : '',
    });
    expect(result.totalQuestions, quiz.quiz.length);
    expect(result.score, inInclusiveRange(0, 100));
    // Dice QUÉ preguntas estuvieron bien, pero la clave no viaja.
    expect(result.correctness.keys, containsAll(quiz.quiz.map((q) => q.id)));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('marcar una lección recalcula curso, módulo y fase de una sola vez',
      () async {
    if (!up) return;
    final s = await signIn(_enactus);

    final courses = await load<List<Course>>(() => s.data.courses);
    final course = await load<Course>(() => s.data.courseById(courses.first.id));
    final lesson = course.modules.first.lessons.first;

    final antes = s.data.courseProgress(course.id).valueOrNull!;
    final impact = await s.data.toggleLesson(lesson.id, course.id);
    final despues = s.data.courseProgress(course.id).valueOrNull!;

    expect(impact.lessonId, lesson.id);
    expect(
        despues.completedLessons,
        impact.completed
            ? antes.completedLessons + 1
            : antes.completedLessons - 1);
    // El recálculo hacia arriba viene en la MISMA respuesta.
    expect(impact.course, isNotNull);

    // Se deja como estaba.
    await s.data.toggleLesson(lesson.id, course.id);
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('el laboratorio trae mentores, LXD y el avance del grupo', () async {
    if (!up) return;
    final s = await signIn(_enactus);

    final labs = await load<List<Laboratory>>(() => s.data.laboratories);
    expect(labs, isNotEmpty);

    final lab = await load<Laboratory>(() => s.data.labById(labs.first.id));
    expect(lab.studentsAssigned, greaterThan(0));
    // Sin esto la pantalla tendría que listar TODOS los usuarios para saber
    // quién es mentor, que es lo que hacía con Hive.
    expect(lab.mentors.isNotEmpty || lab.lxds.isNotEmpty, isTrue);
    // El agregado por fase nunca puede superar a los asignados.
    for (final phase in lab.phases) {
      expect(phase.completedByCount, lessThanOrEqualTo(lab.studentsAssigned));
    }
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('el equipo trae su checklist National Expo', () async {
    if (!up) return;
    final s = await signIn(_enactus);
    final group =
        await load<Group>(() => s.data.groupById(s.user.team!.groupId));

    expect(group.name, isNotEmpty);
    expect(group.checklist, isNotEmpty,
        reason: 'la tabla existía desde la Fase 1 pero nadie la exponía');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('editar el propio perfil NO permite ascenderse de rol', () async {
    if (!up) return;
    final s = await signIn(_enactus);

    await s.auth.updateProfile({
      'phone': '3150000000',
      'role': 'admin',
      'canGradeEnactus': true,
    });

    final me = s.auth.currentUser!;
    expect(me.phone, '3150000000');
    expect(me.role, 'student', reason: 'el rol no lo cambia quien lo pide');
    expect(me.canGradeEnactus, isFalse);
    // Y la respuesta conserva el equipo: si no, el perfil se quedaría sin
    // proyecto hasta recargar.
    expect(me.team, isNotNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  group('aislamiento', () {
    test('un Open Learning recibe 403 de la Ruta, no una lista vacía',
        () async {
      if (!up) return;
      // La regla más importante: una lista vacía haría ver un fallo de
      // permisos como si fuera "todavía no hay datos".
      final s = await signIn(_openLearning);
      expect(s.user.isOpenLearning, isTrue);

      final error = await loadError(() => s.data.rutaProgress);
      expect(error, isA<ForbiddenError>());
      expect(error.message.toLowerCase(), contains('open learning'));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('un estudiante no puede leer el avance de otro', () async {
      if (!up) return;
      final mio = await signIn(_enactus);
      final otro = await signIn(_otroEstudiante);

      await expectLater(
        otro.api.get('/students/${mio.user.id}/ruta-progress'),
        throwsA(isA<ForbiddenError>()),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('una key que nadie referencia responde 404, no 403', () async {
      if (!up) return;
      final s = await signIn(_enactus);
      // Un 403 confirmaría que el objeto está en el bucket.
      await expectLater(
        s.data.resolveFileUrl('submissions/inventada.pdf'),
        throwsA(isA<NotFoundError>()),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('un video no se sirve por URL firmada de S3', () async {
      if (!up) return;
      final s = await signIn(_enactus);
      // Decisión de costo: el video va por CloudFront. La regla vive en el
      // único punto que firma lecturas, no en un documento.
      await expectLater(
        s.data.resolveFileUrl('lessons/x/video.mp4'),
        throwsA(isA<ValidationError>()),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
