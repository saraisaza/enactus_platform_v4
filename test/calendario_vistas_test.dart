// El calendario por mes y por semana, centrado, y para quién es cada evento
// (pedido de Sara, 2026-10-17).
//
// Antes cada día medía como mucho 92 px: en una pantalla ancha el mes ocupaba
// 672 px y quedaba pegado a la izquierda. Los días de la semana estaban
// escritos en español aunque la plataforma estuviera en inglés. Y el LXD solo
// agendaba sesiones de cursos de Open Learning.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:enactus_platform/l10n/textos.dart';
import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/utils/formatos.dart';
import 'package:enactus_platform/widgets/calendar_view.dart';

import 'helpers/fake_api.dart';
import 'helpers/portal_harness.dart';

const _curso = 'cccccccc-0000-4000-8000-0000000000a1';
const _lab = 'cccccccc-0000-4000-8000-0000000000b1';
const _andino = 'cccccccc-0000-4000-8000-0000000000c1';

CalendarEvent _evento(String titulo, DateTime cuando,
        [CalendarEventType tipo = CalendarEventType.openLearningSync]) =>
    CalendarEvent(id: titulo, title: titulo, startsAt: cuando, type: tipo);

Future<void> _mostrar(WidgetTester tester, Size tamano, List<CalendarEvent> eventos) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tamano;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: CalendarView(events: eventos)),
    ),
  ));
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
    cargarFixtures();
  });
  tearDown(Idioma.instancia.restablecer);

  final hoy = DateTime.now();
  final manana = DateTime(hoy.year, hoy.month, hoy.day, 10).add(const Duration(days: 1));

  testWidgets('en una pantalla ancha va centrado y los días llenan el ancho',
      (tester) async {
    await _mostrar(tester, const Size(1800, 1400), [_evento('Sesión', manana)]);
    final caja = tester.getRect(find.byKey(const ValueKey('calendario')));
    expect(caja.width, 1100);
    expect(caja.left, closeTo((1800 - 1100) / 2, 1));
    // Un día ocupa una séptima parte (menos la separación), no 92 px.
    final dia = tester.getSize(find.byKey(ValueKey(
        'dia-${hoy.year}-${hoy.month}-${hoy.day}')));
    expect(dia.width, greaterThan(140));
  });

  testWidgets('el mes muestra el título del evento; la semana, su hora',
      (tester) async {
    await _mostrar(tester, const Size(1400, 1400), [_evento('Sesión de ventas', manana)]);
    expect(find.text('Sesión de ventas'), findsWidgets);

    await tester.tap(find.text(tr.calendarioVistaSemana));
    await tester.pump();
    final titulo = tester.widget<Text>(find.byKey(const ValueKey('calendario-titulo'))).data!;
    expect(titulo, contains('–'), reason: 'la semana se titula «13 – 19 oct»');
    // La semana de mañana puede ser la siguiente: se busca en las dos.
    if (find.text(hora(manana)).evaluate().isEmpty) {
      await tester.tap(find.byTooltip(tr.calendarioSemanaSiguiente));
      await tester.pump();
    }
    expect(find.text(hora(manana)), findsWidgets);
  });

  testWidgets('en el teléfono nada se sale, ni en el mes ni en la semana',
      (tester) async {
    final errores = <FlutterErrorDetails>[];
    final anterior = FlutterError.onError;
    FlutterError.onError = errores.add;
    addTearDown(() => FlutterError.onError = anterior);

    await _mostrar(tester, const Size(360, 1800), [_evento('Sesión', manana)]);
    await tester.tap(find.text(tr.calendarioVistaSemana));
    await tester.pump();
    FlutterError.onError = anterior;
    expect(errores, isEmpty, reason: errores.map((e) => e.exceptionAsString()).join('\n'));
    // En el teléfono la semana es una lista: siete días, uno debajo del otro.
    expect(find.text(tr.calendarioSinEventos), findsWidgets);
  });

  testWidgets('los días de la semana van en el idioma de la plataforma',
      (tester) async {
    await tester.runAsync(() => Idioma.instancia.cambiar('en'));
    await _mostrar(tester, const Size(1400, 1400), const []);
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('L'), findsNothing);
  });

  testWidgets('la leyenda muestra solo los tipos que hay', (tester) async {
    await _mostrar(tester, const Size(1400, 1400), [
      _evento('Asamblea', manana, CalendarEventType.organizacion),
    ]);
    expect(find.text(tr.eventoOrganizacion), findsWidgets);
    expect(find.text(tr.eventoMentoria), findsNothing);
  });

  testWidgets('el estudiante que llega a un mes vacío puede volver',
      (tester) async {
    // «Agenda despejada» reemplazaba todo el calendario en cuanto el mes a la
    // vista quedaba vacío, flechas incluidas: quien retrocedía a un mes sin
    // eventos ya no tenía cómo regresar.
    conSesionGuardada();
    fijarTamano(tester, const Size(1400, 1000));
    final atras = DateTime(hoy.year, hoy.month, 10).subtract(const Duration(days: 40));
    await montar(tester, appDe(Roles.student, conApi: (api) {
      api.routes['/calendar-events'] = {
        'data': [
          {'id': 'e', 'title': 'Jornada', 'type': 'laboratorio',
           'startsAt': atras.toUtc().toIso8601String()},
        ],
        'page': 1, 'pageSize': 100, 'total': 1,
      };
    }));
    await tester.tap(find.text(tr.tabCalendario).first, warnIfMissed: false);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip(tr.calendarioMesAnterior));
      await tester.pump();
      expect(find.byTooltip(tr.calendarioMesSiguiente), findsOneWidget);
    }
    expect(find.text(tr.calendarioAgendaDespejada), findsNothing);
  });

  group('para quién es', () {
    Future<FakeApi> abrir(WidgetTester tester,
        {List<(String, String)> organizaciones = const [(_andino, 'Banco Andino')]}) async {
      useFakeTokenStorage();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 1400);
      addTearDown(tester.view.reset);
      final fake = FakeApi(routes: {
        'POST /calendar-events': {'id': 'e1'},
        '/calendar-events': {'data': <Object>[], 'page': 1, 'pageSize': 100, 'total': 0},
      });
      final data = DataProvider(fake.build());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCalendarEventDialog(
                context,
                initialDay: DateTime(2026, 11, 3),
                allowedTypes: const [
                  CalendarEventType.openLearningSync,
                  CalendarEventType.laboratorio,
                  CalendarEventType.organizacion,
                ],
                courses: const [Course(id: _curso, name: 'Riesgo bancario')],
                labs: const [(_lab, 'Laboratorio IA')],
                organizaciones: organizaciones,
                defaultMeetLink: '',
                onSave: (eventos, id) async {
                  for (final e in eventos) {
                    await data.saveCalendarEvent(e, id: id);
                  }
                },
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return fake;
    }

    Future<Map<String, dynamic>> guardar(WidgetTester tester, FakeApi fake) async {
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, tr.comunGuardar));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      final i = fake.requested.indexOf('POST /calendar-events');
      expect(i, isNot(-1), reason: 'pidió: ${fake.requested}');
      return fake.cuerpos[i];
    }

    testWidgets('el LXD elige un curso, un laboratorio o toda la organización',
        (tester) async {
      await abrir(tester);
      expect(find.text(tr.calendarioParaQuien), findsOneWidget);
      expect(find.byKey(const ValueKey('destino-open_learning_sync')), findsOneWidget);
      expect(find.byKey(const ValueKey('destino-laboratorio')), findsOneWidget);
      expect(find.byKey(const ValueKey('destino-organizacion')), findsOneWidget);
      // Empieza en el curso: dice quién lo verá.
      expect(find.text(tr.calendarioQuienCurso), findsOneWidget);
    });

    testWidgets('un evento del curso se guarda con su curso, y nada más',
        (tester) async {
      final fake = await abrir(tester);
      await tester.enterText(find.widgetWithText(TextField, tr.comunTitulo), 'Taller');
      final cuerpo = await guardar(tester, fake);
      expect(cuerpo['type'], 'open_learning_sync');
      expect(cuerpo['courseId'], _curso);
      expect(cuerpo['laboratoryId'], isNull);
      expect(cuerpo['clientId'], isNull);
    });

    testWidgets('toda la organización: dice quién lo verá y manda su id',
        (tester) async {
      final fake = await abrir(tester);
      await tester.enterText(find.widgetWithText(TextField, tr.comunTitulo), 'Asamblea');
      await tester.tap(find.byKey(const ValueKey('destino-organizacion')));
      await tester.pump();
      expect(find.text(tr.calendarioQuienOrganizacion('Banco Andino')), findsOneWidget);
      final cuerpo = await guardar(tester, fake);
      expect(cuerpo['type'], 'organizacion');
      expect(cuerpo['clientId'], _andino);
      expect(cuerpo['courseId'], isNull);
    });

    testWidgets('un laboratorio', (tester) async {
      final fake = await abrir(tester);
      await tester.enterText(find.widgetWithText(TextField, tr.comunTitulo), 'Jornada');
      await tester.tap(find.byKey(const ValueKey('destino-laboratorio')));
      await tester.pump();
      final cuerpo = await guardar(tester, fake);
      expect(cuerpo['type'], 'laboratorio');
      expect(cuerpo['laboratoryId'], _lab);
    });

    testWidgets('sin organizaciones para elegir, no deja guardar', (tester) async {
      await abrir(tester, organizaciones: const []);
      await tester.enterText(find.widgetWithText(TextField, tr.comunTitulo), 'Asamblea');
      await tester.tap(find.byKey(const ValueKey('destino-organizacion')));
      await tester.pump();
      expect(find.text(tr.calendarioSinOrganizaciones), findsOneWidget);
      expect(
          tester
              .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, tr.comunGuardar))
              .onPressed,
          isNull);
    });
  });
}
