/// Glosario de un curso: los términos de todos sus módulos y el repaso de
/// quien tiene la sesión, tal como los devuelve `GET /courses/:id/glossary`.
library;

/// Lo que un estudiante marcó de un término en el modo repaso.
enum ReviewStatus {
  /// «Ya lo sé».
  known,

  /// «Repasar».
  review;

  static ReviewStatus? fromJson(String? raw) => switch (raw) {
        'known' => ReviewStatus.known,
        'review' => ReviewStatus.review,
        _ => null,
      };
}

// Las letras que se consideran iguales al comparar dos palabras. Es una copia
// EXACTA de `ACENTOS` / `SIN_ACENTOS` en `backend/src/db/schema/glossary.ts`;
// `test/fixtures/claves_glosario.json` lo comprueba de los dos lados.
const _acentos = 'ÁÀÂÄÃáàâäãÉÈÊËéèêëÍÌÎÏíìîïÓÒÔÖÕóòôöõÚÙÛÜúùûüÑ';
const _sinAcentos = 'aaaaaaaaaaeeeeeeeeiiiiiiiioooooooooouuuuuuuuñ';

/// Clave con la que se comparan dos palabras del glosario: sin tildes ni
/// diéresis, en minúscula y con los espacios repetidos reducidos a uno.
///
/// «Innovación» e «innovacion» dan lo mismo; «año» y «ano», no. Sirve para
/// avisar de un duplicado mientras se escribe. Quien decide es la base.
String claveDeTermino(String palabra) {
  final sinTildes = StringBuffer();
  for (final rune in palabra.runes) {
    final letra = String.fromCharCode(rune);
    final i = _acentos.indexOf(letra);
    sinTildes.write(i >= 0 ? _sinAcentos[i] : letra);
  }
  // Solo A–Z a minúscula, como `lower(... collate "C")` en la base: las
  // mayúsculas con tilde ya salieron en minúscula de la tabla.
  return sinTildes
      .toString()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAllMapped(RegExp('[A-Z]'), (m) => m[0]!.toLowerCase());
}

class GlossaryTerm {
  final String id;
  final String courseId;
  final String moduleId;
  final int orderIndex;
  final String word;

  /// Una o dos frases: la tarjeta cerrada y el tooltip.
  final String shortDefinition;
  final String explanation;
  final String example;

  /// Key en S3. Para mostrarla hay que pedir su URL firmada.
  final String? imageS3Key;

  /// Lecciones de su módulo donde aparece, en el orden del módulo.
  final List<String> lessonIds;

  /// Términos del mismo curso, en el orden del glosario.
  final List<String> relatedTermIds;

  const GlossaryTerm({
    required this.id,
    required this.courseId,
    required this.moduleId,
    required this.word,
    required this.shortDefinition,
    this.orderIndex = 0,
    this.explanation = '',
    this.example = '',
    this.imageS3Key,
    this.lessonIds = const [],
    this.relatedTermIds = const [],
  });

  /// ¿Hay algo más que mostrar al expandir la tarjeta?
  bool get hasDetail =>
      explanation.isNotEmpty || example.isNotEmpty || imageS3Key != null;

  /// Letra con la que aparece en la navegación A–Z. `#` si no empieza con
  /// una letra.
  String get letra {
    final clave = claveDeTermino(word);
    if (clave.isEmpty) return '#';
    final primera = clave[0];
    return RegExp('[a-zñ]').hasMatch(primera) ? primera.toUpperCase() : '#';
  }

  factory GlossaryTerm.fromJson(Map<String, dynamic> j) => GlossaryTerm(
        id: j['id'] as String,
        courseId: j['courseId'] as String,
        moduleId: j['moduleId'] as String,
        orderIndex: (j['orderIndex'] as num?)?.toInt() ?? 0,
        word: (j['word'] as String?) ?? '',
        shortDefinition: (j['shortDefinition'] as String?) ?? '',
        explanation: (j['explanation'] as String?) ?? '',
        example: (j['example'] as String?) ?? '',
        imageS3Key: j['imageS3Key'] as String?,
        lessonIds: List<String>.from(j['lessonIds'] as List? ?? const []),
        relatedTermIds:
            List<String>.from(j['relatedTermIds'] as List? ?? const []),
      );
}

