/// Modelos de datos de la plataforma.
///
/// Todos los modelos serializan a JSON para persistirse en Hive (local).
/// La misma serialización sirve como contrato al migrar a PostgreSQL/AWS RDS:
/// cada clase equivale a una tabla y `toJson`/`fromJson` al mapeo ORM.
library;

// ---------------------------------------------------------------------------
// Usuario
// ---------------------------------------------------------------------------

/// Usuario base. Los campos específicos de cada rol viven en [extra]
/// (equivalente a tablas satélite por rol en la base relacional futura).
class AppUser {
  final String id;
  String name;
  String email;
  String password;
  final String role;
  String phone;
  String cedula;

  /// Campos por rol:
  /// - student: university, career, groupId, courseIds (List), companyId,
  ///   donorId, labIds (List, laboratorios asignados — cada uno con su
  ///   propia Ruta de Impacto)
  /// - lxd: canGradeOpenLearning (bool), canGradeEnactus (bool)
  /// - mentor: company, position, specialty, languages, availability,
  ///   experience, interests (el laboratorio asignado vive en
  ///   Laboratory.mentorIds, no aquí: un mentor puede compartir estudiantes
  ///   con otros mentores del mismo laboratorio)
  /// - advisor: university
  /// - company: companyName (sus laboratorios se derivan de los cursos de
  ///   sus LXD — ver [DataProvider.labsForCompany] — no de un campo aquí)
  /// - donor: impactCode
  Map<String, dynamic> extra;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.phone = '',
    this.cedula = '',
    Map<String, dynamic>? extra,
  }) : extra = extra ?? {};

  List<String> get courseIds =>
      List<String>.from(extra['courseIds'] as List? ?? const []);
  set courseIds(List<String> v) => extra['courseIds'] = v;

  /// Laboratorios asignados a un estudiante (cada uno con su propia Ruta
  /// de Impacto, independiente de los demás).
  List<String> get labIds =>
      List<String>.from(extra['labIds'] as List? ?? const []);
  set labIds(List<String> v) => extra['labIds'] = v;

  /// Tipo de estudiante: define si ve Laboratorios/Ruta de Impacto
  /// (Enactus) o solo sus cursos asignados (Open Learning). Lo define el
  /// Admin al crear la cuenta.
  String get studentType =>
      (extra['studentType'] as String?) ?? StudentType.enactus;
  set studentType(String v) => extra['studentType'] = v;

  /// Permiso de calificar de un LXD, controlado por Admin y separado por
  /// contexto: activo por defecto en Open Learning (el LXD es el docente),
  /// desactivado por defecto en Enactus.
  bool get canGradeOpenLearning =>
      (extra['canGradeOpenLearning'] as bool?) ?? true;
  set canGradeOpenLearning(bool v) => extra['canGradeOpenLearning'] = v;

  bool get canGradeEnactus => (extra['canGradeEnactus'] as bool?) ?? false;
  set canGradeEnactus(bool v) => extra['canGradeEnactus'] = v;

  /// Cursos que este Mentor tiene asignados para revisar específicamente
  /// (los asigna Admin o la empresa aliada de su laboratorio). Si está
  /// vacío, revisa todos los cursos de los laboratorios donde está
  /// asignado — ver [DataProvider.reviewableCoursesForMentor].
  List<String> get reviewCourseIds =>
      List<String>.from(extra['reviewCourseIds'] as List? ?? const []);
  set reviewCourseIds(List<String> v) => extra['reviewCourseIds'] = v;

  String get university => (extra['university'] as String?) ?? '';
  String get career => (extra['career'] as String?) ?? '';
  String? get groupId => extra['groupId'] as String?;
  String? get companyId => extra['companyId'] as String?;
  String? get donorId => extra['donorId'] as String?;
  String? get labId => extra['labId'] as String?;
  String get companyName => (extra['companyName'] as String?) ?? '';
  String get impactCode => (extra['impactCode'] as String?) ?? '';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'phone': phone,
        'cedula': cedula,
        'extra': extra,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        password: j['password'] as String,
        role: j['role'] as String,
        phone: (j['phone'] as String?) ?? '',
        cedula: (j['cedula'] as String?) ?? '',
        extra: Map<String, dynamic>.from(j['extra'] as Map? ?? {}),
      );
}

/// Tipo de cuenta de estudiante (lo asigna el Admin al crearla).
class StudentType {
  /// Estudiante Enactus: ve Laboratorios y su Ruta de Impacto.
  static const enactus = 'enactus';

  /// Estudiante de Open Learning (externo): solo ve y completa los cursos
  /// que se le asignaron directamente. Sin laboratorios, fases ni módulos.
  static const openLearning = 'open_learning';

  static const all = [enactus, openLearning];

