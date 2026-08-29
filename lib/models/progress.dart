/// Modelos del progreso, tal como los devuelve la API.
///
/// No tienen equivalente en los modelos de Hive: allá el progreso era una
/// lista de ids (`Progress.completedLessonIds`) y la completitud se calculaba
/// en el navegador en cada `build()`. Acá viene calculada del servidor —
/// incluido el desbloqueo de fases y el estado de cada deadline— y el cliente
/// solo la muestra.
library;

import 'models.dart';

/// Estado del deadline de una fase para un estudiante puntual.
/// Una fase ya completada nunca aparece atrasada, sin importar la fecha.
enum DeadlineStatus {
  none,
  onTrack,
  approaching,
  overdue;

  static DeadlineStatus fromJson(String? raw) => switch (raw) {
        'on_track' => DeadlineStatus.onTrack,
        'approaching' => DeadlineStatus.approaching,
        'overdue' => DeadlineStatus.overdue,
        _ => DeadlineStatus.none,
      };

  bool get isLate => this == DeadlineStatus.overdue;
  bool get needsAttention =>
      this == DeadlineStatus.overdue || this == DeadlineStatus.approaching;
}

/// Avance de un estudiante en un curso.
class CourseProgress {
  final String courseId;
  final String courseName;
  final int totalLessons;
  final int completedLessons;

  /// 0..1, ya calculado por el servidor.
  final double ratio;
  final bool isComplete;

  /// Solo viene en `/students/:id/course-progress/:courseId`.
  final List<String> completedLessonIds;

  const CourseProgress({
    required this.courseId,
    this.courseName = '',
    this.totalLessons = 0,
    this.completedLessons = 0,
    this.ratio = 0,
    this.isComplete = false,
    this.completedLessonIds = const [],
  });

  /// Progreso vacío, para un curso que el estudiante todavía no empezó.
  factory CourseProgress.empty(String courseId) =>
      CourseProgress(courseId: courseId);

  bool isLessonComplete(String lessonId) =>
      completedLessonIds.contains(lessonId);

  factory CourseProgress.fromJson(Map<String, dynamic> j) => CourseProgress(
        courseId: j['courseId'] as String,
        courseName: (j['courseName'] as String?) ?? '',
        totalLessons: (j['totalLessons'] as num?)?.toInt() ?? 0,
        completedLessons: (j['completedLessons'] as num?)?.toInt() ?? 0,
        ratio: (j['ratio'] as num?)?.toDouble() ?? 0,
        isComplete: (j['isComplete'] as bool?) ?? false,
        completedLessonIds:
            List<String>.from(j['completedLessonIds'] as List? ?? const []),
      );
}

/// Un objetivo de fase, con si el estudiante ya lo cumplió.
class ObjectiveProgress {
  final String objectiveId;

  /// `entrepreneurship` | `business`.
  final String category;
  final String text;
  final bool isComplete;

  const ObjectiveProgress({
    required this.objectiveId,
    required this.category,
    required this.text,
    required this.isComplete,
  });

  bool get isBusiness => category == 'business';

  String get categoryLabel =>
      isBusiness ? 'Empresarial' : 'Emprendimiento';

  factory ObjectiveProgress.fromJson(Map<String, dynamic> j) =>
      ObjectiveProgress(
        objectiveId: j['objectiveId'] as String,
        category: (j['category'] as String?) ?? 'entrepreneurship',
        text: (j['text'] as String?) ?? '',
        isComplete: (j['isComplete'] as bool?) ?? false,
      );
}

/// Módulo de una fase, con su avance y su desbloqueo.
class ModuleProgress {
  final String moduleId;
  final String title;
  final int orderIndex;

  /// El último módulo de cada fase es el de mentoría: en vez de contenido,
  /// muestra el botón para unirse a la reunión.
  final bool isMentorshipModule;

  final int ownLessonsTotal;
  final int ownLessonsDone;
  final int coursesTotal;
  final int coursesDone;
  final bool isComplete;

  /// El primero de una fase desbloqueada siempre; el resto exige el anterior.
  final bool isUnlocked;

  final List<CourseProgress> courses;

  /// Las lecturas y entregas PROPIAS del módulo —las que no vienen de un
  /// curso— con si esta persona ya las marcó.
  final List<OwnLesson> ownLessons;

