/// Modelos de datos, mapeados 1:1 contra las respuestas de la API.
///
/// Antes estos modelos servían de contrato con Hive: `toJson`/`fromJson`
/// escribían y leían la caja local. Ahora solo leen — la API es la única
/// fuente de verdad y el cliente no persiste nada (ver `api_service.dart`).
///
/// Tres cambios de forma que conviene tener presentes al leer las vistas:
///
/// 1. **`AppUser.extra` desapareció.** Lo que tenía semántica clara pasó a
///    campo tipado; los siete campos de perfil libre de LXD/Mentor viven en
///    [AppUser.profile].
/// 2. **Las relaciones ya no son listas de ids dentro del usuario.**
///    `labIds`, `courseIds` y `groupId` eran denormalizaciones de Hive; ahora
///    cada una tiene su endpoint. Una pantalla que necesite "los laboratorios
///    de esta persona" pide `/students/:id/ruta-progress`, no mira el usuario.
/// 3. **La completitud no está acá.** Vive en `models/progress.dart`, que
///    mapea lo que el servidor ya calculó.
library;

import 'progress.dart';

// ---------------------------------------------------------------------------
// Usuario
// ---------------------------------------------------------------------------

/// Tipo de cuenta de estudiante. Lo define el Admin al crearla y **solo el
/// servidor lo decide**: nunca llega en un parámetro de petición.
class StudentType {
  static const enactus = 'enactus';
  static const openLearning = 'open_learning';

  static const all = [enactus, openLearning];

  static String label(String? type) => switch (type) {
        openLearning => 'Open Learning',
        _ => 'eduXaction',
      };
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final String role;

  /// `enactus` | `open_learning`. Nulo en los roles que no son estudiante.
  final String? studentType;

  final String phone;
  final String cedula;
  final String city;
  final String university;
  final String career;

  /// Solo rol `company`.
  final String companyName;

  /// Solo rol `donor`.
  final String? impactCode;

  /// Empresa aliada a la que pertenece (estudiante patrocinado, LXD, mentor).
  final String? companyId;

  /// Donante que apoya a este estudiante.
  final String? donorId;

  /// Key en S3. Antes era `avatarBase64`, con la imagen entera embebida en el
  /// registro; ahora es una referencia y la imagen se sirve aparte.
  final String? avatarS3Key;

  /// Los dos permisos de calificar del LXD, separados por contexto.
  final bool canGradeOpenLearning;
  final bool canGradeEnactus;

  /// Perfil libre de LXD y Mentor: company, position, specialty, languages,
  /// availability, experience, interests. Texto sin estructura.
  final Map<String, dynamic> profile;

  final DateTime? joinedAt;

  /// Equipo y proyecto de esta persona. **Solo llega en `GET /auth/me`**, y
  /// solo para estudiantes y alumni: es información de uno mismo, no de
  /// terceros. En cualquier otro usuario es `null`.
  final UserTeam? team;

  /// Nombre de la empresa que la patrocina, resuelto por el servidor. Llega en
  /// `GET /auth/me` y en `GET /users?include=team`.
  final String? sponsorName;

  /// Avance general: el promedio de sus cursos. Solo con
  /// `GET /users?include=progress` — lo usan las tablas de seguimiento del
  /// LXD, el Mentor y el Asesor.
  final OverallProgress? overallProgress;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.studentType,
    this.phone = '',
    this.cedula = '',
    this.city = '',
    this.university = '',
    this.career = '',
    this.companyName = '',
    this.impactCode,
    this.companyId,
    this.donorId,
    this.avatarS3Key,
    this.canGradeOpenLearning = true,
    this.canGradeEnactus = false,
    this.profile = const {},
    this.joinedAt,
    this.team,
    this.sponsorName,
    this.overallProgress,
  });

  bool get isEnactusStudent => studentType == StudentType.enactus;
  bool get isOpenLearning => studentType == StudentType.openLearning;

  /// Valor del perfil libre, o cadena vacía. Evita repetir el cast.
  String profileField(String key) => (profile[key] as String?) ?? '';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
        role: j['role'] as String,
        studentType: j['studentType'] as String?,
        phone: (j['phone'] as String?) ?? '',
        cedula: (j['cedula'] as String?) ?? '',
        city: (j['city'] as String?) ?? '',
        university: (j['university'] as String?) ?? '',
        career: (j['career'] as String?) ?? '',
        companyName: (j['companyName'] as String?) ?? '',
        impactCode: j['impactCode'] as String?,
        companyId: j['companyId'] as String?,
        donorId: j['donorId'] as String?,
        avatarS3Key: j['avatarS3Key'] as String?,
        canGradeOpenLearning: (j['canGradeOpenLearning'] as bool?) ?? true,
        canGradeEnactus: (j['canGradeEnactus'] as bool?) ?? false,
        profile: Map<String, dynamic>.from(j['profile'] as Map? ?? const {}),
        joinedAt: _date(j['joinedAt']),
        team: j['team'] == null
            ? null
            : UserTeam.fromJson(Map<String, dynamic>.from(j['team'] as Map)),
        sponsorName: j['sponsorName'] as String?,
        overallProgress: j['overallProgress'] == null
            ? null
            : OverallProgress.fromJson(
                Map<String, dynamic>.from(j['overallProgress'] as Map)),
      );

  Map<String, dynamic> toUpdateJson() => {
        'name': name,
        'phone': phone,
        'cedula': cedula,
        'city': city,
        'career': career,
        'profile': profile,
      };
}

/// El equipo de una persona, tal como lo resuelve `GET /auth/me` o
/// `GET /users?include=team`.
class UserTeam {
  final String groupId;
  final String groupName;
  final String projectId;
  final String projectName;

  /// Identificador de la etapa (`ideation`, …). La etiqueta la pone el
  /// cliente con [ProjectStage.label]. Solo con `include=team`.
  final String projectStage;

  final String roleInProject;

  const UserTeam({
    required this.groupId,
    required this.groupName,
    required this.projectId,
    required this.projectName,
    this.projectStage = 'ideation',
    this.roleInProject = 'member',
  });

  String get roleLabel => ProjectMemberRole.label(roleInProject);
  String get stageLabel => ProjectStage.label(projectStage);

