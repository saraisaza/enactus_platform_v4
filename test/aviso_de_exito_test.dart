// El aviso de que algo salió bien («Actividad entregada», «Guardado»…).
//
// Antes era un recuadro que se iba solo, con el check dos veces (el ícono y
// un «✓» al final del texto), el título grande y con el subrayado amarillo
// doble que Flutter le pone al texto dibujado sin `Material` debajo. Ahora es
// una tarjeta centrada, de 320 de ancho, con «Continuar» y, cuando hay a dónde
// ir, una acción secundaria («Ver entrega»).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/l10n/textos.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_service.dart';
import 'package:enactus_platform/views/student/course_detail_view.dart';
import 'package:enactus_platform/widgets/common.dart';

import 'helpers/fake_api.dart';
import 'helpers/portal_harness.dart' show conSesionGuardada;

Future<void> _abrir(
  WidgetTester tester, {
  Size tamano = const Size(1200, 900),
  String? detalle,
  String? accion,
  VoidCallback? alAccion,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tamano;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showSuccessCheck(context, 'Actividad entregada',
              detalle: detalle, accion: accion, alAccion: alAccion),
          child: const Text('entregar'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('entregar'));
  await tester.pumpAndSettle();
}

final _tarjeta = find.byKey(const ValueKey('aviso-de-exito'));

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('el título, sin un segundo check ni subrayado, y la explicación',
      (tester) async {
    await _abrir(tester, detalle: tr.entregaRecibidaDetalle);
    expect(_tarjeta, findsOneWidget);
    expect(find.text('Actividad entregada'), findsOneWidget);
    expect(find.textContaining('✓'), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text(tr.entregaRecibidaDetalle), findsOneWidget);

    // Con `Material` debajo, el texto hereda el estilo de la app: nada de la
    // línea amarilla doble de advertencia.
    final titulo = tester.widget<Text>(find.text('Actividad entregada'));
    expect(titulo.style?.decoration, TextDecoration.none);
    expect(titulo.style?.fontSize, 19);
    expect(titulo.style?.fontWeight, FontWeight.w600);
    final estilo = DefaultTextStyle.of(
            tester.element(find.text('Actividad entregada')))
        .style;
    expect(estilo.decoration, isNot(TextDecoration.underline));
    expect(estilo.decorationColor, isNot(const Color(0xFFFFFF00)));
  });

  test('ningún texto de la plataforma trae el «✓» pegado', () {
    for (final texto in [
      tr.actividadEntregada,
      tr.actividadEntregaEnviada,
      tr.comunGuardado,
      tr.perfilActualizado,
      tr.calificarEntregaCalificada,
    ]) {
      expect(texto, isNot(contains('✓')));
    }
  });

  testWidgets('320 de ancho en el computador; en el teléfono, con margen',
      (tester) async {
    await _abrir(tester);
    expect(tester.getSize(_tarjeta).width, 320);
  });

  testWidgets('en una pantalla angosta deja 16 a cada lado', (tester) async {
    await _abrir(tester, tamano: const Size(300, 640));
    expect(tester.getSize(_tarjeta).width, 300 - 32);
  });

  testWidgets('«Continuar» lo cierra, y empieza con el foco', (tester) async {
    await _abrir(tester);
    final continuar = find.widgetWithText(TextButton, tr.comunContinuar);
    expect(Focus.of(tester.element(find.text(tr.comunContinuar))).hasFocus,
        isTrue);
    await tester.tap(continuar);
    await tester.pumpAndSettle();
    expect(_tarjeta, findsNothing);
  });

  testWidgets('Esc lo cierra', (tester) async {
    await _abrir(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_tarjeta, findsNothing);
  });

  testWidgets('tocar fuera lo cierra; tocar la tarjeta, no', (tester) async {
    await _abrir(tester);
    await tester.tap(find.text('Actividad entregada'));
    await tester.pumpAndSettle();
    expect(_tarjeta, findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(_tarjeta, findsNothing);
  });

  testWidgets('la acción secundaria hace lo suyo y cierra', (tester) async {
    var vista = false;
    await _abrir(tester,
        accion: tr.actividadVerEntrega, alAccion: () => vista = true);
    await tester.tap(find.text(tr.actividadVerEntrega));
    await tester.pumpAndSettle();
    expect(vista, isTrue);
    expect(_tarjeta, findsNothing);
  });

  testWidgets('sin acción, solo «Continuar»', (tester) async {
    await _abrir(tester);
    expect(find.byType(TextButton), findsNWidgets(2),
        reason: '«entregar», debajo, y «Continuar»');
  });

  testWidgets('para el lector de pantalla es un diálogo con nombre',
      (tester) async {
    final semantica = tester.ensureSemantics();
    await _abrir(tester);
    expect(
      tester.getSemantics(_tarjeta),
      matchesSemantics(
        label: 'Actividad entregada',
        scopesRoute: true,
        namesRoute: true,
      ),
    );
    semantica.dispose();
  });

  testWidgets('uno nuevo reemplaza al anterior', (tester) async {
    await _abrir(tester);
    showSuccessCheck(tester.element(find.text('entregar')), 'Guardado');
    await tester.pumpAndSettle();
    expect(_tarjeta, findsOneWidget);
    expect(find.text('Guardado'), findsOneWidget);
    expect(find.text('Actividad entregada'), findsNothing);
  });

  group('la entrega libre de un curso', () {
    const curso = 'dddddddd-0000-4000-8000-0000000000c1';
    const entrega = 'dddddddd-0000-4000-8000-0000000000e1';

    Map<String, Object?> pagina(List<Object> datos) =>
        {'data': datos, 'page': 1, 'pageSize': 100, 'total': datos.length};

    Map<String, Object?> laEntrega() => {
          'id': entrega,
          'studentId': 'student1',
          'courseId': curso,
          'taskName': 'Mi propuesta',
          'comment': 'Adjunto la propuesta',
          'status': 'pending',
          'files': <Object>[],
          'submittedAt': '2026-10-15T10:00:00Z',
        };

    testWidgets('«Ver entrega» baja hasta su tarjeta en «Mis entregas»',
        (tester) async {
      useFakeTokenStorage();
      conSesionGuardada();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 700);
      addTearDown(tester.view.reset);

      final fake = FakeApi(routes: {
        '/auth/me': {
          'id': 'student1',
          'name': 'Ana',
          'email': 'ana@test.co',
          'role': 'student',
          'studentType': 'open_learning',
        },
        '/courses/$curso': {
          'id': curso,
          'name': 'Curso',
          'level': 'basic',
          'status': 'published',
          'language': 'es',
          'tags': <String>[],
          'objectives': <Object>[],
          'modules': [
            for (var m = 0; m < 4; m++)
              {
                'id': 'm$m',
                'title': 'Módulo $m',
                'lessons': [
                  for (var l = 0; l < 3; l++)
                    {'id': 'l$m$l', 'title': 'Lección $m.$l', 'type': 'link'},
                ],
              },
          ],
        },
        '/courses/$curso/glossary': {'terms': <Object>[], 'reviews': {}},
        '/students/student1/course-progress/$curso': {
          'courseId': curso,
          'totalLessons': 12,
          'completedLessons': 0,
          'ratio': 0,
          'completedLessonIds': <String>[],
        },
        '/submissions': pagina([]),
        '/notifications': pagina([]),
        '/courses': pagina([]),
        '/projects': pagina([]),
        'POST /submissions': laEntrega(),
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
          home: Scaffold(body: CourseDetailView(courseId: curso)),
        ),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      await tester.ensureVisible(find.text(tr.actividadEntregaLibre));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.actividadEntregaLibre));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, tr.actividadNombreTarea), 'Mi propuesta');
      // El servidor ya la tiene: la lista que vuelve a pedirse la trae.
      fake.routes['/submissions'] = pagina([laEntrega()]);
      await tester.tap(find.text(tr.comunEnviar));
      await tester.pumpAndSettle();

      expect(find.text(tr.actividadEntregaEnviada), findsOneWidget);
      expect(find.text(tr.entregaRecibidaDetalle), findsOneWidget);

      // Se vuelve arriba, como si la persona hubiera seguido mirando.
      await tester.ensureVisible(find.text('Lección 0.0'));
      await tester.pumpAndSettle();
      expect(find.text('Mi propuesta'), findsOneWidget);
      expect(tester.getRect(find.text('Mi propuesta')).top, greaterThan(700),
          reason: 'la tarjeta quedó fuera de la vista');
      await tester.tap(find.text(tr.actividadVerEntrega));
      await tester.pumpAndSettle();

      expect(_tarjeta, findsNothing);
      final tarjeta = tester.getRect(find.text('Mi propuesta'));
      expect(tarjeta.top, greaterThanOrEqualTo(0));
      expect(tarjeta.bottom, lessThanOrEqualTo(700),
          reason: 'la tarjeta de la entrega quedó a la vista');
    });
  });
}
