// El modelo del glosario: cómo se lee la respuesta del servidor y la regla con
// la que el editor avisa de una palabra repetida.
//
// La regla es una COPIA de la que aplica la base (`claveDeTerminoSql` en
// `backend/src/db/schema/glossary.ts`). Las dos leen los mismos ejemplos de
// `test/fixtures/claves_glosario.json`: si un lado cambia y el otro no, el
// editor avisaría de un duplicado distinto del que la base rechaza.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:enactus_platform/models/glossary.dart';

const _curso = 'cccccccc-0000-4000-8000-000000000001';
const _mod1 = 'cccccccc-0000-4000-8000-000000000011';
const _mod2 = 'cccccccc-0000-4000-8000-000000000012';
const _lec1 = 'cccccccc-0000-4000-8000-000000000021';
const _lec2 = 'cccccccc-0000-4000-8000-000000000022';
const _ia = 'cccccccc-0000-4000-8000-000000000031';
const _modelo = 'cccccccc-0000-4000-8000-000000000032';
const _sesgo = 'cccccccc-0000-4000-8000-000000000033';

/// Una respuesta con la forma exacta de `GET /courses/:id/glossary`.
final _respuesta = <String, Object?>{
  'terms': [
    {
      'id': _ia,
      'courseId': _curso,
      'moduleId': _mod1,
      'orderIndex': 1,
      'word': 'Inteligencia artificial',
      'shortDefinition': 'Sistemas que aprenden de datos.',
      'explanation': 'No piensa como una persona.',
      'example': '',
      'imageS3Key': null,
      'lessonIds': [_lec1],
      'relatedTermIds': [_modelo],
    },
    {
      'id': _modelo,
      'courseId': _curso,
      'moduleId': _mod1,
      'orderIndex': 2,
      'word': 'Modelo',
      'shortDefinition': 'Programa que aprendió patrones.',
      'explanation': '',
      'example': '',
      'imageS3Key': null,
      'lessonIds': [_lec1, _lec2],
      'relatedTermIds': <String>[],
    },
    {
      'id': _sesgo,
      'courseId': _curso,
      'moduleId': _mod2,
      'orderIndex': 1,
      'word': 'Ñandú de prueba',
      'shortDefinition': 'Para probar la letra Ñ.',
      'explanation': '',
      'example': '',
      'imageS3Key': 'glossary-images/n.png',
      'lessonIds': <String>[],
      'relatedTermIds': <String>[],
    },
  ],
  'reviews': {_ia: 'known', _sesgo: 'review', _modelo: 'algo-que-no-existe'},
};

void main() {
  group('claveDeTermino — la misma regla que la base', () {
    final fixture = jsonDecode(
            File('test/fixtures/claves_glosario.json').readAsStringSync())
        as Map<String, dynamic>;
    final casos = (fixture['casos'] as List).cast<List<dynamic>>();

    test('el archivo de ejemplos no está vacío', () {
      expect(casos, isNotEmpty);
    });

    for (final caso in casos) {
      final palabra = caso[0] as String;
      final esperada = caso[1] as String;
      test('${jsonEncode(palabra)} → ${jsonEncode(esperada)}', () {
        expect(claveDeTermino(palabra), esperada);
      });
    }
  });

  group('CourseGlossary.fromJson', () {
    final glosario = CourseGlossary.fromJson(_respuesta);

    test('lee los términos en el orden del servidor, con sus listas', () {
      expect(glosario.terms.map((t) => t.word),
          ['Inteligencia artificial', 'Modelo', 'Ñandú de prueba']);
      final modelo = glosario.termById(_modelo)!;
      expect(modelo.lessonIds, [_lec1, _lec2]);
      expect(modelo.hasDetail, isFalse);
      expect(glosario.termById(_ia)!.hasDetail, isTrue);
      expect(glosario.termById(_sesgo)!.hasDetail, isTrue,
          reason: 'una imagen sola ya es algo que mostrar al expandir');
    });

    test('un estado de repaso desconocido se ignora, no revienta', () {
      expect(glosario.reviews, {
        _ia: ReviewStatus.known,
        _sesgo: ReviewStatus.review,
      });
    });

    test('por módulo y por lección', () {
      expect(glosario.forModule(_mod1).map((t) => t.id), [_ia, _modelo]);
      expect(glosario.forModule(_mod2).map((t) => t.id), [_sesgo]);
      expect(glosario.forLesson(_lec1).map((t) => t.id), [_ia, _modelo]);
      expect(glosario.forLesson(_lec2).map((t) => t.id), [_modelo]);
      expect(glosario.forLesson('otra'), isEmpty);
    });

    test('una respuesta vacía es un glosario vacío', () {
      final vacio = CourseGlossary.fromJson(const {'terms': [], 'reviews': {}});
      expect(vacio.isEmpty, isTrue);
      expect(vacio.reviews, isEmpty);
    });
  });

  group('duplicateOf — el aviso del editor', () {
    final glosario = CourseGlossary.fromJson(_respuesta);

    test('encuentra la palabra aunque cambien tildes, mayúsculas o espacios', () {
      expect(glosario.duplicateOf('  INTELIGÉNCIA   artificial ')?.id, _ia);
    });

    test('la propia palabra del término que se edita no cuenta', () {
      expect(glosario.duplicateOf('MODELO', exceptId: _modelo), isNull);
      expect(glosario.duplicateOf('MODELO', exceptId: _ia)?.id, _modelo);
    });

    test('una palabra vacía no es duplicado de nada', () {
      expect(glosario.duplicateOf('   '), isNull);
    });
  });

  group('letra para la navegación A–Z', () {
    GlossaryTerm termino(String word) => GlossaryTerm(
        id: 'x', courseId: _curso, moduleId: _mod1, word: word,
        shortDefinition: 'd');

    test('sin tilde y en mayúscula; la Ñ es su propia letra', () {
      expect(termino('Éxito').letra, 'E');
      expect(termino('árbol').letra, 'A');
      expect(termino('Ñandú').letra, 'Ñ');
    });

    test('lo que no empieza con letra va a #', () {
      expect(termino('3D').letra, '#');
      expect(termino('¿Por qué?').letra, '#');
    });
  });

  group('withReview — la actualización optimista del repaso', () {
    final glosario = CourseGlossary.fromJson(_respuesta);

    test('cambia uno y deja los demás', () {
      final despues = glosario.withReview(_modelo, ReviewStatus.review);
      expect(despues.reviewOf(_modelo), ReviewStatus.review);
      expect(despues.reviewOf(_ia), ReviewStatus.known);
      expect(glosario.reviewOf(_modelo), isNull,
          reason: 'el original no se toca: es una copia');
    });

    test('con null lo quita, para deshacer', () {
      expect(glosario.withReview(_ia, null).reviewOf(_ia), isNull);
    });
  });

  group('GlossaryTermDraft.toJson', () {
    test('manda el formulario completo, recortado, con las listas', () {
      final draft = GlossaryTermDraft.from(
          CourseGlossary.fromJson(_respuesta).termById(_ia)!)
        ..word = '  Inteligencia artificial  '
        ..example = ' Un ejemplo. ';
      expect(draft.toJson(), {
        'word': 'Inteligencia artificial',
        'shortDefinition': 'Sistemas que aprenden de datos.',
        'explanation': 'No piensa como una persona.',
        'example': 'Un ejemplo.',
        'imageS3Key': null,
        'lessonIds': [_lec1],
        'relatedTermIds': [_modelo],
      });
    });
  });
}
