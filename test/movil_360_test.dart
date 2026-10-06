// La app en un teléfono de 360 dp: lo que la suite de escritorio no ve.
//
// `portals_render_test.dart` recorre todas las pestañas, pero en escritorio;
// en teléfono solo monta la primera. La auditoría móvil midió lo que eso
// dejaba pasar: 18 lugares que se salían de la pantalla con la letra normal
// —el calendario por 354 px, el mapa por 300— y 28 con la letra a 1.3x, que
// es la que usa mucha gente mayor o con baja visión.
//
// Acá se recorren TODAS las pestañas de los nueve portales a 360 dp, con la
// barra de estado de un iPhone con notch, a 1.0x y a 1.3x, bajando hasta el
// final de cada una. Cualquier desborde es un fallo, con el archivo y la línea.
//
// Es una medida CONSERVADORA: `flutter_test` dibuja con una fuente de prueba en
// la que cada letra mide lo mismo que el tamaño de la fuente, bastante más
// ancha que DM Sans (ver `movil_test.dart`). Lo que cabe acá, en el teléfono
// cabe con holgura; la letra "normal" de esta prueba se parece más a la letra
// agrandada de un dispositivo.
//
// También se fijan dos comportamientos del teléfono que una prueba de
// escritorio nunca vería: el encabezado no puede quedar debajo de la hora y la
// batería, y el botón atrás de Android no puede cerrar la app con un detalle o
// el menú abiertos.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:enactus_platform/main.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/widgets/app_header.dart';
import 'package:enactus_platform/widgets/portal_shell.dart';

import 'helpers/fake_api.dart';
import 'helpers/portal_harness.dart';

const _telefono = Size(360, 780);

/// Lo que ocupa la barra de estado de un iPhone con notch.
const _barraDeEstado = 47.0;

/// Dónde se creó el widget que desborda, como `lib/...` o como
/// `package:enactus_platform/...` (depende de cómo lo reporte Flutter).
final _ubicacion = RegExp(
    r'(?:lib/|package:enactus_platform/)[A-Za-z0-9_/]+\.dart:\d+');

