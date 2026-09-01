// Los ocho portales se DIBUJAN, en tres anchos y en todas sus pestañas.
//
// Compilar no prueba que una pantalla funcione: un `Row` que desborda, una
// lista sin acotar o un `Column` sin `Expanded` son fallos de EJECUCIÓN. Esta
// suite monta el portal de cada rol y exige que Flutter no lance ninguna
// excepción — que es exactamente lo que veía quien abría la app.
//
// **Por qué contra la API falsa y no contra el backend real**: dentro de
// `testWidgets` el tiempo es falso, así que una petición real nunca completa;
// la prueba se cuelga o deja temporizadores vivos y falla por eso, no por la
// pantalla. Pero los payloads SÍ son reales: los captura
// `tool/capturar_payloads.py` de la base sembrada y viven en
// `fixtures/api_payloads.json`. Una pantalla puede dibujarse perfecto con
// datos imaginarios y romperse con los de verdad.
//
// ---------------------------------------------------------------------------
// Tres formas de que esta prueba pase sin probar nada. Las tres pasaron.
// ---------------------------------------------------------------------------
//
// 1. **`setSurfaceSize` fija píxeles FÍSICOS.** En `flutter_test` el
//    `devicePixelRatio` es 3.0, así que "1440×900" eran 480×300 lógicos, "768"
//    eran 256 y "390" eran 130. Los tres anchos caían en `compact` y el caso
//    de escritorio —la barra lateral de 230px con texto— no se ejecutó nunca.
//    Por eso acá se fija `devicePixelRatio = 1.0` y `physicalSize` a mano.
//
// 2. **La sesión se borraba en el primer frame.** `EnactusApp.initState`
//    llama `restoreSession()` tras el primer frame; sin token guardado eso
//    hace `_setUser(null)` y deja al guardia de rol mostrando el ingreso. La
//    prueba montaba `LoginView` y lo daba por bueno. Se arregla sembrando el
//    token, que además ejercita el camino de restauración de producción en vez
//    de un atajo que solo existe en pruebas.
//
// 3. **El recorrido de pestañas hacía `return` si no encontraba la barra.** Y
//    no la encontraba, por (1). Nueve pruebas verdes que no tocaban nada. Un
//    `return` silencioso convierte "no pude probar" en "probé y está bien":
//    acá cualquier ausencia es `fail`, nunca una salida callada.
//
// De ahí que las afirmaciones sean explícitas —el portal está montado, el
// ingreso NO está, ninguna pestaña quedó en estado de error—: sin ellas, "no
// lanzó excepciones" también lo cumple una pantalla que no llegó a existir.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enactus_platform/main.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/views/auth/login_view.dart';
import 'package:enactus_platform/widgets/async_states.dart';
import 'package:enactus_platform/widgets/portal_shell.dart';

import 'helpers/fake_api.dart';

late final Map<String, dynamic> _fixtures;

Map<String, dynamic> _me(String role) =>
    Map<String, dynamic>.from(_fixtures['me'][role] as Map);

/// Las respuestas reales del backend, por ruta, para el portal de [role].
FakeApi _fake(String role) {
  final rutas = <String, Object?>{
    ...Map<String, Object?>.from(_fixtures['compartidas'] as Map),
    '/auth/me': _me(role),
    // La Ruta de Impacto se pide por id del usuario con sesión.
    '/students/${_me(role)['id']}/ruta-progress': _fixtures['rutaProgress'],
  };

  return FakeApi(
    routes: rutas,
    // Los fallos que el servidor devuelve HOY se reproducen tal cual (hoy:
    // 503 en `/files/download-url`, S3 sin configurar). Fingir un 200 ahí
    // probaría una pantalla que nadie ve.
    statuses: Map<String, int>.from(
        (_fixtures['estados'] as Map?)?.cast<String, int>() ?? const {}),
    // Sin `fallback`: una ruta que el fixture no tenga hace fallar la prueba
    // diciendo cuál es. Antes el fallback devolvía una página vacía para
    // cualquier cosa, y las respuestas que no son páginas —la Ruta de
    // Impacto, las métricas— reventaban en su `fromJson`; la pantalla se
    // dibujaba en estado de ERROR y la prueba lo contaba como éxito.
    // Regenerar los fixtures: python3 tool/capturar_payloads.py
  );
}

/// Sesión ya iniciada: `EnactusApp` restaura desde el token guardado.
void _conSesionGuardada() => SharedPreferences.setMockInitialValues({
      'enactus.accessToken': 'token-de-prueba',
      'enactus.refreshToken': 'refresh-de-prueba',
    });

Widget _app(String role) {
  final api = _fake(role).build();
  final data = DataProvider(api);
  final auth = AuthProvider(api, data);
  return EnactusApp(
    api: api,
    data: data,
    auth: auth,
    initialRoute: AppRoutes.forRole(role),
  );
}

/// Fija el tamaño **lógico** de la ventana. Ver la nota 1 del encabezado.
void _tamano(WidgetTester tester, Size logico) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = logico;
  addTearDown(tester.view.reset);
}

