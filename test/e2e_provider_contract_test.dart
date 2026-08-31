// Cada lectura del provider, con cada rol, contra el BACKEND REAL.
//
// Esta suite existe por dos errores del mismo tipo que ninguna otra prueba
// veía: `users()` y `calendarEvents` pedían `pageSize: 200` cuando el tope del
// servidor es 100, así que respondían 400 SIEMPRE — dejando sin datos al
// buscador del encabezado, al selector de patrocinador y al calendario de los
// cuatro portales que lo muestran. Compilaba, el análisis estático no decía
// nada, y las pruebas del backend pasaban porque nunca mandaban ese número.
//
// La forma de que no vuelva a pasar no es acordarse: es tocar cada getter con
// cada rol y exigir que ninguno falle. Un getter que devuelve lista vacía está
// bien —eso es alcance, y es lo correcto para muchos roles—; uno que devuelve
// error, no.
//
// Se salta sola si el backend está apagado.
//
//   cd backend && npm run db:reset && npm run dev
//   flutter test test/e2e_provider_contract_test.dart
@Tags(['e2e'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_errors.dart';
import 'package:enactus_platform/services/api_service.dart';
import 'package:enactus_platform/main.dart';
import 'package:enactus_platform/utils/constants.dart';

bool up = false;

/// Una cuenta por rol, con la clave del seed.
const _cuentas = <String, (String, String)>{
  'superadmin': ('superadmin1@enactus.co', 'Super123'),
  'admin': ('admin@enactus.co', 'Admin123'),
  'lxd': ('lxd.ia@enactus.co', 'Lxd123'),
  'mentor': ('mentor.ia@enactus.co', 'Mentor123'),
  'advisor': ('asesor@uniandes.edu.co', 'Asesor123'),
  'company': ('empresa@bancolombia.com', 'Empresa123'),
  'donor': ('donante@gmail.com', 'Donante123'),
  'student': ('estudiante1@uniandes.edu.co', 'Est123'),
  'alumni': ('alumni1@uniandes.edu.co', 'Alumni123'),
};

final Map<String, DataProvider> _sessions = {};

Future<bool> _backendUp() async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final req = await client.getUrl(Uri.parse('${ApiService.baseUrl}/health'));
    final res = await req.close();
    await res.drain<void>();
    client.close();
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}

/// Entra UNA vez por rol: el servidor corta a 10 intentos por correo cada 5
/// minutos y una suite que entra en cada prueba se bloquea sola.
Future<DataProvider?> signIn(String role) async {
  final cached = _sessions[role];
  if (cached != null) return cached;

  final credenciales = _cuentas[role];
  if (credenciales == null) return null;

  final api = ApiService();
  final data = DataProvider(api);
  final auth = AuthProvider(api, data);
  final user = await auth.login(credenciales.$1, credenciales.$2);
  if (user == null) return null;

  _sessions[role] = data;
  return data;
}

/// Sondea un getter hasta que tenga dato o error. Devuelve el error, o `null`
/// si llegó el dato.
///
/// Que la lista venga vacía NO es un fallo: es el alcance del rol, y muchos
/// roles legítimamente no ven nada de ciertas cosas.
Future<ApiException?> settle(dynamic Function() read) async {
  for (var i = 0; i < 60; i++) {
    final state = read();
    final error = state.errorOrNull as ApiException?;
    if (error != null) return error;
    if (state.valueOrNull != null) return null;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('El getter nunca resolvió (6 s).');
}

void main() {
  setUpAll(() async {
    HttpOverrides.global = null;
    up = await _backendUp();
    if (!up) {
      // ignore: avoid_print
      print('\n⚠️  Backend apagado en ${ApiService.baseUrl} — se saltan estas '
          'pruebas.\n   Levantalo con: cd backend && npm run dev\n');
    }
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Los getters de lista/objeto que no necesitan un id.
  Map<String, dynamic Function()> gettersDe(DataProvider d) => {
        'courses': () => d.courses,
        'coursesWithStats': () => d.coursesWithStats,
        'catalogs': () => d.catalogs,
        'laboratories': () => d.laboratories,
        'projects': () => d.projects,
        'certificates': () => d.certificates,
        'submissions': () => d.submissions,
        'notifications': () => d.notifications,
        'calendarEvents': () => d.calendarEvents,
        'forumPosts': () => d.forumPosts,
        'forumStats': () => d.forumStats,
        'communicationResources': () => d.communicationResources,
        'evidences': () => d.evidences,
        'siteContent': () => d.siteContent,
        'users()': () => d.users(),
        'groups': () => d.groups,
        'allLaboratories': () => d.allLaboratories,
        // Estos dos tienen alcance propio y responden 403 a quien no
        // corresponde: `settle` lo distingue de un contrato roto.
        'talent': () => d.talent,
        'impactMetrics': () => d.impactMetrics,
      };

  for (final role in _cuentas.keys) {
    test('$role: ninguna lectura del provider responde con error', () async {
      if (!up) return;
      final data = await signIn(role);
      expect(data, isNotNull, reason: 'No se pudo entrar como $role');

      final fallos = <String, String>{};
      for (final entry in gettersDe(data!).entries) {
        final error = await settle(entry.value);
        // 403 es una respuesta legítima: hay lecturas que un rol no tiene.
        // Lo que no puede pasar es un 400 (contrato mal armado) ni un 500.
        if (error != null && error is! ForbiddenError) {
          fallos[entry.key] = '${error.code}: ${error.message}';
        }
      }

      expect(fallos, isEmpty,
          reason: 'Lecturas rotas para $role:\n'
              '${fallos.entries.map((e) => '  · ${e.key} → ${e.value}').join('\n')}');
    }, timeout: const Timeout(Duration(seconds: 90)));
  }

  test('los filtros de users() que usan los portales tampoco fallan', () async {
    if (!up) return;
    final data = await signIn('admin');
    expect(data, isNotNull);

    final variantes = <String, dynamic Function()>{
      'role=student': () => data!.users(role: Roles.student),
      'role=company': () => data!.users(role: Roles.company),
      'role=mentor': () => data!.users(role: Roles.mentor),
      'role=lxd': () => data!.users(role: Roles.lxd),
      'include=team,progress': () =>
          data!.users(role: Roles.student, include: 'team,progress'),
    };

    final fallos = <String, String>{};
    for (final entry in variantes.entries) {
      final error = await settle(entry.value);
      if (error != null) fallos[entry.key] = '${error.code}: ${error.message}';
    }
    expect(fallos, isEmpty, reason: 'Filtros rotos: $fallos');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('el LXD ve empresas para poder elegir patrocinador', () async {
    if (!up) return;
    final data = await signIn('lxd');
    expect(data, isNotNull);

    final error = await settle(() => data!.users(role: Roles.company));
    expect(error, isNull);
    // Sin esto puede GUARDAR un patrocinio pero no ver de quién es.
    expect(data!.users(role: Roles.company).valueOrNull, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 40)));

  /// Cada rol entra a SU portal y la pantalla se dibuja.
  ///
  /// Compilar no prueba que un portal funcione: un `AsyncValue` en error, un
  /// campo que no llegó o un `Row` que desborda son fallos de ejecución. Esta
  /// prueba entra con cada cuenta, monta el portal que le toca y exige que no
  /// haya ninguna excepción de Flutter — que es exactamente lo que veía quien
  /// abría la app.
  for (final role in _cuentas.keys) {
    testWidgets('$role: su portal se dibuja sin excepciones', (tester) async {
      if (!up) return;
      final data = await signIn(role);
      expect(data, isNotNull, reason: 'No se pudo entrar como $role');

      final excepciones = <Object>[];
      final anterior = FlutterError.onError;
      FlutterError.onError = (details) => excepciones.add(
          '${details.exception}\n${details.context}\n'
          '${details.informationCollector?.call().join('\n') ?? ''}');

      try {
        await tester.pumpWidget(_appDe(role, data!));
        // Varios `pump` en vez de `pumpAndSettle`: las peticiones reales no
        // completan dentro del tiempo falso de `testWidgets`, así que lo que
        // se comprueba es que el estado de carga se dibuje sin reventar.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      } finally {
        FlutterError.onError = anterior;
      }

      expect(excepciones, isEmpty,
          reason: 'El portal de $role lanzó: ${excepciones.join('\n')}');
    }, timeout: const Timeout(Duration(seconds: 90)));
  }
}

/// Monta la app directamente en la ruta del rol, sin pasar por el arranque.
Widget _appDe(String role, DataProvider data) {
  final api = ApiService();
  final auth = AuthProvider(api, data);
  return EnactusApp(
    api: api,
    data: data,
    auth: auth,
    initialRoute: AppRoutes.forRole(role),
  );
}
