// La sección «Glosario» de cada módulo en el constructor de cursos.
//
// Lo importante es lo que se MANDA: el formulario completo, con las listas en
// el orden en que se ven, y que una palabra repetida se frene antes de llegar
// al servidor — y, si el servidor igual la rechaza, que se diga junto al
// campo.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_service.dart';
import 'package:enactus_platform/views/lxd/glossary_editor.dart';

import 'helpers/fake_api.dart';

const _curso = 'ffffffff-0000-4000-8000-000000000001';
const _m1 = 'ffffffff-0000-4000-8000-000000000011';
const _m2 = 'ffffffff-0000-4000-8000-000000000012';
const _l1 = 'ffffffff-0000-4000-8000-000000000021';
const _l2 = 'ffffffff-0000-4000-8000-000000000022';
const _modelo = 'ffffffff-0000-4000-8000-000000000031';
const _datos = 'ffffffff-0000-4000-8000-000000000032';
const _sesgo = 'ffffffff-0000-4000-8000-000000000033';

final _course = Course.fromJson({
  'id': _curso,
  'name': 'Introducción a la IA',
  'modules': [
    {
      'id': _m1,
      'title': 'Fundamentos',
      'orderIndex': 1,
      'lessons': [
        {'id': _l1, 'title': '¿Qué es la IA?', 'type': 'video'},
        {'id': _l2, 'title': 'Datos y modelos', 'type': 'pdf'},
      ],
    },
    {'id': _m2, 'title': 'Evaluación', 'orderIndex': 2, 'lessons': []},
  ],
});

Map<String, Object?> _t(String id, String modulo, int orden, String word,
        {String? imagen, List<String> lecciones = const []}) =>
    {
      'id': id,
      'courseId': _curso,
      'moduleId': modulo,
      'orderIndex': orden,
      'word': word,
      'shortDefinition': 'Definición de $word.',
      'explanation': 'Explicación de $word.',
      'example': '',
      'imageS3Key': imagen,
      'lessonIds': lecciones,
      'relatedTermIds': <String>[],
    };

final _glosario = {
  'terms': [
    _t(_modelo, _m1, 1, 'Modelo',
        imagen: 'glossary-images/modelo.png', lecciones: [_l2]),
    _t(_datos, _m1, 2, 'Datos de entrenamiento'),
    _t(_sesgo, _m2, 1, 'Sesgo'),
  ],
  'reviews': <String, String>{},
};

Future<FakeApi> _montar(
  WidgetTester tester, {
  Map<String, Object?> rutas = const {},
  Map<String, int> statuses = const {},
}) async {
  useFakeTokenStorage();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 1600);
  addTearDown(tester.view.reset);

  final fake = FakeApi(
    routes: {
      '/courses/$_curso/glossary': _glosario,
      '/files/download-url': {
        'url': 'https://example.invalid/modelo.png',
        'expiresInSeconds': 3600,
      },
      ...rutas,
    },
    statuses: Map.of(statuses),
  );
  final api = fake.build();
  final data = DataProvider(api);
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<ApiService>.value(value: api),
      ChangeNotifierProvider.value(value: data),
      ChangeNotifierProvider.value(value: AuthProvider(api, data)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ModuleGlossaryEditor(
              course: _course, module: _course.modules.first),
        ),
      ),
    ),
  ));
  await _asentar(tester);
  await tester.tap(find.byKey(const ValueKey('glosario-editor-$_m1')));
  await _asentar(tester);
  return fake;
}

