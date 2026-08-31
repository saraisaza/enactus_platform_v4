// Recorrido de AUTORÍA de punta a punta contra el BACKEND REAL.
//
// Lo que se prueba acá es el camino que recorre un LXD armando un curso, con
// el `DataProvider` de verdad y peticiones HTTP reales: crear el curso,
// categorizarlo, agregarle módulos y lecciones, escribir un quiz con su clave
// y volver a leerla, configurar una actividad y publicar.
//
// Es el complemento de `backend/tests/course-authoring.test.ts`: aquella
// prueba la API por dentro; esta prueba que el cliente **habla su mismo
// idioma** — que los identificadores que manda son los que el servidor
// espera, y que lo que devuelve se parsea sin perder nada. Esa es la clase de
// desajuste que compila perfecto y falla recién en producción.
//
// Se salta sola si el backend está apagado.
//
//   cd backend && npm run db:reset && npm run dev
//   flutter test test/e2e_lxd_authoring_test.dart
@Tags(['e2e'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enactus_platform/models/authoring.dart';
import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_errors.dart';
import 'package:enactus_platform/services/api_service.dart';
import 'package:enactus_platform/utils/constants.dart';

const _lxd = 'lxd.ia@enactus.co';
const _clave = 'Lxd123';

bool up = false;

typedef Session = ({ApiService api, DataProvider data, AuthProvider auth});

Session? _session;

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

/// Una sola sesión para toda la suite: el backend corta a 10 intentos de
/// ingreso por correo cada 5 minutos.
Future<Session> signIn() async {
  final cached = _session;
  if (cached != null) return cached;

  final api = ApiService();
  final data = DataProvider(api);
  final auth = AuthProvider(api, data);
  final user = await auth.login(_lxd, _clave);
  expect(user, isNotNull,
      reason: 'No se pudo entrar con $_lxd: ${auth.loginError?.message}');
  expect(user!.role, Roles.lxd);

  final session = (api: api, data: data, auth: auth);
  _session = session;
  return session;
}

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

void main() {
  /// El curso que crea esta suite. Se borra al final para no dejar basura en
  /// la base de desarrollo.
  String? cursoId;

  setUpAll(() async {
    HttpOverrides.global = null;
    up = await _backendUp();
    if (!up) {
      // ignore: avoid_print
      print('\n⚠️  Backend apagado en ${ApiService.baseUrl} — se saltan estas '
          'pruebas.\n   Levantalo con: cd backend && npm run dev\n');
    }
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDownAll(() async {
    if (!up || cursoId == null) return;
    try {
      await (await signIn()).data.deleteCourse(cursoId!);
    } on ApiException {
      // Si quedó con avance de alguien, el servidor lo bloquea a propósito.
    }
  });

  test('crea un curso y lo trae con sus valores por defecto', () async {
    if (!up) return;
    final s = await signIn();

    final creado = await s.data.createCourse(
      name: 'Curso de prueba automática',
      isOpenLearning: true,
    );
    cursoId = creado.id;

    expect(creado.id, isNotEmpty);
    // Un curso nace en borrador: publicar es un acto explícito.
    expect(creado.status, CourseStatus.draft);
    expect(creado.isOpenLearning, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('guarda la información general con identificadores, no etiquetas',
      () async {
    if (!up) return;
    final s = await signIn();

    // El desajuste clásico: mandar "Intermedio" donde la API espera
    // `intermediate`. Con enum de PostgreSQL detrás, eso es un 400.
    final actualizado = await s.data.updateCourse(cursoId!, {
      'name': 'Curso de prueba automática',
      'subtitle': 'Subtítulo',
      'description': 'Corta',
      'fullDescription': 'Completa',
      'level': 'intermediate',
      'language': 'es',
      'estimatedHours': 8,
    });

    expect(actualizado.level, 'intermediate');
    expect(actualizado.levelLabel, 'Intermedio');
    expect(actualizado.estimatedHours, 8);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('los catálogos vienen de la base y sus códigos los acepta el guardado',
      () async {
    if (!up) return;
    final s = await signIn();

    final catalogos = await load<Catalogs>(() => s.data.catalogs);
    expect(catalogos.competencies, hasLength(12));
    expect(catalogos.ods, hasLength(17));
    // La etiqueta se arma en el cliente; lo que se guarda es el código.
    expect(catalogos.odsLabel('ods_6'), startsWith('ODS 6:'));

    final meta = CourseMetaDraft(
      tags: ['IA', 'Innovación'],
      objectives: [
        ObjectiveDraft(text: 'Objetivo general'),
        ObjectiveDraft(
            category: 'entrepreneurship', text: 'Objetivo de emprendimiento'),
        ObjectiveDraft(category: 'business', text: 'Objetivo empresarial'),
      ],
      competencies: [catalogos.competencies.first.code],
      ods: [catalogos.ods.first.code],
      learningOutcomes: ['Construye un prototipo'],
    );
    await s.data.saveCourseMeta(cursoId!, meta);

    final curso = await load<Course>(() => s.data.courseById(cursoId!));
    expect(curso.tags, containsAll(['IA', 'Innovación']));
    expect(curso.objectives, hasLength(3));
    expect(curso.competencies, [catalogos.competencies.first.code]);
    expect(curso.learningOutcomes, ['Construye un prototipo']);
    // Y la categoría sobrevive al viaje: es lo que decide qué objetivo se
    // copia a la fase al vincular el curso a un módulo de Ruta.
    expect(
      curso.objectives.where((o) => o.category == 'entrepreneurship'),
      hasLength(1),
    );
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('un código de competencia inventado se rechaza con el código adentro',
      () async {
    if (!up) return;
    final s = await signIn();

    try {
      await s.data.saveCourseMeta(
        cursoId!,
        CourseMetaDraft(competencies: ['telepatia']),
      );
      fail('Debería haber fallado con 409.');
    } on ConflictError catch (e) {
      expect(e.details['competencies'], contains('telepatia'));
    }
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('arma módulo y quiz, y la clave vuelve para editarla', () async {
    if (!up) return;
    final s = await signIn();

    await s.data.createModule(cursoId!, 'Módulo 1');
    var curso = await load<Course>(() => s.data.courseById(cursoId!));
    expect(curso.modules, hasLength(1));
    final moduloId = curso.modules.first.id;

    final leccion = await s.data.createLesson(
      moduloId,
      title: 'Quiz de prueba',
      type: 'quiz',
    );

    await s.data.saveLessonQuiz(
      leccion.id,
      [
        QuizQuestionDraft(
          kind: 'multiple',
          question: '¿Cuál es la capital de Colombia?',
          options: ['Medellín', 'Bogotá', 'Cali'],
          answerIndex: 1,
        ),
        QuizQuestionDraft(
          kind: 'order',
          question: 'Ordená las etapas:',
          options: ['Primero', 'Segundo', 'Tercero'],
        ),
      ],
      courseId: cursoId!,
    );

    // La lectura de autoría SÍ trae la clave: sin ella, abrir la lección en el
    // constructor mostraría las respuestas en blanco y el próximo guardado las
    // borraría.
    final borrador = await s.data.lessonQuiz(leccion.id);
    expect(borrador, hasLength(2));
    expect(borrador.first.answerIndex, 1);
    expect(borrador.last.options, ['Primero', 'Segundo', 'Tercero']);

    // La lectura del curso NO: es la misma que ve un estudiante.
    curso = await load<Course>(() => s.data.courseById(cursoId!));
    final guardada = curso.modules.first.lessons
        .firstWhere((l) => l.id == leccion.id);
    expect(guardada.quiz, hasLength(2));
    expect(guardada.quiz.first.options, hasLength(3));
    expect(guardada.quiz.first.question, contains('capital'));
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('una pregunta incompleta devuelve TODOS los problemas', () async {
    if (!up) return;
    final s = await signIn();

    final curso = await load<Course>(() => s.data.courseById(cursoId!));
    final quiz = curso.modules.first.lessons
        .firstWhere((l) => l.type == LessonType.quiz);

    try {
      await s.data.saveLessonQuiz(
        quiz.id,
        [
          QuizQuestionDraft(
              kind: 'multiple', question: 'Sin marcar', options: ['A', 'B']),
          QuizQuestionDraft(kind: 'short', question: 'Sin clave'),
        ],
        courseId: cursoId!,
      );
      fail('Debería haber fallado con 409.');
    } on ConflictError catch (e) {
      final problems = e.details['problems'] as List;
      // Los dos, no solo el primero: quien arma un quiz largo prefiere verlos
      // juntos, y el editor los pinta pregunta por pregunta.
      expect(problems, hasLength(2));
      expect(problems.map((p) => (p as Map)['question']), [1, 2]);
    }

    // Y el quiz anterior quedó intacto.
    final borrador = await s.data.lessonQuiz(quiz.id);
    expect(borrador, hasLength(2));
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('configura una actividad con rúbrica y tipos de entregable', () async {
    if (!up) return;
    final s = await signIn();

    var curso = await load<Course>(() => s.data.courseById(cursoId!));
    final leccion = await s.data.createLesson(
      curso.modules.first.id,
      title: 'Entrega final',
      type: 'activity',
    );

    await s.data.saveLessonActivity(
      leccion.id,
      ActivityDraft(
        description: 'Entregá tu propuesta.',
        deadline: '2026-12-01',
        requiresFile: true,
        requiresText: true,
        maxFiles: 2,
        gradingMode: GradingMode.points100,
        // Identificadores del enum, no "PDF"/"Documento".
        allowedTypes: ['pdf', 'document'],
        rubric: [
          RubricDraft(criterion: 'Claridad', points: 50),
          RubricDraft(criterion: 'Viabilidad', points: 50),
        ],
      ),
      courseId: cursoId!,
    );

    curso = await load<Course>(() => s.data.courseById(cursoId!));
    final guardada =
        curso.modules.first.lessons.firstWhere((l) => l.id == leccion.id);
    final actividad = guardada.activity;

    expect(actividad, isNotNull);
    expect(actividad!.maxFiles, 2);
    expect(actividad.deadline, '2026-12-01');
    expect(actividad.allowedTypes, containsAll(['pdf', 'document']));
    expect(actividad.rubric, hasLength(2));
    expect(actividad.totalPoints, 100);
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('una actividad que no pide nada se rechaza', () async {
    if (!up) return;
    final s = await signIn();

    final curso = await load<Course>(() => s.data.courseById(cursoId!));
    final actividad = curso.modules.first.lessons
        .firstWhere((l) => l.type == LessonType.activity);

    await expectLater(
      s.data.saveLessonActivity(
        actividad.id,
        ActivityDraft(requiresFile: false, requiresText: false),
        courseId: cursoId!,
      ),
      throwsA(isA<ConflictError>()),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('reordenar lecciones deja el orden que se pidió', () async {
    if (!up) return;
    final s = await signIn();

    var curso = await load<Course>(() => s.data.courseById(cursoId!));
    final modulo = curso.modules.first;
    final invertidas = modulo.lessons.map((l) => l.id).toList().reversed.toList();

    await s.data.reorderLessons(modulo.id, invertidas, courseId: cursoId!);

    curso = await load<Course>(() => s.data.courseById(cursoId!));
    expect(curso.modules.first.lessons.map((l) => l.id).toList(), invertidas);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('la ventana de fechas y el patrocinio se validan en el servidor',
      () async {
    if (!up) return;
    final s = await signIn();

    // Cerrar antes de abrir no tiene sentido y el servidor lo dice.
    await expectLater(
      s.data.updateCourse(cursoId!, {
        'openDate': '2026-12-01',
        'closeDate': '2026-09-01',
      }),
      throwsA(isA<ConflictError>()),
    );

    final ok = await s.data.updateCourse(cursoId!, {
      'openDate': '2026-09-01',
      'closeDate': '2026-12-01',
    });
    expect(ok.openDate, '2026-09-01');
    expect(ok.closeDate, '2026-12-01');

    // El patrocinador tiene que ser una cuenta de empresa: la clave ajena
    // apunta a `users` y aceptaría cualquiera.
    final empresas = await load<List<AppUser>>(
        () => s.data.users(role: Roles.company));
    expect(empresas, isNotEmpty);
    final conPatrocinio = await s.data.updateCourse(
      cursoId!,
      {'sponsorCompanyId': empresas.first.id},
    );
    expect(conPatrocinio.sponsorCompanyId, empresas.first.id);
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('publicar exige contenido completo y dice qué falta', () async {
    if (!up) return;
    final s = await signIn();

    // El curso tiene un quiz y una actividad, ninguna lección de video a medio
    // cargar: se publica.
    final publicado = await s.data.publishCourse(cursoId!);
    expect(publicado.status, CourseStatus.published);

    // Y con una lección de video sin origen, deja de poder publicarse.
    final curso = await load<Course>(() => s.data.courseById(cursoId!));
    await s.data.createLesson(
      curso.modules.first.id,
      title: 'Video sin cargar',
      type: 'video',
    );

    try {
      await s.data.publishCourse(cursoId!);
      fail('Debería haber fallado: hay un video sin origen.');
    } on ConflictError catch (e) {
      expect(e.details['lessons'], isNotEmpty);
    }
  }, timeout: const Timeout(Duration(seconds: 40)));
}