  factory UserTeam.fromJson(Map<String, dynamic> j) => UserTeam(
        groupId: (j['groupId'] as String?) ?? '',
        groupName: (j['groupName'] as String?) ?? '',
        projectId: (j['projectId'] as String?) ?? '',
        projectName: (j['projectName'] as String?) ?? '',
        projectStage: (j['projectStage'] as String?) ?? 'ideation',
        roleInProject: (j['roleInProject'] as String?) ?? 'member',
      );
}

/// Avance general de una persona: el promedio de sus cursos.
///
/// Sale de la misma vista de PostgreSQL que alimenta cada pantalla de
/// estudiante, así que la tabla del LXD y el portal del estudiante no pueden
/// discrepar.
class OverallProgress {
  /// 0..1.
  final double ratio;
  final int coursesTotal;
  final int coursesDone;

  const OverallProgress({
    this.ratio = 0,
    this.coursesTotal = 0,
    this.coursesDone = 0,
  });

  factory OverallProgress.fromJson(Map<String, dynamic> j) => OverallProgress(
        ratio: (j['ratio'] as num?)?.toDouble() ?? 0,
        coursesTotal: (j['coursesTotal'] as num?)?.toInt() ?? 0,
        coursesDone: (j['coursesDone'] as num?)?.toInt() ?? 0,
      );
}

// ---------------------------------------------------------------------------
// Proyecto y equipo
// ---------------------------------------------------------------------------

/// Etapas de un proyecto. La API guarda un identificador en inglés; la
/// etiqueta en español la pone el cliente, para no atar el dato al idioma.
class ProjectStage {
  static const all = [
    'ideation',
    'validation',
    'prototype',
    'pilot',
    'scaling',
    'national_expo',
  ];

  static String label(String stage) => switch (stage) {
        'validation' => 'Validación',
        'prototype' => 'Prototipo',
        'pilot' => 'Piloto',
        'scaling' => 'Escalamiento',
        'national_expo' => 'National Expo',
        _ => 'Ideación',
      };
}

/// Rol de una persona dentro del proyecto de su equipo.
///
/// Es la brecha de modelo que detectó la auditoría de frontend: antes
/// `Group.studentIds` era solo una lista de ids, sin rol.
class ProjectMemberRole {
  static const all = [
    'leader',
    'research',
    'finance',
    'communications',
    'design',
    'operations',
    'member',
  ];

  static String label(String role) => switch (role) {
        'leader' => 'Líder',
        'research' => 'Investigación',
        'finance' => 'Finanzas',
        'communications' => 'Comunicaciones',
        'design' => 'Diseño',
        'operations' => 'Operaciones',
        _ => 'Integrante',
      };
}

class Project {
  final String id;
  final String name;
  final String description;
  final String problem;
  final String solution;
  final String community;
  final String stage;
  final String impactIndicators;
  final bool expoEnabled;

  /// Códigos ODS (`ods_6`). Solo con `?include=ods` o en el detalle.
  final List<String> ods;

  /// Integrantes con su rol. Solo en el detalle.
  final List<ProjectMember> team;

  /// Los equipos del proyecto con su asesor académico. Solo en el detalle.
  ///
  /// Un proyecto puede tener más de un equipo —una universidad cada uno— y el
  /// asesor está en el equipo, no en el proyecto.
  final List<ProjectTeam> teams;

  /// Universidades de los equipos que trabajan el proyecto, y cuánta gente lo
  /// integra. Solo con `?include=teams`.
  ///
  /// Vienen resumidas con el proyecto porque el directorio las necesita para
  /// filtrar y contar; la alternativa era traerse todos los equipos de la
  /// plataforma y cruzarlos en el navegador.
  final List<String> universities;
  final int teamSize;

  final DateTime? createdAt;

  const Project({
    required this.id,
    required this.name,
    this.description = '',
    this.problem = '',
    this.solution = '',
    this.community = '',
    this.stage = 'ideation',
    this.impactIndicators = '',
    this.expoEnabled = false,
    this.ods = const [],
    this.team = const [],
    this.teams = const [],
    this.universities = const [],
    this.teamSize = 0,
    this.createdAt,
  });

