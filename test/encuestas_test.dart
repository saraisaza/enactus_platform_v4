// Encuestas de verdad, del lado de la app.
//
// Antes una encuesta eran preguntas abiertas: el editor no dejaba elegir otro
// tipo y el estudiante escribía en cuadros de texto que se mandaban como una
// ENTREGA, que caía en la bandeja de calificar. Ahora:
//
// - El editor ofrece elegir una opción, calificar de 1 a 5 y comentario
//   libre, sin respuesta correcta.
// - El estudiante responde con opciones y números; el comentario es opcional;
//   lo que manda va a `/survey-response`, no a `/submissions`.
// - Quien diseña el curso ve los resultados juntos y sin nombres.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/l10n/textos.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_service.dart';
import 'package:enactus_platform/views/lxd/lesson_editor.dart';
import 'package:enactus_platform/views/lxd/resultados_encuesta.dart';
import 'package:enactus_platform/views/student/course_detail_view.dart';

import 'helpers/fake_api.dart';
import 'helpers/portal_harness.dart' show conSesionGuardada;

// UUID de verdad: el contrato cliente->servidor reenvía los cuerpos que se
// mandan acá al endpoint real.
const _curso = 'dddddddd-0000-4000-8000-000000000001';
const _modulo = 'dddddddd-0000-4000-8000-000000000002';
const _encuesta = 'dddddddd-0000-4000-8000-000000000003';
const _calificar = 'dddddddd-0000-4000-8000-000000000011';
const _elegir = 'dddddddd-0000-4000-8000-000000000012';
const _comentar = 'dddddddd-0000-4000-8000-000000000013';

