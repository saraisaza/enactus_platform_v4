// El glosario en el `DataProvider`: qué pide, qué manda y cómo queda la
// caché después de cada escritura.
//
// Los cuerpos que se mandan acá quedan anotados en el contrato cliente ->
// servidor (`GENERAR_CONTRATO=1 flutter test`), y el backend los reenvía a sus
// endpoints reales: por eso los ids son UUID de verdad.

import 'package:flutter_test/flutter_test.dart';

import 'package:enactus_platform/models/glossary.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_errors.dart';

import 'helpers/fake_api.dart';

const _curso = 'dddddddd-0000-4000-8000-000000000001';
const _mod = 'dddddddd-0000-4000-8000-000000000011';
const _lec = 'dddddddd-0000-4000-8000-000000000021';
const _ia = 'dddddddd-0000-4000-8000-000000000031';
const _modelo = 'dddddddd-0000-4000-8000-000000000032';

Map<String, Object?> _termino(String id, String word, int orden) => {
      'id': id,
      'courseId': _curso,
      'moduleId': _mod,
      'orderIndex': orden,
      'word': word,
      'shortDefinition': 'Definición de $word.',
      'explanation': '',
      'example': '',
      'imageS3Key': null,
      'lessonIds': [_lec],
      'relatedTermIds': <String>[],
    };

final _glosario = <String, Object?>{
  'terms': [_termino(_ia, 'Inteligencia artificial', 1), _termino(_modelo, 'Modelo', 2)],
  'reviews': {_ia: 'known'},
};

Map<String, Object?> _error(int status, String code, String message,
        [Map<String, Object?>? details]) =>
    {
      'error': {'code': code, 'message': message, 'details': ?details},
    };

/// Monta el provider sobre la API falsa. Sin widgets: lo que se prueba es el
/// provider.
({FakeApi fake, DataProvider data}) _montar(
    {Map<String, Object?> rutas = const {}, Map<String, int>? statuses}) {
  useFakeTokenStorage();
  final fake = FakeApi(
    routes: {'/courses/$_curso/glossary': _glosario, ...rutas},
    statuses: statuses,
  );
  return (fake: fake, data: DataProvider(fake.build()));
}

