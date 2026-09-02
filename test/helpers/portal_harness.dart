import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enactus_platform/main.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/utils/constants.dart';

import 'fake_api.dart';

/// Montaje de los ocho portales contra payloads REALES del backend.
///
/// Vive acá y no dentro de una suite porque lo usan dos, y montar un portal
/// tiene tres trampas que ya costaron caro una vez (ver el encabezado de
/// `portals_render_test.dart`): el tamaño lógico, la sesión que se borra en el
/// primer frame y las ausencias que se tragan en silencio. Duplicar ese
/// montaje sería duplicar las tres.

late Map<String, dynamic> _fixtures;

const rolesDePortal = [
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

/// Carga los fixtures capturados del backend sembrado. Llamar en `setUpAll`.
void cargarFixtures() {
  final archivo = File('test/fixtures/api_payloads.json');
  if (!archivo.existsSync()) {
    fail('Faltan los fixtures. Generalos con:\n'
        '  cd backend && npm run db:reset && npm run dev\n'
        '  python3 tool/capturar_payloads.py');
  }
  _fixtures = jsonDecode(archivo.readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic> usuarioDe(String role) =>
    Map<String, dynamic>.from(_fixtures['me'][role] as Map);

/// Sesión ya iniciada: `EnactusApp` la restaura desde el token guardado.
void conSesionGuardada() => SharedPreferences.setMockInitialValues({
      'enactus.accessToken': 'token-de-prueba',
      'enactus.refreshToken': 'refresh-de-prueba',
    });

FakeApi fakeDe(String role) {
  final rutas = <String, Object?>{
    ...Map<String, Object?>.from(_fixtures['compartidas'] as Map),
    '/auth/me': usuarioDe(role),
    '/students/${usuarioDe(role)['id']}/ruta-progress': _fixtures['rutaProgress'],
  };
  return FakeApi(
    routes: rutas,
    // Los fallos que el servidor devuelve HOY se reproducen tal cual.
    statuses: Map<String, int>.from(
        (_fixtures['estados'] as Map?)?.cast<String, int>() ?? const {}),
    // Sin `fallback`: una ruta sin fixture hace fallar la prueba diciendo cuál.
  );
}

Widget appDe(String role) {
  final api = fakeDe(role).build();
  final data = DataProvider(api);
  final auth = AuthProvider(api, data);
  return EnactusApp(
    api: api,
    data: data,
    auth: auth,
    initialRoute: AppRoutes.forRole(role),
  );
}

/// Sin sesión guardada: el caso de quien todavía no entró.
void sinSesionGuardada() => SharedPreferences.setMockInitialValues({});

/// Una pantalla pública (portada, ingreso): sin sesión y sin rol.
///
/// Usa los mismos payloads reales — la portada pide `/site-content` — y borra
/// el token: con uno sembrado, `restoreSession()` pediría `/auth/me`, que en
/// una pantalla pública no corresponde.
Widget appPublica(String ruta) {
  sinSesionGuardada();
  final api = FakeApi(
    routes: Map<String, Object?>.from(_fixtures['compartidas'] as Map),
    statuses: Map<String, int>.from(
        (_fixtures['estados'] as Map?)?.cast<String, int>() ?? const {}),
  ).build();
  final data = DataProvider(api);
  final auth = AuthProvider(api, data);
  return EnactusApp(api: api, data: data, auth: auth, initialRoute: ruta);
}

/// Fija el tamaño **lógico** de la ventana.
///
/// `setSurfaceSize` fija píxeles FÍSICOS y en `flutter_test` el
/// `devicePixelRatio` es 3.0: usarlo daba un tercio del ancho pedido y todas
/// las pruebas caían en `compact` sin que nadie lo notara.
void fijarTamano(WidgetTester tester, Size logico) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = logico;
  addTearDown(tester.view.reset);
}

/// Monta, deja pasar unos frames y devuelve las excepciones que lanzó Flutter.
Future<List<String>> montar(WidgetTester tester, Widget app) async {
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

/// Los textos del CUERPO de la pestaña — sin encabezado, barra lateral ni pie.
///
/// Existe por un hueco que encontró la auditoría de pruebas (mutación F2):
/// se hizo que `StudentDashboardView` devolviera un `Container()` vacío y las
/// 124 pruebas siguieron en verde. `_esElPortal` comprobaba que el armazón
/// estuviera montado y que no hubiera estado de error, y una pantalla en
/// blanco cumple las dos cosas.
///
/// No sirve contar los textos de toda la pantalla: el encabezado y el pie
/// aportan varias decenas por sí solos y taparían el cuerpo vacío. Por eso el
/// conteo se ancla a la llave `portal-content` de `PortalShell`.
List<String> textosDelContenido(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(
      of: find.byKey(const Key('portal-content')),
      matching: find.byType(Text),
    ))
    .map((t) => t.data)
    .whereType<String>()
    .where((s) => s.trim().isNotEmpty)
    .toList();

/// Los rótulos de la barra lateral, en escritorio (en tablet son solo íconos).
List<String> rotulosDeBarraLateral(WidgetTester tester, Finder barra) => tester
    .widgetList<Text>(
        find.descendant(of: barra.first, matching: find.byType(Text)))
    .map((t) => t.data)
    .whereType<String>()
    .toList();
