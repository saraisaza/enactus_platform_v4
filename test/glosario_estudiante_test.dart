// El glosario como lo ve el estudiante, en la pantalla real del curso.
//
// Lo que se prueba es lo que pide el diseño: el texto de la lección con las
// palabras resaltadas y su tooltip; «Glosario de esta lección» con su estado
// vacío; el glosario del módulo con buscador y A–Z; tarjetas que se expanden
// y relacionados que llevan al término; el modo repaso que guarda «ya lo sé»
// / «repasar»; el teclado; y que en el teléfono se vea en una columna.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_service.dart';
import 'package:enactus_platform/views/student/course_detail_view.dart';
import 'package:enactus_platform/widgets/glosario.dart';

import 'helpers/fake_api.dart';
import 'helpers/portal_harness.dart' show conSesionGuardada;

// UUID de verdad: el contrato cliente->servidor reenvía los cuerpos que se
// mandan acá al endpoint real.
const _curso = 'eeeeeeee-0000-4000-8000-000000000001';
const _m1 = 'eeeeeeee-0000-4000-8000-000000000011';
const _m2 = 'eeeeeeee-0000-4000-8000-000000000012';
const _lecTexto = 'eeeeeeee-0000-4000-8000-000000000021';
const _lecSinTerminos = 'eeeeeeee-0000-4000-8000-000000000022';
const _lecM2 = 'eeeeeeee-0000-4000-8000-000000000023';
const _ia = 'eeeeeeee-0000-4000-8000-000000000031';
const _modelo = 'eeeeeeee-0000-4000-8000-000000000032';
const _datos = 'eeeeeeee-0000-4000-8000-000000000033';
const _sesgo = 'eeeeeeee-0000-4000-8000-000000000034';

const _ana = {
  'id': 'student1',
  'name': 'Ana Estudiante',
  'email': 'ana@test.co',
  'role': 'student',
  'studentType': 'enactus',
};

const _cursoJson = {
  'id': _curso,
  'name': 'Introducción a la IA',
  'level': 'basic',
  'status': 'published',
  'language': 'es',
  'tags': <String>[],
  'objectives': <Object>[],
  'modules': [
    {
      'id': _m1,
      'title': 'Fundamentos',
      'lessons': [
        {
          'id': _lecTexto,
          'title': '¿Qué es la IA?',
          'type': 'pdf',
          'description':
              'La inteligencia artificial aprende de datos. Un modelo es lo que '
                  'queda después de entrenar.',
        },
        {'id': _lecSinTerminos, 'title': 'Material extra', 'type': 'pdf'},
      ],
    },
    {
      'id': _m2,
      'title': 'Evaluación',
      'lessons': [
        {'id': _lecM2, 'title': 'Casos', 'type': 'pdf'},
      ],
    },
  ],
};

Map<String, Object?> _termino(
  String id,
  String modulo,
  int orden,
  String word,
  String definicion, {
  String explicacion = '',
  String ejemplo = '',
  List<String> lecciones = const [],
  List<String> relacionados = const [],
}) =>
    {
      'id': id,
      'courseId': _curso,
      'moduleId': modulo,
      'orderIndex': orden,
      'word': word,
      'shortDefinition': definicion,
      'explanation': explicacion,
      'example': ejemplo,
      'imageS3Key': null,
      'lessonIds': lecciones,
      'relatedTermIds': relacionados,
    };

final _glosario = {
  'terms': [
    _termino(_ia, _m1, 1, 'Inteligencia artificial',
        'Sistemas que aprenden de datos para hacer tareas humanas.',
        explicacion: 'No piensa como una persona: aprende patrones.',
        ejemplo: 'Una app que detecta plagas en fotos de cultivos.',
        lecciones: [_lecTexto],
        relacionados: [_modelo, _sesgo]),
    _termino(_modelo, _m1, 2, 'Modelo',
        'Programa que aprendió patrones a partir de datos.',
        explicacion: 'Se entrena una vez y se usa muchas.',
        lecciones: [_lecTexto]),
    _termino(_datos, _m1, 3, 'Datos de entrenamiento',
        'Ejemplos con los que un modelo aprende.'),
    _termino(_sesgo, _m2, 1, 'Sesgo',
        'Error sistemático que favorece o perjudica a un grupo.',
        explicacion: 'Suele venir de los datos.'),
  ],
  'reviews': {_modelo: 'review'},
};

Map<String, Object?> _page(List<Object> data) =>
    {'data': data, 'page': 1, 'pageSize': 100, 'total': data.length};