  static String label(String type) => switch (type) {
        openLearning => 'Open Learning',
        _ => 'Enactus',
      };
}

// ---------------------------------------------------------------------------
// Proyecto y Grupo
// ---------------------------------------------------------------------------

class Project {
  final String id;
  String name;
  String description;
  String problem;
  String solution;
  String community;
  List<String> ods;
  String stage;
  String impactIndicators;
  bool expoEnabled; // habilitado para RUTA NATIONAL EXPO

  Project({
    required this.id,
    required this.name,
    this.description = '',
    this.problem = '',
    this.solution = '',
    this.community = '',
    List<String>? ods,
    this.stage = 'Ideación',
    this.impactIndicators = '',
    this.expoEnabled = false,
  }) : ods = ods ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'problem': problem,
        'solution': solution,
        'community': community,
        'ods': ods,
        'stage': stage,
        'impactIndicators': impactIndicators,
        'expoEnabled': expoEnabled,
      };

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'] as String,
        name: j['name'] as String,
        description: (j['description'] as String?) ?? '',
        problem: (j['problem'] as String?) ?? '',
        solution: (j['solution'] as String?) ?? '',
        community: (j['community'] as String?) ?? '',
        ods: List<String>.from(j['ods'] as List? ?? const []),
        stage: (j['stage'] as String?) ?? 'Ideación',
        impactIndicators: (j['impactIndicators'] as String?) ?? '',
        expoEnabled: (j['expoEnabled'] as bool?) ?? false,
      );
}

class Group {
  final String id;
  String name;
  String projectId;
  String university;
  String advisorId;
  List<String> studentIds;

  Group({
    required this.id,
    required this.name,
    required this.projectId,
    this.university = '',
    this.advisorId = '',
    List<String>? studentIds,
  }) : studentIds = studentIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'projectId': projectId,
        'university': university,
        'advisorId': advisorId,
        'studentIds': studentIds,
      };

  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id: j['id'] as String,
        name: j['name'] as String,
        projectId: j['projectId'] as String,
        university: (j['university'] as String?) ?? '',
        advisorId: (j['advisorId'] as String?) ?? '',
        studentIds: List<String>.from(j['studentIds'] as List? ?? const []),
      );
}

// ---------------------------------------------------------------------------
// Laboratorio, Curso, Módulo y Lección
// ---------------------------------------------------------------------------

class Laboratory {
  final String id;
  String name;
  String description;
  String objectives;
  List<String> mentorIds; // mentores encargados (pueden compartir estudiantes)
  String sponsorCompanyId; // empresa patrocinadora (opcional)

  /// Ruta de Impacto de este laboratorio: siempre 3 fases. Si no vienen
  /// definidas (laboratorio nuevo o migrado desde antes de la Ruta de
  /// Impacto) se generan 3 fases vacías por defecto, autocurativo: basta
  /// con guardar el laboratorio una vez editado para que persistan.
  List<Phase> phases;

  Laboratory({
    required this.id,
    required this.name,
    this.description = '',
    this.objectives = '',
    List<String>? mentorIds,
    this.sponsorCompanyId = '',
    List<Phase>? phases,
  })  : mentorIds = mentorIds ?? [],
        phases = (phases == null || phases.isEmpty)
            ? _defaultPhases()
            : phases;

  static List<Phase> _defaultPhases() => [
        Phase(id: 'phase_1', order: 1, title: 'Fase 1'),
        Phase(id: 'phase_2', order: 2, title: 'Fase 2'),
        Phase(id: 'phase_3', order: 3, title: 'Fase 3'),
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'objectives': objectives,
        'mentorIds': mentorIds,
        'sponsorCompanyId': sponsorCompanyId,
        'phases': phases.map((p) => p.toJson()).toList(),
      };