Future<void> _asentar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('el editor', () {
    Future<FakeApi> abrir(WidgetTester tester) async {
      useFakeTokenStorage();
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1400, 1400);
      addTearDown(tester.view.reset);

      final fake = FakeApi(
        routes: {
          'POST /modules/$_modulo/lessons': {
            'id': _encuesta,
            'title': 'Opinión del curso',
            'type': 'survey',
          },
          'PUT /lessons/$_encuesta/quiz': {'questions': <Object>[]},
        },
        // Recargar el curso después de guardar no es lo que se mide acá.
        fallback: (_) => const <String, Object?>{},
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
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLessonEditor(context,
                    courseId: _curso, moduleId: _modulo),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return fake;
    }

    Future<void> elegirTipo(WidgetTester tester, String tipo) async {
      await tester.tap(find.byKey(const ValueKey('tipo-de-pregunta-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tipo).last);
      await tester.pumpAndSettle();
    }

    testWidgets('una pregunta nueva es de elegir, con dos opciones y SIN '
        'marcar una correcta', (tester) async {
      await abrir(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, tr.leccionTipoEncuesta));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, tr.leccionPregunta));
      await tester.pumpAndSettle();

      expect(find.text(tr.encuestaTipoElegir), findsOneWidget);
      expect(find.widgetWithText(TextFormField, tr.leccionOpcionNumero(1)),
          findsOneWidget);
      expect(find.widgetWithText(TextFormField, tr.leccionOpcionNumero(2)),
          findsOneWidget);
      expect(find.byType(Radio<int>), findsNothing,
          reason: 'en una encuesta ninguna opción es la correcta');
      expect(find.text(tr.encuestaOpcionesAyuda), findsOneWidget);

      // El selector ofrece solo los tres tipos de encuesta.
      await tester.tap(find.byKey(const ValueKey('tipo-de-pregunta-0')));
      await tester.pumpAndSettle();
      expect(find.text(tr.encuestaTipoCalificar), findsWidgets);
      expect(find.text(tr.encuestaTipoComentario), findsWidgets);
      expect(find.text(tr.quizTipoVerdaderoFalso), findsNothing);
      expect(find.text(tr.quizTipoOrdenar), findsNothing);
    });

    testWidgets('calificar de 1 a 5 se guarda con sus etiquetas', (tester) async {
      final fake = await abrir(tester);
      await tester.enterText(
          find.widgetWithText(TextField, tr.comunTitulo).first, 'Opinión del curso');
      await tester.tap(find.widgetWithText(ChoiceChip, tr.leccionTipoEncuesta));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, tr.leccionPregunta));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextFormField, tr.leccionEnunciado),
          '¿Qué tan útil le pareció?');

      await elegirTipo(tester, tr.encuestaTipoCalificar);
      expect(find.widgetWithText(TextFormField, tr.leccionOpcionNumero(1)),
          findsNothing,
          reason: 'calificar no tiene opciones: tiene los números del 1 al 5');
      await tester.enterText(
          find.widgetWithText(TextFormField, tr.encuestaEtiqueta1), 'Nada útil');
      await tester.enterText(
          find.widgetWithText(TextFormField, tr.encuestaEtiqueta5), 'Muy útil');

      await tester.tap(find.widgetWithText(ElevatedButton, tr.comunGuardar));
      await _asentar(tester);

      final i = fake.requested.indexOf('PUT /lessons/$_encuesta/quiz');
      expect(i, isNot(-1), reason: 'pidió: ${fake.requested}');
      final preguntas = fake.cuerpos[i]['questions'] as List;
      expect(preguntas, hasLength(1));
      expect(preguntas.first, {
        'kind': 'scale',
        'question': '¿Qué tan útil le pareció?',
        'options': ['Nada útil', 'Muy útil'],
        'answerIndex': null,
        'answerText': null,
      });
    });

    testWidgets('pasar un quiz a encuesta deja sus preguntas en tipos de '
        'encuesta, sin clave', (tester) async {
      await abrir(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, tr.leccionTipoQuiz));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, tr.leccionPregunta));
      await tester.pumpAndSettle();
      await elegirTipo(tester, tr.quizTipoVerdaderoFalso);
      await tester.tap(find.widgetWithText(ChoiceChip, tr.quizVerdadero));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, tr.leccionTipoEncuesta));
      await tester.pumpAndSettle();
      expect(find.text(tr.encuestaTipoElegir), findsOneWidget,
          reason: 'verdadero/falso no es una pregunta de encuesta');
      expect(find.widgetWithText(ChoiceChip, tr.quizVerdadero), findsNothing);
    });
  });

  group('el estudiante', () {
    const encuestaJson = {
      'id': _encuesta,
      'title': 'Opinión del curso',
      'type': 'survey',
      'quiz': [
        {
          'id': _calificar,
          'kind': 'scale',
          'question': '¿Qué tan útil le pareció?',
          'options': ['Nada útil', 'Muy útil'],
        },
        {
          'id': _elegir,
          'kind': 'multiple',
          'question': '¿Qué formato prefiere?',
          'options': ['Video', 'Lectura'],
        },
        {
          'id': _comentar,
          'kind': 'short',
          'question': '¿Qué mejoraría?',
          'options': <String>[],
        },
      ],
    };

    Future<FakeApi> abrir(WidgetTester tester,
        {Map<String, Object>? yaRespondio}) async {
      conSesionGuardada();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 1800);
      addTearDown(tester.view.reset);

      final fake = FakeApi(routes: {
        '/auth/me': {
          'id': 'student1',
          'name': 'Ana Estudiante',
          'email': 'ana@test.co',
          'role': 'student',
          'studentType': 'enactus',
        },
        '/courses/$_curso': {
          'id': _curso,
          'name': 'Seguridad eléctrica',
          'level': 'basic',
          'status': 'published',
          'language': 'es',
          'tags': <String>[],
          'objectives': <Object>[],
          'modules': [
            {
              'id': _modulo,
              'title': 'Cierre',
              'lessons': [encuestaJson],
            },
          ],
        },
        '/courses/$_curso/glossary': {'terms': <Object>[], 'reviews': {}},
        '/students/student1/course-progress/$_curso': {
          'courseId': _curso,
          'totalLessons': 1,
          'completedLessons': 0,
          'ratio': 0,
          'completedLessonIds': <String>[],
        },
        '/submissions': {
          'data': <Object>[],
          'page': 1,
          'pageSize': 100,
          'total': 0,
        },
        '/notifications': {
          'data': <Object>[],
          'page': 1,
          'pageSize': 100,
          'total': 0,
        },
        // Si era la última lección, el certificado sale solo: se vuelve a pedir.
        '/certificates': {
          'data': <Object>[],
          'page': 1,
          'pageSize': 100,
          'total': 0,
        },
        'GET /lessons/$_encuesta/survey-response': {'answers': yaRespondio},
        'POST /lessons/$_encuesta/survey-response': {
          'answers': {_calificar: 4, _elegir: 1},
        },
      });
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
        child: const MaterialApp(
          home: Scaffold(body: CourseDetailView(courseId: _curso)),
        ),
      ));
      await _asentar(tester);
      await tester.tap(find.text('Opinión del curso').first);
      await _asentar(tester);
      return fake;
    }

    VoidCallback? enviar(WidgetTester tester) => tester
        .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, tr.comunEnviar))
        .onPressed;

    testWidgets('elige, califica y comenta; se manda como respuesta de '
        'encuesta, no como entrega', (tester) async {
      final fake = await abrir(tester);

      // Sin elegir ni calificar todavía no se puede enviar, y dice por qué.
      expect(enviar(tester), isNull);
      expect(find.text(tr.encuestaFaltanRespuestas), findsOneWidget);
      // Las etiquetas quedan bajo los extremos.
      expect(find.text('1 = Nada útil'), findsOneWidget);
      expect(find.text('5 = Muy útil'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('calificar-$_calificar-4')));
      await tester.pump();
      expect(enviar(tester), isNull, reason: 'falta elegir el formato');
      await tester.tap(find.text('Lectura'));
      await tester.pump();
      // El comentario es opcional: ya se puede enviar.
      expect(enviar(tester), isNotNull);
      await tester.enterText(
          find.widgetWithText(TextFormField, tr.encuestaComentarioOpcional),
          'Más ejemplos');
      await tester.pump();

      final antes = fake.requested
          .where((r) => r.endsWith('/course-progress/$_curso'))
          .length;
      await tester.tap(find.widgetWithText(ElevatedButton, tr.comunEnviar));
      await _asentar(tester);

      final i = fake.requested.indexOf('POST /lessons/$_encuesta/survey-response');
      expect(i, isNot(-1), reason: 'pidió: ${fake.requested}');
      expect(fake.cuerpos[i], {
        'answers': {_calificar: 4, _elegir: 1, _comentar: 'Más ejemplos'},
      });
      expect(fake.requested, isNot(contains('POST /submissions')),
          reason: 'una encuesta no es una entrega: nadie la califica');
      expect(
          fake.requested
              .where((r) => r.endsWith('/course-progress/$_curso'))
              .length,
          greaterThan(antes),
          reason: 'responderla completa la lección: el avance se vuelve a pedir');
      expect(find.text(tr.encuestaGracias), findsOneWidget);
      // El aviso de «gracias» se va solo.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('si ya la respondió, se abre con sus respuestas', (tester) async {
      await abrir(tester, yaRespondio: {
        _calificar: 5,
        _elegir: 0,
        _comentar: 'Todo claro',
      });
      expect(find.text(tr.encuestaYaRespondio), findsOneWidget);
      expect(find.text('Todo claro'), findsOneWidget);
      expect(
          tester
              .widget<Semantics>(find.ancestor(
                  of: find.byKey(const ValueKey('calificar-$_calificar-5')),
                  matching: find.byType(Semantics)).first)
              .properties
              .selected,
          isTrue);
      expect(enviar(tester), isNotNull);
    });
  });

  testWidgets('los resultados: opciones, promedio y comentarios, sin nombres',
      (tester) async {
    useFakeTokenStorage();
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 1600);
    addTearDown(tester.view.reset);
    final api = FakeApi(routes: {
      '/lessons/$_encuesta/survey-results': {
        'responses': 2,
        'questions': [
          {
            'id': _calificar,
            'kind': 'scale',
            'question': '¿Qué tan útil le pareció?',
            'options': ['Nada útil', 'Muy útil'],
            'counts': [0, 1, 0, 0, 1],
            'average': 3.5,
          },
          {
            'id': _elegir,
            'kind': 'multiple',
            'question': '¿Qué formato prefiere?',
            'options': ['Video', 'Lectura'],
            'counts': [2, 0],
          },
          {
            'id': _comentar,
            'kind': 'short',
            'question': '¿Qué mejoraría?',
            'options': <String>[],
            'comments': ['Más ejemplos', 'Que sea más corto'],
          },
        ],
      },
    }).build();
    final data = DataProvider(api);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: data,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultadosDeEncuestaView(lessonId: _encuesta),
          ),
        ),
      ),
    ));
    await _asentar(tester);

    expect(find.text(tr.encuestaRespondieron(2)), findsOneWidget);
    expect(find.text(tr.encuestaAnonima), findsOneWidget);
    expect(find.textContaining('3,5'), findsOneWidget);
    expect(find.text('1 · Nada útil'), findsOneWidget);
    expect(find.text('5 · Muy útil'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('2 · 100 %'), findsOneWidget);
    expect(find.text('Más ejemplos'), findsOneWidget);
    expect(find.text('Que sea más corto'), findsOneWidget);
  });
}
