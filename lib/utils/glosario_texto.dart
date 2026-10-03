import '../models/glossary.dart';

/// Un pedazo del texto de una lección: texto suelto, o una aparición de un
/// término del glosario.
typedef SegmentoDeTexto = ({String texto, GlossaryTerm? termino});

/// Parte [texto] en pedazos, marcando dónde aparece cada término.
///
/// Reglas, en el orden en que importan:
///
/// - **Palabra entera.** «modelo» no se marca dentro de «modelos» ni de
///   «remodelo».
/// - **Sin tildes ni mayúsculas**, con la misma regla que los duplicados
///   ([claveDeTermino]): «Inteligencia Artificial» marca el término
///   «inteligencia artificial». Los espacios dentro de una expresión pueden
///   ser varios, o un salto de línea.
/// - **La más larga primero.** Con «datos» y «datos de entrenamiento» en el
///   glosario, «datos de entrenamiento» se marca entera; y si la larga no
///   cabe («datos de entrenamientos»), se marca «datos».
/// - **Todas las apariciones**, no solo la primera.
///
/// El texto que se devuelve es el ORIGINAL: la comparación se hace sobre una
/// copia normalizada del mismo largo, así que los índices coinciden.
List<SegmentoDeTexto> segmentarConGlosario(
  String texto,
  Iterable<GlossaryTerm> terminos,
) {
  final porClave = <String, GlossaryTerm>{};
  for (final t in terminos) {
    final clave = claveDeTermino(t.word);
    if (clave.isNotEmpty) porClave.putIfAbsent(clave, () => t);
  }
  if (texto.isEmpty || porClave.isEmpty) {
    return [(texto: texto, termino: null)];
  }

  final claves = porClave.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final alternativas = claves
      .map((c) => c.split(' ').map(RegExp.escape).join(r'\s+'))
      .join('|');
  final patron = RegExp(
    '(?<![\\p{L}\\p{N}])(?:$alternativas)(?![\\p{L}\\p{N}])',
    unicode: true,
  );

  final normalizado = normalizarConMismoLargo(texto);
  final segmentos = <SegmentoDeTexto>[];
  var desde = 0;
  for (final m in patron.allMatches(normalizado)) {
    final termino = porClave[claveDeTermino(m[0]!)];
    if (termino == null) continue;
    if (m.start > desde) {
      segmentos.add((texto: texto.substring(desde, m.start), termino: null));
    }
    segmentos.add((texto: texto.substring(m.start, m.end), termino: termino));
    desde = m.end;
  }
  if (desde < texto.length) {
    segmentos.add((texto: texto.substring(desde), termino: null));
  }
  return segmentos;
}
