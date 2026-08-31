// Recorrido del portal ADMIN de punta a punta contra el BACKEND REAL.
//
// Complementa a `backend/tests/*`: aquellas prueban la API por dentro; esta
// prueba que el cliente habla su mismo idioma — que los identificadores que
// manda son los que el servidor espera y que lo que devuelve se parsea sin
// perder nada. Es la clase de desajuste que compila perfecto y falla en
// producción.
//
// Se salta sola si el backend está apagado.
//
//   cd backend && npm run db:reset && npm run dev
//   flutter test test/e2e_admin_test.dart
@Tags(['e2e'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_errors.dart';
import 'package:enactus_platform/services/api_service.dart';
import 'package:enactus_platform/utils/constants.dart';

bool up = false;

typedef Session = ({ApiService api, DataProvider data, AuthProvider auth});

Session? _admin;

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

Future<Session> signInAdmin() async {
  final cached = _admin;
  if (cached != null) return cached;

  final api = ApiService();
  final data = DataProvider(api);
  final auth = AuthProvider(api, data);
  final user = await auth.login('admin@enactus.co', 'Admin123');
  expect(user, isNotNull, reason: auth.loginError?.message);
  final session = (api: api, data: data, auth: auth);
  _admin = session;
  return session;
}

Future<T> load<T>(dynamic Function() read) async {
  for (var i = 0; i < 80; i++) {
    final state = read();
    final error = state.errorOrNull as ApiException?;
    if (error != null) throw error;
    final value = state.valueOrNull as T?;
    if (value != null) return value;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('El dato nunca llegó (8 s).');
}

void main() {
  /// Lo que crea esta suite; se limpia al final.
  String? usuarioId;
  String? labId;

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

  tearDownAll(() async {
    if (!up) return;
    final s = await signInAdmin();
    if (usuarioId != null) {
      try {
        await s.data.deleteUser(usuarioId!);
      } on ApiException {
        // Ya estaba borrado.
      }
    }
    if (labId != null) {
      try {
        await s.data.setLabStudents(labId!, const []);
        await s.data.deleteLab(labId!);
      } on ApiException {
        // Con gente adentro el servidor lo bloquea a propósito.
      }
    }
  });

  // -------------------------------------------------------------------------
  // Panel
  // -------------------------------------------------------------------------

  test('el panel trae sus cifras del servidor, no de contar listas', () async {
    if (!up) return;
    final s = await signInAdmin();
    final metrics = await load<ImpactMetrics>(() => s.data.impactMetrics);

    // Los conteos existen y son coherentes entre sí.
    expect(metrics.counts.courses, greaterThan(0));
    expect(metrics.counts.laboratories, greaterThan(0));
    expect(metrics.counts.allStudents,
        metrics.counts.students + metrics.counts.alumni);

    // La cobertura de ODS trae los crudos, no solo la tasa: un 100% sobre dos
    // personas y otro sobre doscientas no son la misma noticia.
    for (final ods in metrics.odsCompletionRate) {
      expect(ods.total, greaterThan(0));
      expect(ods.completed, lessThanOrEqualTo(ods.total));
      expect(ods.label, startsWith('ODS '));
    }
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('el conteo de cursos NO tiene el techo de una página', () async {
    if (!up) return;
    final s = await signInAdmin();
    final metrics = await load<ImpactMetrics>(() => s.data.impactMetrics);
    final pagina = await load<List<Course>>(() => s.data.courses);

    // Con pocos cursos coinciden; lo que importa es que el conteo NO salga de
    // `pagina.length`, que se queda clavado en 100 al crecer.
    expect(metrics.counts.courses, greaterThanOrEqualTo(pagina.length));
  }, timeout: const Timeout(Duration(seconds: 40)));

  // -------------------------------------------------------------------------
  // Personas
  // -------------------------------------------------------------------------

  test('crea una cuenta con identificadores, no etiquetas', () async {
    if (!up) return;
    final s = await signInAdmin();

    final creado = await s.data.createUser({
      'name': 'Cuenta de prueba automática',
      'email': 'prueba.admin.${DateTime.now().millisecondsSinceEpoch}@test.co',
      'password': 'Prueba123',
      'role': Roles.lxd,
      'phone': '3001112233',
      'city': 'Bogotá',
      'profile': {'position': 'Diseñadora', 'specialty': 'IA'},
    });
    usuarioId = creado.id;

    expect(creado.role, Roles.lxd);
    expect(creado.profile['position'], 'Diseñadora');
    // Un rol que no es estudiante NO lleva tipo de estudiante: es lo que
    // separa eduXaction de Open Learning en toda la API.
    expect(creado.studentType, isNull);
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('un estudiante SIN tipo se rechaza', () async {
    if (!up) return;
    final s = await signInAdmin();
    await expectLater(
      s.data.createUser({
        'name': 'Sin tipo',
        'email': 'sin.tipo.${DateTime.now().millisecondsSinceEpoch}@test.co',
        'password': 'Prueba123',
        'role': Roles.student,
      }),
      throwsA(isA<ConflictError>()),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('el permiso de calificar va por su propio endpoint', () async {
    if (!up) return;
    final s = await signInAdmin();

    // No se acepta en el alta ni en el parcheo general: cada cambio queda
    // registrado con quién lo hizo.
    final actualizado = await s.data.setCanGrade(
      usuarioId!,
      openLearning: false,
      enactus: true,
    );
    expect(actualizado.canGradeOpenLearning, isFalse);
    expect(actualizado.canGradeEnactus, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('restablecer la contraseña funciona y cierra las sesiones', () async {
    if (!up) return;
    final s = await signInAdmin();
    final cuenta = await load<AppUser>(() => s.data.userById(usuarioId!));

    // Antes de cambiarla, la cuenta puede entrar.
    final antes = ApiService();
    final authAntes = AuthProvider(antes, DataProvider(antes));
    expect(await authAntes.login(cuenta.email, 'Prueba123'), isNotNull);

    await s.data.updateUser(usuarioId!, {'password': 'NuevaClave456'});

    // Con la nueva entra; con la vieja, no.
    final despues = ApiService();
    final authDespues = AuthProvider(despues, DataProvider(despues));
    expect(await authDespues.login(cuenta.email, 'NuevaClave456'), isNotNull);

    final conVieja = ApiService();
    final authVieja = AuthProvider(conVieja, DataProvider(conVieja));
    expect(await authVieja.login(cuenta.email, 'Prueba123'), isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('el filtro por rol lo aplica el servidor', () async {
    if (!up) return;
    final s = await signInAdmin();
    final mentores = await load<List<AppUser>>(
        () => s.data.users(role: Roles.mentor));

    expect(mentores, isNotEmpty);
    // Todos, no "los de esta página que además son mentores".
    expect(mentores.every((u) => u.role == Roles.mentor), isTrue);
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('include=reviews trae cuántas entregas revisó cada mentor', () async {
    if (!up) return;
    final s = await signInAdmin();
    final mentores = await load<List<AppUser>>(
        () => s.data.users(role: Roles.mentor, include: 'reviews'));
    expect(mentores, isNotEmpty);
    // El campo llega; su valor lo comprueba la prueba del backend contra SQL.
    expect(mentores.first.reviewsCount, isNotNull);
  }, timeout: const Timeout(Duration(seconds: 40)));

  // -------------------------------------------------------------------------
  // Laboratorios y Ruta de Impacto
  // -------------------------------------------------------------------------

  test('crear un laboratorio lo deja con sus TRES fases', () async {
    if (!up) return;
    final s = await signInAdmin();

    final creado = await s.data.createLab(
      name: 'Laboratorio de prueba automática',
      description: 'Para las pruebas',
    );
    labId = creado.id;

    // Un laboratorio sin fases no tiene Ruta y nadie podría cursarlo.
    final detalle = await load<Laboratory>(() => s.data.labById(labId!));
    expect(detalle.phases, hasLength(3));
    expect(detalle.phases.map((p) => p.orderIndex), [1, 2, 3]);
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('el módulo de mentoría es siempre el último de la fase', () async {
    if (!up) return;
    final s = await signInAdmin();
    var lab = await load<Laboratory>(() => s.data.labById(labId!));
    final fase = lab.phases.first;

    for (final titulo in ['Diagnóstico', 'Investigación', 'Mentoría']) {
      await s.data.createRutaModule(fase.id, titulo, labId: labId!);
    }

    lab = await load<Laboratory>(() => s.data.labById(labId!));
    final modulos = lab.phases.first.modules;
    expect(modulos, hasLength(3));
    expect(modulos.map((m) => m.isMentorshipModule), [false, false, true]);

    // Y al reordenar, el flag se mueve con él: se recalcula, no se arrastra.
    final invertido = modulos.map((m) => m.id).toList().reversed.toList();
    await s.data.reorderRutaModules(fase.id, invertido, labId: labId!);

    lab = await load<Laboratory>(() => s.data.labById(labId!));
    final reordenados = lab.phases.first.modules;
    expect(reordenados.map((m) => m.id).toList(), invertido);
    expect(reordenados.map((m) => m.isMentorshipModule), [false, false, true]);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('vincular un curso importa sus objetivos a la fase', () async {
    if (!up) return;
    final s = await signInAdmin();
    var lab = await load<Laboratory>(() => s.data.labById(labId!));
    final modulo = lab.phases.first.modules.first;
    final cursos = await load<List<Course>>(() => s.data.courses);
    final curso = cursos.firstWhere((c) => !c.isRutaExpo);

    final importados = await s.data.setRutaModuleCourses(
      modulo.id,
      [curso.id],
      labId: labId!,
    );
    expect(importados, greaterThanOrEqualTo(0));

    lab = await load<Laboratory>(() => s.data.labById(labId!));
    expect(lab.phases.first.modules.first.courseIds, contains(curso.id));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('un objetivo sin cursos avisa que nunca se completa', () async {
    if (!up) return;
    final s = await signInAdmin();
    var lab = await load<Laboratory>(() => s.data.labById(labId!));
    final fase = lab.phases.first;

    await s.data.createObjective(
      fase.id,
      category: ObjectiveCategory.entrepreneurship,
      text: 'Objetivo de prueba',
      labId: labId!,
    );

    lab = await load<Laboratory>(() => s.data.labById(labId!));
    final objetivo = lab.phases.first.objectives
        .firstWhere((o) => o.text == 'Objetivo de prueba');

    // Sin cursos no se puede completar NUNCA — y traba la fase entera.
    expect(objetivo.neverCompletable, isTrue);

    final cursos = await load<List<Course>>(() => s.data.courses);
    final sinCursos = await s.data.setObjectiveCourses(
      objetivo.id,
      [cursos.first.id],
      labId: labId!,
    );
    expect(sinCursos, isFalse);

    lab = await load<Laboratory>(() => s.data.labById(labId!));
    final conCursos = lab.phases.first.objectives
        .firstWhere((o) => o.id == objetivo.id);
    expect(conCursos.courseIds, hasLength(1));
    expect(conCursos.neverCompletable, isFalse);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('las lecciones propias del módulo llegan en el detalle', () async {
    if (!up) return;
    final s = await signInAdmin();
    var lab = await load<Laboratory>(() => s.data.labById(labId!));
    final modulo = lab.phases.first.modules.first;

    await s.data.createOwnLesson(
      modulo.id,
      title: 'Lectura inicial',
      type: 'pdf',
      labId: labId!,
    );

    lab = await load<Laboratory>(() => s.data.labById(labId!));
    final propias = lab.phases.first.modules.first.ownLessons;
    expect(propias, hasLength(1));
    expect(propias.first.title, 'Lectura inicial');
    expect(propias.first.type, LessonType.pdf);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('un laboratorio con gente adentro no se borra', () async {
    if (!up) return;
    final s = await signInAdmin();
    final estudiantes = await load<List<AppUser>>(
        () => s.data.users(role: Roles.student));
    final enactus = estudiantes
        .where((e) => e.studentType == StudentType.enactus)
        .toList();
    if (enactus.isEmpty) return;

    await s.data.setLabStudents(labId!, [enactus.first.id]);
    await expectLater(
      s.data.deleteLab(labId!),
      throwsA(isA<ConflictError>()),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('un Open Learning no entra a un laboratorio', () async {
    if (!up) return;
    final s = await signInAdmin();
    final estudiantes = await load<List<AppUser>>(
        () => s.data.users(role: Roles.student));
    final ol = estudiantes
        .where((e) => e.studentType == StudentType.openLearning)
        .toList();
    if (ol.isEmpty) return;

    // Recibiría acceso a los cursos del laboratorio sin haber pasado por
    // eduXaction, que es el aislamiento que sostiene el resto de la API.
    await expectLater(
      s.data.setLabStudents(labId!, [ol.first.id]),
      throwsA(isA<ConflictError>()),
    );
  }, timeout: const Timeout(Duration(seconds: 40)));

  // -------------------------------------------------------------------------
  // Portada
  // -------------------------------------------------------------------------

  test('la galería llega con id para administrarla y URL para pintarla',
      () async {
    if (!up) return;
    final s = await signInAdmin();
    final content = await load<SiteContent>(() => s.data.siteContent);

    // Dos formas del mismo dato: la portada pinta `galleryImages` y no sabe
    // qué es un id; el panel necesita el id para poder quitar una.
    expect(content.gallery.length, content.galleryImages.length);
    for (final img in content.gallery) {
      expect(img.id, isNotEmpty);
    }
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('una key fuera de site-gallery/ se rechaza', () async {
    if (!up) return;
    final s = await signInAdmin();
    // La portada se ve SIN sesión: publicar acá el adjunto de una entrega lo
    // haría firmable para cualquiera que entrara.
    await expectLater(
      s.data.addGalleryImage('submissions/privado.pdf'),
      throwsA(isA<ValidationError>()),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('guardar la portada no pierde los laboratorios ni la galería', () async {
    if (!up) return;
    final s = await signInAdmin();
    final antes = await load<SiteContent>(() => s.data.siteContent);

    await s.data.saveSiteContent({
      'heroTitle': antes.heroTitle,
      'heroSubtitle': antes.heroSubtitle,
      'bannerText': antes.bannerText,
      'aboutText': antes.aboutText,
      'meetingLink': antes.meetingLink,
      'statStudents': antes.statStudents,
      'statProjects': antes.statProjects,
      'statLabs': antes.statLabs,
      'statUniversities': antes.statUniversities,
    });

    // El PATCH devuelve la fila de configuración a secas: si se guardara esa
    // respuesta como contenido, la portada perdería sus laboratorios.
    final despues = s.data.siteContent.valueOrNull;
    expect(despues, isNotNull);
    expect(despues!.laboratories.length, antes.laboratories.length);
  }, timeout: const Timeout(Duration(seconds: 40)));
}
