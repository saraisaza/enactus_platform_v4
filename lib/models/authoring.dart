import 'models.dart';

/// Borradores del constructor de cursos.
///
/// Son deliberadamente MUTABLES, al revés que todo lo de `models.dart`: un
/// formulario con veinte campos que se editan de a uno no se lleva bien con
/// objetos inmutables —cada tecla obligaría a reconstruir el árbol entero— y
/// además estas clases cargan algo que los modelos de lectura no tienen ni
/// pueden tener: la clave de respuestas.
///
/// Viven en un archivo aparte justamente por eso. Un `QuizQuestion` es lo que
/// ve un estudiante, sin la respuesta correcta; un [QuizQuestionDraft] es lo
/// que edita quien arma el quiz, con ella. Mezclarlos haría fácil devolver sin
/// querer la clave por el endpoint equivocado.

/// Una pregunta tal como la edita el constructor, con su clave.
class QuizQuestionDraft {
  /// El id que le dio la base, o `null` si todavía no se guardó. No se manda
  /// al servidor: el `PUT` reemplaza el conjunto entero y asigna ids nuevos.
  final String? id;

  String kind;
  String question;
  List<String> options;

  /// `multiple`: índice de la correcta. `truefalse`: 0 = Verdadero, 1 = Falso.
  int? answerIndex;

  /// `short` y `fill`: la respuesta esperada.
  String? answerText;

  QuizQuestionDraft({
    this.id,
    this.kind = 'multiple',
    this.question = '',
    List<String>? options,
    this.answerIndex,
    this.answerText,
  }) : options = options ?? <String>[];

  factory QuizQuestionDraft.fromJson(Map<String, dynamic> j) =>
      QuizQuestionDraft(
        id: j['id'] as String?,
        kind: (j['kind'] as String?) ?? 'multiple',
        question: (j['question'] as String?) ?? '',
        options: List<String>.from(j['options'] as List? ?? const []),
        answerIndex: (j['answerIndex'] as num?)?.toInt(),
        answerText: j['answerText'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'question': question,
        'options': options,
        'answerIndex': answerIndex,
        'answerText': answerText,
      };
}

/// La configuración de una actividad mientras se edita.
class ActivityDraft {
  String description;

  /// `AAAA-MM-DD`, o `null` si no tiene fecha límite.
  String? deadline;

  bool requiresFile;
  bool requiresText;
  int maxFiles;
  String gradingMode;
  List<String> allowedTypes;
  List<RubricDraft> rubric;

  ActivityDraft({
    this.description = '',
    this.deadline,
    this.requiresFile = false,
    this.requiresText = true,
    this.maxFiles = 1,
    this.gradingMode = 'points100',
    List<String>? allowedTypes,
    List<RubricDraft>? rubric,
  })  : allowedTypes = allowedTypes ?? <String>[],
        rubric = rubric ?? <RubricDraft>[];

  factory ActivityDraft.from(ActivityConfig config) => ActivityDraft(
        description: config.description,
        deadline: config.deadline,
        requiresFile: config.requiresFile,
        requiresText: config.requiresText,
        maxFiles: config.maxFiles,
        gradingMode: config.gradingMode,
        allowedTypes: [...config.allowedTypes],
        rubric: config.rubric
            .map((r) => RubricDraft(criterion: r.criterion, points: r.points))
            .toList(),
      );

  int get totalPoints => rubric.fold(0, (sum, r) => sum + r.points);

  Map<String, dynamic> toJson() => {
        'description': description,
        'deadline': deadline,
        'requiresFile': requiresFile,
        'requiresText': requiresText,
        'maxFiles': maxFiles,
        'gradingMode': gradingMode,
        'allowedTypes': allowedTypes,
        'rubric': rubric.map((r) => r.toJson()).toList(),
      };
}

class RubricDraft {
  String criterion;
  int points;

  RubricDraft({this.criterion = '', this.points = 0});

  Map<String, dynamic> toJson() => {'criterion': criterion, 'points': points};
}

/// La categorización de un curso mientras se edita: las seis listas que
/// `PUT /courses/:id/meta` reemplaza juntas.
class CourseMetaDraft {
  List<String> tags;
  List<ObjectiveDraft> objectives;
  List<String> competencies;
  List<String> ods;
  List<String> learningOutcomes;
  List<String> prerequisiteCourseIds;

  CourseMetaDraft({
    List<String>? tags,
    List<ObjectiveDraft>? objectives,
    List<String>? competencies,
    List<String>? ods,
    List<String>? learningOutcomes,
    List<String>? prerequisiteCourseIds,
  })  : tags = tags ?? <String>[],
        objectives = objectives ?? <ObjectiveDraft>[],
        competencies = competencies ?? <String>[],
        ods = ods ?? <String>[],
        learningOutcomes = learningOutcomes ?? <String>[],
        prerequisiteCourseIds = prerequisiteCourseIds ?? <String>[];

  factory CourseMetaDraft.from(Course course) => CourseMetaDraft(
        tags: [...course.tags],
        objectives: course.objectives
            .map((o) => ObjectiveDraft(category: o.category, text: o.text))
            .toList(),
        competencies: [...course.competencies],
        ods: [...course.ods],
        learningOutcomes: [...course.learningOutcomes],
        prerequisiteCourseIds: [...course.prerequisiteCourseIds],
      );

  /// Los objetivos de una categoría, en el orden en que están.
  List<ObjectiveDraft> byCategory(String? category) =>
      objectives.where((o) => o.category == category).toList();

  Map<String, dynamic> toJson() => {
        'tags': tags,
        'objectives': objectives.map((o) => o.toJson()).toList(),
        'competencies': competencies,
        'ods': ods,
        'learningOutcomes': learningOutcomes,
        'prerequisiteCourseIds': prerequisiteCourseIds,
      };
}

class ObjectiveDraft {
  /// `null` = objetivo general del curso. Con categoría
  /// (`entrepreneurship`/`business`) se copia a la fase al vincular el curso.
  final String? category;
  String text;

  ObjectiveDraft({this.category, this.text = ''});

  Map<String, dynamic> toJson() => {'category': category, 'text': text};
}
