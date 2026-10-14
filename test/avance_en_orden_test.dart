import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/models/progress.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_service.dart';
import 'package:enactus_platform/views/student/course_detail_view.dart';
import 'package:enactus_platform/views/student/ruta_impacto_view.dart';
import 'package:enactus_platform/widgets/file_viewer.dart';

import 'helpers/fake_api.dart';
import 'helpers/portal_harness.dart' show conSesionGuardada;

/// Avance en orden y sin marcar a mano (pedido de Sara, 2026-10-14).
///
/// En la prueba beta, una estudiante tocaba el círculo de cada lección y la
/// daba por completa sin ver el video ni leer el material, y pasaba a las
/// siguientes. Estas pruebas fijan lo que la pantalla hace ahora:
///
/// - el círculo es solo un indicador: tocarlo no marca nada;
/// - lo que todavía no le toca se ve con candado, y no se abre;
/// - cada lección se completa con su prueba, y eso lo decide el servidor
///   (aprobar el quiz, recorrer la lectura…): la pantalla aplica lo que él
///   responde y abre la siguiente.

// Con forma de uuid: los cuerpos que se mandan quedan en el contrato
// cliente → servidor (`test/fixtures/cuerpos_del_cliente.json`).
const _video = 'e0000000-0000-4000-8000-0000000000a1';
const _quiz = 'e0000000-0000-4000-8000-0000000000a2';
const _lectura = 'e0000000-0000-4000-8000-0000000000a3';

const _ana = {
  'id': 'student1',
  'name': 'Ana Estudiante',
  'email': 'ana@test.co',
  'role': 'student',
  'studentType': 'open_learning',
};

/// El curso de la beta: «Visualización video» (video + quiz) y «Lectura».
const _curso = {
  'id': 'beta',
  'name': '[Beta MÓVIL] Emprendimiento social en 15 minutos',
  'description': 'El curso de la prueba beta',
  'level': 'basic',
  'status': 'published',
  'language': 'es',
  'tags': <String>[],
  'objectives': <Object>[],
  'modules': [
    {
      'id': 'm1',
      'title': 'Visualización video',
      'lessons': [
        {
          'id': _video,
          'title': 'Conformar equipo',
          'type': 'video',
          'videoType': 'youtube',
          'videoYoutubeId': 'dQw4w9WgXcQ',
        },
        {
          'id': _quiz,
          'title': 'Preguntas del video',
          'type': 'quiz',
          'quiz': [
            {
              'id': 'p1',
              'kind': 'truefalse',
              'question': '¿Un equipo necesita roles?',
              'options': <String>[],
            },
          ],
        },
      ],
    },
    {
      'id': 'm2',
      'title': 'Lectura',
      'lessons': [
        {
          'id': _lectura,
          'title': 'Lectura en imagen',
          'type': 'resource',
          'resourceS3Key': 'lessons/lectura/infografia.png',
          'resourceFileName': 'infografia.png',
        },
      ],
    },
  ],
};

Map<String, Object?> _progreso(List<String> hechas, String? siguiente) => {
      'courseId': 'beta',
      'courseName': _curso['name'],
      'totalLessons': 3,
      'completedLessons': hechas.length,
      'ratio': hechas.length / 3,
      'isComplete': hechas.length == 3,
      'completedLessonIds': hechas,
      'nextLessonId': siguiente,
      'videoProgress': <Object>[],
    };

Map<String, Object?> _impacto(String leccion, int hechas, String? siguiente) => {
      'lessonId': leccion,
      'completed': true,
      'course': {
        'courseId': 'beta',
        'totalLessons': 3,
        'completedLessons': hechas,
        'ratio': hechas / 3,
        'isComplete': hechas == 3,
        'nextLessonId': siguiente,
      },
      'rutaImpact': <Object>[],
    };

