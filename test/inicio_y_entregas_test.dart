// El inicio dice qué hay esta semana, y el calendario recuerda las entregas
// (pedido de Sara, 2026-11-10).
//
// Debajo del saludo decía «Aún no tiene proyecto asignado», que a un Open
// Learning o al empleado de una empresa no le decía nada. El calendario solo
// mostraba lo que alguien agendaba: las fechas límite de las actividades y de
// las fases existían, pero no salían en ningún calendario. Y todos los
// eventos de laboratorio iban del mismo verde, fueran del laboratorio que
// fueran.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:enactus_platform/l10n/textos.dart';
import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/utils/app_theme.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/views/student/student_dashboard_view.dart';
import 'package:enactus_platform/widgets/calendar_view.dart';

import 'helpers/fake_api.dart';
import 'helpers/portal_harness.dart';

const _labIa = 'b0b722b7-5dc6-58de-b9ad-77b0415e8d85';
const _cursoIa = 'f5883732-7819-58a7-bc9a-e67556e5dc2d';

String _dia(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, Object?> _entregaDeCurso(DateTime cuando,
        {String id = 'a1', String titulo = 'Proyecto: IA para su comunidad',
        bool hecha = false}) =>
    {
      'kind': 'course_activity', 'id': id, 'title': titulo,
      'dueDate': _dia(cuando), 'done': hecha,
      'courseId': _cursoIa, 'courseName': 'Introducción a la Inteligencia Artificial',
      'laboratoryId': _labIa, 'laboratoryName': 'Laboratorio IA y Tecnología',
      'phaseOrder': null,
    };

Map<String, Object?> _fase(DateTime cuando, {bool hecha = false}) => {
      'kind': 'lab_phase', 'id': 'f1', 'title': 'Fase 1: Fundamentos',
      'dueDate': _dia(cuando), 'done': hecha,
      'courseId': null, 'courseName': null,
      'laboratoryId': _labIa, 'laboratoryName': 'Laboratorio IA y Tecnología',
      'phaseOrder': 1,
    };

const _sinCursos = {
  'data': <Object>[], 'page': 1, 'pageSize': 100, 'total': 0, 'totalPages': 0,
};

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
    cargarFixtures();
  });
  tearDown(Idioma.instancia.restablecer);

  final hoy = DateTime.now();
  final lunes = DateTime(hoy.year, hoy.month, hoy.day)
      .subtract(Duration(days: hoy.weekday - 1));
  final domingo = lunes.add(const Duration(days: 6));

  group('la frase de la semana', () {
    test('sin entregas, lo dice con las palabras que pidió Sara', () {
      expect(
          resumenDeLaSemana(
              cursosActivos: 3, entregasDeCursos: 0,
              laboratorios: 0, entregasDeLaboratorios: 0),
          'No tiene entregas de cursos para esta semana.');
    });

    test('con cursos y entregas, cuenta los dos', () {
      expect(
          resumenDeLaSemana(
              cursosActivos: 3, entregasDeCursos: 1,
              laboratorios: 0, entregasDeLaboratorios: 0),
          'Tiene 3 cursos para esta semana y 1 entregable.');
      expect(
          resumenDeLaSemana(
              cursosActivos: 1, entregasDeCursos: 2,
              laboratorios: 0, entregasDeLaboratorios: 0),
          'Tiene 1 curso para esta semana y 2 entregables.');
    });

    test('con laboratorios, los nombra con sus entregas', () {
      expect(
          resumenDeLaSemana(
              cursosActivos: 2, entregasDeCursos: 1,
              laboratorios: 1, entregasDeLaboratorios: 0),
          'Tiene 2 cursos para esta semana y 1 entregable. '
          'Tiene 1 laboratorio asignado, sin entregas esta semana.');
      expect(
          resumenDeLaSemana(
              cursosActivos: 2, entregasDeCursos: 0,
              laboratorios: 2, entregasDeLaboratorios: 3),
          'No tiene entregas de cursos para esta semana. '
          'Tiene 2 laboratorios asignados y 3 entregas de laboratorio esta semana.');
    });

    test('en una empresa son capacitaciones, y no hay laboratorios', () {
      Idioma.instancia.usarVocabularioDeEmpresa(true);
      expect(
          resumenDeLaSemana(
              cursosActivos: 2, entregasDeCursos: 1,
              laboratorios: 0, entregasDeLaboratorios: 0),
          'Tiene 2 capacitaciones para esta semana y 1 entregable.');
      expect(
          resumenDeLaSemana(
              cursosActivos: 2, entregasDeCursos: 0,
              laboratorios: 0, entregasDeLaboratorios: 0),
          'No tiene entregas de capacitaciones para esta semana.');
    });

    test('en inglés también', () async {
      await Idioma.instancia.cambiar('en');
      expect(
          resumenDeLaSemana(
              cursosActivos: 2, entregasDeCursos: 1,
              laboratorios: 1, entregasDeLaboratorios: 1),
          'You have 2 courses for this week and 1 deliverable. '
          'You have 1 laboratory assigned and 1 laboratory deliverable due this week.');
    });

    test('solo cuenta lo que vence esta semana y sigue sin hacer', () {
      Entrega e(DateTime cuando, {bool hecha = false}) => Entrega(
          tipo: TipoDeEntrega.actividadDeCurso, id: '$cuando$hecha',
          title: 't', dueDate: cuando, done: hecha);
      final semana = entregasDeLaSemana([
        e(lunes),
        e(domingo),
        e(lunes.subtract(const Duration(days: 1))), // la semana pasada
        e(domingo.add(const Duration(days: 1))), // la que viene
        e(lunes.add(const Duration(days: 2)), hecha: true), // ya entregada
      ], lunes, domingo);
      expect(semana.map((x) => x.dueDate), [lunes, domingo]);
    });
  });

  test('la fecha de una entrega es un día de acá, sin correrse por la zona', () {
    final entrega = Entrega.fromJson(_entregaDeCurso(DateTime(2026, 11, 12)))!;
    expect(entrega.dueDate, DateTime(2026, 11, 12));
    expect(entrega.tipo, TipoDeEntrega.actividadDeCurso);
    expect(entrega.esDeLaboratorio, isFalse,
        reason: 'un curso de laboratorio sigue siendo un curso');
    expect(Entrega.fromJson({..._fase(DateTime(2026, 11, 12))})!.esDeLaboratorio, isTrue);
    expect(Entrega.fromJson({'id': 'x', 'dueDate': 'no es una fecha'}), isNull);
  });

  group('el color de cada evento', () {
    final cuando = DateTime(2026, 11, 12, 10);

    test('lo que es de un laboratorio lleva el color de ese laboratorio', () {
      final delLab = CalendarEvent(
          id: '1', startsAt: cuando, type: CalendarEventType.laboratorio,
          laboratoryId: _labIa, laboratoryName: 'Laboratorio IA y Tecnología');
      final mentoria = CalendarEvent(
          id: '2', startsAt: cuando, type: CalendarEventType.mentoria, laboratoryId: _labIa);
      // El evento es de un curso; el laboratorio le llega por el curso.
      final delCurso = CalendarEvent(
          id: '3', startsAt: cuando, type: CalendarEventType.openLearningSync,
          courseId: _cursoIa, courseLaboratoryId: _labIa);
      for (final e in [delLab, mentoria, delCurso]) {
        expect(colorDeEvento(e), labColorFor(_labIa), reason: e.id);
      }
    });

    test('lo que no es de ningún laboratorio sigue con el color de su tipo', () {
      final asamblea = CalendarEvent(
          id: '4', startsAt: cuando, type: CalendarEventType.organizacion);
      final capacitacion = CalendarEvent(
          id: '5', startsAt: cuando, type: CalendarEventType.openLearningSync, courseId: 'c');
      expect(colorDeEvento(asamblea), calendarEventColor(CalendarEventType.organizacion));
      expect(colorDeEvento(capacitacion),
          calendarEventColor(CalendarEventType.openLearningSync));
    });

    test('la leyenda nombra cada laboratorio con su color', () {
      final leyenda = leyendaDelCalendario([
        CalendarEvent(
            id: '1', startsAt: cuando, type: CalendarEventType.laboratorio,
            laboratoryId: _labIa, laboratoryName: 'Laboratorio IA y Tecnología'),
        CalendarEvent(id: '4', startsAt: cuando, type: CalendarEventType.organizacion),
      ]);
      expect(leyenda.map((l) => l.texto),
          ['Laboratorio IA y Tecnología', tr.eventoOrganizacion]);
      expect(leyenda.first.color, labColorFor(_labIa));
      // «Laboratorio» a secas ya no aparece: cada uno va con su nombre.
      expect(leyenda.map((l) => l.texto), isNot(contains(tr.eventoLaboratorio)));
    });
  });

  group('el inicio', () {
    testWidgets('dice lo de la semana donde antes decía «sin proyecto»',
        (tester) async {
      conSesionGuardada();
      fijarTamano(tester, const Size(1400, 1000));
      await montar(tester, appDe(Roles.student, conApi: (api) {
        api.routes['/calendar-events/entregas'] = {
          'data': [
            _entregaDeCurso(lunes.add(const Duration(days: 6))),
            _entregaDeCurso(lunes.add(const Duration(days: 30)), id: 'a2', titulo: 'Otra'),
          ],
        };
      }));
      // El estudiante de los fixtures tiene 2 cursos —uno ya completo, que no
      // cuenta como algo por hacer esta semana— y 2 laboratorios.
      expect(
          find.text('Tiene 1 curso para esta semana y 1 entregable. '
              'Tiene 2 laboratorios asignados, sin entregas esta semana.'),
          findsOneWidget);
      expect(find.textContaining('proyecto asignado'), findsNothing);
      // Y en Pendientes se ve cuál es la entrega.
      expect(find.text(tr.dashboardEntregaPendiente('Proyecto: IA para su comunidad')),
          findsOneWidget);
      expect(find.text(tr.dashboardEntregaPendiente('Otra')), findsNothing,
          reason: 'vence en un mes: no es de esta semana');
    });

    testWidgets('si las entregas no llegan, no afirma que no hay', (tester) async {
      conSesionGuardada();
      fijarTamano(tester, const Size(1400, 1000));
      await montar(tester, appDe(Roles.student, conApi: (api) {
        api.statuses['/calendar-events/entregas'] = 500;
      }));
      expect(find.textContaining('No tiene entregas'), findsNothing);
      // El resto del inicio sigue ahí.
      expect(find.text(tr.dashboardPendientes.toUpperCase()), findsOneWidget);
    });

    testWidgets('sin cursos, el acceso rápido lleva a la fase de su laboratorio',
        (tester) async {
      conSesionGuardada();
      fijarTamano(tester, const Size(1400, 1000));
      await montar(tester, appDe(Roles.student, conApi: (api) {
        api.routes['/courses'] = _sinCursos;
      }));
      // Antes: «Todo por empezar», y nada que tocar.
      expect(find.text(tr.dashboardTodoPorEmpezar.toUpperCase()), findsNothing);
      expect(find.byKey(const ValueKey('acceso-laboratorio-$_labIa')), findsOneWidget);
      expect(find.text(tr.dashboardFaseEnCurso), findsNWidgets(2),
          reason: 'una tarjeta por laboratorio asignado');
      expect(find.text('FASE 1: FUNDAMENTOS'), findsOneWidget);
      expect(find.text('Laboratorio IA y Tecnología'), findsWidgets);

      await tester.tap(find.text(tr.dashboardIrALaFase).first);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      // Quedó en el detalle del laboratorio, con sus fases.
      expect(find.text(tr.dashboardFaseEnCurso), findsNothing);
      expect(find.textContaining('Laboratorio IA y Tecnología'.toUpperCase()),
          findsWidgets);
    });

    testWidgets('con un curso a medias, el acceso rápido es el curso',
        (tester) async {
      conSesionGuardada();
      fijarTamano(tester, const Size(1400, 1000));
      await montar(tester, appDe(Roles.student));
      expect(find.text(tr.dashboardContinueDonde), findsOneWidget);
      expect(find.text(tr.dashboardFaseEnCurso), findsNothing);
    });

    testWidgets('un Open Learning sin cursos no pide laboratorios que no tiene',
        (tester) async {
      conSesionGuardada();
      fijarTamano(tester, const Size(1400, 1000));
      late FakeApi falsa;
      await montar(
          tester,
          appDe(Roles.student,
              cambios: {'studentType': 'open_learning', 'team': null},
              conApi: (api) {
            falsa = api;
            api.routes['/courses'] = _sinCursos;
            api.routes['/calendar-events/entregas'] = {'data': <Object>[]};
          }));
      expect(find.text(tr.dashboardTodoPorEmpezar.toUpperCase()), findsOneWidget);
      expect(find.text('No tiene entregas de cursos para esta semana.'), findsOneWidget);
      expect(falsa.requested.where((r) => r.contains('ruta-progress')), isEmpty);
    });
  });

  group('el calendario del estudiante', () {
    Future<void> abrirCalendario(WidgetTester tester,
        {required List<Map<String, Object?>> entregas,
        List<Map<String, Object?>> eventos = const []}) async {
      conSesionGuardada();
      fijarTamano(tester, const Size(1400, 1100));
      await montar(tester, appDe(Roles.student, conApi: (api) {
        api.routes['/calendar-events/entregas'] = {'data': entregas};
        api.routes['/calendar-events'] = {
          'data': eventos, 'page': 1, 'pageSize': 100, 'total': eventos.length,
        };
      }));
      await tester.tap(find.text(tr.tabCalendario).first, warnIfMissed: false);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    // Un día de este mes que no sea hoy, para no depender de la fecha.
    final otroDia = DateTime(hoy.year, hoy.month, hoy.day == 15 ? 16 : 15);

    testWidgets('dice que ahí aparecerán los eventos y las entregas',
        (tester) async {
      await abrirCalendario(tester, entregas: [_entregaDeCurso(otroDia)]);
      expect(find.text('Los próximos eventos y entregas aparecerán en el calendario.'),
          findsOneWidget);
    });

    testWidgets('una entrega sale en su día, aunque nadie haya agendado nada',
        (tester) async {
      await abrirCalendario(tester, entregas: [_entregaDeCurso(otroDia)]);
      // Sin eventos, antes esto era «Agenda despejada».
      expect(find.text(tr.calendarioAgendaDespejada), findsNothing);
      final marca = find.byKey(const ValueKey('entrega-a1'));
      expect(marca, findsOneWidget);
      // Con el color de su laboratorio.
      final caja = tester.widget<Container>(marca).decoration! as BoxDecoration;
      expect((caja.border! as Border).top.color, labColorFor(_labIa));
      expect(find.text(tr.calendarioEntregas), findsOneWidget, reason: 'la leyenda');
      expect(find.text('Laboratorio IA y Tecnología'), findsWidgets);

      await tester.tap(marca);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
          find.text('${tr.calendarioEntregaDeCurso} · '
              'Introducción a la Inteligencia Artificial'),
          findsWidgets);
      expect(find.text(tr.calificacionPendiente), findsOneWidget);
      expect(find.text(tr.calendarioIrAlCurso), findsOneWidget);
    });

    testWidgets('lo que viene: la entrega pendiente sí, la ya entregada no',
        (tester) async {
      final manana = DateTime(hoy.year, hoy.month, hoy.day).add(const Duration(days: 1));
      await abrirCalendario(tester, entregas: [
        _entregaDeCurso(manana, titulo: 'Pendiente de mañana'),
        _entregaDeCurso(manana, id: 'a2', titulo: 'Ya entregada', hecha: true),
        _fase(manana.add(const Duration(days: 1))),
      ]);
      expect(find.text(tr.calendarioProximos.toUpperCase()), findsOneWidget);
      expect(tr.calendarioProximos, 'Próximos eventos y entregas');
      final proximos = find.ancestor(
          of: find.text(tr.calendarioProximos.toUpperCase()),
          matching: find.byType(Column));
      Finder enProximos(String texto) =>
          find.descendant(of: proximos.first, matching: find.textContaining(texto));
      expect(enProximos('Pendiente de mañana'), findsOneWidget);
      expect(enProximos('Ya entregada'), findsNothing);
      expect(enProximos(tr.calendarioFechaDeFase), findsOneWidget);
    });

    testWidgets('un evento de laboratorio va del color de su laboratorio',
        (tester) async {
      await abrirCalendario(tester, entregas: const [], eventos: [
        {
          'id': 'e1', 'title': 'Jornada del laboratorio', 'type': 'laboratorio',
          'startsAt': DateTime(otroDia.year, otroDia.month, otroDia.day, 10)
              .toUtc()
              .toIso8601String(),
          'laboratoryId': _labIa, 'laboratoryName': 'Laboratorio IA y Tecnología',
        },
      ]);
      final chip = find.ancestor(
          of: find.text('Jornada del laboratorio').first,
          matching: find.byType(Container));
      final colores = tester
          .widgetList<Container>(chip)
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color);
      expect(colores, contains(labColorFor(_labIa)));
      expect(colores, isNot(contains(calendarEventColor(CalendarEventType.laboratorio))));
      // La leyenda dice de qué laboratorio es, no «Laboratorio» a secas.
      expect(find.text('Laboratorio IA y Tecnología'), findsWidgets);
    });
  });

  test('Mis Cursos y el calendario dicen lo que pidió Sara', () {
    expect(tr.cursosSubtitulo,
        'Cursos especializados para cada línea de trabajo que puede tener una empresa.');
    expect(tr.calendarioSubtitulo,
        'Los próximos eventos y entregas aparecerán en el calendario.');
    // En una empresa el calendario dice lo mismo: ya no tiene texto aparte.
    Idioma.instancia.usarVocabularioDeEmpresa(true);
    expect(tr.calendarioSubtitulo,
        'Los próximos eventos y entregas aparecerán en el calendario.');
  });
}
