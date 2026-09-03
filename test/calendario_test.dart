// Guardar un evento de calendario.
//
// Esta pantalla estaba rota de tres formas a la vez, y las tres se tapaban
// entre sí. La de fondo: un evento de Ruta de Impacto —el tipo que Admin trae
// por defecto— mandaba `courseId: ''` y `laboratoryId: ''`, y el servidor los
// valida como uuid opcional, así que respondía 400 «Invalid UUID». La segunda:
// el diálogo no capturaba el error, de modo que la excepción se perdía en el
// `Future` del botón y el botón parecía no hacer nada. La tercera: editar
// llamaba a POST y no a PATCH, así que cuando llegaba a guardar duplicaba.
//
// Las pruebas de backend no podían encontrarlo: pasaban SOLO el campo que su
// tipo de evento usa, nunca la forma real del cuerpo que manda la app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/widgets/calendar_view.dart';

import 'helpers/fake_api.dart';

const _idEvento = 'bbbbbbbb-0000-4000-8000-000000000001';
const _idCurso = 'cccccccc-0000-4000-8000-000000000002';

Map<String, Object?> _eventoDe(String tipo) => {
      'id': _idEvento,
      'title': 'Encuentro',
      'description': '',
      'startsAt': '2026-10-01T15:00:00.000Z',
      'type': tipo,
      'meetLink': '',
      'guests': '',
      'courseId': null,
      'laboratoryId': null,
    };

/// Monta el diálogo del calendario ya abierto.
Future<void> montar(
  WidgetTester tester,
  FakeApi fake, {
  CalendarEvent? existing,
  List<CalendarEventType> tipos = CalendarEventType.values,
  List<Course> cursos = const [],
}) async {
  useFakeTokenStorage();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1400, 1200);
  addTearDown(tester.view.reset);

  final data = DataProvider(fake.build());

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showCalendarEventDialog(
            context,
            existing: existing,
            initialDay: DateTime(2026, 10, 1),
            allowedTypes: tipos,
            courses: cursos,
            labs: const [],
            defaultMeetLink: '',
            onSave: (eventos, idQueSeEdita) async {
              for (final e in eventos) {
                await data.saveCalendarEvent(e, id: idQueSeEdita);
              }
            },
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  ));

  await tester.tap(find.text('abrir'));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> guardar(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
  // 2.4 s en total: al guardar bien aparece el aviso de éxito, que se retira
  // solo a los 1.75 s con un `Future.delayed`. Cortar antes deja ese
  // temporizador vivo y `flutter_test` lo reporta como fallo de la prueba.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  // El diálogo formatea fechas en español; sin esto `DateFormat` lanza al
  // construirlo y el fallo se ve como un error de la prueba, no del código.
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('un evento de Ruta manda los ids en null, no en cadena vacía',
      (tester) async {
    // El fallo de fondo. Con `''` el servidor responde 400 y el evento no se
    // crea nunca — y ese es el tipo que Admin trae seleccionado por defecto.
    final fake = FakeApi(routes: {
      '/calendar-events': _eventoDe('ruta_impacto'),
    });

    await montar(tester, fake, tipos: const [CalendarEventType.rutaImpacto]);
    await tester.enterText(find.byType(TextField).first, 'Encuentro de Ruta');
    await tester.pump();
    await guardar(tester);

    expect(fake.requested, contains('POST /calendar-events'));
    final cuerpo = fake.cuerpos[fake.requested.indexOf('POST /calendar-events')];
    expect(cuerpo['courseId'], isNull);
    expect(cuerpo['laboratoryId'], isNull);
    expect(cuerpo['type'], 'ruta_impacto');
    expect(cuerpo['title'], 'Encuentro de Ruta');
  });

  testWidgets('una sesión Open Learning manda su curso y el laboratorio nulo',
      (tester) async {
    // El otro lado de lo mismo: el campo que SÍ corresponde va con su id, y el
    // que no, en null. Antes iban el id y una cadena vacía, y el 400 llegaba
    // igual por el segundo.
    final fake = FakeApi(routes: {
      '/calendar-events': _eventoDe('open_learning_sync'),
    });

    await montar(
      tester,
      fake,
      tipos: const [CalendarEventType.openLearningSync],
      cursos: [
        Course.fromJson({
          'id': _idCurso,
          'name': 'Marketing Digital',
          'isOpenLearning': true,
        }),
      ],
    );
    await tester.enterText(find.byType(TextField).first, 'Sesión');
    await tester.pump();
    await guardar(tester);

    final cuerpo = fake.cuerpos[fake.requested.indexOf('POST /calendar-events')];
    expect(cuerpo['courseId'], _idCurso);
    expect(cuerpo['laboratoryId'], isNull);
  });

  testWidgets('si el servidor rechaza, se ve el error y no se pierde lo escrito',
      (tester) async {
    // Antes la excepción se perdía y el diálogo quedaba igual: para quien lo
    // usa, el botón simplemente no hacía nada.
    final fake = FakeApi(
      routes: {'/calendar-events': _eventoDe('ruta_impacto')},
      statuses: {'/calendar-events': 400},
    );

    await montar(tester, fake, tipos: const [CalendarEventType.rutaImpacto]);
    await tester.enterText(find.byType(TextField).first, 'Encuentro de Ruta');
    await tester.pump();
    await guardar(tester);

    // El diálogo sigue abierto, con el error a la vista y el título intacto.
    expect(find.text('Agregar evento'), findsOneWidget);
    expect(find.textContaining('no son válidos'), findsOneWidget);
    expect(find.text('Encuentro de Ruta'), findsOneWidget);
  });

  testWidgets('editar ACTUALIZA el evento, no crea uno nuevo', (tester) async {
    // `saveCalendarEvent` decide entre POST y PATCH según el id, y el diálogo
    // no se lo pasaba: editar duplicaba el evento en el calendario.
    final fake = FakeApi(routes: {
      '/calendar-events/$_idEvento': _eventoDe('ruta_impacto'),
      '/calendar-events': {'data': const [], 'total': 0, 'page': 1, 'pageSize': 100},
    });

    await montar(
      tester,
      fake,
      existing: CalendarEvent.fromJson(
        Map<String, dynamic>.from(_eventoDe('ruta_impacto')),
      ),
    );
    await guardar(tester);

    expect(fake.requested, contains('PATCH /calendar-events/$_idEvento'));
    expect(fake.requested.any((r) => r == 'POST /calendar-events'), isFalse);
  });

  test('toJson convierte la cadena vacía en null', () {
    // La red de seguridad en el modelo: `''` no es un id, solo puede
    // significar "sin vincular", y para eso el servidor espera `null`.
    final evento = CalendarEvent(
      id: _idEvento,
      title: 'x',
      startsAt: DateTime.utc(2026, 10, 1, 15),
      courseId: '',
      laboratoryId: '',
    );

    expect(evento.toJson()['courseId'], isNull);
    expect(evento.toJson()['laboratoryId'], isNull);
  });
}