/// El glosario completo de un curso y el repaso de quien lo mira.
///
/// Se pide entero —son decenas de términos, no miles— porque cualquier
/// lección puede necesitar resaltar palabras de su módulo, y un término
/// relacionado puede estar en otro módulo.
class CourseGlossary {
  /// Ordenados por módulo y, dentro del módulo, por el orden del LXD.
  final List<GlossaryTerm> terms;

  final Map<String, ReviewStatus> reviews;

  const CourseGlossary({this.terms = const [], this.reviews = const {}});

  bool get isEmpty => terms.isEmpty;

  GlossaryTerm? termById(String id) {
    for (final t in terms) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<GlossaryTerm> forModule(String moduleId) =>
      terms.where((t) => t.moduleId == moduleId).toList();

  List<GlossaryTerm> forLesson(String lessonId) =>
      terms.where((t) => t.lessonIds.contains(lessonId)).toList();

  ReviewStatus? reviewOf(String termId) => reviews[termId];

  /// El término que ya usa esta palabra en el curso, si hay alguno.
  ///
  /// [exceptId] es el término que se está editando: cambiarle solo las
  /// mayúsculas a su propia palabra no es un duplicado.
  GlossaryTerm? duplicateOf(String word, {String? exceptId}) {
    final clave = claveDeTermino(word);
    if (clave.isEmpty) return null;
    for (final t in terms) {
      if (t.id != exceptId && claveDeTermino(t.word) == clave) return t;
    }
    return null;
  }

  /// Copia con el repaso de un término cambiado, para la actualización
  /// optimista del modo repaso.
  CourseGlossary withReview(String termId, ReviewStatus? status) {
    final next = Map<String, ReviewStatus>.from(reviews);
    if (status == null) {
      next.remove(termId);
    } else {
      next[termId] = status;
    }
    return CourseGlossary(terms: terms, reviews: next);
  }

  factory CourseGlossary.fromJson(Map<String, dynamic> j) {
    final reviews = <String, ReviewStatus>{};
    (j['reviews'] as Map? ?? const {}).forEach((termId, raw) {
      final status = ReviewStatus.fromJson(raw as String?);
      if (status != null) reviews['$termId'] = status;
    });
    return CourseGlossary(
      terms: (j['terms'] as List? ?? const [])
          .map((e) =>
              GlossaryTerm.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      reviews: reviews,
    );
  }
}

/// Lo que el editor manda al crear o editar un término.
///
/// Va SIEMPRE el formulario completo, listas incluidas: el servidor reemplaza
/// lecciones y relacionados por lo que llega.
class GlossaryTermDraft {
  String word;
  String shortDefinition;
  String explanation;
  String example;
  String? imageS3Key;
  List<String> lessonIds;
  List<String> relatedTermIds;

  GlossaryTermDraft({
    this.word = '',
    this.shortDefinition = '',
    this.explanation = '',
    this.example = '',
    this.imageS3Key,
    List<String>? lessonIds,
    List<String>? relatedTermIds,
  })  : lessonIds = lessonIds ?? [],
        relatedTermIds = relatedTermIds ?? [];

  factory GlossaryTermDraft.from(GlossaryTerm t) => GlossaryTermDraft(
        word: t.word,
        shortDefinition: t.shortDefinition,
        explanation: t.explanation,
        example: t.example,
        imageS3Key: t.imageS3Key,
        lessonIds: [...t.lessonIds],
        relatedTermIds: [...t.relatedTermIds],
      );

  Map<String, dynamic> toJson() => {
        'word': word.trim(),
        'shortDefinition': shortDefinition.trim(),
        'explanation': explanation.trim(),
        'example': example.trim(),
        'imageS3Key': imageS3Key,
        'lessonIds': lessonIds,
        'relatedTermIds': relatedTermIds,
      };
}
