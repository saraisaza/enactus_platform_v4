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

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_errors.dart';
import 'package:enactus_platform/services/api_service.dart';
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

typedef Sesion = ({ApiService api, DataProvider data, AuthProvider auth});

final Map<String, Sesion> _sessions = {};

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
Future<Sesion?> signIn(String role) async {
  final cached = _sessions[role];
  if (cached != null) return cached;

  final credenciales = _cuentas[role];
  if (credenciales == null) return null;

  final api = ApiService();
  final data = DataProvider(api);
  final auth = AuthProvider(api, data);
  final user = await auth.login(credenciales.$1, credenciales.$2);
  if (user == null) return null;

  final sesion = (api: api, data: data, auth: auth);
  _sessions[role] = sesion;
  return sesion;
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
      return;
    }

    // Se entra con TODAS las cuentas acá, antes de que empiece ninguna prueba.
    //
    // No es una optimización: dentro de `testWidgets` el tiempo es falso y una
    // petición real nunca completa —la prueba se cuelga hasta el timeout— así
    // que el ingreso tiene que ocurrir en un contexto asíncrono de verdad.
    // `setUpAll` lo es; el cuerpo de un `testWidgets`, no.
    for (final role in _cuentas.keys) {
      await signIn(role);
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
      final sesion = await signIn(role);
      expect(sesion, isNotNull, reason: 'No se pudo entrar como $role');

      final fallos = <String, String>{};
      for (final entry in gettersDe(sesion!.data).entries) {
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
    final sesion = await signIn('admin');
    expect(sesion, isNotNull);
    final data = sesion!.data;

    final variantes = <String, dynamic Function()>{
      'role=student': () => data.users(role: Roles.student),
      'role=company': () => data.users(role: Roles.company),
      'role=mentor': () => data.users(role: Roles.mentor),
      'role=lxd': () => data.users(role: Roles.lxd),
      'include=team,progress': () =>
          data.users(role: Roles.student, include: 'team,progress'),
    };

    final fallos = <String, String>{};
    for (final entry in variantes.entries) {
      final error = await settle(entry.value);
      if (error != null) fallos[entry.key] = '${error.code}: ${error.message}';
    }
    expect(fallos, isEmpty, reason: 'Filtros rotos: $fallos');
  }, timeout: const Timeout(Duration(seconds: 60)));

  /// Las lecturas POR ID, que las de arriba no tocan.
  ///
  /// El mapa `gettersDe` solo cubre los getters sin id, y eso dejaba fuera
  /// justo las pantallas de detalle: la Ruta de Impacto, el avance en un
  /// curso, el perfil de una persona, un laboratorio, un proyecto, un equipo.
  /// El hueco se notó cuando `RutaProgress.fromJson` reventó con un
  /// `type 'Null' is not a subtype of type 'String'` sin que ninguna prueba
  /// fallara: nadie estaba mirando ese contrato contra el servidor.
  test('las lecturas por id tampoco fallan (Ruta, curso, perfil, lab…)',
      () async {
    if (!up) return;
    final sesion = await signIn('student');
    expect(sesion, isNotNull);
    final data = sesion!.data;
    final admin = (await signIn('admin'))!.data;

    // Se toman ids REALES de los listados, no inventados: un id inventado
    // daría 404 y la prueba pasaría sin haber ejercitado ningún parseo.
    expect(await settle(() => data.courses), isNull);
    final cursos = data.courses.valueOrNull!;
    expect(cursos, isNotEmpty, reason: 'El seed debería traer cursos.');

    expect(await settle(() => admin.users(role: Roles.student)), isNull);
    final estudiantes = admin.users(role: Roles.student).valueOrNull!;
    expect(estudiantes, isNotEmpty);

    expect(await settle(() => admin.laboratories), isNull);
    expect(await settle(() => admin.projects), isNull);
    expect(await settle(() => admin.groups), isNull);

    final fallos = <String, String>{};

    Future<void> comprobar(String nombre, dynamic Function() leer) async {
      final error = await settle(leer);
      if (error != null && error is! ForbiddenError) {
        fallos[nombre] = '${error.code}: ${error.message}';
      }
    }

    await comprobar('rutaProgress', () => data.rutaProgress);
    await comprobar(
        'courseProgress', () => data.courseProgress(cursos.first.id));
    await comprobar('courseById', () => data.courseById(cursos.first.id));
    await comprobar('userById', () => admin.userById(estudiantes.first.id));

    final labs = admin.laboratories.valueOrNull ?? const [];
    if (labs.isNotEmpty) {
      await comprobar('labById', () => admin.labById(labs.first.id));
    }
    final proyectos = admin.projects.valueOrNull ?? const [];
    if (proyectos.isNotEmpty) {
      await comprobar('projectById', () => admin.projectById(proyectos.first.id));
    }
    final equipos = admin.groups.valueOrNull ?? const [];
    if (equipos.isNotEmpty) {
      await comprobar('groupById', () => admin.groupById(equipos.first.id));
    }

    // Estos dos no son getters con estado: devuelven `Future` y lanzan.
    try {
      await data.rutaProgressOf(estudiantes.first.id);
    } on ApiException catch (e) {
      // Un estudiante mirando a OTRO recibe 403, y está bien: lo que no puede
      // pasar es un 400 (contrato mal armado) ni un 500.
      if (e is! ForbiddenError) {
        fallos['rutaProgressOf'] = '${e.code}: ${e.message}';
      }
    }
    try {
      await admin.rutaProgressOf(estudiantes.first.id);
    } on ApiException catch (e) {
      fallos['rutaProgressOf (admin)'] = '${e.code}: ${e.message}';
    }

    expect(fallos, isEmpty,
        reason: 'Lecturas por id rotas:\n'
            '${fallos.entries.map((e) => '  · ${e.key} → ${e.value}').join('\n')}');
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('el LXD ve empresas para poder elegir patrocinador', () async {
    if (!up) return;
    final sesion = await signIn('lxd');
    expect(sesion, isNotNull);
    final data = sesion!.data;

    final error = await settle(() => data.users(role: Roles.company));
    expect(error, isNull);
    // Sin esto puede GUARDAR un patrocinio pero no ver de quién es.
    expect(data.users(role: Roles.company).valueOrNull, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 40)));

}
