// Los modelos parsean las respuestas de la API sin perder nada.
//
// Antes esta prueba hacía un viaje de ida y vuelta (`toJson` → `fromJson`)
// contra el contrato de Hive. Ya no hay tal viaje: los modelos SOLO leen, y lo
// que leen es la respuesta del servidor. Así que se prueba lo que de verdad
// puede romperse: que un payload con la forma real de la API se convierta en
// el objeto correcto, y que uno incompleto no tumbe la pantalla.
import 'package:flutter_test/flutter_test.dart';

import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/models/progress.dart';

void main() {
  group('AppUser', () {
    test('parsea la respuesta de /auth/me con equipo y patrocinador', () {
      final user = AppUser.fromJson({
        'id': 'u1',
        'name': 'Ana Estudiante',
        'email': 'ana@test.co',
        'role': 'student',
        'studentType': 'enactus',
        'university': 'Universidad Test',
        'canGradeOpenLearning': false,
        'canGradeEnactus': false,
        'joinedAt': '2024-03-01T00:00:00.000Z',
        'team': {
          'groupId': 'g1',
          'groupName': 'Equipo AquaVida',
          'projectId': 'p1',
          'projectName': 'AquaVida',
          'roleInProject': 'leader',
        },
        'sponsorName': 'Bancolombia',
      });

      expect(user.name, 'Ana Estudiante');
      expect(user.university, 'Universidad Test');
      expect(user.isEnactusStudent, isTrue);
      expect(user.team?.groupName, 'Equipo AquaVida');
      expect(user.team?.roleLabel, 'Líder');
      expect(user.sponsorName, 'Bancolombia');
      expect(user.joinedAt?.year, 2024);
    });

    test('sin equipo ni patrocinador no revienta: quedan en null', () {
      // Es el caso de cualquier rol que no sea estudiante o alumni.
      final user = AppUser.fromJson({
        'id': 'u2',
        'name': 'Marco Mentor',
        'email': 'marco@test.co',
        'role': 'mentor',
      });
      expect(user.team, isNull);
      expect(user.sponsorName, isNull);
      expect(user.isEnactusStudent, isFalse);
    });

    test('NUNCA expone una contraseña, venga como venga en el JSON', () {
      // El servidor no la manda, pero si algún día se colara, el modelo no
      // tiene dónde guardarla.
      final user = AppUser.fromJson({
        'id': 'u3',
        'name': 'X',
        'email': 'x@x.co',
        'role': 'student',
        'passwordHash': r'$2b$10$loquesea',
      });
      expect(user.profile.containsKey('passwordHash'), isFalse);
    });
  });

  group('Course', () {
    test('parsea el detalle con módulos, lecciones y metadatos', () {
      final course = Course.fromJson({
        'id': 'c1',
        'name': 'Curso Test',
        'level': 'intermediate',
        'status': 'published',
        'laboratoryId': 'lab1',
        'laboratoryName': 'Laboratorio Test',
        'creatorName': 'Luz LXD',
        'tags': ['IA', 'Innovación'],
        'ods': ['ods_4'],
        'objectives': [
          {'id': 'o1', 'category': null, 'text': 'Entender la IA'},
        ],
        'modules': [
          {
            'id': 'm1',
            'title': 'Módulo 1',
            'lessons': [
              {'id': 'l1', 'title': 'L1', 'type': 'video'},
              {'id': 'l2', 'title': 'L2', 'type': 'pdf'},
            ],
          },
        ],
      });

      expect(course.lessonCount, 2);
      expect(course.levelLabel, 'Intermedio');
      expect(course.isPublished, isTrue);
      expect(course.laboratoryName, 'Laboratorio Test');
      expect(course.tags, contains('IA'));
      expect(course.objectives.single.isGeneral, isTrue);
      expect(course.lessonById('l2')?.type, LessonType.pdf);
    });

    test('el quiz llega SIN la clave de respuestas', () {
      // La corrección ocurre en el servidor. El modelo no tiene dónde poner
      // una respuesta correcta, así que aunque llegara, no se guardaría.
      final lesson = Lesson.fromJson({
        'id': 'l1',
        'title': 'Quiz',
        'type': 'quiz',
        'quiz': [
          {
            'id': 'q1',
            'kind': 'multiple',
            'question': '¿Cuál?',
            'options': ['A', 'B'],
          },
        ],
      });
      expect(lesson.quiz.single.options, ['A', 'B']);
      expect(lesson.quiz.single.question, '¿Cuál?');
    });

    test('distingue los dos orígenes de video', () {
      final externo = Lesson.fromJson({
        'id': 'l1',
        'title': 'V',
        'type': 'video',
        'videoType': 'external',
        'videoUrl': 'https://youtu.be/x',
      });
      final propio = Lesson.fromJson({
        'id': 'l2',
        'title': 'V',
        'type': 'video',
        'videoType': 'uploaded',
        'videoS3Key': 'lessons/x/a.mp4',
      });
      final sinVideo =
          Lesson.fromJson({'id': 'l3', 'title': 'V', 'type': 'video'});

      expect(externo.isExternalVideo, isTrue);
      expect(propio.isUploadedVideo, isTrue);
      // Una lección a medio construir: tiene tipo video pero ningún origen.
      expect(sinVideo.hasVideo, isFalse);
    });
  });

  group('Progreso', () {
    test('LabProgress suma los módulos de todas sus fases', () {
      final lab = LabProgress.fromJson({
        'laboratoryId': 'lab1',
        'laboratoryName': 'Lab',
        'phasesTotal': 2,
        'phasesDone': 1,
        'isComplete': false,
        'certificateIssued': false,
        'phases': [
          {
            'phaseId': 'f1',
            'orderIndex': 1,
            'title': 'Fase 1',
            'isComplete': true,
            'isUnlocked': true,
            'modulesTotal': 3,
            'modulesDone': 3,
          },
          {
            'phaseId': 'f2',
            'orderIndex': 2,
            'title': 'Fase 2',
            'isComplete': false,
            'isUnlocked': true,
            'modulesTotal': 2,
            'modulesDone': 1,
          },
        ],
      });

      // Una sola fuente para el anillo de avance y para cada tarjeta de fase.
      expect(lab.moduleProgress.done, 4);
      expect(lab.moduleProgress.total, 5);
      // La primera fase desbloqueada y sin terminar: a dónde mandar a la
      // persona.
      expect(lab.currentPhase?.phaseId, 'f2');
      expect(lab.certificateAvailable, isFalse);
    });

    test('el certificado está disponible solo si la Ruta está completa y no emitido',
        () {
      LabProgress make({required bool complete, required bool issued}) =>
          LabProgress.fromJson({
            'laboratoryId': 'l',
            'laboratoryName': 'L',
            'phasesTotal': 1,
            'phasesDone': 1,
            'isComplete': complete,
            'certificateIssued': issued,
            'phases': [],
          });

      expect(make(complete: true, issued: false).certificateAvailable, isTrue);
      expect(make(complete: true, issued: true).certificateAvailable, isFalse);
      expect(make(complete: false, issued: false).certificateAvailable, isFalse);
    });

    test('un módulo sin contenido no es lo mismo que uno pendiente', () {
      final vacio = ModuleProgress.fromJson({
        'moduleId': 'm1',
        'title': 'M',
        'orderIndex': 1,
        'isMentorshipModule': false,
        'ownLessonsTotal': 0,
        'ownLessonsDone': 0,
        'coursesTotal': 0,
        'coursesDone': 0,
        'isComplete': false,
        'isUnlocked': true,
      });
      expect(vacio.isEmpty, isTrue);
      expect(vacio.ratio, 0);
    });

    test('DeadlineStatus mapea los valores del servidor', () {
      expect(DeadlineStatus.fromJson('overdue'), DeadlineStatus.overdue);
      expect(DeadlineStatus.fromJson('approaching').needsAttention, isTrue);
      expect(DeadlineStatus.fromJson('on_track').isLate, isFalse);
      // Un valor desconocido no revienta: cae en `none`.
      expect(DeadlineStatus.fromJson('inventado'), DeadlineStatus.none);
    });

    test('QuizResult marca qué preguntas estuvieron bien, sin la clave', () {
      final result = QuizResult.fromJson({
        'attemptId': 'a1',
        'score': 75,
        'passed': true,
        'correctCount': 3,
        'totalQuestions': 4,
        'correctness': {'q1': true, 'q2': false},
      });
      expect(result.passed, isTrue);
      expect(result.isCorrect('q1'), isTrue);
      expect(result.isCorrect('q2'), isFalse);
      // Una pregunta que no vino se considera incorrecta, no null.
      expect(result.isCorrect('q9'), isFalse);
    });
  });

  group('Submission', () {
    test('la nota se lee en su escala, y `numeric` llega como texto', () {
      // La API devuelve `numeric` como cadena para no perder precisión.
      final sub = Submission.fromJson({
        'id': 's1',
        'taskName': 'Entrega',
        'submittedAt': '2026-01-10T12:00:00.000Z',
        'grade': '85.5',
        'gradingMode': 'points100',
        'gradedAt': '2026-01-11T12:00:00.000Z',
      });
      expect(sub.grade, 85.5);
      expect(sub.isGraded, isTrue);
      expect(sub.gradeLabel, '86/100');
    });

    test('100 significa cosas distintas según la escala', () {
      expect(GradingMode.display(100, 'points100'), '100/100');
      expect(GradingMode.display(1, 'passfail'), 'Aprobado');
      expect(GradingMode.display(0, 'passfail'), 'Reprobado');
      expect(GradingMode.display(4.5, 'scale5'), '4.5');
      expect(GradingMode.display(null, 'points100'), 'Pendiente');
    });

    test('no se puede borrar una entrega ya calificada o comentada', () {
      Submission make({double? grade, String feedback = ''}) =>
          Submission.fromJson({
            'id': 's',
            'taskName': 't',
            'submittedAt': '2026-01-01T00:00:00.000Z',
            'grade': grade,
            'gradedAt': grade == null ? null : '2026-01-02T00:00:00.000Z',
            'feedback': feedback,
          });

      expect(make().canBeDeletedByStudent, isTrue);
      expect(make(grade: 80).canBeDeletedByStudent, isFalse);
      expect(make(feedback: 'Revisá el punto 2').canBeDeletedByStudent, isFalse);
    });
  });

  group('Etapas de proyecto y ODS', () {
    test('la etapa se guarda como identificador y se muestra traducida', () {
      // El desajuste que rompía el filtro en silencio: la lista de etapas
      // tiene que ser de identificadores, no de etiquetas.
      final project = Project.fromJson({
        'id': 'p1',
        'name': 'AquaVida',
        'stage': 'national_expo',
        'ods': ['ods_6'],
      });
      expect(project.stage, 'national_expo');
      expect(project.stageLabel, 'National Expo');
      expect(ProjectStage.all, contains('national_expo'));
      expect(ProjectStage.all, isNot(contains('National Expo')));
    });
  });
}