FakeApi _fake({String studentId = 'student1'}) => FakeApi(routes: {
      '/auth/me': _ana,
      '/courses/$_curso': _cursoJson,
      '/courses/$_curso/glossary': _glosario,
      '/students/$studentId/course-progress/$_curso': {
        'courseId': _curso,
        'totalLessons': 3,
        'completedLessons': 0,
        'ratio': 0,
        'completedLessonIds': <String>[],
      },
      '/submissions': _page([]),
      '/notifications': _page([]),
      '/glossary-terms/$_ia/review': {'termId': _ia, 'status': 'known'},
    });

Future<FakeApi> _abrir(
  WidgetTester tester, {
  double ancho = 1400,
  String? studentId,
}) async {
  // Con token sembrado, `restoreSession` pide `/auth/me` y deja la sesión de
  // Ana abierta: el modo repaso necesita saber que quien mira es estudiante.
  conSesionGuardada();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(ancho, 2400);
  addTearDown(tester.view.reset);

  final fake = _fake(studentId: studentId ?? 'student1');
  final api = fake.build();
  final data = DataProvider(api)..setCurrentUser('student1');
  final auth = AuthProvider(api, data);
  await auth.restoreSession();
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<ApiService>.value(value: api),
      ChangeNotifierProvider.value(value: data),
      ChangeNotifierProvider.value(value: auth),
    ],
    child: MaterialApp(
      home: Scaffold(
          body: CourseDetailView(courseId: _curso, studentId: studentId)),
    ),
  ));
  await _asentar(tester);
  return fake;
}

Future<void> _asentar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _desplegarLeccion(WidgetTester tester, String titulo) async {
  final boton = find.descendant(
    of: find.byKey(ValueKey('leccion-${titulo == '¿Qué es la IA?' ? _lecTexto : titulo == 'Material extra' ? _lecSinTerminos : _lecM2}')),
    matching: find.byTooltip('Ver texto y glosario de la lección'),
  );
  await tester.tap(boton);
  await _asentar(tester);
}

Future<void> _abrirGlosarioDelModulo(WidgetTester tester, String modulo) async {
  final card = find.byKey(ValueKey('glosario-modulo-$modulo'));
  await tester.ensureVisible(card);
  await tester.tap(card);
  await _asentar(tester);
}