/// Monta, deja pasar unos frames y devuelve las excepciones que lanzó Flutter.
Future<List<String>> _montar(WidgetTester tester, Widget app) async {
  final excepciones = <String>[];
  final anterior = FlutterError.onError;
  FlutterError.onError = (details) => excepciones.add(
      '${details.exception}\n${details.context}\n'
      '${details.informationCollector?.call().take(4).join('\n') ?? ''}');
  try {
    await tester.pumpWidget(app);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  } finally {
    FlutterError.onError = anterior;
  }
  return excepciones;
}

/// El portal de verdad está en pantalla — no el ingreso ni un estado de error.
void _esElPortal(String role, String donde) {
  expect(find.byType(LoginView), findsNothing,
      reason: 'El guardia de rol mandó al ingreso en $donde '
          '(${Roles.label(role)}): la prueba estaría midiendo esa pantalla.');
  expect(find.byType(PortalShell), findsOneWidget,
      reason: 'No se montó el portal de ${Roles.label(role)} en $donde.');
  expect(find.byType(ErrorState), findsNothing,
      reason: 'Una lectura falló y ${Roles.label(role)} quedó en estado de '
          'error en $donde: se estaría midiendo la maquetación del error.');
}

const _roles = [
  Roles.superAdmin,
  Roles.admin,
  Roles.lxd,
  Roles.mentor,
  Roles.advisor,
  Roles.company,
  Roles.donor,
  Roles.student,
  Roles.alumni,
];

void main() {
  setUpAll(() async {
    // Lo mismo que hace `main()` antes de `runApp`. Sin esto, cualquier
    // pantalla que formatee una fecha revienta — y el fallo diría "locale no
    // inicializado", no "la pantalla está rota".
    await initializeDateFormatting('es');

    final archivo = File('test/fixtures/api_payloads.json');
    if (!archivo.existsSync()) {
      fail('Faltan los fixtures. Generalos con:\n'
          '  cd backend && npm run db:reset && npm run dev\n'
          '  python3 tool/capturar_payloads.py');
    }
    _fixtures =
        jsonDecode(archivo.readAsStringSync()) as Map<String, dynamic>;
  });

  setUp(_conSesionGuardada);

  for (final (etiqueta, tamano) in const [
    ('teléfono', Size(390, 844)),
    ('tablet', Size(768, 1024)),
    ('escritorio', Size(1440, 900)),
  ]) {
    for (final role in _roles) {
      testWidgets('${Roles.label(role)} en $etiqueta: su portal se dibuja',
          (tester) async {
        _tamano(tester, tamano);

        final excepciones = await _montar(tester, _app(role));

        _esElPortal(role, '$etiqueta (${tamano.width.round()}px)');
        expect(excepciones, isEmpty,
            reason: 'El portal de ${Roles.label(role)} a '
                '${tamano.width.round()}px lanzó:\n${excepciones.join('\n')}');
      });
    }
  }

  /// Recorre TODAS las pestañas, no solo la primera.
  ///
  /// Un portal que abre bien puede tener rota su cuarta pestaña, y montar solo
  /// la inicial no lo vería nunca. Se hace en escritorio porque ahí la barra
  /// lateral muestra los rótulos y se puede tocar cada uno por su nombre; en
  /// tablet son solo íconos con `Tooltip` y en teléfono viven en un `Drawer`.
  for (final role in _roles) {
    testWidgets('${Roles.label(role)}: TODAS sus pestañas se dibujan',
        (tester) async {
      _tamano(tester, const Size(1440, 900));

      final excepciones = await _montar(tester, _app(role));
      _esElPortal(role, 'la pestaña inicial');
      expect(excepciones, isEmpty,
          reason: 'Al montar ${Roles.label(role)}:\n${excepciones.join('\n')}');

      final barra = find.descendant(
          of: find.byType(PortalShell), matching: find.byType(ListView));
      expect(barra, findsWidgets,
          reason: 'No se encontró la barra lateral de ${Roles.label(role)}. '
              'Antes esto era un `return` y las nueve pruebas de pestañas '
              'pasaban sin tocar ninguna.');

      final rotulos = tester
          .widgetList<Text>(
              find.descendant(of: barra.first, matching: find.byType(Text)))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      expect(rotulos.length, greaterThan(1),
          reason: 'La barra lateral de ${Roles.label(role)} devolvió '
              '$rotulos: en escritorio cada pestaña tiene su rótulo.');

      final rotos = <String>[];
      for (final rotulo in rotulos) {
        final anterior = FlutterError.onError;
        FlutterError.onError = (d) => rotos.add('[$rotulo] ${d.exception}\n'
            '${d.context}\n'
            '${d.informationCollector?.call().take(4).join('\n') ?? ''}');
        try {
          final destino = find.descendant(
              of: barra.first, matching: find.text(rotulo));
          expect(destino, findsWidgets,
              reason: 'Desapareció la pestaña "$rotulo" de '
                  '${Roles.label(role)}.');
          await tester.tap(destino.first, warnIfMissed: false);
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 120));
          }
        } finally {
          FlutterError.onError = anterior;
        }
        _esElPortal(role, 'la pestaña "$rotulo"');
      }

      expect(rotos, isEmpty,
          reason: 'Pestañas rotas en ${Roles.label(role)}:\n'
              '${rotos.join('\n')}');
    });
  }
}