  const ModuleProgress({
    required this.moduleId,
    required this.title,
    required this.orderIndex,
    required this.isMentorshipModule,
    required this.ownLessonsTotal,
    required this.ownLessonsDone,
    required this.coursesTotal,
    required this.coursesDone,
    required this.isComplete,
    required this.isUnlocked,
    required this.courses,
    this.ownLessons = const [],
  });

  /// Un módulo sin nada configurado todavía. El servidor nunca lo cuenta como
  /// completo, y la interfaz debería decir "sin contenido aún", no "pendiente".
  bool get isEmpty => ownLessonsTotal == 0 && coursesTotal == 0;

  int get totalItems => ownLessonsTotal + coursesTotal;
  int get doneItems => ownLessonsDone + coursesDone;

  double get ratio => totalItems == 0 ? 0 : doneItems / totalItems;

  factory ModuleProgress.fromJson(Map<String, dynamic> j) => ModuleProgress(
        moduleId: j['moduleId'] as String,
        title: (j['title'] as String?) ?? '',
        orderIndex: (j['orderIndex'] as num?)?.toInt() ?? 0,
        isMentorshipModule: (j['isMentorshipModule'] as bool?) ?? false,
        ownLessonsTotal: (j['ownLessonsTotal'] as num?)?.toInt() ?? 0,
        ownLessonsDone: (j['ownLessonsDone'] as num?)?.toInt() ?? 0,
        coursesTotal: (j['coursesTotal'] as num?)?.toInt() ?? 0,
        coursesDone: (j['coursesDone'] as num?)?.toInt() ?? 0,
        isComplete: (j['isComplete'] as bool?) ?? false,
        isUnlocked: (j['isUnlocked'] as bool?) ?? false,
        courses: (j['courses'] as List? ?? const [])
            .map((e) =>
                CourseProgress.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        ownLessons: (j['ownLessons'] as List? ?? const [])
            .map((e) => OwnLesson.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Una lectura o entrega propia de un módulo de la Ruta.
///
/// No pertenece a ningún curso: la crea el Admin dentro del módulo. Se marca
/// con el mismo endpoint que cualquier lección.
class OwnLesson {
  final String id;
  final String title;
  final LessonType type;
  final String description;
  final String? resourceS3Key;
  final String? resourceFileName;
  final String? externalUrl;
  final VideoSourceType? videoType;
  final String? videoUrl;
  final String? videoS3Key;
  final bool isComplete;

  const OwnLesson({
    required this.id,
    required this.title,
    this.type = LessonType.resource,
    this.description = '',
    this.resourceS3Key,
    this.resourceFileName,
    this.externalUrl,
    this.videoType,
    this.videoUrl,
    this.videoS3Key,
    this.isComplete = false,
  });

  bool get isActivity => type == LessonType.activity;

  /// La misma forma que [Lesson], para poder reutilizar los widgets que ya
  /// saben abrir una lección (el reproductor de video, por ejemplo).
  Lesson toLesson() => Lesson(
        id: id,
        title: title,
        type: type,
        description: description,
        resourceS3Key: resourceS3Key,
        resourceFileName: resourceFileName,
        externalUrl: externalUrl,
        videoType: videoType,
        videoUrl: videoUrl,
        videoS3Key: videoS3Key,
      );

  factory OwnLesson.fromJson(Map<String, dynamic> j) => OwnLesson(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? '',
        type: LessonType.fromJson(j['type'] as String?),
        description: (j['description'] as String?) ?? '',
        resourceS3Key: j['resourceS3Key'] as String?,
        resourceFileName: j['resourceFileName'] as String?,
        externalUrl: j['externalUrl'] as String?,
        videoType: VideoSourceType.fromJson(j['videoType'] as String?),
        videoUrl: j['videoUrl'] as String?,
        videoS3Key: j['videoS3Key'] as String?,
        isComplete: (j['isComplete'] as bool?) ?? false,
      );
}

/// Fase de la Ruta de Impacto, con su avance, desbloqueo y deadline.
class PhaseProgress {
  final String phaseId;
  final int orderIndex;
  final String title;
  final String description;

  /// ISO `yyyy-MM-dd`, o `null` si el Admin no la puso.
  final String? deadline;
  final DeadlineStatus deadlineStatus;

  final int modulesTotal;
  final int modulesDone;
  final bool isComplete;
  final bool isUnlocked;

  final List<ObjectiveProgress> objectives;
  final List<ModuleProgress> modules;

  const PhaseProgress({
    required this.phaseId,
    required this.orderIndex,
    required this.title,
    this.description = '',
    required this.deadline,
    required this.deadlineStatus,
    required this.modulesTotal,
    required this.modulesDone,
    required this.isComplete,
    required this.isUnlocked,
    required this.objectives,
    required this.modules,
  });

  /// Una fase desbloqueada pero sin contenido publicado no es lo mismo que
  /// una con trabajo pendiente: no hay nada que la persona pueda hacer.
  bool get hasPublishedContent => modules.isNotEmpty || objectives.isNotEmpty;

  double get ratio => modulesTotal == 0 ? 0 : modulesDone / modulesTotal;

  DateTime? get deadlineDate =>
      deadline == null ? null : DateTime.tryParse(deadline!);

  factory PhaseProgress.fromJson(Map<String, dynamic> j) => PhaseProgress(
        phaseId: j['phaseId'] as String,
        orderIndex: (j['orderIndex'] as num?)?.toInt() ?? 0,
        title: (j['title'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        deadline: j['deadline'] as String?,
        deadlineStatus: DeadlineStatus.fromJson(j['deadlineStatus'] as String?),
        modulesTotal: (j['modulesTotal'] as num?)?.toInt() ?? 0,
        modulesDone: (j['modulesDone'] as num?)?.toInt() ?? 0,
        isComplete: (j['isComplete'] as bool?) ?? false,
        isUnlocked: (j['isUnlocked'] as bool?) ?? false,
        objectives: (j['objectives'] as List? ?? const [])
            .map((e) =>
                ObjectiveProgress.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        modules: (j['modules'] as List? ?? const [])
            .map((e) =>
                ModuleProgress.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// La Ruta de Impacto de UN laboratorio para UN estudiante.
class LabProgress {
  final String laboratoryId;
  final String laboratoryName;
  final int phasesTotal;
  final int phasesDone;
  final bool isComplete;

  /// Si ya se emitió el certificado. Con [isComplete] en true y esto en false,
  /// el certificado está disponible para emitir.
  final bool certificateIssued;

  final List<PhaseProgress> phases;

  const LabProgress({
    required this.laboratoryId,
    required this.laboratoryName,
    required this.phasesTotal,
    required this.phasesDone,
    required this.isComplete,
    required this.certificateIssued,
    required this.phases,
  });

  bool get certificateAvailable => isComplete && !certificateIssued;

  double get ratio => phasesTotal == 0 ? 0 : phasesDone / phasesTotal;

  /// Módulos hechos/totales de toda la Ruta, sumando sus fases. Única fuente
  /// para el anillo de avance y para cada tarjeta de fase — no hay un campo
  /// aparte que se pueda desincronizar.
  ({int done, int total}) get moduleProgress {
    var done = 0;
    var total = 0;
    for (final phase in phases) {
      done += phase.modulesDone;
      total += phase.modulesTotal;
    }
    return (done: done, total: total);
  }

  /// La primera fase con trabajo pendiente: a dónde mandar a la persona.
  PhaseProgress? get currentPhase {
    for (final phase in phases) {
      if (phase.isUnlocked && !phase.isComplete) return phase;
    }
    return phases.isEmpty ? null : phases.last;
  }

  factory LabProgress.fromJson(Map<String, dynamic> j) => LabProgress(
        laboratoryId: j['laboratoryId'] as String,
        laboratoryName: (j['laboratoryName'] as String?) ?? '',
        phasesTotal: (j['phasesTotal'] as num?)?.toInt() ?? 0,
        phasesDone: (j['phasesDone'] as num?)?.toInt() ?? 0,
        isComplete: (j['isComplete'] as bool?) ?? false,
        certificateIssued: (j['certificateIssued'] as bool?) ?? false,
        phases: (j['phases'] as List? ?? const [])
            .map((e) =>
                PhaseProgress.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Respuesta completa de `/students/:id/ruta-progress`.
class RutaProgress {
  final String studentId;
  final String studentName;
  final List<LabProgress> laboratories;

  const RutaProgress({
    required this.studentId,
    required this.studentName,
    required this.laboratories,
  });

  LabProgress? labById(String id) {
    for (final lab in laboratories) {
      if (lab.laboratoryId == id) return lab;
    }
    return null;
  }

  /// Avance promedio entre todos sus laboratorios.
  double get overallRatio {
    if (laboratories.isEmpty) return 0;
    final sum = laboratories.fold<double>(0, (acc, l) => acc + l.ratio);
    return sum / laboratories.length;
  }

  List<LabProgress> get certificatesAvailable =>
      laboratories.where((l) => l.certificateAvailable).toList();

  factory RutaProgress.fromJson(Map<String, dynamic> j) => RutaProgress(
        studentId: j['studentId'] as String,
        studentName: (j['studentName'] as String?) ?? '',
        laboratories: (j['laboratories'] as List? ?? const [])
            .map((e) =>
                LabProgress.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Efecto de marcar o desmarcar una lección, tal como lo devuelve
/// `POST /progress/lessons/:id/toggle`.
///
/// Trae el recálculo completo hacia arriba —curso, módulo, fase y Ruta— en una
/// sola respuesta, así que la pantalla no necesita volver a preguntar nada.
class ToggleImpact {
  final String lessonId;
  final bool completed;
  final CourseProgress? course;

  /// Un mismo curso puede estar en la Ruta de varios laboratorios.
  final List<RutaImpact> rutaImpact;

  const ToggleImpact({
    required this.lessonId,
    required this.completed,
    required this.course,
    required this.rutaImpact,
  });

  /// Si con este cambio quedó alguna Ruta lista para certificar.
  RutaImpact? get newlyCertifiable {
    for (final impact in rutaImpact) {
      if (impact.certificateAvailable) return impact;
    }
    return null;
  }

  factory ToggleImpact.fromJson(Map<String, dynamic> j) => ToggleImpact(
        lessonId: j['lessonId'] as String,
        completed: (j['completed'] as bool?) ?? false,
        course: j['course'] == null
            ? null
            : CourseProgress.fromJson(
                Map<String, dynamic>.from(j['course'] as Map)),
        rutaImpact: (j['rutaImpact'] as List? ?? const [])
            .map((e) => RutaImpact.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Cómo quedó la Ruta de un laboratorio tras marcar una lección.
class RutaImpact {
  final String laboratoryId;
  final String moduleId;
  final String moduleTitle;
  final bool moduleComplete;
  final String phaseId;
  final int phaseOrder;
  final int phaseModulesDone;
  final int phaseModulesTotal;
  final bool phaseComplete;
  final int rutaPhasesDone;
  final int rutaPhasesTotal;
  final bool rutaComplete;
  final bool certificateAvailable;

  const RutaImpact({
    required this.laboratoryId,
    required this.moduleId,
    required this.moduleTitle,
    required this.moduleComplete,
    required this.phaseId,
    required this.phaseOrder,
    required this.phaseModulesDone,
    required this.phaseModulesTotal,
    required this.phaseComplete,
    required this.rutaPhasesDone,
    required this.rutaPhasesTotal,
    required this.rutaComplete,
    required this.certificateAvailable,
  });

  factory RutaImpact.fromJson(Map<String, dynamic> j) => RutaImpact(
        laboratoryId: j['laboratoryId'] as String,
        moduleId: j['moduleId'] as String,
        moduleTitle: (j['moduleTitle'] as String?) ?? '',
        moduleComplete: (j['moduleComplete'] as bool?) ?? false,
        phaseId: j['phaseId'] as String,
        phaseOrder: (j['phaseOrder'] as num?)?.toInt() ?? 0,
        phaseModulesDone: (j['phaseModulesDone'] as num?)?.toInt() ?? 0,
        phaseModulesTotal: (j['phaseModulesTotal'] as num?)?.toInt() ?? 0,
        phaseComplete: (j['phaseComplete'] as bool?) ?? false,
        rutaPhasesDone: (j['rutaPhasesDone'] as num?)?.toInt() ?? 0,
        rutaPhasesTotal: (j['rutaPhasesTotal'] as num?)?.toInt() ?? 0,
        rutaComplete: (j['rutaComplete'] as bool?) ?? false,
        certificateAvailable: (j['certificateAvailable'] as bool?) ?? false,
      );
}

/// Página de un listado. Todos los listados de la API vienen paginados.
class Page<T> {
  final List<T> data;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  const Page({
    required this.data,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  const Page.empty()
      : data = const [],
        page = 1,
        pageSize = 0,
        total = 0,
        totalPages = 0;

  bool get hasMore => page < totalPages;

  factory Page.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) parse,
  ) =>
      Page(
        data: (j['data'] as List? ?? const [])
            .map((e) => parse(Map<String, dynamic>.from(e as Map)))
            .toList(),
        page: (j['page'] as num?)?.toInt() ?? 1,
        pageSize: (j['pageSize'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        totalPages: (j['totalPages'] as num?)?.toInt() ?? 0,
      );
}

/// Resultado de resolver un quiz, tal como lo devuelve
/// `POST /lessons/:id/quiz-attempt`.
///
/// La nota viene calculada del servidor: la clave de respuestas nunca llega al
/// cliente. [correctness] dice QUÉ preguntas estuvieron bien —retroalimentación
/// legítima— pero no cuál era la respuesta de las falladas; si la trajera,
/// bastaría con mandar un intento en blanco para obtener la clave completa.
class QuizResult {
  final String attemptId;

  /// 0..100.
  final int score;
  final bool passed;
  final int correctCount;
  final int totalQuestions;

  /// `{ idDePregunta: acertó }`.
  final Map<String, bool> correctness;

  const QuizResult({
    required this.attemptId,
    required this.score,
    required this.passed,
    required this.correctCount,
    required this.totalQuestions,
    this.correctness = const {},
  });

  bool isCorrect(String questionId) => correctness[questionId] ?? false;

  factory QuizResult.fromJson(Map<String, dynamic> j) => QuizResult(
        attemptId: (j['attemptId'] as String?) ?? '',
        score: (j['score'] as num?)?.toInt() ?? 0,
        passed: (j['passed'] as bool?) ?? false,
        correctCount: (j['correctCount'] as num?)?.toInt() ?? 0,
        totalQuestions: (j['totalQuestions'] as num?)?.toInt() ?? 0,
        correctness: Map<String, bool>.from(
            (j['correctness'] as Map? ?? const {}).map(
                (key, value) => MapEntry('$key', value == true))),
      );
}

/// Un estudiante en la tabla de seguimiento de un curso.
///
/// Todo lo que la fila muestra viene en la misma respuesta: avance, nota
/// promedio, última actividad y el comentario del equipo docente. Resolverlo
/// en el cliente serían cuatro peticiones por fila.
class CourseStudent {
  final String id;
  final String name;
  final String email;
  final String? avatarS3Key;
  final String university;
  final CourseProgress progress;

  /// `null` cuando esta persona no tiene ninguna entrega calificada. No es 0:
  /// "todavía no tiene nota" y "sacó cero" son cosas distintas.
  final double? avgGrade;
  final int gradedCount;
  final int pendingCount;

  /// Lo más reciente entre marcar una lección y hacer una entrega — "cuándo
  /// se supo de esta persona por última vez".
  final DateTime? lastActivityAt;

  /// Comentario privado del equipo docente. **El estudiante no lo ve**: no
  /// hay endpoint que se lo devuelva.
  final String note;

  const CourseStudent({
    required this.id,
    required this.name,
    this.email = '',
    this.avatarS3Key,
    this.university = '',
    required this.progress,
    this.avgGrade,
    this.gradedCount = 0,
    this.pendingCount = 0,
    this.lastActivityAt,
    this.note = '',
  });

  bool get hasStarted => progress.completedLessons > 0;

  factory CourseStudent.fromJson(Map<String, dynamic> j) => CourseStudent(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
        avatarS3Key: j['avatarS3Key'] as String?,
        university: (j['university'] as String?) ?? '',
        progress: CourseProgress.fromJson(
            Map<String, dynamic>.from(j['progress'] as Map)),
        avgGrade: (j['avgGrade'] as num?)?.toDouble(),
        gradedCount: (j['gradedCount'] as num?)?.toInt() ?? 0,
        pendingCount: (j['pendingCount'] as num?)?.toInt() ?? 0,
        lastActivityAt: _parseDate(j['lastActivityAt']),
        note: (j['note'] as String?) ?? '',
      );
}

/// Cifras del encabezado del seguimiento de un curso.
class CourseStats {
  final int enrolled;
  final int completed;

  /// 0..1.
  final double avgProgress;

  /// `null` si nadie tiene nota todavía.
  final double? avgGrade;
  final int pending;

  const CourseStats({
    this.enrolled = 0,
    this.completed = 0,
    this.avgProgress = 0,
    this.avgGrade,
    this.pending = 0,
  });

  factory CourseStats.fromJson(Map<String, dynamic> j) => CourseStats(
        enrolled: (j['enrolled'] as num?)?.toInt() ?? 0,
        completed: (j['completed'] as num?)?.toInt() ?? 0,
        avgProgress: (j['avgProgress'] as num?)?.toDouble() ?? 0,
        avgGrade: (j['avgGrade'] as num?)?.toDouble(),
        pending: (j['pending'] as num?)?.toInt() ?? 0,
      );
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