void _simularTelefono(WidgetTester tester, {double escala = 1.0}) {
  fijarTamano(tester, _telefono);
  const insets = FakeViewPadding(top: _barraDeEstado, bottom: 34);
  tester.view.padding = insets;
  tester.view.viewPadding = insets;
  tester.platformDispatcher.textScaleFactorTestValue = escala;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _frames(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Va a una pestaña como lo haría una persona: por la barra inferior si está
/// ahí, o por "Más".
Future<void> _irA(WidgetTester tester, String rotulo) async {
  final enBarra = find.descendant(
      of: find.byType(NavigationBar), matching: find.byTooltip(rotulo));
  if (enBarra.evaluate().isNotEmpty) {
    await tester.tap(enBarra.first);
  } else {
    await tester.tap(find.byTooltip('Más opciones'));
    await _frames(tester, 4);
    // El menú es una lista que se desplaza: con letra grande, las últimas
    // opciones quedan más abajo del borde, y una persona baja hasta ellas.
    final enCajon =
        find.descendant(of: find.byType(Drawer), matching: find.text(rotulo));
    await tester.scrollUntilVisible(enCajon, 120,
        scrollable: find
            .descendant(
                of: find.byType(Drawer), matching: find.byType(Scrollable))
            .first);
    await tester.tap(enCajon.first);
  }
  await _frames(tester);
}

/// Baja hasta el final de la pestaña: lo que se construye perezosamente
/// también tiene que caber.
Future<void> _bajarHastaElFinal(WidgetTester tester) async {
  final cuerpo = find.byKey(const Key('portal-content'));
  if (cuerpo.evaluate().isEmpty) return;
  for (var i = 0; i < 4; i++) {
    await tester.drag(cuerpo, const Offset(0, -700), warnIfMissed: false);
    await _frames(tester, 2);
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    cargarFixtures();
  });

  for (final escala in const [1.0, 1.3]) {
    for (final role in rolesDePortal) {
      testWidgets(
          '${Roles.label(role)} a 360 dp, letra ${escala}x: ninguna pestaña '
          'se sale de la pantalla', (tester) async {
        conSesionGuardada();
        _simularTelefono(tester, escala: escala);
        final desbordes = <String>{};
        var pestana = '(inicial)';
        final anterior = FlutterError.onError;
        FlutterError.onError = (d) {
          final texto = d.toString();
          if (!texto.contains('overflowed')) return anterior?.call(d);
          final donde = _ubicacion.allMatches(texto).map((m) => m.group(0));
          // Si el widget que desborda lo creó Flutter (una fila dentro de un
          // `ListTile`), su ubicación no es de este código: la cadena de
          // widgets ("creator: Row ← Padding ← …") dice de quién es.
          final cadena = RegExp(r'creator: ([^\n]{0,240})')
                  .firstMatch(texto)
                  ?.group(1) ??
              '';
          desbordes.add('[$pestana] ${d.exception.toString().split('\n').first} '
              '@ ${donde.isEmpty ? cadena : donde.take(2).join(', ')}');
        };
        // El manejador se restaura ANTES de cualquier `expect`: con el
        // propio todavía puesto, un fallo deja a `flutter_test` trabado en vez
        // de reportarlo.
        try {
          await tester.pumpWidget(appDe(role));
          await _frames(tester, 8);
          await _bajarHastaElFinal(tester);

          final rotulos = tester
              .widget<PortalShell>(find.byType(PortalShell))
              .tabs
              .map((t) => t.label)
              .toList();
          for (final rotulo in rotulos.skip(1)) {
            pestana = rotulo;
            await _irA(tester, rotulo);
            await _bajarHastaElFinal(tester);
          }
        } finally {
          FlutterError.onError = anterior;
        }

        expect(desbordes, isEmpty,
            reason: 'A 360 dp con letra ${escala}x, ${Roles.label(role)} '
                'desborda:\n${desbordes.join('\n')}');
      });
    }
  }

  // Las pantallas de detalle que se abren encima del portal: curso (con sus
  // módulos y lecciones), laboratorio, proyecto y perfil de una persona. Las
  // rutas auxiliares sin fixture responden una página vacía: acá importa que
  // la pantalla quepa, no cada dato.
  for (final escala in const [1.0, 1.3]) {
    testWidgets('detalles a 360 dp, letra ${escala}x: ninguno se sale de la '
        'pantalla', (tester) async {
      final fx = jsonDecode(
              File('test/fixtures/api_payloads.json').readAsStringSync())
          as Map<String, dynamic>;
      final rutas = (fx['compartidas'] as Map).keys.cast<String>().toList();
      String? id(String pref) => rutas
          .where((r) => r.startsWith(pref) && r.split('/').length == 3)
          .firstOrNull
          ?.substring(pref.length);
      final casos = <(String, String)>[
        for (final r in rutas.where(
            (r) => r.startsWith('/courses/') && r.split('/').length == 3))
          (Roles.student, '/cursos/${r.substring('/courses/'.length)}'),
        if (id('/laboratories/') case final i?) (Roles.admin, '/laboratorios/$i'),
        if (id('/projects/') case final i?) (Roles.student, '/proyectos/$i'),
        if (id('/users/') case final i?) (Roles.admin, '/usuarios/$i'),
      ];
      expect(casos.length, greaterThanOrEqualTo(4),
          reason: 'Faltan fixtures de detalle: la prueba no mediría nada.');

      final desbordes = <String>{};
      var ruta = '';
      final anterior = FlutterError.onError;
      FlutterError.onError = (d) {
        final texto = d.toString();
        if (!texto.contains('overflowed')) return anterior?.call(d);
        final donde = _ubicacion.allMatches(texto).map((m) => m.group(0));
        desbordes.add('[$ruta] ${d.exception.toString().split('\n').first} '
            '@ ${donde.take(2).join(', ')}');
      };
      try {
        for (final (role, destino) in casos) {
          ruta = destino;
          conSesionGuardada();
          _simularTelefono(tester, escala: escala);
          final base = fakeDe(role);
          final api = FakeApi(
            routes: base.routes,
            statuses: base.statuses,
            fallback: (_) => const {
              'data': <Object>[],
              'page': 1,
              'pageSize': 100,
              'total': 0,
              'totalPages': 1,
            },
          ).build();
          final data = DataProvider(api);
          await tester.pumpWidget(EnactusApp(
              key: UniqueKey(),
              api: api,
              data: data,
              auth: AuthProvider(api, data),
              initialRoute: destino));
          await _frames(tester, 10);
          final scroll = find.byType(Scrollable);
          for (var i = 0; i < 6 && scroll.evaluate().isNotEmpty; i++) {
            await tester.drag(scroll.first, const Offset(0, -700),
                warnIfMissed: false);
            await _frames(tester, 2);
          }
        }
      } finally {
        FlutterError.onError = anterior;
      }
      expect(desbordes, isEmpty,
          reason: 'A 360 dp con letra ${escala}x, una pantalla de detalle '
              'desborda:\n${desbordes.join('\n')}');
    });
  }

  testWidgets('el encabezado no queda debajo de la barra de estado',
      (tester) async {
    conSesionGuardada();
    _simularTelefono(tester);
    await tester.pumpWidget(appDe(Roles.student));
    await _frames(tester, 8);

    final logo = find.descendant(
        of: find.byType(AppHeader), matching: find.byType(GestureDetector));
    final primero = tester.getRect(logo.first);
    expect(primero.top, greaterThanOrEqualTo(_barraDeEstado),
        reason: 'El encabezado empieza en y=${primero.top}, debajo de la hora '
            'y la batería (que llegan hasta y=$_barraDeEstado).');
  });

  group('botón atrás de Android', () {
    /// Como arranca la app en el teléfono: sin ruta inicial, o sea con el
    /// Navigator propio del portal.
    Future<List<MethodCall>> montar(WidgetTester tester) async {
      conSesionGuardada();
      _simularTelefono(tester);
      final llamadas = <MethodCall>[];
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        llamadas.add(call);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      final api = fakeDe(Roles.student).build();
      final data = DataProvider(api);
      await tester.pumpWidget(
          EnactusApp(api: api, data: data, auth: AuthProvider(api, data)));
      await _frames(tester, 10);
      expect(find.byType(PortalShell), findsOneWidget);
      return llamadas;
    }

    Future<void> atras(WidgetTester tester) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
        (_) {},
      );
      await _frames(tester);
    }

    bool cerroLaApp(List<MethodCall> llamadas) =>
        llamadas.any((c) => c.method == 'SystemNavigator.pop');

    testWidgets('con un detalle abierto, vuelve al portal', (tester) async {
      final llamadas = await montar(tester);
      Navigator.of(tester.element(find.byType(PortalShell))).push(
        MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('DETALLE ABIERTO'))),
      );
      await _frames(tester);
      await atras(tester);
      expect(find.text('DETALLE ABIERTO'), findsNothing,
          reason: 'Atrás no cerró el detalle.');
      expect(cerroLaApp(llamadas), isFalse,
          reason: 'Atrás cerró la app con un detalle abierto.');
    });

    testWidgets('con el menú "Más" abierto, lo cierra', (tester) async {
      final llamadas = await montar(tester);
      await tester.tap(find.byTooltip('Más opciones'));
      await _frames(tester, 4);
      expect(find.byType(Drawer), findsOneWidget);
      await atras(tester);
      expect(find.byType(Drawer), findsNothing,
          reason: 'Atrás no cerró el menú.');
      expect(cerroLaApp(llamadas), isFalse,
          reason: 'Atrás cerró la app con el menú abierto.');
    });

    testWidgets('en otra pestaña, vuelve a la primera antes de salir',
        (tester) async {
      final llamadas = await montar(tester);
      final shell = tester.widget<PortalShell>(find.byType(PortalShell));
      await _irA(tester, shell.tabs[2].label);
      await atras(tester);
      expect(cerroLaApp(llamadas), isFalse,
          reason: 'Atrás salió de la app desde una pestaña secundaria.');
      // Y ya en la primera, atrás sí sale: es lo que espera Android.
      await atras(tester);
      expect(cerroLaApp(llamadas), isTrue);
    });
  });
}
