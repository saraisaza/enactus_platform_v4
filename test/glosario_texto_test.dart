// Dónde se resaltan las palabras del glosario dentro del texto de una
// lección. Es lógica pura: si marca de más, el texto se llena de subrayados
// que no significan nada; si marca de menos, el tooltip no aparece donde el
// estudiante lo busca.

import 'package:flutter_test/flutter_test.dart';

import 'package:enactus_platform/models/glossary.dart';
import 'package:enactus_platform/utils/glosario_texto.dart';

GlossaryTerm _t(String id, String word) => GlossaryTerm(
    id: id, courseId: 'c', moduleId: 'm', word: word, shortDefinition: 'd');

final _ia = _t('ia', 'Inteligencia artificial');
final _modelo = _t('modelo', 'Modelo');
final _datos = _t('datos', 'Datos');
final _datosEnt = _t('datos-ent', 'Datos de entrenamiento');
final _sesgo = _t('sesgo', 'Sesgo');
final _ano = _t('ano', 'Año');

/// Lo marcado, como «texto→id», para que el fallo se lea de un vistazo.
List<String> _marcas(String texto, List<GlossaryTerm> terminos) => [
      for (final s in segmentarConGlosario(texto, terminos))
        if (s.termino != null) '${s.texto}→${s.termino!.id}',
    ];

void main() {
  test('sin tildes ni mayúsculas, devolviendo el texto ORIGINAL', () {
    expect(
      _marcas('La INTELIGENCIA ARTIFICIÁL cambia todo.', [_ia]),
      ['INTELIGENCIA ARTIFICIÁL→ia'],
    );
  });

  test('solo palabras enteras', () {
    expect(_marcas('modelos y remodelo, pero sí un modelo.', [_modelo]),
        ['modelo→modelo']);
  });

  test('la expresión más larga gana; si no cabe, vale la corta', () {
    expect(_marcas('Los datos de entrenamiento importan.', [_datos, _datosEnt]),
        ['datos de entrenamiento→datos-ent']);
    expect(
      _marcas('Los datos de entrenamientos no existen.', [_datos, _datosEnt]),
      ['datos→datos'],
    );
  });

  test('varios espacios o un salto de línea dentro de la expresión', () {
    expect(_marcas('Inteligencia\n  artificial', [_ia]),
        ['Inteligencia\n  artificial→ia']);
  });

  test('todas las apariciones, y varios términos', () {
    expect(
      _marcas('Un modelo con sesgo. Otro modelo sin sesgo.', [_modelo, _sesgo]),
      ['modelo→modelo', 'sesgo→sesgo', 'modelo→modelo', 'sesgo→sesgo'],
    );
  });

  test('la ñ cuenta: «año» no se marca en «ano»', () {
    expect(_marcas('Un año y un ano.', [_ano]), ['año→ano']);
  });

  test('los pedazos vuelven a armar el texto exacto', () {
    const texto = '¿Qué es un Modelo? Un modelo aprende de datos.';
    final segmentos = segmentarConGlosario(texto, [_modelo, _datos]);
    expect(segmentos.map((s) => s.texto).join(), texto);
  });

  test('sin términos o sin texto, un solo pedazo sin marcar', () {
    expect(segmentarConGlosario('Hola', const []),
        [(texto: 'Hola', termino: null)]);
    expect(segmentarConGlosario('', [_modelo]), [(texto: '', termino: null)]);
  });

  test('caracteres especiales en la palabra no rompen la búsqueda', () {
    final cmas = _t('c++', 'C++');
    final pregunta = _t('q', '¿Por qué?');
    expect(_marcas('Programar en C++ es distinto.', [cmas]), ['C++→c++']);
    expect(_marcas('La pregunta ¿por qué? importa.', [pregunta]),
        ['¿por qué?→q']);
  });
}
