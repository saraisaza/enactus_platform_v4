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
  /// - student: university, career, groupId, courseIds (List), companyId, donorId
  /// - mentor: company, position, specialty, languages, availability,
  ///   experience, interests, labId
  /// - advisor: university
  /// - company: companyName, sponsoredLabId
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

  String get university => (extra['university'] as String?) ?? '';
  String get career => (extra['career'] as String?) ?? '';
  String? get groupId => extra['groupId'] as String?;
  String? get companyId => extra['companyId'] as String?;
  String? get donorId => extra['donorId'] as String?;
  String? get labId => extra['labId'] as String?;
  String get companyName => (extra['companyName'] as String?) ?? '';
  String? get sponsoredLabId => extra['sponsoredLabId'] as String?;
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
  String mentorId; // mentor encargado
  String sponsorCompanyId; // empresa patrocinadora (opcional)

  Laboratory({
    required this.id,
    required this.name,
    this.description = '',
    this.objectives = '',
    this.mentorId = '',
    this.sponsorCompanyId = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'objectives': objectives,
        'mentorId': mentorId,
        'sponsorCompanyId': sponsorCompanyId,
      };

  factory Laboratory.fromJson(Map<String, dynamic> j) => Laboratory(
        id: j['id'] as String,
        name: j['name'] as String,
        description: (j['description'] as String?) ?? '',
        objectives: (j['objectives'] as String?) ?? '',
        mentorId: (j['mentorId'] as String?) ?? '',
        sponsorCompanyId: (j['sponsorCompanyId'] as String?) ?? '',
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
  String labId; // vacío para RUTA NATIONAL EXPO
  String mentorId; // mentor creador
  List<CourseModule> modules;
  bool isRutaExpo;
  String projectId; // solo para RUTA NATIONAL EXPO

  // Categorización y pedagogía
  String level; // Básico | Intermedio | Avanzado
  int estimatedHours;
  String language;
  String status; // Borrador | Publicado | Archivado
  List<String> tags;
  List<String> objectives;
  List<String> competencies;
  List<String> learningOutcomes;
  List<String> prerequisiteCourseIds;
  List<String> ods;

  // Certificado
  bool generatesCertificate;
  String certificateName;
  int certifiedHours;
  String certificateSigner;

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
    this.mentorId = '',
    List<CourseModule>? modules,
    this.isRutaExpo = false,
    this.projectId = '',
    this.level = 'Básico',
    this.estimatedHours = 0,
    this.language = 'Español',
    this.status = 'Publicado',
    List<String>? tags,
    List<String>? objectives,
    List<String>? competencies,
    List<String>? learningOutcomes,
    List<String>? prerequisiteCourseIds,
    List<String>? ods,
    this.generatesCertificate = false,
    this.certificateName = '',
    this.certifiedHours = 0,
    this.certificateSigner = '',
    this.openDate = '',
    this.closeDate = '',
    this.maxStudents = 0,
    this.visible = true,
    this.sponsorCompanyId = '',
  })  : modules = modules ?? [],
        tags = tags ?? [],
        objectives = objectives ?? [],
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
        'mentorId': mentorId,
        'modules': modules.map((m) => m.toJson()).toList(),
        'isRutaExpo': isRutaExpo,
        'projectId': projectId,
        'level': level,
        'estimatedHours': estimatedHours,
        'language': language,
        'status': status,
        'tags': tags,
        'objectives': objectives,
        'competencies': competencies,
        'learningOutcomes': learningOutcomes,
        'prerequisiteCourseIds': prerequisiteCourseIds,
        'ods': ods,
        'generatesCertificate': generatesCertificate,
        'certificateName': certificateName,
        'certifiedHours': certifiedHours,
        'certificateSigner': certificateSigner,
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
        mentorId: (j['mentorId'] as String?) ?? '',
        modules: (j['modules'] as List? ?? const [])
            .map((e) =>
                CourseModule.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        isRutaExpo: (j['isRutaExpo'] as bool?) ?? false,
        projectId: (j['projectId'] as String?) ?? '',
        level: (j['level'] as String?) ?? 'Básico',
        estimatedHours: (j['estimatedHours'] as num?)?.toInt() ?? 0,
        language: (j['language'] as String?) ?? 'Español',
        status: (j['status'] as String?) ?? 'Publicado',
        tags: List<String>.from(j['tags'] as List? ?? const []),
        objectives:
            List<String>.from(j['objectives'] as List? ?? const []),
        competencies:
            List<String>.from(j['competencies'] as List? ?? const []),
        learningOutcomes:
            List<String>.from(j['learningOutcomes'] as List? ?? const []),
        prerequisiteCourseIds: List<String>.from(
            j['prerequisiteCourseIds'] as List? ?? const []),
        ods: List<String>.from(j['ods'] as List? ?? const []),
        generatesCertificate:
            (j['generatesCertificate'] as bool?) ?? false,
        certificateName: (j['certificateName'] as String?) ?? '',
        certifiedHours: (j['certifiedHours'] as num?)?.toInt() ?? 0,
        certificateSigner: (j['certificateSigner'] as String?) ?? '',
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

/// Entrega de un estudiante (individual) o de un grupo (RUTA NATIONAL EXPO).
class Submission {
  final String id;
  final String courseId;
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
    required this.courseId,
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
        courseId: j['courseId'] as String,
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

class Certificate {
  final String id;
  final String code;
  final String studentId;
  final String studentName;
  final String courseId;
  final String courseName;
  final String mentorName;
  final int hours; // horas certificadas (0 = no mostrar)
  final DateTime date;

  Certificate({
    required this.id,
    required this.code,
    required this.studentId,
    required this.studentName,
    required this.courseId,
    required this.courseName,
    required this.mentorName,
    this.hours = 0,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'studentId': studentId,
        'studentName': studentName,
        'courseId': courseId,
        'courseName': courseName,
        'mentorName': mentorName,
        'hours': hours,
        'date': date.toIso8601String(),
      };

  factory Certificate.fromJson(Map<String, dynamic> j) => Certificate(
        id: j['id'] as String,
        code: j['code'] as String,
        studentId: j['studentId'] as String,
        studentName: j['studentName'] as String,
        courseId: j['courseId'] as String,
        courseName: j['courseName'] as String,
        mentorName: j['mentorName'] as String,
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
// Contenido editable de la página principal
// ---------------------------------------------------------------------------

class SiteContent {
  String heroTitle;
  String heroSubtitle;
  String bannerText;
  String aboutText;

  SiteContent({
    this.heroTitle = 'Enactus Colombia',
    this.heroSubtitle =
        'Formamos líderes que transforman comunidades a través del emprendimiento social.',
    this.bannerText = 'Convocatoria National Expo 2026 abierta',
    this.aboutText =
        'Conectamos estudiantes, mentores, universidades, empresas y donantes '
        'para crear proyectos de impacto social en toda Colombia.',
  });

  Map<String, dynamic> toJson() => {
        'heroTitle': heroTitle,
        'heroSubtitle': heroSubtitle,
        'bannerText': bannerText,
        'aboutText': aboutText,
      };

  factory SiteContent.fromJson(Map<String, dynamic> j) => SiteContent(
        heroTitle: (j['heroTitle'] as String?) ?? 'Enactus Colombia',
        heroSubtitle: (j['heroSubtitle'] as String?) ?? '',
        bannerText: (j['bannerText'] as String?) ?? '',
        aboutText: (j['aboutText'] as String?) ?? '',
      );
}