void main() {
  testWidgets('el texto de la lección resalta las palabras del glosario, con tooltip',
      (tester) async {
    await _abrir(tester);
    // Plegado: el texto no se ve hasta desplegar la lección.
    expect(find.byType(TextoConGlosario), findsNothing);

    await _desplegarLeccion(tester, '¿Qué es la IA?');
    expect(find.byType(TextoConGlosario), findsOneWidget);

    final resaltadas = tester.widgetList<Tooltip>(find.descendant(
      of: find.byType(TextoConGlosario),
      matching: find.byType(Tooltip),
    ));
    expect(
      resaltadas.map((t) => t.richMessage!.toPlainText().split('\n').first),
      ['Inteligencia artificial', 'Modelo'],
      reason: '«datos» no es un término; «Datos de entrenamiento» sí, pero no '
          'aparece entero en el texto',
    );

    // Tocar la palabra muestra la definición. En el texto va en minúscula: se
    // resalta igual, y se muestra como está escrita.
    await tester.tap(find.descendant(
        of: find.byType(TextoConGlosario), matching: find.text('modelo')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Programa que aprendió patrones a partir de datos.',
            findRichText: true),
        findsWidgets);
  });

  testWidgets('«Glosario de esta lección» trae sus términos, o lo dice si no hay',
      (tester) async {
    await _abrir(tester);
    await _desplegarLeccion(tester, '¿Qué es la IA?');
    expect(find.text('GLOSARIO DE ESTA LECCIÓN'), findsOneWidget);
    expect(find.byType(TarjetaTermino), findsNWidgets(2));

    await _desplegarLeccion(tester, 'Material extra');
    expect(find.text('Esta lección no tiene términos de glosario.'), findsOneWidget);
  });

  testWidgets('el glosario del módulo: buscador en tiempo real y letras A–Z',
      (tester) async {
    await _abrir(tester);
    expect(find.text('3 términos · 1 por repasar'), findsOneWidget);
    await _abrirGlosarioDelModulo(tester, _m1);
    expect(find.byType(TarjetaTermino), findsNWidgets(3));

    // Busca en la palabra y en la definición, sin tildes ni mayúsculas.
    await tester.enterText(find.widgetWithText(TextField, 'Buscar en el glosario'), 'PATRONES');
    await tester.pump();
    expect(find.byType(TarjetaTermino), findsOneWidget);
    expect(find.text('Modelo'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextField, 'Buscar en el glosario'), 'blockchain');
    await tester.pump();
    expect(find.text('Ningún término coincide con «blockchain».'), findsOneWidget);
    await tester.tap(find.text('Quitar los filtros'));
    await tester.pump();
    expect(find.byType(TarjetaTermino), findsNWidgets(3));

    // Letra D: solo «Datos de entrenamiento». Una letra sin términos no se
    // puede elegir.
    await tester.tap(find.widgetWithText(TextButton, 'D'));
    await tester.pump();
    expect(find.byType(TarjetaTermino), findsOneWidget);
    expect(find.text('Datos de entrenamiento'), findsOneWidget);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'B')).onPressed,
        isNull);
  });

  testWidgets('la tarjeta se expande, y un relacionado lleva al término',
      (tester) async {
    await _abrir(tester);
    await _abrirGlosarioDelModulo(tester, _m1);

    expect(find.text('No piensa como una persona: aprende patrones.'), findsNothing);
    await tester.tap(find.text('Inteligencia artificial').last);
    await _asentar(tester);
    expect(find.text('No piensa como una persona: aprende patrones.'), findsOneWidget);
    expect(find.text('Una app que detecta plagas en fotos de cultivos.'), findsOneWidget);

    // «Modelo» está en este módulo: se abre acá mismo.
    await tester.tap(find.widgetWithText(ActionChip, 'Modelo'));
    await _asentar(tester);
    expect(find.text('Se entrena una vez y se usa muchas.'), findsOneWidget);

    // «Sesgo» es de otro módulo: se abre en un diálogo.
    await tester.tap(find.widgetWithText(ActionChip, 'Sesgo'));
    await _asentar(tester);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.descendant(of: find.byType(Dialog), matching: find.text('Suele venir de los datos.')),
        findsOneWidget);
  });

  testWidgets('con el teclado: Tab llega a la tarjeta y Enter la expande',
      (tester) async {
    await _abrir(tester);
    await _abrirGlosarioDelModulo(tester, _m1);

    for (var i = 0; i < 60; i++) {
      if (FocusManager.instance.primaryFocus?.debugLabel == 'término $_ia') break;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'término $_ia');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _asentar(tester);
    expect(find.text('No piensa como una persona: aprende patrones.'), findsOneWidget);
  });

  testWidgets('modo repaso: voltear la tarjeta y guardar «ya lo sé»',
      (tester) async {
    final fake = await _abrir(tester);
    await _abrirGlosarioDelModulo(tester, _m1);
    await tester.tap(find.text('Modo repaso'));
    await _asentar(tester);

    expect(find.byType(TarjetaRepaso), findsNWidgets(3));
    expect(find.text('Toque para ver la definición'), findsNWidgets(3));

    // Voltear: aparece la definición.
    await tester.tap(find.text('Inteligencia artificial').last);
    await _asentar(tester);
    expect(find.text('Sistemas que aprenden de datos para hacer tareas humanas.'),
        findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Ya lo sé').first);
    await _asentar(tester);
    expect(fake.requested, contains('PUT /glossary-terms/$_ia/review'));
    expect(fake.cuerpos[fake.requested.indexOf('PUT /glossary-terms/$_ia/review')],
        {'status': 'known'});
    expect(find.textContaining('Ya lo sabe: 1 de 3'), findsOneWidget);

    // Solo los de repasar: queda «Modelo».
    await tester.tap(find.text('Solo los de repasar'));
    await _asentar(tester);
    expect(find.byType(TarjetaRepaso), findsOneWidget);
    expect(find.text('Modelo'), findsWidgets);
  });

  testWidgets('quien mira el curso de OTRO estudiante no guarda repaso a su nombre',
      (tester) async {
    await _abrir(tester, studentId: 'otro');
    await _abrirGlosarioDelModulo(tester, _m1);
    await tester.tap(find.text('Modo repaso'));
    await _asentar(tester);

    expect(find.byType(TarjetaRepaso), findsNWidgets(3));
    expect(find.text('Ya lo sé'), findsNothing);
    expect(find.textContaining('se guarda en la cuenta de cada estudiante'), findsOneWidget);
  });

  for (final (ancho, columnas) in [(360.0, 1), (800.0, 2), (1400.0, 3)]) {
    testWidgets('a ${ancho.toInt()} px las tarjetas van en $columnas columna(s)',
        (tester) async {
      await _abrir(tester, ancho: ancho);
      await _abrirGlosarioDelModulo(tester, _m1);

      final xs = tester
          .widgetList(find.byType(TarjetaTermino))
          .map((w) => tester.getTopLeft(find.byWidget(w)).dx.round())
          .toSet();
      expect(xs.length, columnas);
      expect(tester.takeException(), isNull);
    });
  }
}