  String get stageLabel => ProjectStage.label(stage);

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        problem: (j['problem'] as String?) ?? '',
        solution: (j['solution'] as String?) ?? '',
        community: (j['community'] as String?) ?? '',
        stage: (j['stage'] as String?) ?? 'ideation',
        impactIndicators: (j['impactIndicators'] as String?) ?? '',
        expoEnabled: (j['expoEnabled'] as bool?) ?? false,
        ods: List<String>.from(j['ods'] as List? ?? const []),
        team: (j['team'] as List? ?? const [])
            .map((e) =>
                ProjectMember.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        teams: (j['teams'] as List? ?? const [])
            .map((e) =>
                ProjectTeam.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        universities:
            List<String>.from(j['universities'] as List? ?? const []),
        teamSize: (j['teamSize'] as num?)?.toInt() ?? 0,
        createdAt: _date(j['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'problem': problem,
        'solution': solution,
        'community': community,
        'stage': stage,
        'impactIndicators': impactIndicators,
        'expoEnabled': expoEnabled,
        'ods': ods,
      };
}

/// Un equipo de un proyecto, con su asesor académico.
class ProjectTeam {
  final String groupId;
  final String groupName;
  final String university;
  final String? advisorName;

  const ProjectTeam({
    required this.groupId,
    required this.groupName,
    this.university = '',
    this.advisorName,
  });

  factory ProjectTeam.fromJson(Map<String, dynamic> j) => ProjectTeam(
        groupId: (j['groupId'] as String?) ?? '',
        groupName: (j['groupName'] as String?) ?? '',
        university: (j['university'] as String?) ?? '',
        advisorName: j['advisorName'] as String?,
      );
}

/// Integrante del equipo de un proyecto, con su rol.
class ProjectMember {
  final String userId;
  final String name;
  final String roleInProject;
  final String groupId;
  final String groupName;
  final String university;
  final String career;
  final String? avatarS3Key;

  const ProjectMember({
    required this.userId,
    required this.name,
    required this.roleInProject,
    this.groupId = '',
    this.groupName = '',
    this.university = '',
    this.career = '',
    this.avatarS3Key,
  });

  String get roleLabel => ProjectMemberRole.label(roleInProject);

  factory ProjectMember.fromJson(Map<String, dynamic> j) => ProjectMember(
        userId: j['userId'] as String,
        name: (j['name'] as String?) ?? '',
        roleInProject: (j['roleInProject'] as String?) ?? 'member',
        groupId: (j['groupId'] as String?) ?? '',
        groupName: (j['groupName'] as String?) ?? '',
        university: (j['university'] as String?) ?? '',
        career: (j['career'] as String?) ?? '',
        avatarS3Key: j['avatarS3Key'] as String?,
      );
}

class Group {
  final String id;
  final String name;
  final String projectId;
  final String university;
  final String? advisorId;

  /// Solo en el detalle.
  final List<ProjectMember> members;

  /// Checklist RUTA NATIONAL EXPO del equipo. Solo en el detalle, y de SOLO
  /// LECTURA: no hay pantalla que lo edite ni endpoint de escritura.
  final List<ChecklistItem> checklist;

  const Group({
    required this.id,
    required this.name,
    required this.projectId,
    this.university = '',
    this.advisorId,
    this.members = const [],
    this.checklist = const [],
  });

  List<ChecklistItem> get pendingChecklist =>
      checklist.where((item) => !item.done).toList();

  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        projectId: (j['projectId'] as String?) ?? '',
        university: (j['university'] as String?) ?? '',
        advisorId: j['advisorId'] as String?,
        members: (j['members'] as List? ?? const [])
            .map((e) =>
                ProjectMember.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        checklist: (j['checklist'] as List? ?? const [])
            .map((e) =>
                ChecklistItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class ChecklistItem {
  final String id;
  final String label;
  final bool done;

  const ChecklistItem({
    required this.id,
    required this.label,
    this.done = false,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
        id: j['id'] as String,
        label: (j['label'] as String?) ?? '',
        done: (j['done'] as bool?) ?? false,
      );
}

// ---------------------------------------------------------------------------
// Laboratorio y Ruta de Impacto (estructura; el avance está en progress.dart)
// ---------------------------------------------------------------------------

class Laboratory {
  final String id;
  final String name;
  final String description;
  final String objectives;
  final String? sponsorCompanyId;

  /// Sube con cada cambio estructural de la Ruta. El certificado guarda contra
  /// qué versión se emitió, para que agregar contenido después no lo invalide.
  final int contentVersion;

  /// Estructura de las fases. Solo en el detalle.
  final List<Phase> phases;

  /// Cuántos equipos de la red trabajan en esta área. Solo con
  /// `?scope=all`, la vista reducida de "otros laboratorios de la red".
  final int teamCount;

  /// LXDs del laboratorio. Solo en el detalle.
  ///
  /// No es una asignación explícita: son quienes crearon sus cursos. Misma
  /// definición que usa el servidor para decidir qué laboratorios ve un LXD.
  final List<LabStaff> lxds;

  /// Mentores que acompañan el laboratorio. Solo en el detalle.
  ///
  /// Vienen resueltos con el laboratorio a propósito: la alternativa era pedir
  /// la lista completa de usuarios y filtrarla en el navegador, que es lo que
  /// hacía la versión con Hive — y por eso cualquier rol podía enumerar a toda
  /// la plataforma.
  final List<LabStaff> mentors;

  /// Nombre de la empresa patrocinadora, ya resuelto. Solo en el detalle.
  final String? sponsorName;

  /// Cuántos estudiantes tienen este laboratorio asignado. Solo en el detalle.
  final int studentsAssigned;

  const Laboratory({
    required this.id,
    required this.name,
    this.description = '',
    this.objectives = '',
    this.sponsorCompanyId,
    this.contentVersion = 1,
    this.phases = const [],
    this.mentors = const [],
    this.lxds = const [],
    this.sponsorName,
    this.studentsAssigned = 0,
    this.teamCount = 0,
  });

  factory Laboratory.fromJson(Map<String, dynamic> j) => Laboratory(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        objectives: (j['objectives'] as String?) ?? '',
        sponsorCompanyId: j['sponsorCompanyId'] as String?,
        contentVersion: (j['contentVersion'] as num?)?.toInt() ?? 1,
        phases: (j['phases'] as List? ?? const [])
            .map((e) => Phase.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        mentors: (j['mentors'] as List? ?? const [])
            .map((e) => LabStaff.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        lxds: (j['lxds'] as List? ?? const [])
            .map((e) => LabStaff.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        sponsorName: j['sponsorName'] as String?,
        studentsAssigned: (j['studentsAssigned'] as num?)?.toInt() ?? 0,
        teamCount: (j['teamCount'] as num?)?.toInt() ?? 0,
      );
}

/// Un mentor o LXD tal como aparece en el detalle de SU laboratorio.
///
/// Incluye correo y disponibilidad: son las personas que acompañan a quien
/// mira, y coordinar una mentoría necesita cómo contactarlas. Es contacto
/// acotado a ese laboratorio, no un directorio de la plataforma.
class LabStaff {
  final String id;
  final String name;
  final String email;
  final String? avatarS3Key;

  /// Horario que publicó, o vacío si no publicó ninguno.
  final String availability;

  const LabStaff({
    required this.id,
    required this.name,
    this.email = '',
    this.avatarS3Key,
    this.availability = '',
  });

  factory LabStaff.fromJson(Map<String, dynamic> j) => LabStaff(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
        avatarS3Key: j['avatarS3Key'] as String?,
        availability: (j['availability'] as String?) ?? '',
      );
}

/// Categoría de un objetivo de fase o de curso.
class ObjectiveCategory {
  static const entrepreneurship = 'entrepreneurship';
  static const business = 'business';
  static const all = [entrepreneurship, business];

  static String label(String c) =>
      c == business ? 'Empresarial' : 'Emprendimiento';
}

class Objective {
  final String id;
  final String category;
  final String text;

  const Objective({
    required this.id,
    this.category = ObjectiveCategory.entrepreneurship,
    this.text = '',
  });

  factory Objective.fromJson(Map<String, dynamic> j) => Objective(
        id: j['id'] as String,
        category:
            (j['category'] as String?) ?? ObjectiveCategory.entrepreneurship,
        text: (j['text'] as String?) ?? '',
      );
}

/// Módulo dentro de una fase. No confundir con [CourseModule], que agrupa
/// lecciones dentro de un curso.
class RutaModule {
  final String id;
  final int orderIndex;
  final String title;

  /// El último módulo de cada fase: en vez de contenido, la reunión con el
  /// Mentor. El servidor lo recalcula solo tras cualquier cambio.
  final bool isMentorshipModule;
  final List<String> courseIds;

  const RutaModule({
    required this.id,
    this.orderIndex = 1,
    this.title = '',
    this.isMentorshipModule = false,
    this.courseIds = const [],
  });

  factory RutaModule.fromJson(Map<String, dynamic> j) => RutaModule(
        id: j['id'] as String,
        orderIndex: (j['orderIndex'] as num?)?.toInt() ?? 1,
        title: (j['title'] as String?) ?? '',
        isMentorshipModule: (j['isMentorshipModule'] as bool?) ?? false,
        courseIds: List<String>.from(j['courseIds'] as List? ?? const []),
      );
}

class Phase {
  final String id;
  final int orderIndex;
  final String title;
  final String description;
  final String? deadline;
  final List<Objective> objectives;
  final List<RutaModule> modules;

  /// Cuántos de los estudiantes asignados completaron esta fase.
  ///
  /// Es el avance del GRUPO, el que ve un Admin, LXD, Mentor o Empresa: ellos
  /// no tienen avance propio en un laboratorio. El avance personal de quien
  /// mira vive en `/students/:id/ruta-progress`, no acá.
  final int completedByCount;

  const Phase({
    required this.id,
    this.orderIndex = 1,
    this.title = '',
    this.description = '',
    this.deadline,
    this.objectives = const [],
    this.modules = const [],
    this.completedByCount = 0,
  });

  DateTime? get deadlineDate =>
      deadline == null ? null : DateTime.tryParse(deadline!);

  factory Phase.fromJson(Map<String, dynamic> j) => Phase(
        id: j['id'] as String,
        orderIndex: (j['orderIndex'] as num?)?.toInt() ?? 1,
        title: (j['title'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        deadline: j['deadline'] as String?,
        objectives: (j['objectives'] as List? ?? const [])
            .map((e) => Objective.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        modules: (j['modules'] as List? ?? const [])
            .map((e) => RutaModule.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        completedByCount: (j['completedByCount'] as num?)?.toInt() ?? 0,
      );
}

// ---------------------------------------------------------------------------
// Curso, módulo y lección
// ---------------------------------------------------------------------------

enum LessonType {
  video,
  pdf,
  resource,
  link,
  quiz,
  activity,
  survey;

  static LessonType fromJson(String? raw) => LessonType.values.firstWhere(
        (t) => t.name == raw,
        orElse: () => LessonType.video,
      );
}

/// Origen del video de una lección.
enum VideoSourceType {
  /// Enlace a YouTube o Vimeo: se muestra en un iframe.
  external,

  /// Archivo propio en S3, servido por CloudFront con URL firmada.
  uploaded;

  static VideoSourceType? fromJson(String? raw) => switch (raw) {
        'external' => VideoSourceType.external,
        'uploaded' => VideoSourceType.uploaded,
        _ => null,
      };
}

class QuizQuestion {
  final String id;
  final String kind;
  final String question;
  final List<String> options;

  /// Ojo: la clave de respuestas NUNCA llega al cliente de un estudiante.
  /// El quiz se califica en el servidor.
  const QuizQuestion({
    required this.id,
    this.kind = 'multiple',
    this.question = '',
    this.options = const [],
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        id: j['id'] as String,
        kind: (j['kind'] as String?) ?? 'multiple',
        question: (j['question'] as String?) ?? '',
        options: (j['options'] as List? ?? const [])
            .map((e) => e is Map ? '${e['text']}' : '$e')
            .toList(),
      );
}

class RubricItem {
  final String criterion;
  final int points;

  const RubricItem({required this.criterion, this.points = 0});

  factory RubricItem.fromJson(Map<String, dynamic> j) => RubricItem(
        criterion: (j['criterion'] as String?) ?? '',
        points: (j['points'] as num?)?.toInt() ?? 0,
      );
}

class ActivityConfig {
  final String description;
  final String? deadline;
  final bool requiresFile;
  final bool requiresText;
  final int maxFiles;

  /// `points100` | `passfail` | `review` | `scale5`.
  final String gradingMode;
  final List<RubricItem> rubric;

  const ActivityConfig({
    this.description = '',
    this.deadline,
    this.requiresFile = false,
    this.requiresText = true,
    this.maxFiles = 1,
    this.gradingMode = 'points100',
    this.rubric = const [],
  });

  int get totalPoints => rubric.fold(0, (sum, r) => sum + r.points);

  factory ActivityConfig.fromJson(Map<String, dynamic> j) => ActivityConfig(
        description: (j['description'] as String?) ?? '',
        deadline: j['deadline'] as String?,
        requiresFile: (j['requiresFile'] as bool?) ?? false,
        requiresText: (j['requiresText'] as bool?) ?? true,
        maxFiles: (j['maxFiles'] as num?)?.toInt() ?? 1,
        gradingMode: (j['gradingMode'] as String?) ?? 'points100',
        rubric: (j['rubric'] as List? ?? const [])
            .map((e) => RubricItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class Lesson {
  final String id;
  final String title;
  final LessonType type;
  final String description;
  final int durationMin;
  final int orderIndex;

  /// PDF o recurso descargable: key en S3.
  final String? resourceS3Key;
  final String? resourceFileName;

  /// Solo `type == link`.
  final String? externalUrl;

  /// Los dos orígenes de video. `null` si la lección no es de video, o si
  /// todavía no se le cargó ninguno (una lección a medio construir).
  final VideoSourceType? videoType;

  /// Solo `videoType == external`: el enlace de YouTube/Vimeo.
  final String? videoUrl;

  /// Solo `videoType == uploaded`: la key en S3. Para reproducirlo hay que
  /// pedirle al servidor una URL firmada de CloudFront — nunca se arma a mano.
  final String? videoS3Key;
  final int? videoDurationSec;

  final List<QuizQuestion> quiz;
  final ActivityConfig? activity;

  const Lesson({
    required this.id,
    required this.title,
    this.type = LessonType.video,
    this.description = '',
    this.durationMin = 0,
    this.orderIndex = 0,
    this.resourceS3Key,
    this.resourceFileName,
    this.externalUrl,
    this.videoType,
    this.videoUrl,
    this.videoS3Key,
    this.videoDurationSec,
    this.quiz = const [],
    this.activity,
  });

  bool get hasVideo => videoType != null;
  bool get isExternalVideo => videoType == VideoSourceType.external;
  bool get isUploadedVideo => videoType == VideoSourceType.uploaded;

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? '',
        type: LessonType.fromJson(j['type'] as String?),
        description: (j['description'] as String?) ?? '',
        durationMin: (j['durationMin'] as num?)?.toInt() ?? 0,
        orderIndex: (j['orderIndex'] as num?)?.toInt() ?? 0,
        resourceS3Key: j['resourceS3Key'] as String?,
        resourceFileName: j['resourceFileName'] as String?,
        externalUrl: j['externalUrl'] as String?,
        videoType: VideoSourceType.fromJson(j['videoType'] as String?),
        videoUrl: j['videoUrl'] as String?,
        videoS3Key: j['videoS3Key'] as String?,
        videoDurationSec: (j['videoDurationSec'] as num?)?.toInt(),
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
  final String title;
  final int orderIndex;
  final List<Lesson> lessons;

  const CourseModule({
    required this.id,
    required this.title,
    this.orderIndex = 0,
    this.lessons = const [],
  });

  factory CourseModule.fromJson(Map<String, dynamic> j) => CourseModule(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? '',
        orderIndex: (j['orderIndex'] as num?)?.toInt() ?? 0,
        lessons: (j['lessons'] as List? ?? const [])
            .map((e) => Lesson.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Nivel y estado de un curso: identificador en inglés, etiqueta en español.
class CourseLevel {
  static const all = ['basic', 'intermediate', 'advanced'];
  static String label(String level) => switch (level) {
        'intermediate' => 'Intermedio',
        'advanced' => 'Avanzado',
        _ => 'Básico',
      };
}

class CourseStatus {
  static const draft = 'draft';
  static const published = 'published';
  static const archived = 'archived';
  static const all = [draft, published, archived];

  static String label(String status) => switch (status) {
        published => 'Publicado',
        archived => 'Archivado',
        _ => 'Borrador',
      };
}

class Course {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final String fullDescription;
  final String? coverS3Key;

  /// Vacío en Open Learning y en la RUTA NATIONAL EXPO (legado).
  final String? laboratoryId;

  /// El LXD que lo creó. Determina quién puede editarlo.
  final String? creatorId;

  final bool isOpenLearning;
  final bool isRutaExpo;

  final String level;
  final int estimatedHours;
  final String language;
  final String status;

  final bool generatesCertificate;
  final int certifiedHours;
  final int maxStudents;
  final bool visible;
  final String? sponsorCompanyId;

  /// Solo con `?include=modules` (y `lessons` para las lecciones).
  final List<CourseModule> modules;

  /// Nombre del laboratorio y del LXD que lo creó. Vienen siempre en la
  /// respuesta: una tarjeta de curso los muestra, y sin ellos el cliente
  /// tendría que pedir un laboratorio y un usuario por cada tarjeta.
  final String? laboratoryName;
  final String? creatorName;

  /// Cifras de seguimiento. Solo con `?include=stats` — las tarjetas del
  /// portal LXD las muestran, y pedirlas por tarjeta sería una petición por
  /// curso.
  final CourseStats? stats;

  /// Título del módulo de la Ruta al que está vinculado, o `null`. Solo con
  /// `?include=stats`. Un curso de eduXaction sin vincular no le llega a
  /// nadie aunque esté publicado, y la tarjeta lo avisa.
  final String? linkedModule;

  /// Etiquetas, objetivos, competencias y ODS. Solo en el detalle, y ahí
  /// siempre: son cuatro consultas chicas y la ficha los muestra todos.
  final List<String> tags;
  final List<CourseObjective> objectives;
  final List<String> competencies;
  final List<String> ods;

  const Course({
    required this.id,
    required this.name,
    this.subtitle = '',
    this.description = '',
    this.fullDescription = '',
    this.coverS3Key,
    this.laboratoryId,
    this.creatorId,
    this.isOpenLearning = false,
    this.isRutaExpo = false,
    this.level = 'basic',
    this.estimatedHours = 0,
    this.language = 'es',
    this.status = CourseStatus.draft,
    this.generatesCertificate = false,
    this.certifiedHours = 0,
    this.maxStudents = 0,
    this.visible = true,
    this.sponsorCompanyId,
    this.modules = const [],
    this.laboratoryName,
    this.creatorName,
    this.stats,
    this.linkedModule,
    this.tags = const [],
    this.objectives = const [],
    this.competencies = const [],
    this.ods = const [],
  });

  bool get isPublished => status == CourseStatus.published;
  bool get isDraft => status == CourseStatus.draft;

  String get levelLabel => CourseLevel.label(level);
  String get statusLabel => CourseStatus.label(status);

  int get lessonCount =>
      modules.fold(0, (sum, m) => sum + m.lessons.length);

  /// Horas a contabilizar: certificadas si las tiene, si no las estimadas.
  int get hours => certifiedHours > 0 ? certifiedHours : estimatedHours;

  Lesson? lessonById(String lessonId) {
    for (final module in modules) {
      for (final lesson in module.lessons) {
        if (lesson.id == lessonId) return lesson;
      }
    }
    return null;
  }

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        subtitle: (j['subtitle'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        fullDescription: (j['fullDescription'] as String?) ?? '',
        coverS3Key: j['coverS3Key'] as String?,
        laboratoryId: j['laboratoryId'] as String?,
        creatorId: j['creatorId'] as String?,
        isOpenLearning: (j['isOpenLearning'] as bool?) ?? false,
        isRutaExpo: (j['isRutaExpo'] as bool?) ?? false,
        level: (j['level'] as String?) ?? 'basic',
        estimatedHours: (j['estimatedHours'] as num?)?.toInt() ?? 0,
        language: (j['language'] as String?) ?? 'es',
        status: (j['status'] as String?) ?? CourseStatus.draft,
        generatesCertificate: (j['generatesCertificate'] as bool?) ?? false,
        certifiedHours: (j['certifiedHours'] as num?)?.toInt() ?? 0,
        maxStudents: (j['maxStudents'] as num?)?.toInt() ?? 0,
        visible: (j['visible'] as bool?) ?? true,
        sponsorCompanyId: j['sponsorCompanyId'] as String?,
        modules: (j['modules'] as List? ?? const [])
            .map((e) =>
                CourseModule.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        laboratoryName: j['laboratoryName'] as String?,
        creatorName: j['creatorName'] as String?,
        stats: j['stats'] == null
            ? null
            : CourseStats.fromJson(
                Map<String, dynamic>.from(j['stats'] as Map)),
        linkedModule: j['linkedModule'] as String?,
        tags: List<String>.from(j['tags'] as List? ?? const []),
        objectives: (j['objectives'] as List? ?? const [])
            .map((e) =>
                CourseObjective.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        competencies:
            List<String>.from(j['competencies'] as List? ?? const []),
        ods: List<String>.from(j['ods'] as List? ?? const []),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'subtitle': subtitle,
        'description': description,
        'fullDescription': fullDescription,
        'laboratoryId': laboratoryId,
        'isOpenLearning': isOpenLearning,
        'level': level,
        'estimatedHours': estimatedHours,
        'language': language,
        'generatesCertificate': generatesCertificate,
        'certifiedHours': certifiedHours,
        'maxStudents': maxStudents,
        'visible': visible,
      };
}

/// Objetivo de aprendizaje de un curso.
///
/// `category` nula = objetivo general. Con categoría
/// (`entrepreneurship`/`business`) es de los que se copian a la fase al
/// vincular el curso a un módulo de la Ruta.
class CourseObjective {
  final String id;
  final String? category;
  final String text;

  const CourseObjective({required this.id, this.category, this.text = ''});

  bool get isGeneral => category == null;

  factory CourseObjective.fromJson(Map<String, dynamic> j) => CourseObjective(
        id: j['id'] as String,
        category: j['category'] as String?,
        text: (j['text'] as String?) ?? '',
      );
}

// ---------------------------------------------------------------------------
// Entregas y certificados
// ---------------------------------------------------------------------------

/// Escala de una calificación. Se guarda JUNTO a la nota porque el número por
/// sí solo no significa nada: 100 es "aprobado" en `passfail` y "nota
/// perfecta" en `points100`.
class GradingMode {
  static const points100 = 'points100';
  static const passfail = 'passfail';
  static const review = 'review';
  static const scale5 = 'scale5';

  static String label(String mode) => switch (mode) {
        passfail => 'Aprobado / Reprobado',
        review => 'Solo revisión',
        scale5 => 'Escala 0-5',
        _ => 'Puntaje 0-100',
      };

  /// Cómo se muestra una nota en su escala. `null` = sin calificar.
  static String display(double? grade, String? mode) {
    if (grade == null) return 'Pendiente';
    return switch (mode) {
      passfail => grade > 0 ? 'Aprobado' : 'Reprobado',
      scale5 => grade.toStringAsFixed(1),
      review => 'Revisado',
      _ => '${grade.round()}/100',
    };
  }

  /// Si la nota cuenta como aprobada en su escala.
  static bool isPassing(double? grade, String? mode) {
    if (grade == null) return false;
    return switch (mode) {
      passfail => grade > 0,
      scale5 => grade >= 3,
      _ => grade >= 60,
    };
  }
}

class SubmissionFile {
  final String id;
  final String s3Key;
  final String fileName;
  final String contentType;
  final int sizeBytes;

  const SubmissionFile({
    required this.id,
    required this.s3Key,
    required this.fileName,
    this.contentType = '',
    this.sizeBytes = 0,
  });

  factory SubmissionFile.fromJson(Map<String, dynamic> j) => SubmissionFile(
        id: j['id'] as String,
        s3Key: (j['s3Key'] as String?) ?? '',
        fileName: (j['fileName'] as String?) ?? '',
        contentType: (j['contentType'] as String?) ?? '',
        sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
      );
}

class Submission {
  final String id;
  final String? courseId;
  final String? rutaModuleId;
  final String? studentId;
  final String? groupId;
  final String? lessonId;
  final String taskName;
  final String comment;
  final DateTime submittedAt;

  final double? grade;
  final String? gradingMode;
  final String? gradedBy;
  final DateTime? gradedAt;

  /// Comentario del Mentor. El Mentor revisa y comenta, pero NO califica.
  final String feedback;
  final String? reviewedBy;

  final List<SubmissionFile> files;

  /// Nombre de quien entregó, del curso y de la lección — resueltos por el
  /// servidor. Sin esto, la bandeja de calificaciones haría tres peticiones
  /// por entrega solo para escribir una línea de encabezado.
  final String? studentName;
  final String? courseName;
  final String? lessonTitle;

  const Submission({
    required this.id,
    this.courseId,
    this.rutaModuleId,
    this.studentId,
    this.groupId,
    this.lessonId,
    required this.taskName,
    this.comment = '',
    required this.submittedAt,
    this.grade,
    this.gradingMode,
    this.gradedBy,
    this.gradedAt,
    this.feedback = '',
    this.reviewedBy,
    this.files = const [],
    this.studentName,
    this.courseName,
    this.lessonTitle,
  });

  bool get isGroup => groupId != null;

  /// Quién la hizo, para mostrar. Una entrega de equipo no tiene estudiante.
  String get authorLabel => studentName ?? (isGroup ? 'Entrega grupal' : '—');
  bool get isGraded => gradedAt != null;
  bool get isReviewed => feedback.isNotEmpty;

  String get gradeLabel => GradingMode.display(grade, gradingMode);

  /// Se puede borrar solo mientras no la hayan calificado ni comentado.
  bool get canBeDeletedByStudent => !isGraded && !isReviewed;

  factory Submission.fromJson(Map<String, dynamic> j) => Submission(
        id: j['id'] as String,
        courseId: j['courseId'] as String?,
        rutaModuleId: j['rutaModuleId'] as String?,
        studentId: j['studentId'] as String?,
        groupId: j['groupId'] as String?,
        lessonId: j['lessonId'] as String?,
        taskName: (j['taskName'] as String?) ?? '',
        comment: (j['comment'] as String?) ?? '',
        submittedAt: _date(j['submittedAt']) ?? DateTime.now(),
        grade: _grade(j['grade']),
        gradingMode: j['gradingMode'] as String?,
        gradedBy: j['gradedBy'] as String?,
        gradedAt: _date(j['gradedAt']),
        feedback: (j['feedback'] as String?) ?? '',
        reviewedBy: j['reviewedBy'] as String?,
        files: (j['files'] as List? ?? const [])
            .map((e) =>
                SubmissionFile.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        studentName: j['studentName'] as String?,
        courseName: j['courseName'] as String?,
        lessonTitle: j['lessonTitle'] as String?,
      );

  /// La API devuelve `numeric` como cadena, para no perder precisión.
  static double? _grade(Object? raw) => switch (raw) {
        null => null,
        final num n => n.toDouble(),
        final String s => double.tryParse(s),
        _ => null,
      };
}

class Certificate {
  final String id;
  final String code;
  final String studentId;
  final String laboratoryId;
  final String studentName;
  final String laboratoryName;
  final String issuerName;
  final int hours;
  final DateTime issuedAt;

  const Certificate({
    required this.id,
    required this.code,
    required this.studentId,
    required this.laboratoryId,
    required this.studentName,
    required this.laboratoryName,
    this.issuerName = '',
    this.hours = 0,
    required this.issuedAt,
  });

  factory Certificate.fromJson(Map<String, dynamic> j) => Certificate(
        id: j['id'] as String,
        code: (j['code'] as String?) ?? '',
        studentId: (j['studentId'] as String?) ?? '',
        laboratoryId: (j['laboratoryId'] as String?) ?? '',
        studentName: (j['studentNameSnapshot'] as String?) ?? '',
        laboratoryName: (j['laboratoryNameSnapshot'] as String?) ?? '',
        issuerName: (j['issuerNameSnapshot'] as String?) ?? '',
        hours: (j['hours'] as num?)?.toInt() ?? 0,
        issuedAt: _date(j['issuedAt']) ?? DateTime.now(),
      );
}

// ---------------------------------------------------------------------------
// Evidencias, recursos, notificaciones, foro y calendario
// ---------------------------------------------------------------------------

class Evidence {
  final String id;
  final String donorId;

  /// La otra brecha de modelo que cerró el esquema: antes una evidencia solo
  /// se relacionaba con el donante y no había forma de saber a qué proyecto
  /// pertenecía.
  final String? projectId;

  /// `photo` | `video` | `testimonial` | `report` | `story`.
  final String type;
  final String title;
  final String description;
  final String? s3Key;
  final DateTime evidenceDate;

  const Evidence({
    required this.id,
    required this.donorId,
    this.projectId,
    required this.type,
    required this.title,
    this.description = '',
    this.s3Key,
    required this.evidenceDate,
  });

  static String typeLabel(String type) => switch (type) {
        'photo' => 'Foto',
        'video' => 'Video',
        'testimonial' => 'Testimonio',
        'report' => 'Reporte',
        _ => 'Historia',
      };

  factory Evidence.fromJson(Map<String, dynamic> j) => Evidence(
        id: j['id'] as String,
        donorId: (j['donorId'] as String?) ?? '',
        projectId: j['projectId'] as String?,
        type: (j['type'] as String?) ?? 'story',
        title: (j['title'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        s3Key: j['s3Key'] as String?,
        evidenceDate: _date(j['evidenceDate']) ?? DateTime.now(),
      );
}

class CommunicationResource {
  final String id;
  final String title;
  final String description;

  /// `file` | `link`.
  final String type;
  final String? fileName;
  final String? s3Key;
  final String? url;
  final DateTime createdAt;

  const CommunicationResource({
    required this.id,
    required this.title,
    this.description = '',
    required this.type,
    this.fileName,
    this.s3Key,
    this.url,
    required this.createdAt,
  });

  bool get isLink => type == 'link';

  String get fileExt {
    final name = fileName ?? '';
    return name.contains('.') ? name.split('.').last.toLowerCase() : '';
  }

  factory CommunicationResource.fromJson(Map<String, dynamic> j) =>
      CommunicationResource(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        type: (j['type'] as String?) ?? 'link',
        fileName: j['fileName'] as String?,
        s3Key: j['s3Key'] as String?,
        url: j['url'] as String?,
        createdAt: _date(j['createdAt']) ?? DateTime.now(),
      );
}

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    this.body = '',
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        userId: (j['userId'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        createdAt: _date(j['createdAt']) ?? DateTime.now(),
        readAt: _date(j['readAt']),
      );
}

class ForumCategory {
  static const question = 'question';
  static const progress = 'progress';
  static const resource = 'resource';
  static const announcement = 'announcement';
  static const all = [question, progress, resource, announcement];

  static String label(String c) => switch (c) {
        progress => 'Avance',
        resource => 'Recurso',
        announcement => 'Anuncio',
        _ => 'Pregunta',
      };
}

/// Cifras del encabezado del foro, calculadas por el servidor.
class ForumStats {
  final int activeUsersThisWeek;
  final List<ForumTeamActivity> mostActiveTeams;

  const ForumStats({
    this.activeUsersThisWeek = 0,
    this.mostActiveTeams = const [],
  });

  factory ForumStats.fromJson(Map<String, dynamic> j) => ForumStats(
        activeUsersThisWeek:
            (j['activeUsersThisWeek'] as num?)?.toInt() ?? 0,
        mostActiveTeams: (j['mostActiveTeams'] as List? ?? const [])
            .map((e) =>
                ForumTeamActivity.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class ForumTeamActivity {
  final String groupId;
  final String groupName;
  final int count;

  const ForumTeamActivity({
    required this.groupId,
    required this.groupName,
    required this.count,
  });

  factory ForumTeamActivity.fromJson(Map<String, dynamic> j) =>
      ForumTeamActivity(
        groupId: (j['groupId'] as String?) ?? '',
        groupName: (j['groupName'] as String?) ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

class ForumReply {
  final String id;
  final String authorId;
  final String authorName;

  /// Rol del autor, para la etiqueta de la tarjeta. Viene con la publicación:
  /// el cliente no puede —ni debe— pedir el perfil de cada autor.
  final String authorRole;
  final String body;
  final DateTime createdAt;

  const ForumReply({
    required this.id,
    required this.authorId,
    this.authorName = '',
    this.authorRole = '',
    required this.body,
    required this.createdAt,
  });

  factory ForumReply.fromJson(Map<String, dynamic> j) => ForumReply(
        id: j['id'] as String,
        authorId: (j['authorId'] as String?) ?? '',
        authorName: (j['authorName'] as String?) ?? '',
        authorRole: (j['authorRole'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        createdAt: _date(j['createdAt']) ?? DateTime.now(),
      );
}

class ForumPost {
  final String id;
  final String authorId;
  final String authorName;

  /// Rol del autor, para la etiqueta de la tarjeta. Viene con la publicación:
  /// el cliente no puede —ni debe— pedir el perfil de cada autor.
  final String authorRole;
  final String body;
  final String category;
  final bool pinned;
  final DateTime createdAt;

  /// En el listado vienen los conteos; el detalle trae las respuestas.
  final int replyCount;
  final int likeCount;
  final bool likedByMe;
  final List<ForumReply> replies;

  const ForumPost({
    required this.id,
    required this.authorId,
    this.authorName = '',
    this.authorRole = '',
    required this.body,
    this.category = ForumCategory.question,
    this.pinned = false,
    required this.createdAt,
    this.replyCount = 0,
    this.likeCount = 0,
    this.likedByMe = false,
    this.replies = const [],
  });

  String get categoryLabel => ForumCategory.label(category);

  factory ForumPost.fromJson(Map<String, dynamic> j) => ForumPost(
        id: j['id'] as String,
        authorId: (j['authorId'] as String?) ?? '',
        authorName: (j['authorName'] as String?) ?? '',
        authorRole: (j['authorRole'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        category: (j['category'] as String?) ?? ForumCategory.question,
        pinned: (j['pinned'] as bool?) ?? false,
        createdAt: _date(j['createdAt']) ?? DateTime.now(),
        replyCount: (j['replyCount'] as num?)?.toInt() ??
            (j['replies'] as List?)?.length ??
            0,
        likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
        likedByMe: (j['likedByMe'] as bool?) ?? false,
        replies: (j['replies'] as List? ?? const [])
            .map((e) => ForumReply.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

enum CalendarEventType {
  openLearningSync,
  rutaImpacto,
  mentoria;

  static CalendarEventType fromJson(String? raw) => switch (raw) {
        'open_learning_sync' => CalendarEventType.openLearningSync,
        'mentoria' => CalendarEventType.mentoria,
        _ => CalendarEventType.rutaImpacto,
      };

  String get apiValue => switch (this) {
        CalendarEventType.openLearningSync => 'open_learning_sync',
        CalendarEventType.rutaImpacto => 'ruta_impacto',
        CalendarEventType.mentoria => 'mentoria',
      };

  String get label => switch (this) {
        CalendarEventType.openLearningSync => 'Sesión Open Learning',
        CalendarEventType.rutaImpacto => 'Ruta de Impacto',
        CalendarEventType.mentoria => 'Mentoría',
      };
}

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime startsAt;
  final CalendarEventType type;
  final String meetLink;
  final String guests;
  final String? courseId;
  final String? laboratoryId;

  const CalendarEvent({
    required this.id,
    this.title = '',
    this.description = '',
    required this.startsAt,
    this.type = CalendarEventType.rutaImpacto,
    this.meetLink = '',
    this.guests = '',
    this.courseId,
    this.laboratoryId,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> j) => CalendarEvent(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        startsAt: _date(j['startsAt']) ?? DateTime.now(),
        type: CalendarEventType.fromJson(j['type'] as String?),
        meetLink: (j['meetLink'] as String?) ?? '',
        guests: (j['guests'] as String?) ?? '',
        courseId: j['courseId'] as String?,
        laboratoryId: j['laboratoryId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'type': type.apiValue,
        'meetLink': meetLink,
        'guests': guests,
        'courseId': courseId,
        'laboratoryId': laboratoryId,
      };
}

/// Laboratorio tal como lo ve la portada pública: nombre y descripción, nada
/// más. Viene dentro de `/site-content`, no de `/laboratories` — ese sigue
/// exigiendo sesión y aislando por rol.
class PublicLab {
  final String id;
  final String name;
  final String description;

  const PublicLab({
    required this.id,
    required this.name,
    this.description = '',
  });

  factory PublicLab.fromJson(Map<String, dynamic> j) => PublicLab(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
      );
}

/// Contenido editable de la página principal.
class SiteContent {
  final String heroTitle;
  final String heroSubtitle;
  final String bannerText;
  final String aboutText;
  final String meetingLink;
  final int statStudents;
  final int statProjects;
  final int statLabs;
  final int statUniversities;

  /// Los laboratorios que se muestran en la portada.
  final List<PublicLab> laboratories;

  /// URLs **ya firmadas** de la galería del hero, listas para `Image.network`.
  ///
  /// Es la única lista de archivos que llega resuelta en vez de como key: la
  /// portada se ve sin sesión, así que no hay quien pida la firma después.
  /// Vencen en una hora, igual que las demás; una visita más larga que eso
  /// recarga la portada.
  final List<String> galleryImages;

  const SiteContent({
    this.heroTitle = 'eduXaction Colombia',
    this.heroSubtitle = '',
    this.bannerText = '',
    this.aboutText = '',
    this.meetingLink = '',
    this.statStudents = 0,
    this.statProjects = 0,
    this.statLabs = 0,
    this.statUniversities = 0,
    this.laboratories = const [],
    this.galleryImages = const [],
  });

  factory SiteContent.fromJson(Map<String, dynamic> j) => SiteContent(
        heroTitle: (j['heroTitle'] as String?) ?? 'eduXaction Colombia',
        heroSubtitle: (j['heroSubtitle'] as String?) ?? '',
        bannerText: (j['bannerText'] as String?) ?? '',
        aboutText: (j['aboutText'] as String?) ?? '',
        meetingLink: (j['meetingLink'] as String?) ?? '',
        statStudents: (j['statStudents'] as num?)?.toInt() ?? 0,
        statProjects: (j['statProjects'] as num?)?.toInt() ?? 0,
        statLabs: (j['statLabs'] as num?)?.toInt() ?? 0,
        statUniversities: (j['statUniversities'] as num?)?.toInt() ?? 0,
        laboratories: (j['laboratories'] as List? ?? const [])
            .map((e) => PublicLab.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        galleryImages:
            List<String>.from(j['galleryImages'] as List? ?? const []),
      );
}

// ---------------------------------------------------------------------------

/// Fecha de la API (ISO 8601) o `null`. Tolera un valor faltante o corrupto
/// sin tumbar la pantalla entera.
DateTime? _date(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