Future<void> _asentar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('muestra los términos del módulo, no los de otros', (tester) async {
    await _montar(tester);
    expect(find.text('Glosario del módulo · 2 términos'), findsOneWidget);
    expect(find.text('Modelo'), findsOneWidget);
    expect(find.text('Datos de entrenamiento'), findsOneWidget);
    expect(find.text('Sesgo'), findsNothing);
  });

  testWidgets('agregar: manda el formulario completo, en el orden en que se ve',
      (tester) async {
    final fake = await _montar(tester, rutas: {
      '/modules/$_m1/glossary-terms': _t(_sesgo, _m1, 3, 'Algoritmo'),
    });

    await tester.tap(find.byKey(const ValueKey('glosario-agregar-$_m1')));
    await _asentar(tester);
    await tester.enterText(find.byKey(const ValueKey('glosario-palabra')), '  Algoritmo ');
    await tester.enterText(find.byKey(const ValueKey('glosario-definicion')),
        'Pasos para resolver un problema.');
    await tester.enterText(find.byKey(const ValueKey('glosario-ejemplo')),
        'Una receta de cocina.');
    // Marcadas al revés del orden del módulo: se mandan en el del módulo.
    await tester.tap(find.widgetWithText(FilterChip, 'Datos y modelos'));
    await tester.tap(find.widgetWithText(FilterChip, '¿Qué es la IA?'));
    // Un relacionado de OTRO módulo también vale.
    await tester.tap(find.widgetWithText(FilterChip, 'Sesgo'));
    await tester.pump();

    await tester.tap(find.text('Guardar'));
    await _asentar(tester);

    final i = fake.requested.indexOf('POST /modules/$_m1/glossary-terms');
    expect(i, isNonNegative);
    expect(fake.cuerpos[i], {
      'word': 'Algoritmo',
      'shortDefinition': 'Pasos para resolver un problema.',
      'explanation': '',
      'example': 'Una receta de cocina.',
      'imageS3Key': null,
      'lessonIds': [_l1, _l2],
      'relatedTermIds': [_sesgo],
    });
    expect(find.byType(AlertDialog), findsNothing, reason: 'se cerró al guardar');
    // El aviso «Término agregado ✓» se va solo; se lo deja terminar.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('una palabra repetida se avisa mientras se escribe y no se manda',
      (tester) async {
    final fake = await _montar(tester);
    await tester.tap(find.byKey(const ValueKey('glosario-agregar-$_m1')));
    await _asentar(tester);

    await tester.enterText(find.byKey(const ValueKey('glosario-palabra')), 'SESGO');
    await tester.enterText(find.byKey(const ValueKey('glosario-definicion')), 'x');
    await tester.pump();
    expect(find.text('Ya existe «Sesgo» en el módulo «Evaluación».'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('glosario-palabra')), 'modélo');
    await tester.pump();
    expect(find.text('Ya existe «Modelo» en este módulo.'), findsOneWidget);

    await tester.tap(find.text('Guardar'));
    await _asentar(tester);
    expect(fake.requested.where((r) => r.startsWith('POST')), isEmpty);
  });

  testWidgets('sin palabra ni definición, Guardar dice qué falta', (tester) async {
    final fake = await _montar(tester);
    await tester.tap(find.byKey(const ValueKey('glosario-agregar-$_m1')));
    await _asentar(tester);

    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.text('La palabra es obligatoria.'), findsOneWidget);
    expect(find.text('La definición corta es obligatoria.'), findsOneWidget);
    expect(fake.requested.where((r) => r.startsWith('POST')), isEmpty);
  });

  testWidgets('si el servidor rechaza la palabra, lo dice junto al campo',
      (tester) async {
    await _montar(tester, rutas: {
      '/modules/$_m1/glossary-terms': {
        'error': {
          'code': 'conflict',
          'message':
              'El término «Algoritmo» ya está en el glosario de este curso, en el módulo «Evaluación».',
          'details': {'field': 'word'},
        },
      },
    }, statuses: {
      '/modules/$_m1/glossary-terms': 409,
    });
    await tester.tap(find.byKey(const ValueKey('glosario-agregar-$_m1')));
    await _asentar(tester);
    await tester.enterText(find.byKey(const ValueKey('glosario-palabra')), 'Algoritmo');
    await tester.enterText(find.byKey(const ValueKey('glosario-definicion')), 'x');
    await tester.tap(find.text('Guardar'));
    await _asentar(tester);

    expect(
      find.text('El término «Algoritmo» ya está en el glosario de este curso, '
          'en el módulo «Evaluación».'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'no se cerró');
  });

  testWidgets('editar: la propia palabra no es duplicado, y se puede quitar la imagen',
      (tester) async {
    final fake = await _montar(tester, rutas: {
      '/glossary-terms/$_modelo': _t(_modelo, _m1, 1, 'MODELO'),
    });
    await tester.tap(find.byTooltip('Editar «Modelo»'));
    await _asentar(tester);

    await tester.enterText(find.byKey(const ValueKey('glosario-palabra')), 'MODELO');
    await tester.pump();
    expect(find.textContaining('Ya existe'), findsNothing);

    await tester.tap(find.text('Quitar imagen'));
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await _asentar(tester);

    final i = fake.requested.indexOf('PATCH /glossary-terms/$_modelo');
    expect(i, isNonNegative);
    expect(fake.cuerpos[i], {
      'word': 'MODELO',
      'shortDefinition': 'Definición de Modelo.',
      'explanation': 'Explicación de Modelo.',
      'example': '',
      'imageS3Key': null,
      'lessonIds': [_l2],
      'relatedTermIds': <String>[],
    });
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('cancelar con cambios pregunta antes de descartar', (tester) async {
    await _montar(tester);
    await tester.tap(find.byKey(const ValueKey('glosario-agregar-$_m1')));
    await _asentar(tester);
    await tester.enterText(find.byKey(const ValueKey('glosario-palabra')), 'Algo');
    await tester.tap(find.text('Cancelar'));
    await _asentar(tester);
    expect(find.text('Descartar cambios'), findsOneWidget);
  });

  testWidgets('borrar pide confirmación y manda DELETE', (tester) async {
    final fake = await _montar(tester, rutas: {
      '/glossary-terms/$_datos': const <String, Object?>{},
    });
    await tester.tap(find.byTooltip('Eliminar «Datos de entrenamiento»'));
    await _asentar(tester);
    expect(find.text('Eliminar término'), findsOneWidget);
    await tester.tap(find.text('Confirmar'));
    await _asentar(tester);
    expect(fake.requested, contains('DELETE /glossary-terms/$_datos'));
  });
}