FakeApi _api(Map<String, Object?> progreso, [Map<String, Object?> extra = const {}]) =>
    FakeApi(routes: {
      '/auth/me': _ana,
      '/courses/beta': _curso,
      '/courses/beta/glossary': {'terms': <Object>[], 'reviews': <String, Object>{}},
      '/students/student1/course-progress/beta': progreso,
      '/submissions': {'data': <Object>[], 'page': 1, 'pageSize': 100, 'total': 0},
      '/notifications': {'data': <Object>[], 'page': 1, 'pageSize': 100, 'total': 0},
      '/certificates': {'data': <Object>[], 'page': 1, 'pageSize': 100, 'total': 0},
      ...extra,
    });

Future<DataProvider> _montar(WidgetTester tester, FakeApi fake, Widget pantalla) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 1600);
  addTearDown(tester.view.reset);

  // Con sesión: lo que hace en la lección cuenta como SU avance.
  conSesionGuardada();
  final api = fake.build();
  final data = DataProvider(api)..setCurrentUser('student1');
  final auth = AuthProvider(api, data);
  await auth.restoreSession();
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<ApiService>.value(value: api),
      ChangeNotifierProvider.value(value: data),
      ChangeNotifierProvider.value(value: auth),
    ],
    child: MaterialApp(home: Scaffold(body: pantalla)),
  ));
  await _esperar(tester);
  return data;
}

Future<void> _esperar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// El indicador de estado de la lección [titulo].
Finder _indicador(String titulo, IconData icono) => find.descendant(
      of: find.ancestor(of: find.text(titulo), matching: find.byType(Row)).first,
      matching: find.byIcon(icono),
    );

List<String> _escrituras(FakeApi fake) =>
    fake.requested.where((r) => !r.startsWith('GET')).toList();