/// Deja correr los microtasks y las respuestas de la API falsa.
Future<void> _esperar() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('glossaryOf pide el glosario UNA vez y lo deja en caché', () async {
    final m = _montar();

    expect(m.data.glossaryOf(_curso).isLoading, isTrue);
    await _esperar();

    final glosario = m.data.glossaryOf(_curso).valueOrNull!;
    expect(glosario.terms.map((t) => t.word), ['Inteligencia artificial', 'Modelo']);
    expect(glosario.reviewOf(_ia), ReviewStatus.known);

    m.data.glossaryOf(_curso);
    await _esperar();
    expect(m.fake.requested.where((r) => r.endsWith('/glossary')), hasLength(1));
  });

  test('crear manda el formulario completo y recarga el glosario', () async {
    final m = _montar(rutas: {
      '/modules/$_mod/glossary-terms': _termino(_modelo, 'Modelo', 2),
    });

    final draft = GlossaryTermDraft(
      word: ' Modelo ',
      shortDefinition: 'Programa que aprendió patrones.',
      explanation: 'Se entrena con datos.',
      example: 'Uno que predice la deserción.',
      imageS3Key: 'glossary-images/modelo.png',
      lessonIds: [_lec],
      relatedTermIds: [_ia],
    );
    final creado =
        await m.data.createGlossaryTerm(_mod, draft, courseId: _curso);

    expect(creado.id, _modelo);
    expect(m.fake.requested, [
      'POST /modules/$_mod/glossary-terms',
      'GET /courses/$_curso/glossary',
    ]);
    expect(m.fake.cuerpos.first, {
      'word': 'Modelo',
      'shortDefinition': 'Programa que aprendió patrones.',
      'explanation': 'Se entrena con datos.',
      'example': 'Uno que predice la deserción.',
      'imageS3Key': 'glossary-images/modelo.png',
      'lessonIds': [_lec],
      'relatedTermIds': [_ia],
    });
    expect(m.data.glossaryOf(_curso).valueOrNull, isNotNull);
  });

  test('una palabra repetida llega como ConflictError con el módulo donde está',
      () async {
    final m = _montar(
      rutas: {
        '/modules/$_mod/glossary-terms': _error(
          409,
          'conflict',
          'El término «Modelo» ya está en el glosario de este curso, en el módulo «Fundamentos».',
          {'field': 'word', 'existingTermId': _modelo, 'moduleTitle': 'Fundamentos'},
        ),
      },
      statuses: {'/modules/$_mod/glossary-terms': 409},
    );

    await expectLater(
      m.data.createGlossaryTerm(
          _mod, GlossaryTermDraft(word: 'MODELO', shortDefinition: 'x'),
          courseId: _curso),
      throwsA(isA<ConflictError>()
          .having((e) => e.message, 'message', contains('Fundamentos'))
          .having((e) => e.details['field'], 'campo', 'word')),
    );
    // Falló la escritura: no hay nada que recargar.
    expect(m.fake.requested, ['POST /modules/$_mod/glossary-terms']);
  });

  test('editar manda PATCH con todo el formulario', () async {
    final m = _montar(rutas: {
      '/glossary-terms/$_ia': _termino(_ia, 'IA', 1),
    });
    final draft = GlossaryTermDraft.from(
        GlossaryTerm.fromJson(_termino(_ia, 'Inteligencia artificial', 1)))
      ..word = 'IA';

    await m.data.updateGlossaryTerm(_ia, draft, courseId: _curso);

    expect(m.fake.requested.first, 'PATCH /glossary-terms/$_ia');
    expect(m.fake.cuerpos.first['word'], 'IA');
    expect(m.fake.cuerpos.first['lessonIds'], [_lec],
        reason: 'las listas van siempre: el servidor las reemplaza');
  });

  test('reordenar manda la lista completa del módulo', () async {
    final m = _montar(rutas: {
      '/modules/$_mod/glossary-terms/order': [
        _termino(_modelo, 'Modelo', 1),
        _termino(_ia, 'Inteligencia artificial', 2),
      ],
    });

    await m.data.reorderGlossaryTerms(_mod, [_modelo, _ia], courseId: _curso);

    expect(m.fake.requested.first, 'PUT /modules/$_mod/glossary-terms/order');
    expect(m.fake.cuerpos.first, {
      'orderedIds': [_modelo, _ia],
    });
  });

  test('borrar un término recarga el glosario', () async {
    final m = _montar(rutas: {'/glossary-terms/$_modelo': const <String, Object?>{}});

    await m.data.deleteGlossaryTerm(_modelo, courseId: _curso);

    expect(m.fake.requested, [
      'DELETE /glossary-terms/$_modelo',
      'GET /courses/$_curso/glossary',
    ]);
  });

  group('modo repaso', () {
    test('la marca se ve EN EL ACTO, antes de que responda la red', () async {
      final m = _montar(rutas: {
        '/glossary-terms/$_modelo/review': {'termId': _modelo, 'status': 'review'},
      });
      m.data.glossaryOf(_curso);
      await _esperar();

      final guardando = m.data
          .setGlossaryReview(_modelo, ReviewStatus.review, courseId: _curso);
      expect(m.data.glossaryOf(_curso).valueOrNull!.reviewOf(_modelo),
          ReviewStatus.review);
      await guardando;

      expect(m.fake.requested.last, 'PUT /glossary-terms/$_modelo/review');
      expect(m.fake.cuerpos.last, {'status': 'review'});
    });

    test('si el servidor la rechaza, vuelve a lo que había y avisa', () async {
      final m = _montar(
        rutas: {
          '/glossary-terms/$_ia/review':
              _error(404, 'not_found', 'No se encontró el término.'),
        },
        statuses: {'/glossary-terms/$_ia/review': 404},
      );
      m.data.glossaryOf(_curso);
      await _esperar();

      await expectLater(
        m.data.setGlossaryReview(_ia, ReviewStatus.review, courseId: _curso),
        throwsA(isA<NotFoundError>()),
      );
      expect(m.data.glossaryOf(_curso).valueOrNull!.reviewOf(_ia),
          ReviewStatus.known);
    });
  });

  test('borrar un módulo descarta el glosario en caché: sus términos se fueron',
      () async {
    final m = _montar(rutas: {
      '/modules/$_mod': const <String, Object?>{},
      '/courses/$_curso': {'id': _curso, 'name': 'Curso', 'modules': <Object?>[]},
    });
    m.data.glossaryOf(_curso);
    await _esperar();

    await m.data.deleteModule(_mod, courseId: _curso);
    m.data.glossaryOf(_curso);
    await _esperar();

    expect(m.fake.requested.where((r) => r.endsWith('/glossary')), hasLength(2));
  });
}
