/// Los resultados de una encuesta, como los ve quien la diseñó: juntos y sin
/// nombres. Una encuesta que se sabe anónima se responde con más franqueza.
class ResultadosDeEncuesta {
  /// Cuántas personas la respondieron.
  final int respuestas;
  final List<ResultadoDePregunta> preguntas;

  const ResultadosDeEncuesta({
    required this.respuestas,
    required this.preguntas,
  });

  factory ResultadosDeEncuesta.fromJson(Map<String, dynamic> j) =>
      ResultadosDeEncuesta(
        respuestas: (j['responses'] as num?)?.toInt() ?? 0,
        preguntas: [
          for (final p in j['questions'] as List? ?? const [])
            ResultadoDePregunta.fromJson(Map<String, dynamic>.from(p as Map)),
        ],
      );
}

/// Lo que se respondió en una pregunta.
class ResultadoDePregunta {
  final String id;

  /// `multiple` (elegir una opción), `scale` (de 1 a 5) o `short`
  /// (comentario).
  final String kind;
  final String question;

  /// `multiple`: las opciones. `scale`: las etiquetas del 1 y del 5, si las
  /// tiene.
  final List<String> options;

  /// `multiple`: cuántos eligieron cada opción. `scale`: cuántos dieron 1,
  /// 2, 3, 4 y 5.
  final List<int> counts;

  /// `scale`: el promedio, o `null` si nadie calificó.
  final double? average;

  /// `short`: los comentarios, el más nuevo primero.
  final List<String> comments;

  const ResultadoDePregunta({
    required this.id,
    required this.kind,
    required this.question,
    this.options = const [],
    this.counts = const [],
    this.average,
    this.comments = const [],
  });

  /// Cuántas personas respondieron ESTA pregunta.
  int get total => counts.fold(0, (a, b) => a + b);

  factory ResultadoDePregunta.fromJson(Map<String, dynamic> j) =>
      ResultadoDePregunta(
        id: j['id'] as String,
        kind: j['kind'] as String? ?? 'short',
        question: j['question'] as String? ?? '',
        options: List<String>.from(j['options'] as List? ?? const []),
        counts: [
          for (final n in j['counts'] as List? ?? const []) (n as num).toInt(),
        ],
        average: (j['average'] as num?)?.toDouble(),
        comments: List<String>.from(j['comments'] as List? ?? const []),
      );
}