  factory Laboratory.fromJson(Map<String, dynamic> j) {
    // Compatibilidad con datos previos a "varios mentores por laboratorio":
    // si solo existe el antiguo `mentorId` (String), se envuelve en lista.
    final legacyMentorId = j['mentorId'] as String?;
    final mentorIds = j['mentorIds'] != null
        ? List<String>.from(j['mentorIds'] as List)
        : (legacyMentorId == null || legacyMentorId.isEmpty
            ? <String>[]
            : [legacyMentorId]);
    return Laboratory(
      id: j['id'] as String,
      name: j['name'] as String,
      description: (j['description'] as String?) ?? '',
      objectives: (j['objectives'] as String?) ?? '',
      mentorIds: mentorIds,
      sponsorCompanyId: (j['sponsorCompanyId'] as String?) ?? '',
      phases: (j['phases'] as List? ?? const [])
          .map((e) => Phase.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Ruta de Impacto: fases, objetivos y módulos dentro de un laboratorio
// ---------------------------------------------------------------------------

/// Categoría de un objetivo de fase.
class ObjectiveCategory {
  static const entrepreneurship = 'Emprendimiento';
  static const business = 'Empresarial';
  static const all = [entrepreneurship, business];
}

/// Objetivo de una fase. Se marca completado cuando el estudiante completa
/// el 100% de TODOS los cursos en [sourceCourseIds] (no basta con uno solo).
/// Lo definen Admin, Mentor y LXD; se prellenan al asignar un curso del LXD
/// a un módulo de la fase, tomando los objetivos propios de ese curso.
class Objective {
  final String id;
  String category; // ObjectiveCategory.entrepreneurship | .business
  String text;
  List<String> sourceCourseIds;

  Objective({
    required this.id,
    this.category = ObjectiveCategory.entrepreneurship,
    this.text = '',
    List<String>? sourceCourseIds,
  }) : sourceCourseIds = sourceCourseIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'text': text,
        'sourceCourseIds': sourceCourseIds,
      };

  factory Objective.fromJson(Map<String, dynamic> j) => Objective(
        id: j['id'] as String,
        category:
            (j['category'] as String?) ?? ObjectiveCategory.entrepreneurship,
        text: (j['text'] as String?) ?? '',
        sourceCourseIds:
            List<String>.from(j['sourceCourseIds'] as List? ?? const []),
      );
}

/// Módulo dentro de una fase de la Ruta de Impacto. No confundir con
/// [CourseModule] (que agrupa lecciones DENTRO de un curso): un [RutaModule]
/// agrupa entregas/lecturas propias + varios cursos completos asignados.
/// El último módulo de cada fase es el "módulo de mentoría"
/// ([isMentorshipModule]): en vez de contenido, muestra el botón para
/// unirse a la reunión con el Mentor.
class RutaModule {
  final String id;
  int order;
  String title;
  bool isMentorshipModule;
  List<String> courseIds; // cursos del LXD asignados a este módulo
  List<Lesson> ownLessons; // entregas y lecturas propias del módulo

  RutaModule({
    required this.id,
    this.order = 1,
    this.title = '',
    this.isMentorshipModule = false,
    List<String>? courseIds,
    List<Lesson>? ownLessons,
  })  : courseIds = courseIds ?? [],
        ownLessons = ownLessons ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'order': order,
        'title': title,
        'isMentorshipModule': isMentorshipModule,
        'courseIds': courseIds,
        'ownLessons': ownLessons.map((l) => l.toJson()).toList(),
      };

  factory RutaModule.fromJson(Map<String, dynamic> j) => RutaModule(
        id: j['id'] as String,
        order: (j['order'] as num?)?.toInt() ?? 1,
        title: (j['title'] as String?) ?? '',
        isMentorshipModule: (j['isMentorshipModule'] as bool?) ?? false,
        courseIds: List<String>.from(j['courseIds'] as List? ?? const []),
        ownLessons: (j['ownLessons'] as List? ?? const [])
            .map((e) => Lesson.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Fase de la Ruta de Impacto. Fase 1 (order == 1) siempre desbloqueada;
/// las siguientes requieren que la anterior esté completa
/// (ver [DataProvider.isPhaseUnlocked]).
class Phase {
  final String id;
  int order;
  String title;
  String description;
  String deadline; // ISO date o vacío — la pone el Admin, ver DataProvider.checkPhaseDeadlineAlerts
  List<Objective> objectives;
  List<RutaModule> modules;

  Phase({
    required this.id,
    this.order = 1,
    this.title = '',
    this.description = '',
    this.deadline = '',
    List<Objective>? objectives,
    List<RutaModule>? modules,
  })  : objectives = objectives ?? [],
        modules = modules ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'order': order,
        'title': title,
        'description': description,
        'deadline': deadline,
        'objectives': objectives.map((o) => o.toJson()).toList(),
        'modules': modules.map((m) => m.toJson()).toList(),
      };

  factory Phase.fromJson(Map<String, dynamic> j) => Phase(
        id: j['id'] as String,
        order: (j['order'] as num?)?.toInt() ?? 1,
        title: (j['title'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        deadline: (j['deadline'] as String?) ?? '',
        objectives: (j['objectives'] as List? ?? const [])
            .map((e) =>
                Objective.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        modules: (j['modules'] as List? ?? const [])
            .map((e) =>
                RutaModule.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Estado de [Phase.deadline] respecto a hoy, para un estudiante puntual
/// (una fase ya completada nunca está "atrasada" aunque haya pasado la
/// fecha). Lo calcula [DataProvider.phaseDeadlineStatus].
enum DeadlineStatus { none, onTrack, approaching, overdue }

/// Progreso de un estudiante en la Ruta de Impacto de UN laboratorio
/// (un estudiante en varios laboratorios tiene una Ruta independiente por
/// cada uno). El desbloqueo de fases y el completado de módulos/objetivos
/// se derivan de esto + del progreso de los cursos vinculados
/// (ver métodos de Ruta de Impacto en [DataProvider]).
class RutaProgress {
  final String id; // '$studentId::$labId'
  final String studentId;
  final String labId;
  List<String> completedOwnLessonIds; // entregas/lecturas propias de módulos
  DateTime? updatedAt;

  RutaProgress({
    required this.studentId,
    required this.labId,
    List<String>? completedOwnLessonIds,
    this.updatedAt,
  })  : id = '$studentId::$labId',
        completedOwnLessonIds = completedOwnLessonIds ?? [];

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'labId': labId,
        'completedOwnLessonIds': completedOwnLessonIds,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory RutaProgress.fromJson(Map<String, dynamic> j) => RutaProgress(
        studentId: j['studentId'] as String,
        labId: j['labId'] as String,
        completedOwnLessonIds:
            List<String>.from(j['completedOwnLessonIds'] as List? ?? const []),
        updatedAt: j['updatedAt'] == null
            ? null
            : DateTime.tryParse(j['updatedAt'] as String),
      );
}

/// Tipo de lección: video, PDF, recurso descargable, enlace, quiz,
/// actividad (entregable) o encuesta.
enum LessonType { video, pdf, resource, link, quiz, activity, survey }

/// Pregunta de quiz. [kind]:
/// - multiple: opción múltiple ([options] + [answerIndex])
/// - truefalse: verdadero/falso ([answerIndex]: 0 = Verdadero, 1 = Falso)
/// - short: respuesta corta ([answerText], comparación flexible)
/// - fill: completar la frase ([answerText])
/// - order: ordenar elementos ([options] en el orden CORRECTO)
class QuizQuestion {
  String kind;
  String question;
  List<String> options;
  int answerIndex;
  String answerText;

  QuizQuestion({
    this.kind = 'multiple',
    this.question = '',
    List<String>? options,
    this.answerIndex = 0,
    this.answerText = '',
  }) : options = options ?? [];

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'question': question,
        'options': options,
        'answerIndex': answerIndex,
        'answerText': answerText,
      };

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        kind: (j['kind'] as String?) ?? 'multiple',
        question: (j['question'] as String?) ?? '',
        options: List<String>.from(j['options'] as List? ?? const []),
        answerIndex: (j['answerIndex'] as num?)?.toInt() ?? 0,
        answerText: (j['answerText'] as String?) ?? '',
      );
}

/// Configuración de una actividad (entregable).
class ActivityConfig {
  String description;
  String deadline; // ISO date o vacío
  bool requiresFile;
  bool requiresText;
  int maxFiles;
  List<String> allowedTypes; // PDF, Video, Documento, Imagen, ZIP

  /// 'points100' (0–100) | 'passfail' | 'review' (solo revisión)
  String gradingMode;

  /// Rúbrica: lista de {criterion, points}.
  List<Map<String, dynamic>> rubric;

  ActivityConfig({
    this.description = '',
    this.deadline = '',
    this.requiresFile = false,
    this.requiresText = true,
    this.maxFiles = 1,
    List<String>? allowedTypes,
    this.gradingMode = 'points100',
    List<Map<String, dynamic>>? rubric,
  })  : allowedTypes = allowedTypes ?? [],
        rubric = rubric ?? [];

  Map<String, dynamic> toJson() => {
        'description': description,
        'deadline': deadline,
        'requiresFile': requiresFile,
        'requiresText': requiresText,
        'maxFiles': maxFiles,
        'allowedTypes': allowedTypes,
        'gradingMode': gradingMode,
        'rubric': rubric,
      };

  factory ActivityConfig.fromJson(Map<String, dynamic> j) => ActivityConfig(
        description: (j['description'] as String?) ?? '',
        deadline: (j['deadline'] as String?) ?? '',
        requiresFile: (j['requiresFile'] as bool?) ?? false,
        requiresText: (j['requiresText'] as bool?) ?? true,
        maxFiles: (j['maxFiles'] as num?)?.toInt() ?? 1,
        allowedTypes:
            List<String>.from(j['allowedTypes'] as List? ?? const []),
        gradingMode: (j['gradingMode'] as String?) ?? 'points100',
        rubric: (j['rubric'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
}

class Lesson {
  final String id;
  String title;
  LessonType type;

  /// Ruta local dentro de `course_resources/` (o URL si type == link).
  /// Al migrar a AWS este campo pasará a ser la key del objeto en S3.
  String resourcePath;

  String description;
  int durationMin;

  /// Para quiz y encuesta.
  List<QuizQuestion> quiz;

  /// Para actividades (entregables).
  ActivityConfig? activity;

  Lesson({
    required this.id,
    required this.title,
    this.type = LessonType.video,
    this.resourcePath = '',
    this.description = '',
    this.durationMin = 0,
    List<QuizQuestion>? quiz,
    this.activity,
  }) : quiz = quiz ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'resourcePath': resourcePath,
        'description': description,
        'durationMin': durationMin,
        'quiz': quiz.map((q) => q.toJson()).toList(),
        'activity': activity?.toJson(),
      };

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'] as String,
        title: j['title'] as String,
        type: LessonType.values.firstWhere((t) => t.name == j['type'],
            orElse: () => LessonType.video),
        resourcePath: (j['resourcePath'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        durationMin: (j['durationMin'] as num?)?.toInt() ?? 0,
        quiz: (j['quiz'] as List? ?? const [])
            .map((e) =>
                QuizQuestion.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        activity: j['activity'] == null
            ? null
            : ActivityConfig.fromJson(
                Map<String, dynamic>.from(j['activity'] as Map)),
      );
}

class CourseModule {
  final String id;
  String title;
  List<Lesson> lessons;

  CourseModule({required this.id, required this.title, List<Lesson>? lessons})
      : lessons = lessons ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'lessons': lessons.map((l) => l.toJson()).toList(),
      };

  factory CourseModule.fromJson(Map<String, dynamic> j) => CourseModule(
        id: j['id'] as String,
        title: j['title'] as String,
        lessons: (j['lessons'] as List? ?? const [])
            .map((e) => Lesson.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class Course {
  final String id;
  String name;
  String subtitle;
  String description; // descripción corta
  String fullDescription;
  String coverImagePath;
  String introVideoPath;
  String labId; // vacío para RUTA NATIONAL EXPO (legado) o para Open Learning
  String creatorId; // LXD que creó el curso
  List<CourseModule> modules;
  bool isRutaExpo; // legado: ya no se usa para crear rutas nuevas
  String projectId; // legado, solo para RUTA NATIONAL EXPO

  /// Curso de Open Learning: se asigna directo a estudiantes, sin
  /// laboratorio, fases ni Ruta de Impacto.
  bool isOpenLearning;

  // Categorización y pedagogía
  String level; // Básico | Intermedio | Avanzado
  int estimatedHours;
  String language;
  String status; // Borrador | Publicado | Archivado
  List<String> tags;
  List<String> objectives;

  /// Objetivos del curso por categoría: al asignar este curso a un módulo
  /// de una fase, se prellenan como objetivos de esa fase
  /// (ver [Objective] y sección 5.4 de la Ruta de Impacto).
  List<String> entrepreneurshipObjectives;
  List<String> businessObjectives;
  List<String> competencies;
  List<String> learningOutcomes;
  List<String> prerequisiteCourseIds;
  List<String> ods;

  // Certificado
  bool generatesCertificate;
  int certifiedHours;

  // Restricciones y patrocinio
  String openDate; // ISO o vacío
  String closeDate;
  int maxStudents; // 0 = sin límite
  bool visible;
  String sponsorCompanyId;

  Course({
    required this.id,
    required this.name,
    this.subtitle = '',
    this.description = '',
    this.fullDescription = '',
    this.coverImagePath = '',
    this.introVideoPath = '',
    this.labId = '',
    this.creatorId = '',
    List<CourseModule>? modules,
    this.isRutaExpo = false,
    this.projectId = '',
    this.isOpenLearning = false,
    this.level = 'Básico',
    this.estimatedHours = 0,
    this.language = 'Español',
    this.status = 'Publicado',
    List<String>? tags,
    List<String>? objectives,
    List<String>? entrepreneurshipObjectives,
    List<String>? businessObjectives,
    List<String>? competencies,
    List<String>? learningOutcomes,
    List<String>? prerequisiteCourseIds,
    List<String>? ods,
    this.generatesCertificate = false,
    this.certifiedHours = 0,
    this.openDate = '',
    this.closeDate = '',
    this.maxStudents = 0,
    this.visible = true,
    this.sponsorCompanyId = '',
  })  : modules = modules ?? [],
        tags = tags ?? [],
        objectives = objectives ?? [],
        entrepreneurshipObjectives = entrepreneurshipObjectives ?? [],
        businessObjectives = businessObjectives ?? [],
        competencies = competencies ?? [],
        learningOutcomes = learningOutcomes ?? [],
        prerequisiteCourseIds = prerequisiteCourseIds ?? [],
        ods = ods ?? [];

  int get lessonCount =>
      modules.fold(0, (sum, m) => sum + m.lessons.length);

  bool get isPublished => status == 'Publicado';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subtitle': subtitle,
        'description': description,
        'fullDescription': fullDescription,
        'coverImagePath': coverImagePath,
        'introVideoPath': introVideoPath,
        'labId': labId,
        'creatorId': creatorId,
        'modules': modules.map((m) => m.toJson()).toList(),
        'isRutaExpo': isRutaExpo,
        'projectId': projectId,
        'isOpenLearning': isOpenLearning,
        'level': level,
        'estimatedHours': estimatedHours,
        'language': language,
        'status': status,
        'tags': tags,
        'objectives': objectives,
        'entrepreneurshipObjectives': entrepreneurshipObjectives,
        'businessObjectives': businessObjectives,
        'competencies': competencies,
        'learningOutcomes': learningOutcomes,
        'prerequisiteCourseIds': prerequisiteCourseIds,
        'ods': ods,
        'generatesCertificate': generatesCertificate,
        'certifiedHours': certifiedHours,
        'openDate': openDate,
        'closeDate': closeDate,
        'maxStudents': maxStudents,
        'visible': visible,
        'sponsorCompanyId': sponsorCompanyId,
      };

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: j['id'] as String,
        name: j['name'] as String,
        subtitle: (j['subtitle'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        fullDescription: (j['fullDescription'] as String?) ?? '',
        coverImagePath: (j['coverImagePath'] as String?) ?? '',
        introVideoPath: (j['introVideoPath'] as String?) ?? '',
        labId: (j['labId'] as String?) ?? '',
        // Compatibilidad: los cursos guardados antes del rename Mentor→LXD
        // usan la clave antigua `mentorId` para el creador.
        creatorId:
            (j['creatorId'] as String?) ?? (j['mentorId'] as String?) ?? '',
        modules: (j['modules'] as List? ?? const [])
            .map((e) =>
                CourseModule.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        isRutaExpo: (j['isRutaExpo'] as bool?) ?? false,
        projectId: (j['projectId'] as String?) ?? '',
        isOpenLearning: (j['isOpenLearning'] as bool?) ?? false,
        level: (j['level'] as String?) ?? 'Básico',
        estimatedHours: (j['estimatedHours'] as num?)?.toInt() ?? 0,
        language: (j['language'] as String?) ?? 'Español',
        status: (j['status'] as String?) ?? 'Publicado',
        tags: List<String>.from(j['tags'] as List? ?? const []),
        objectives:
            List<String>.from(j['objectives'] as List? ?? const []),
        entrepreneurshipObjectives: List<String>.from(
            j['entrepreneurshipObjectives'] as List? ?? const []),
        businessObjectives:
            List<String>.from(j['businessObjectives'] as List? ?? const []),
        competencies:
            List<String>.from(j['competencies'] as List? ?? const []),
        learningOutcomes:
            List<String>.from(j['learningOutcomes'] as List? ?? const []),
        prerequisiteCourseIds: List<String>.from(
            j['prerequisiteCourseIds'] as List? ?? const []),
        ods: List<String>.from(j['ods'] as List? ?? const []),
        generatesCertificate:
            (j['generatesCertificate'] as bool?) ?? false,
        certifiedHours: (j['certifiedHours'] as num?)?.toInt() ?? 0,
        openDate: (j['openDate'] as String?) ?? '',
        closeDate: (j['closeDate'] as String?) ?? '',
        maxStudents: (j['maxStudents'] as num?)?.toInt() ?? 0,
        visible: (j['visible'] as bool?) ?? true,
        sponsorCompanyId: (j['sponsorCompanyId'] as String?) ?? '',
      );
}

// ---------------------------------------------------------------------------
// Progreso, Entregas, Certificados
// ---------------------------------------------------------------------------

/// Progreso de un estudiante en un curso (lecciones completadas).
class Progress {
  final String id; // '$studentId::$courseId'
  final String studentId;
  final String courseId;
  List<String> completedLessonIds;
  DateTime? updatedAt; // última actividad registrada

  Progress({
    required this.studentId,
    required this.courseId,
    List<String>? completedLessonIds,
    this.updatedAt,
  })  : id = '$studentId::$courseId',
        completedLessonIds = completedLessonIds ?? [];

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'courseId': courseId,
        'completedLessonIds': completedLessonIds,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Progress.fromJson(Map<String, dynamic> j) => Progress(
        studentId: j['studentId'] as String,
        courseId: j['courseId'] as String,
        completedLessonIds:
            List<String>.from(j['completedLessonIds'] as List? ?? const []),
        updatedAt: j['updatedAt'] == null
            ? null
            : DateTime.tryParse(j['updatedAt'] as String),
      );
}

/// Entrega de un estudiante (individual) o de un grupo (legado, RUTA
/// NATIONAL EXPO). [courseId] identifica una actividad de curso;
/// [rutaModuleId] identifica una entrega propia de un módulo de la Ruta de
/// Impacto (ver [RutaModule]) — son mutuamente excluyentes.
class Submission {
  final String id;
  final String courseId;
  final String rutaModuleId;
  final String studentId; // vacío si es grupal
  final String groupId; // vacío si es individual
  final String lessonId; // actividad/encuesta asociada (vacío = entrega libre)
  String taskName;
  String comment;
  String filePath;
  double? grade;
  String feedback;
  final DateTime date;

  bool get isGroup => groupId.isNotEmpty;

  Submission({
    required this.id,
    this.courseId = '',
    this.rutaModuleId = '',
    this.studentId = '',
    this.groupId = '',
    this.lessonId = '',
    required this.taskName,
    this.comment = '',
    this.filePath = '',
    this.grade,
    this.feedback = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseId': courseId,
        'rutaModuleId': rutaModuleId,
        'studentId': studentId,
        'groupId': groupId,
        'lessonId': lessonId,
        'taskName': taskName,
        'comment': comment,
        'filePath': filePath,
        'grade': grade,
        'feedback': feedback,
        'date': date.toIso8601String(),
      };

  factory Submission.fromJson(Map<String, dynamic> j) => Submission(
        id: j['id'] as String,
        courseId: (j['courseId'] as String?) ?? '',
        rutaModuleId: (j['rutaModuleId'] as String?) ?? '',
        studentId: (j['studentId'] as String?) ?? '',
        groupId: (j['groupId'] as String?) ?? '',
        lessonId: (j['lessonId'] as String?) ?? '',
        taskName: j['taskName'] as String,
        comment: (j['comment'] as String?) ?? '',
        filePath: (j['filePath'] as String?) ?? '',
        grade: (j['grade'] as num?)?.toDouble(),
        feedback: (j['feedback'] as String?) ?? '',
        date: DateTime.parse(j['date'] as String),
      );
}

/// Certificado por completar la Ruta de Impacto de un laboratorio
/// (ya no existe certificado por curso individual). Lo emite quien tenga
/// el permiso de calificar activo en ese contexto
/// (ver [AppUser.canGradeEnactus] / [AppUser.canGradeOpenLearning]).
class Certificate {
  final String id;
  final String code;
  final String studentId;
  final String studentName;
  final String labId;
  final String labName;
  final String issuerName;
  final int hours; // horas certificadas (0 = no mostrar)
  final DateTime date;

  Certificate({
    required this.id,
    required this.code,
    required this.studentId,
    required this.studentName,
    required this.labId,
    required this.labName,
    required this.issuerName,
    this.hours = 0,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'studentId': studentId,
        'studentName': studentName,
        'labId': labId,
        'labName': labName,
        'issuerName': issuerName,
        'hours': hours,
        'date': date.toIso8601String(),
      };

  factory Certificate.fromJson(Map<String, dynamic> j) => Certificate(
        id: j['id'] as String,
        code: j['code'] as String,
        studentId: j['studentId'] as String,
        studentName: j['studentName'] as String,
        // Compatibilidad con certificados por curso (legado, previos a
        // "certificado por Ruta de Impacto").
        labId: (j['labId'] as String?) ?? (j['courseId'] as String?) ?? '',
        labName:
            (j['labName'] as String?) ?? (j['courseName'] as String?) ?? '',
        issuerName: (j['issuerName'] as String?) ??
            (j['mentorName'] as String?) ??
            '',
        hours: (j['hours'] as num?)?.toInt() ?? 0,
        date: DateTime.parse(j['date'] as String),
      );
}

// ---------------------------------------------------------------------------
// Checklist RUTA NATIONAL EXPO (por grupo)
// ---------------------------------------------------------------------------

class ExpoChecklist {
  final String groupId;
  List<Map<String, dynamic>> items; // {label, done}

  ExpoChecklist({required this.groupId, List<Map<String, dynamic>>? items})
      : items = items ?? [];

  Map<String, dynamic> toJson() => {'groupId': groupId, 'items': items};

  factory ExpoChecklist.fromJson(Map<String, dynamic> j) => ExpoChecklist(
        groupId: j['groupId'] as String,
        items: (j['items'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
}

// ---------------------------------------------------------------------------
// Evidencias de donantes y notificaciones
// ---------------------------------------------------------------------------

/// Evidencia de impacto visible para un donante (cargada por el admin).
class Evidence {
  final String id;
  final String donorId;
  String type; // foto | video | testimonio | reporte | historia
  String title;
  String description;
  String resourcePath;
  final DateTime date;

  Evidence({
    required this.id,
    required this.donorId,
    required this.type,
    required this.title,
    this.description = '',
    this.resourcePath = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'donorId': donorId,
        'type': type,
        'title': title,
        'description': description,
        'resourcePath': resourcePath,
        'date': date.toIso8601String(),
      };

  factory Evidence.fromJson(Map<String, dynamic> j) => Evidence(
        id: j['id'] as String,
        donorId: j['donorId'] as String,
        type: j['type'] as String,
        title: j['title'] as String,
        description: (j['description'] as String?) ?? '',
        resourcePath: (j['resourcePath'] as String?) ?? '',
        date: DateTime.parse(j['date'] as String),
      );
}

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime date;
  bool read;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    this.body = '',
    DateTime? date,
    this.read = false,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'body': body,
        'date': date.toIso8601String(),
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        userId: j['userId'] as String,
        title: j['title'] as String,
        body: (j['body'] as String?) ?? '',
        date: DateTime.parse(j['date'] as String),
        read: (j['read'] as bool?) ?? false,
      );
}

// ---------------------------------------------------------------------------
// Foro de la comunidad Enactus
// ---------------------------------------------------------------------------

/// Publicación del foro: el único espacio de la plataforma que NO está
/// aislado por laboratorio, universidad o empresa — lo comparten Admin,
/// Super Admin, Asesores y estudiantes Enactus (ver
/// [DataProvider.canAccessForum]).
class ForumPost {
  final String id;
  final String authorId;
  String body;
  final DateTime date;

  ForumPost({
    required this.id,
    required this.authorId,
    required this.body,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'body': body,
        'date': date.toIso8601String(),
      };

  factory ForumPost.fromJson(Map<String, dynamic> j) => ForumPost(
        id: j['id'] as String,
        authorId: j['authorId'] as String,
        body: (j['body'] as String?) ?? '',
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
      );
}

// ---------------------------------------------------------------------------
// Contenido editable de la página principal
// ---------------------------------------------------------------------------

class SiteContent {
  String heroTitle;
  String heroSubtitle;
  String bannerText;
  String aboutText;

  /// Link genérico de videollamada para los módulos de mentoría (Ruta de
  /// Impacto) y las reuniones LXD↔estudiante de Open Learning. Por ahora es
  /// un solo link fijo editable por Admin, sin integración real con un
  /// proveedor de meetings.
  String meetingLink;

  /// Cifras del hero público (contadores "Estudiantes activos", "Proyectos
  /// de impacto", "Laboratorios", "Universidades aliadas"). Editables desde
  /// Admin en vez de calcularse solas, para que reflejen números reales que
  /// el equipo cura a mano.
  int statStudents;
  int statProjects;
  int statLabs;
  int statUniversities;

  /// Imágenes de la galería del landing, codificadas en base64 (no hay
  /// backend de archivos: se editan y guardan localmente desde Admin →
  /// "Contenido página").
  List<String> galleryImages;

  SiteContent({
    this.heroTitle = 'Enactus Colombia',
    this.heroSubtitle =
        'Formamos líderes que transforman comunidades a través del emprendimiento social.',
    this.bannerText = 'Convocatoria National Expo 2026 abierta',
    this.aboutText =
        'Conectamos estudiantes, mentores, universidades, empresas y donantes '
        'para crear proyectos de impacto social en toda Colombia.',
    this.meetingLink = 'https://meet.google.com/enactus-mentoria',
    this.statStudents = 6,
    this.statProjects = 2,
    this.statLabs = 6,
    this.statUniversities = 2,
    List<String>? galleryImages,
  }) : galleryImages = galleryImages ?? [];

  Map<String, dynamic> toJson() => {
        'heroTitle': heroTitle,
        'heroSubtitle': heroSubtitle,
        'bannerText': bannerText,
        'aboutText': aboutText,
        'meetingLink': meetingLink,
        'statStudents': statStudents,
        'statProjects': statProjects,
        'statLabs': statLabs,
        'statUniversities': statUniversities,
        'galleryImages': galleryImages,
      };

  factory SiteContent.fromJson(Map<String, dynamic> j) => SiteContent(
        heroTitle: (j['heroTitle'] as String?) ?? 'Enactus Colombia',
        heroSubtitle: (j['heroSubtitle'] as String?) ?? '',
        bannerText: (j['bannerText'] as String?) ?? '',
        aboutText: (j['aboutText'] as String?) ?? '',
        meetingLink: (j['meetingLink'] as String?) ??
            'https://meet.google.com/enactus-mentoria',
        statStudents: (j['statStudents'] as num?)?.toInt() ?? 6,
        statProjects: (j['statProjects'] as num?)?.toInt() ?? 2,
        statLabs: (j['statLabs'] as num?)?.toInt() ?? 6,
        statUniversities: (j['statUniversities'] as num?)?.toInt() ?? 2,
        galleryImages: (j['galleryImages'] as List?)?.cast<String>() ?? [],
      );
}