void main() {
  setUp(useFakeTokenStorage);

  group('el curso, como en la beta', () {
    testWidgets('el círculo es solo un indicador: tocarlo no marca nada',
        (tester) async {
      final fake = _api(_progreso([], _video));
      await _montar(tester, fake, const CourseDetailView(courseId: 'beta'));

      expect(_indicador('Conformar equipo', Icons.radio_button_unchecked),
          findsOneWidget);
      // Ya no es un botón.
      expect(find.byType(IconButton).evaluate().where((e) {
        final icono = (e.widget as IconButton).icon;
        return icono is Icon &&
            (icono.icon == Icons.radio_button_unchecked ||
                icono.icon == Icons.check_circle);
      }), isEmpty);

      await tester.tap(_indicador('Conformar equipo', Icons.radio_button_unchecked));
      await _esperar(tester);
      // Lo único que pudo pasar es abrir el video; nada se escribió.
      expect(fake.requested.where((r) =>
          r.endsWith('/complete') || r.endsWith('/toggle')), isEmpty);
      expect(find.text('Se completa al ver el video completo.'), findsNothing,
          reason: 'el tooltip no se muestra por un toque');
    });

    testWidgets('lo que todavía no le toca tiene candado y no se abre',
        (tester) async {
      final fake = _api(_progreso([], _video));
      await _montar(tester, fake, const CourseDetailView(courseId: 'beta'));

      // La segunda parte del módulo y el módulo siguiente, con candado.
      expect(_indicador('Preguntas del video', Icons.lock_outline), findsOneWidget);
      expect(_indicador('Lectura en imagen', Icons.lock_outline), findsOneWidget);

      await tester.tap(find.text('Preguntas del video'));
      await _esperar(tester);
      expect(find.text('Bloqueada: primero complete «Conformar equipo».'),
          findsOneWidget);
      // El quiz no se abrió.
      expect(find.text('¿Un equipo necesita roles?'), findsNothing);

      await tester.tap(find.text('Lectura en imagen'));
      await _esperar(tester);
      expect(fake.requested, isNot(contains('POST /files/download-url')));
      expect(_escrituras(fake), isEmpty);
    });

    testWidgets('aprobar el quiz lo completa en el servidor y abre lo siguiente',
        (tester) async {
      final fake = _api(_progreso([_video], _quiz), {
        '/lessons/$_quiz/quiz-attempt': {
          'attemptId': 'a1',
          'score': 100,
          'passed': true,
          'correctCount': 1,
          'totalQuestions': 1,
          'correctness': {'p1': true},
          'lessonCompleted': true,
          'impact': _impacto(_quiz, 2, _lectura),
        },
      });
      await _montar(tester, fake, const CourseDetailView(courseId: 'beta'));
      expect(_indicador('Conformar equipo', Icons.check_circle), findsOneWidget);
      expect(_indicador('Lectura en imagen', Icons.lock_outline), findsOneWidget);

      await tester.tap(find.text('Preguntas del video'));
      await _esperar(tester);
      await tester.tap(find.text('Verdadero'));
      await tester.pump();
      await tester.tap(find.text('Calificar'));
      await _esperar(tester);
      expect(find.textContaining('Aprobado'), findsOneWidget);
      await tester.tap(find.text('Cerrar').last);
      await _esperar(tester);

      expect(_indicador('Preguntas del video', Icons.check_circle), findsOneWidget);
      expect(_indicador('Lectura en imagen', Icons.radio_button_unchecked),
          findsOneWidget);
      // Ni «completar» ni «toggle»: la nota la pone el servidor, y el completar
      // también.
      expect(_escrituras(fake), ['POST /lessons/$_quiz/quiz-attempt']);
    });

    testWidgets('la lectura se completa al recorrerla, no al tocar nada',
        (tester) async {
      final fake = _api(_progreso([_video, _quiz], _lectura), {
        '/files/download-url': {
          'url': 'https://archivos.test/infografia.png',
          'expiresInSeconds': 300,
        },
        '/progress/lessons/$_lectura/complete': _impacto(_lectura, 3, null),
      });
      await _montar(tester, fake, const CourseDetailView(courseId: 'beta'));

      await tester.tap(find.text('Lectura en imagen'));
      await _esperar(tester);
      // Una imagen se ve entera apenas se abre: eso es recorrerla.
      expect(find.byType(Dialog), findsOneWidget);
      expect(fake.requested.where((r) => r == 'POST /progress/lessons/$_lectura/complete'),
          hasLength(1));
      expect(find.text('¡Lección completada!'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar'));
      await _esperar(tester);
      expect(_indicador('Lectura en imagen', Icons.check_circle), findsOneWidget);
      // Que termine la animación de «¡Lección completada!».
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('un 409 del servidor se dice con sus palabras', (tester) async {
      final fake = _api(_progreso([_video, _quiz], _lectura), {
        '/files/download-url': {
          'url': 'https://archivos.test/infografia.png',
          'expiresInSeconds': 300,
        },
        '/progress/lessons/$_lectura/complete': {
          'error': {'code': 'conflict', 'message': 'Primero complete «Conformar equipo».'},
        },
      })
        ..statuses['/progress/lessons/$_lectura/complete'] = 409;
      await _montar(tester, fake, const CourseDetailView(courseId: 'beta'));

      await tester.tap(find.text('Lectura en imagen'));
      await _esperar(tester);
      expect(find.text('Primero complete «Conformar equipo».'), findsOneWidget);
    });
  });

  group('el visor del material', () {
    testWidgets('una imagen avisa que se leyó, una sola vez', (tester) async {
      var avisos = 0;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => FileViewer.show(context,
                url: 'https://archivos.test/a.png',
                fileName: 'a.png',
                onReadToEnd: () => avisos++),
            child: const Text('abrir'),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await _esperar(tester);
      await tester.pump();
      expect(avisos, 1);
    });

    testWidgets('un archivo que no se muestra pide descargarlo para completar',
        (tester) async {
      var avisos = 0;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => FileViewer.show(context,
                url: 'https://archivos.test/a.docx',
                fileName: 'a.docx',
                onReadToEnd: () => avisos++),
            child: const Text('abrir'),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await _esperar(tester);
      expect(find.text('Descargue el archivo para completar la lección.'),
          findsOneWidget);
      // Abrirlo no basta.
      expect(avisos, 0);
    });

    testWidgets('sin lección no hay franja de avance', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => FileViewer.show(context,
                url: 'https://archivos.test/a.docx', fileName: 'a.docx'),
            child: const Text('abrir'),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await _esperar(tester);
      expect(find.textContaining('para completar la lección'), findsNothing);
    });
  });

  group('el progreso', () {
    test('el resumen del listado no alcanza: se pide el detalle', () async {
      final fake = FakeApi(routes: {
        '/courses': {
          'data': [
            {
              ..._curso,
              'progress': {
                'courseId': 'beta',
                'totalLessons': 3,
                'completedLessons': 1,
                'ratio': 0.33,
                'isComplete': false,
              },
            },
          ],
          'page': 1,
          'pageSize': 100,
          'total': 1,
        },
        '/students/student1/course-progress/beta': _progreso([_video], _quiz),
      });
      final data = DataProvider(fake.build())..setCurrentUser('student1');
      data.courses;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(data.courseProgress('beta').valueOrNull?.hasLessonDetail, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final detalle = data.courseProgress('beta').valueOrNull!;
      expect(fake.requested, contains('GET /students/student1/course-progress/beta'));
      expect(detalle.isLessonComplete(_video), isTrue);
      expect(detalle.isLessonAvailable(_quiz), isTrue);
      expect(detalle.isLessonAvailable(_lectura), isFalse);
    });

    test('un servidor anterior, sin el orden, no deja el curso cerrado', () {
      final viejo = CourseProgress.fromJson({
        'courseId': 'beta',
        'completedLessonIds': <String>[],
      });
      expect(viejo.knowsLessonOrder, isFalse);
      expect(viejo.isLessonAvailable(_lectura), isTrue);
    });

    test('completar lo ya completo no vuelve a pedir nada', () async {
      final fake = _api(_progreso([_video], _quiz));
      final data = DataProvider(fake.build())..setCurrentUser('student1');
      data.courseProgress('beta');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await data.completeLesson(_video, courseId: 'beta'), isNull);
      expect(_escrituras(fake), isEmpty);
    });
  });

  group('la Ruta', () {
    Map<String, Object?> ruta() => {
          'studentId': 'student1',
          'studentName': 'Ana',
          'laboratories': [
            {
              'laboratoryId': 'lab1',
              'laboratoryName': 'Laboratorio',
              'phasesTotal': 1,
              'phasesDone': 0,
              'isComplete': false,
              'certificateIssued': false,
              'phases': [
                {
                  'phaseId': 'f1',
                  'orderIndex': 1,
                  'title': 'Fase 1',
                  'description': '',
                  'deadline': null,
                  'deadlineStatus': 'none',
                  'modulesTotal': 1,
                  'modulesDone': 0,
                  'isComplete': false,
                  'isUnlocked': true,
                  'objectives': <Object>[],
                  'modules': [
                    {
                      'moduleId': 'mod1',
                      'title': 'Módulo 1',
                      'orderIndex': 1,
                      'isMentorshipModule': false,
                      'ownLessonsTotal': 2,
                      'ownLessonsDone': 0,
                      'coursesTotal': 0,
                      'coursesDone': 0,
                      'isComplete': false,
                      'isUnlocked': true,
                      'courses': <Object>[],
                      'ownLessons': [
                        {
                          'id': 'guia',
                          'title': 'Guía de la fase',
                          'type': 'link',
                          'externalUrl': 'https://guia.test',
                          'isComplete': false,
                          'isUnlocked': true,
                        },
                        {
                          'id': 'entrega',
                          'title': 'Entrega del diagnóstico',
                          'type': 'activity',
                          'isComplete': false,
                          'isUnlocked': false,
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        };

    testWidgets('una entrega propia bloqueada dice cuál falta y no se abre',
        (tester) async {
      final fake = FakeApi(routes: {
        '/auth/me': {..._ana, 'studentType': 'enactus'},
        '/students/student1/ruta-progress': ruta(),
        '/site-content': {'meetingLink': ''},
        '/notifications': {'data': <Object>[], 'page': 1, 'pageSize': 100, 'total': 0},
      });
      await _montar(tester, fake,
          const ModuleDetailScreen(labId: 'lab1', phaseIndex: 0, moduleIndex: 0));

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      await tester.tap(find.text('Entrega del diagnóstico'));
      await _esperar(tester);
      expect(find.text('Bloqueada: primero complete «Guía de la fase».'),
          findsWidgets);
      expect(find.text('Enviar'), findsNothing);
      expect(_escrituras(fake), isEmpty);
    });
  });
}
