import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/authoring.dart';
import '../models/models.dart';
import '../models/progress.dart';
import '../services/api_errors.dart';
import '../services/api_service.dart';
import '../utils/async_value.dart';

/// Estado de datos de la aplicación, contra la API.
///
/// Reemplaza al `DataProvider` que leía Hive de forma síncrona. La diferencia
/// de fondo: **los getters siguen siendo síncronos, pero devuelven
/// [AsyncValue], no datos crudos.** El provider hace el pedido una vez, guarda
/// el resultado y notifica; la vista solo lee estado y cubre las tres ramas.
///
/// ```dart
/// data.courses.when(
///   loading: () => const CardGridSkeleton(),
///   error: (e) => ErrorState(e, onRetry: data.reloadCourses),
///   data: (courses) => CourseGrid(courses),
/// )
/// ```
///
/// **Carga perezosa:** el primer acceso a un getter dispara su pedido. Eso
/// evita tener que agregar `initState` a treinta vistas, muchas de ellas sin
/// estado. La mutación ocurre dentro de `build`, pero nunca se notifica ahí:
/// el estado pasa a `loading` de forma síncrona (sin notificar) y el
/// `notifyListeners` llega recién cuando responde la red.
///
/// **Lo que ya no está acá:** la completitud, el progreso y los permisos. Eso
/// lo calcula el servidor. Este archivo tenía ~95 métodos, de los cuales una
/// treintena eran reglas de negocio; esas reglas ahora viven en la API y sus
/// vistas de PostgreSQL.
class DataProvider extends ChangeNotifier {
  final ApiService api;

  DataProvider(this.api);

  /// Id del usuario con sesión. Lo fija `AuthProvider` al entrar y al salir:
  /// muchas consultas son "lo mío" y necesitan saber de quién.
  String? _currentUserId;

  String? get currentUserId => _currentUserId;

  /// Cambiar de sesión invalida TODO el estado. Sin esto, quien entra después
  /// vería por un instante los datos de quien salió.
  void setCurrentUser(String? userId) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    _resetAll();
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Estado
  // -------------------------------------------------------------------------

  AsyncValue<List<Course>> _courses = const AsyncValue.idle();
  AsyncValue<RutaProgress> _rutaProgress = const AsyncValue.idle();
  AsyncValue<List<Laboratory>> _laboratories = const AsyncValue.idle();
  AsyncValue<List<Project>> _projects = const AsyncValue.idle();
  AsyncValue<List<Certificate>> _certificates = const AsyncValue.idle();
  AsyncValue<List<AppNotification>> _notifications = const AsyncValue.idle();
  AsyncValue<List<CalendarEvent>> _calendarEvents = const AsyncValue.idle();
  AsyncValue<List<ForumPost>> _forumPosts = const AsyncValue.idle();
  AsyncValue<ForumStats> _forumStats = const AsyncValue.idle();
  AsyncValue<List<Submission>> _submissions = const AsyncValue.idle();
  AsyncValue<List<CommunicationResource>> _commResources =
      const AsyncValue.idle();
  AsyncValue<List<Evidence>> _evidences = const AsyncValue.idle();
  AsyncValue<SiteContent> _siteContent = const AsyncValue.idle();

  int _unreadNotifications = 0;

  /// Cachés por id. Una pantalla de detalle pide su entidad y se queda acá,
  /// para que volver atrás y entrar de nuevo no dispare otro pedido.
  final Map<String, AsyncValue<Course>> _courseById = {};
  final Map<String, AsyncValue<Project>> _projectById = {};
  final Map<String, AsyncValue<Laboratory>> _labById = {};
  final Map<String, AsyncValue<Group>> _groupById = {};
  final Map<String, AsyncValue<ForumPost>> _forumPostById = {};
  final Map<String, AsyncValue<CourseProgress>> _courseProgress = {};

  void _resetAll() {
    _courses = const AsyncValue.idle();
    _authoredCourses = const AsyncValue.idle();
    _rutaProgress = const AsyncValue.idle();
    _laboratories = const AsyncValue.idle();
    _allLaboratories = const AsyncValue.idle();
    _projects = const AsyncValue.idle();
    _certificates = const AsyncValue.idle();
    _notifications = const AsyncValue.idle();
    _calendarEvents = const AsyncValue.idle();
    _forumPosts = const AsyncValue.idle();
    _forumStats = const AsyncValue.idle();
    _submissions = const AsyncValue.idle();
    _commResources = const AsyncValue.idle();
    _evidences = const AsyncValue.idle();
    _groups = const AsyncValue.idle();
    _catalogs = const AsyncValue.idle();
    _universities = const AsyncValue.idle();
    _talent = const AsyncValue.idle();
    _impactMetrics = const AsyncValue.idle();
    // `_siteContent` NO se limpia: es público y no depende de quién mire.
    _unreadNotifications = 0;
    _courseById.clear();
    _projectById.clear();
    _labById.clear();
    _groupById.clear();
    _forumPostById.clear();
    _courseProgress.clear();
    _usersByQuery.clear();
    _userById.clear();
    _courseStudents.clear();
    _courseStats.clear();
    // Las URLs firmadas se emitieron para la sesión anterior: al cambiar de
    // cuenta se descartan, en vez de dejar enlaces vivos a archivos que la
    // cuenta nueva quizá no puede ver.
    _fileUrls.clear();
    _fileUrlExpiry.clear();
  }

  // -------------------------------------------------------------------------
  // Cursos
  // -------------------------------------------------------------------------

  /// Los cursos que el rol con sesión puede ver. El alcance lo decide el
  /// servidor: un estudiante recibe solo lo publicado de sus laboratorios.
  AsyncValue<List<Course>> get courses {
    _lazy(_courses, (v) => _courses = v, _fetchCourses);
    return _courses;
  }

  Future<void> reloadCourses() =>
      _refresh((v) => _courses = v, _fetchCourses, _courses.valueOrNull);

  AsyncValue<List<Course>> _authoredCourses = const AsyncValue.idle();

  /// Los cursos con sus cifras de seguimiento, para quien los administra.
  ///
  /// Es una lista aparte de [courses] porque pide otra cosa: `include=stats`
  /// solo tiene sentido para quien acompaña el curso, y traerlo siempre le
  /// costaría una consulta más a cada estudiante que abre "Mis Cursos".
  AsyncValue<List<Course>> get coursesWithStats {
    _lazy(_authoredCourses, (v) => _authoredCourses = v, _fetchCoursesWithStats);
    return _authoredCourses;
  }

  Future<void> reloadCoursesWithStats() => _refresh(
        (v) => _authoredCourses = v,
        _fetchCoursesWithStats,
        _authoredCourses.valueOrNull,
      );

  Future<List<Course>> _fetchCoursesWithStats() async {
    final json = await api
        .get('/courses', query: {'pageSize': 100, 'include': 'stats'});
    return Page.fromJson(
      Map<String, dynamic>.from(json as Map),
      Course.fromJson,
    ).data;
  }

  /// Trae el progreso junto con los cursos: una tarjeta de curso muestra su
  /// avance, y pedirlo por separado sería una petición por tarjeta.
  Future<List<Course>> _fetchCourses() async {
    final json = await api
        .get('/courses', query: {'pageSize': 100, 'include': 'progress'});
    final page = Map<String, dynamic>.from(json as Map);

    // El avance viene anidado en cada curso; se guarda en la caché de
    // progreso para que la pantalla de detalle no lo vuelva a pedir.
    for (final raw in (page['data'] as List? ?? const [])) {
      final item = Map<String, dynamic>.from(raw as Map);
      final progress = item['progress'];
      if (progress is Map) {
        final parsed =
            CourseProgress.fromJson(Map<String, dynamic>.from(progress));
        // Sin pisar un progreso ya cargado con sus lecciones marcadas: ese
        // trae más detalle que este resumen.
        // Bajo la clave del usuario con sesión: este resumen es SUYO.
        final key = _progressKey(parsed.courseId, null);
        if (_courseProgress[key]?.valueOrNull == null) {
          _courseProgress[key] = AsyncValue.data(parsed);
        }
      }
    }

    return Page.fromJson(page, Course.fromJson).data;
  }

  /// Un curso con sus módulos y lecciones.
  AsyncValue<Course> courseById(String id) {
    final current = _courseById[id] ?? const AsyncValue<Course>.idle();
    _lazy(current, (v) => _courseById[id] = v, () async {
      final json = await api.get('/courses/$id',
          query: {'include': 'modules,lessons'});
      return Course.fromJson(Map<String, dynamic>.from(json as Map));
    });
    return _courseById[id] ?? current;
  }

  Future<void> reloadCourse(String id) => _refresh(
        (v) => _courseById[id] = v,
        () async {
          final json = await api.get('/courses/$id',
              query: {'include': 'modules,lessons'});
          return Course.fromJson(Map<String, dynamic>.from(json as Map));
        },
        _courseById[id]?.valueOrNull,
      );

  // -------------------------------------------------------------------------
  // Autoría de cursos (LXD y Admin)
  // -------------------------------------------------------------------------

  /// Crea un curso y devuelve el creado, con su id real.
  ///
  /// El id lo asigna PostgreSQL: el cliente ya no lo inventa. Antes había un
  /// `newId('crs')` que generaba uno local, y dos pestañas creando a la vez
  /// podían chocar.
  Future<Course> createCourse({
    required String name,
    String? laboratoryId,
    bool isOpenLearning = false,
  }) async {
    final json = await api.post('/courses', body: {
      'name': name,
      'laboratoryId': laboratoryId,
      'isOpenLearning': isOpenLearning,
    });
    final course = Course.fromJson(Map<String, dynamic>.from(json as Map));
    await reloadCoursesWithStats();
    return course;
  }

  Future<Course> updateCourse(String id, Map<String, dynamic> changes) async {
    final json = await api.patch('/courses/$id', body: changes);
    final course = Course.fromJson(Map<String, dynamic>.from(json as Map));
    await _refreshAfterCourseMutation(id);
    return course;
  }

  /// Publica el curso.
  ///
  /// El servidor comprueba que no queden lecciones a medio construir —una de
  /// video sin enlace ni archivo, por ejemplo— y responde 409 con el detalle
  /// de QUÉ falta. Ese detalle es justo lo que la pantalla necesita mostrar.
  Future<Course> publishCourse(String id) async {
    final json = await api.post('/courses/$id/publish');
    final course = Course.fromJson(Map<String, dynamic>.from(json as Map));
    await _refreshAfterCourseMutation(id);
    return course;
  }

  Future<Course> archiveCourse(String id) async {
    final json = await api.post('/courses/$id/archive');
    final course = Course.fromJson(Map<String, dynamic>.from(json as Map));
    await _refreshAfterCourseMutation(id);
    return course;
  }

  /// Vuelve a pedir el detalle después de escribir sobre el curso.
  ///
  /// **No** se guarda en caché lo que devuelve la escritura: esa respuesta es
  /// la fila del curso a secas —sin módulos, sin lecciones y sin
  /// categorización— y ponerla donde estaba el detalle completo vaciaba el
  /// constructor apenas se guardaba cualquier campo. El curso seguía entero en
  /// la base; lo que se rompía era la copia del cliente.
  Future<void> _refreshAfterCourseMutation(String id) async {
    await reloadCourse(id);
    await reloadCoursesWithStats();
  }

  /// Borra un curso.
  ///
  /// Si está vinculado a una Ruta o tiene estudiantes con avance, el servidor
  /// responde 409 con el detalle: borrarlo dejaría el progreso huérfano y el
  /// módulo de la fase bloqueado en silencio para todo el laboratorio.
  Future<void> deleteCourse(String id) async {
    await api.delete('/courses/$id');
    _courseById.remove(id);
    _courseStats.remove(id);
    _courseStudents.remove(id);
    await reloadCoursesWithStats();
  }

  AsyncValue<Catalogs> _catalogs = const AsyncValue.idle();

  /// Competencias Enactus y ODS, tal como están en la base.
  ///
  /// No son constantes de Dart: eran dos listas duplicadas —una acá, otra en
  /// PostgreSQL— que se iban separando en silencio. Son 12 y 17 filas que no
  /// cambian entre despliegues, así que se piden una vez por sesión.
  AsyncValue<Catalogs> get catalogs {
    _lazy(_catalogs, (v) => _catalogs = v, () async {
      final json = await api.get('/catalogs');
      return Catalogs.fromJson(Map<String, dynamic>.from(json as Map));
    });
    return _catalogs;
  }

  AsyncValue<List<University>> _universities = const AsyncValue.idle();

  /// El catálogo de universidades, para los desplegables.
  ///
  /// Se pide una vez por sesión, como los otros catálogos. Solo trae las
  /// activas: una inactiva —«Sin asignar» lo es— no debe aparecer como opción,
  /// porque alguien la elegiría por estar ahí y el servidor la rechazaría de
  /// todas formas.
  AsyncValue<List<University>> get universities {
    _lazy(_universities, (v) => _universities = v, () async {
      final json = await api.get('/universities');
      final mapa = Map<String, dynamic>.from(json as Map);
      return (mapa['data'] as List? ?? const [])
          .map((e) => University.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    });
    return _universities;
  }

  /// La universidad por su id, o `null` si no está en el catálogo cargado.
  ///
  /// Devuelve `null` en vez de inventar un nombre: una universidad que no está
  /// puede ser una inactiva, y mostrarla como si fuera normal es lo que este
  /// trabajo viene a evitar.
  University? universityById(String? id) {
    if (id == null || id.isEmpty) return null;
    return _universities.valueOrNull?.where((u) => u.id == id).firstOrNull;
  }

  /// Reemplaza la categorización completa: etiquetas, objetivos, competencias,
  /// ODS, resultados de aprendizaje y prerrequisitos.
  ///
  /// Va en una sola petición porque el editor las presenta como un solo
  /// formulario: guardar unas sí y otras no dejaría el curso a medio describir.
  Future<void> saveCourseMeta(String courseId, CourseMetaDraft meta) async {
    await api.put('/courses/$courseId/meta', body: meta.toJson());
    await reloadCourse(courseId);
  }

  // -------------------------------------------------------------------------
  // Módulos y lecciones
  // -------------------------------------------------------------------------

  Future<void> createModule(String courseId, String title) async {
    await api.post('/courses/$courseId/modules', body: {'title': title});
    await reloadCourse(courseId);
  }

  Future<void> renameModule(
    String moduleId,
    String title, {
    required String courseId,
  }) async {
    await api.patch('/modules/$moduleId', body: {'title': title});
    await reloadCourse(courseId);
  }

  Future<void> deleteModule(String moduleId, {required String courseId}) async {
    await api.delete('/modules/$moduleId');
    await reloadCourse(courseId);
  }

  /// Reordena TODOS los módulos de una vez.
  ///
  /// Un PATCH por módulo no sirve: con `unique(course_id, order_index)` el
  /// intercambio falla en el primer paso. El servidor lo hace en transacción y
  /// en dos pasadas.
  Future<void> reorderModules(
    String courseId,
    List<String> orderedIds,
  ) async {
    await api.put('/courses/$courseId/modules/order',
        body: {'orderedIds': orderedIds});
    await reloadCourse(courseId);
  }

  Future<Lesson> createLesson(
    String moduleId, {
    required String title,
    required String type,
    String description = '',
    int durationMin = 0,
    String? externalUrl,
  }) async {
    final json = await api.post('/modules/$moduleId/lessons', body: {
      'title': title,
      'type': type,
      'description': description,
      'durationMin': durationMin,
      'externalUrl': ?externalUrl,
    });
    return Lesson.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<Lesson> updateLesson(
    String lessonId,
    Map<String, dynamic> changes,
  ) async {
    final json = await api.patch('/lessons/$lessonId', body: changes);
    return Lesson.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<void> deleteLesson(String lessonId, {required String courseId}) async {
    await api.delete('/lessons/$lessonId');
    await reloadCourse(courseId);
  }

  Future<void> reorderLessons(
    String moduleId,
    List<String> orderedIds, {
    required String courseId,
  }) async {
    await api.put('/modules/$moduleId/lessons/order',
        body: {'orderedIds': orderedIds});
    await reloadCourse(courseId);
  }

  // -------------------------------------------------------------------------
  // Autoría de quiz y actividad
  // -------------------------------------------------------------------------

  /// Las preguntas CON su clave de respuestas, para editarlas.
  ///
  /// Es la única lectura de la API que la devuelve, y solo a quien puede editar
  /// el curso. Sin ella, abrir una lección ya hecha mostraría las respuestas en
  /// blanco y el primer guardado borraría la clave.
  Future<List<QuizQuestionDraft>> lessonQuiz(String lessonId) async {
    final json = await api.get('/lessons/$lessonId/quiz');
    final body = Map<String, dynamic>.from(json as Map);
    return (body['questions'] as List? ?? const [])
        .map((e) =>
            QuizQuestionDraft.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Reemplaza las preguntas de la lección.
  ///
  /// Si alguna está incompleta el servidor responde 409 con `problems`: la
  /// lista de TODAS las fallas, no solo la primera.
  Future<void> saveLessonQuiz(
    String lessonId,
    List<QuizQuestionDraft> questions, {
    required String courseId,
  }) async {
    await api.put('/lessons/$lessonId/quiz',
        body: {'questions': questions.map((q) => q.toJson()).toList()});
    await reloadCourse(courseId);
  }

  Future<void> saveLessonActivity(
    String lessonId,
    ActivityDraft activity, {
    required String courseId,
  }) async {
    await api.put('/lessons/$lessonId/activity', body: activity.toJson());
    await reloadCourse(courseId);
  }

  /// Asocia un video externo (YouTube/Vimeo) a la lección.
  Future<void> setLessonExternalVideo(
    String lessonId,
    String url, {
    required String courseId,
  }) async {
    await api.post('/lessons/$lessonId/video-external', body: {'url': url});
    await reloadCourse(courseId);
  }

  /// Confirma el recurso descargable que ya se subió a S3.
  Future<void> setLessonResource(
    String lessonId,
    Map<String, dynamic> uploaded, {
    required String courseId,
  }) async {
    await api.post('/lessons/$lessonId/resource', body: {
      'key': uploaded['s3Key'],
      'fileName': uploaded['fileName'],
      'contentType': uploaded['contentType'],
      'sizeBytes': uploaded['sizeBytes'],
    });
    await reloadCourse(courseId);
  }

  // -------------------------------------------------------------------------
  // Progreso y Ruta de Impacto
  // -------------------------------------------------------------------------

  /// Ruta de Impacto completa del usuario con sesión.
  ///
  /// Un estudiante de Open Learning recibe 403 del servidor, que llega acá
  /// como [ForbiddenError] — no como una lista vacía. La pantalla debe
  /// mostrar ese error, no "todavía no hay laboratorios".
  AsyncValue<RutaProgress> get rutaProgress {
    _lazy(_rutaProgress, (v) => _rutaProgress = v, _fetchRutaProgress);
    return _rutaProgress;
  }

  Future<void> reloadRutaProgress() => _refresh(
        (v) => _rutaProgress = v,
        _fetchRutaProgress,
        _rutaProgress.valueOrNull,
      );

  Future<RutaProgress> _fetchRutaProgress() async {
    final id = _requireUser();
    final json = await api.get('/students/$id/ruta-progress');
    return RutaProgress.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Ruta de Impacto de OTRO estudiante (Mentor, Asesor, LXD, Admin).
  /// No se cachea: son consultas puntuales de seguimiento.
  Future<RutaProgress> rutaProgressOf(String studentId) async {
    final json = await api.get('/students/$studentId/ruta-progress');
    return RutaProgress.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Progreso en un curso, con sus lecciones marcadas.
  ///
  /// Sin [studentId] es el del usuario con sesión — el caso de siempre. Con
  /// [studentId] es el de OTRA persona: lo usan Mentor, Asesor, LXD y Admin
  /// para mirar el avance de un estudiante. El servidor decide si quien
  /// pregunta puede; un estudiante pidiendo el de otro recibe 403.
  AsyncValue<CourseProgress> courseProgress(String courseId,
      {String? studentId}) {
    final key = _progressKey(courseId, studentId);
    final current =
        _courseProgress[key] ?? const AsyncValue<CourseProgress>.idle();
    _lazy(current, (v) => _courseProgress[key] = v,
        () => _fetchCourseProgress(courseId, studentId));
    return _courseProgress[key] ?? current;
  }

  Future<void> reloadCourseProgress(String courseId, {String? studentId}) {
    final key = _progressKey(courseId, studentId);
    return _refresh(
      (v) => _courseProgress[key] = v,
      () => _fetchCourseProgress(courseId, studentId),
      _courseProgress[key]?.valueOrNull,
    );
  }

  /// La caché se indexa por persona: sin eso, abrir el curso de un estudiante
  /// desde el portal del Mentor pisaría el progreso propio del Mentor y al
  /// volver a su portal vería el ajeno.
  String _progressKey(String courseId, String? studentId) =>
      '${studentId ?? _currentUserId}/$courseId';

  Future<CourseProgress> _fetchCourseProgress(
      String courseId, String? studentId) async {
    final id = studentId ?? _requireUser();
    final json = await api.get('/students/$id/course-progress/$courseId');
    return CourseProgress.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Marca o desmarca una lección.
  ///
  /// La respuesta trae el recálculo de curso, módulo, fase y Ruta, así que se
  /// actualiza todo el estado afectado sin pedir nada más. Devuelve el impacto
  /// para que la pantalla pueda, por ejemplo, celebrar que se completó la Ruta.
  Future<ToggleImpact> toggleLesson(String lessonId, String courseId) async {
    final json = await api.post('/progress/lessons/$lessonId/toggle');
    final impact =
        ToggleImpact.fromJson(Map<String, dynamic>.from(json as Map));

    // Progreso del curso: viene en la misma respuesta.
    final course = impact.course;
    if (course != null) {
      // Marcar una lección solo puede hacerlo la propia persona, así que el
      // recálculo se guarda bajo su clave.
      final key = _progressKey(courseId, null);
      final previous = _courseProgress[key]?.valueOrNull;
      final completed = [...?previous?.completedLessonIds];
      if (impact.completed) {
        if (!completed.contains(lessonId)) completed.add(lessonId);
      } else {
        completed.remove(lessonId);
      }
      _courseProgress[key] = AsyncValue.data(CourseProgress(
        courseId: course.courseId,
        courseName: previous?.courseName ?? '',
        totalLessons: course.totalLessons,
        completedLessons: course.completedLessons,
        ratio: course.ratio,
        isComplete: course.isComplete,
        completedLessonIds: completed,
      ));
    }

    // La Ruta cambió hacia arriba: se vuelve a pedir el árbol completo. Es una
    // petición, no cinco, y garantiza que fases y desbloqueos queden exactos.
    if (impact.rutaImpact.isNotEmpty) {
      unawaited(reloadRutaProgress());
    }

    notifyListeners();
    return impact;
  }

  /// Marca una lección como completa **solo si todavía no lo estaba**.
  ///
  /// [toggleLesson] alterna: aprobar un quiz dos veces lo desmarcaría. Acá el
  /// acto es "esto quedó hecho", no "cambiá el estado".
  Future<void> toggleLessonIfPending(String lessonId, String courseId) async {
    final done = _courseProgress[_progressKey(courseId, null)]
            ?.valueOrNull
            ?.isLessonComplete(lessonId) ??
        false;
    if (done) return;
    await toggleLesson(lessonId, courseId);
  }

  /// Marca una lectura o entrega PROPIA de un módulo de la Ruta.
  ///
  /// No pertenece a ningún curso, así que no hay progreso de curso que
  /// actualizar: la respuesta trae el recálculo de módulo, fase y Ruta, y con
  /// eso se vuelve a pedir el árbol completo. `IfPending` y no un toggle:
  /// volver a abrir una lectura no debería desmarcarla.
  Future<void> toggleRutaLessonIfPending(String lessonId) async {
    final alreadyDone = _rutaProgress.valueOrNull?.laboratories.any((lab) =>
            lab.phases.any((phase) => phase.modules.any((module) =>
                module.ownLessons.any((l) => l.id == lessonId && l.isComplete)))) ??
        false;
    if (alreadyDone) return;

    await api.post('/progress/lessons/$lessonId/toggle');
    await reloadRutaProgress();
  }

  /// Envía las respuestas de un quiz y devuelve el resultado.
  ///
  /// **La nota la calcula el servidor.** La clave de respuestas nunca llega al
  /// cliente, así que acá no hay nada que corregir: se mandan las respuestas y
  /// vuelve el puntaje, con qué preguntas estuvieron bien (pero no cuál era la
  /// correcta de las falladas).
  Future<QuizResult> submitQuiz(
    String lessonId,
    Map<String, Object> answers,
  ) async {
    final json = await api.post('/lessons/$lessonId/quiz-attempt',
        body: {'answers': answers});
    return QuizResult.fromJson(Map<String, dynamic>.from(json as Map));
  }

  // -------------------------------------------------------------------------
  // Personas
  // -------------------------------------------------------------------------

  final Map<String, AsyncValue<List<AppUser>>> _usersByQuery = {};

  /// Las personas que el rol con sesión puede ver.
  ///
  /// El alcance lo decide el servidor: un estudiante recibe una lista vacía
  /// porque no tiene directorio de personas, y un filtro **nunca** amplía lo
  /// que a alguien le corresponde ver.
  AsyncValue<List<AppUser>> users({
    String? role,
    String? laboratoryId,
    String? groupId,
    String? companyId,
    /// `team` y/o `progress`: el equipo y el avance general de cada persona,
    /// en dos consultas para toda la página en vez de cuatro por fila.
    String? include,
  }) {
    final query = <String, dynamic>{
      // 100 es el TOPE del servidor (`paginationSchema`), no un número
      // elegido acá: pedir 200 devolvía 400 en cada llamada y dejaba sin
      // datos a todo lo que lista personas. Cuando una lista pase de 100
      // habrá que paginarla de verdad; subir el tope solo correría el
      // problema.
      'pageSize': 100,
      'role': ?role,
      'laboratoryId': ?laboratoryId,
      'groupId': ?groupId,
      'companyId': ?companyId,
      'include': ?include,
    };
    final key = query.entries.map((e) => '${e.key}=${e.value}').join('&');

    final current = _usersByQuery[key] ?? const AsyncValue<List<AppUser>>.idle();
    _lazy(current, (v) => _usersByQuery[key] = v, () async {
      final json = await api.get('/users', query: query);
      return Page.fromJson(
        Map<String, dynamic>.from(json as Map),
        AppUser.fromJson,
      ).data;
    });
    return _usersByQuery[key] ?? current;
  }

  final Map<String, AsyncValue<AppUser>> _userById = {};

  AsyncValue<AppUser> userById(String id) {
    final current = _userById[id] ?? const AsyncValue<AppUser>.idle();
    _lazy(current, (v) => _userById[id] = v, () async {
      final json = await api.get('/users/$id');
      return AppUser.fromJson(Map<String, dynamic>.from(json as Map));
    });
    return _userById[id] ?? current;
  }

  /// Crea una cuenta.
  ///
  /// El servidor decide qué roles puede dar de alta quien pide: un Admin
  /// cualquiera menos superadmin, una Empresa solo LXD y mentores de su
  /// equipo. Acá no se replica esa regla — se muestra el error que devuelve.
  Future<AppUser> createUser(Map<String, dynamic> fields) async {
    final json = await api.post('/users', body: fields);
    final user = AppUser.fromJson(Map<String, dynamic>.from(json as Map));
    _usersByQuery.clear();
    notifyListeners();
    return user;
  }

  Future<AppUser> updateUser(String id, Map<String, dynamic> changes) async {
    final json = await api.patch('/users/$id', body: changes);
    final user = AppUser.fromJson(Map<String, dynamic>.from(json as Map));
    _userById[id] = AsyncValue.data(user);
    _usersByQuery.clear();
    notifyListeners();
    return user;
  }

  Future<void> deleteUser(String id) async {
    await api.delete('/users/$id');
    _userById.remove(id);
    _usersByQuery.clear();
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Asignación de material a un estudiante
  // -------------------------------------------------------------------------

  /// Lo que un estudiante tiene asignado hoy: laboratorios y cursos directos.
  ///
  /// No se cachea a propósito. Es una lectura que se hace al abrir el diálogo
  /// de asignación y que tiene que reflejar lo que otro administrador acabe de
  /// cambiar; un valor viejo acá hace que al guardar se pisen asignaciones
  /// ajenas sin que nadie lo note, porque la escritura es un reemplazo de la
  /// lista completa.
  Future<StudentAssignments> studentAssignments(String studentId) async {
    final json = await api.get('/users/$studentId/assignments');
    return StudentAssignments.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Reemplaza los laboratorios de un estudiante Enactus.
  ///
  /// Es también lo que le da acceso a los CURSOS de esos laboratorios: quitar
  /// uno se lo quita. Su avance no se borra —vuelve tal cual si se reasigna—
  /// pero deja de verlo.
  Future<void> setStudentLaboratories(
    String studentId,
    List<String> laboratoryIds,
  ) async {
    await api.put('/users/$studentId/laboratories', body: {
      'ids': laboratoryIds,
    });
    _usersByQuery.clear();
    _userById.remove(studentId);
    await reloadLaboratories();
    notifyListeners();
  }

  /// Reemplaza los cursos directos de un estudiante de Open Learning.
  ///
  /// Devuelve los cursos que quedaron asignados pero que el estudiante
  /// TODAVÍA no puede ver, por estar en borrador o marcados como no visibles.
  /// Se permite asignarlos —sirve para dejar la matrícula lista antes de
  /// publicar— pero la pantalla tiene que decirlo: una asignación que se
  /// guarda y no se ve, sin aviso, se da por hecha y nadie la revisa.
  Future<List<CourseNotReady>> setStudentCourses(
    String studentId,
    List<String> courseIds,
  ) async {
    final json = await api.put('/users/$studentId/courses', body: {
      'ids': courseIds,
    });
    _usersByQuery.clear();
    _userById.remove(studentId);
    notifyListeners();
    final mapa = Map<String, dynamic>.from(json as Map);
    return (mapa['notReady'] as List? ?? const [])
        .map((e) => CourseNotReady.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Cambia el permiso de calificar de un LXD.
  ///
  /// Son DOS permisos, no uno, y van por su propio endpoint porque cada
  /// cambio queda registrado con quién, a quién y los valores anterior y
  /// nuevo. Por eso no se aceptan en el alta ni en el parcheo general.
  Future<AppUser> setCanGrade(
    String id, {
    bool? openLearning,
    bool? enactus,
  }) async {
    final json = await api.patch('/admin/users/$id/can-grade', body: {
      'canGradeOpenLearning': ?openLearning,
      'canGradeEnactus': ?enactus,
    });
    final user = AppUser.fromJson(Map<String, dynamic>.from(json as Map));
    _userById[id] = AsyncValue.data(user);
    _usersByQuery.clear();
    notifyListeners();
    return user;
  }

  /// Manda un aviso a una o varias personas.
  ///
  /// A quién se le puede escribir lo decide el servidor con los alcances que
  /// ya existen. Nadie recibe el correo de nadie: el aviso llega a la bandeja
  /// dentro de la plataforma.
  Future<int> notify(
    List<String> userIds, {
    required String title,
    String body = '',
  }) async {
    final json = await api.post('/notifications',
        body: {'userIds': userIds, 'title': title, 'body': body});
    final map = Map<String, dynamic>.from(json as Map);
    return (map['sent'] as num?)?.toInt() ?? 0;
  }

  /// Le avisa al equipo de administración sin saber quiénes son.
  ///
  /// Es el canal de "necesito ayuda" de un aliado. Antes esta pantalla buscaba
  /// el correo de un admin en la lista completa de usuarios: esa lista ya no
  /// existe para un aliado, y no debería.
  Future<int> notifyAdmins({
    required String title,
    String body = '',
  }) async {
    final json = await api.post('/notifications/admins',
        body: {'title': title, 'body': body});
    final map = Map<String, dynamic>.from(json as Map);
    return (map['sent'] as num?)?.toInt() ?? 0;
  }

  // -------------------------------------------------------------------------
  // BuscaTalento y métricas de impacto
  // -------------------------------------------------------------------------

  AsyncValue<List<TalentProfile>> _talent = const AsyncValue.idle();

  /// El directorio de talento Enactus, para Donante y Empresa.
  ///
  /// Es el único listado de personas con alcance más ancho que [users]: acá
  /// los dos roles ven a TODOS los estudiantes Enactus, porque la pantalla
  /// existe para descubrir a alguien que todavía no conocen. Trae el perfil
  /// profesional, no los datos de contacto.
  AsyncValue<List<TalentProfile>> get talent {
    _lazy(_talent, (v) => _talent = v, () async {
      final json = await api.get('/talent', query: {'pageSize': 100});
      return Page.fromJson(
        Map<String, dynamic>.from(json as Map),
        TalentProfile.fromJson,
      ).data;
    });
    return _talent;
  }

  AsyncValue<ImpactMetrics> _impactMetrics = const AsyncValue.idle();

  /// Horas por competencia, cobertura de ODS y horas patrocinadas.
  ///
  /// Las tres las calculaba el cliente recorriendo toda la base. Ahora llegan
  /// resueltas y en una sola petición: la pantalla las muestra juntas.
  AsyncValue<ImpactMetrics> get impactMetrics {
    _lazy(_impactMetrics, (v) => _impactMetrics = v, () async {
      final json = await api.get('/admin/metrics');
      return ImpactMetrics.fromJson(Map<String, dynamic>.from(json as Map));
    });
    return _impactMetrics;
  }

  Future<void> reloadImpactMetrics() => _refresh(
        (v) => _impactMetrics = v,
        () async {
          final json = await api.get('/admin/metrics');
          return ImpactMetrics.fromJson(Map<String, dynamic>.from(json as Map));
        },
        _impactMetrics.valueOrNull,
      );

  // -------------------------------------------------------------------------
  // Respaldo y restauración (Admin / Super Admin)
  // -------------------------------------------------------------------------

  /// Descarga el respaldo completo.
  ///
  /// A diferencia del volcado que hacía la versión con Hive, este **no lleva
  /// credenciales**: las contraseñas hasheadas y las sesiones abiertas quedan
  /// fuera. Un respaldo es para restaurar datos, no para llevárselas.
  Future<Map<String, dynamic>> exportBackup() async {
    final json = await api.get('/admin/backup');
    return Map<String, dynamic>.from(json as Map);
  }

  /// Restaura un respaldo. Reemplaza la base entera y es de superadmin.
  Future<Map<String, dynamic>> restoreBackup(
    Map<String, dynamic> payload,
  ) async {
    final json = await api.post('/admin/restore', body: payload);
    final result = Map<String, dynamic>.from(json as Map);
    _resetAll();
    notifyListeners();
    return result;
  }

  // -------------------------------------------------------------------------
  // Seguimiento de un curso (LXD, Mentor, Asesor, Admin)
  // -------------------------------------------------------------------------

  final Map<String, AsyncValue<List<CourseStudent>>> _courseStudents = {};
  final Map<String, AsyncValue<CourseStats>> _courseStats = {};

  /// Los estudiantes de un curso con todo lo que la tabla de seguimiento
  /// muestra: avance, nota promedio, última actividad y comentario. Una sola
  /// petición, no cuatro por fila.
  AsyncValue<List<CourseStudent>> courseStudents(String courseId) {
    final current =
        _courseStudents[courseId] ?? const AsyncValue<List<CourseStudent>>.idle();
    _lazy(current, (v) => _courseStudents[courseId] = v,
        () => _fetchCourseStudents(courseId));
    return _courseStudents[courseId] ?? current;
  }

  Future<void> reloadCourseStudents(String courseId) => _refresh(
        (v) => _courseStudents[courseId] = v,
        () => _fetchCourseStudents(courseId),
        _courseStudents[courseId]?.valueOrNull,
      );

  Future<List<CourseStudent>> _fetchCourseStudents(String courseId) async {
    final json = await api.get('/courses/$courseId/students');
    final map = Map<String, dynamic>.from(json as Map);
    return (map['students'] as List? ?? const [])
        .map((e) => CourseStudent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  AsyncValue<CourseStats> courseStats(String courseId) {
    final current =
        _courseStats[courseId] ?? const AsyncValue<CourseStats>.idle();
    _lazy(current, (v) => _courseStats[courseId] = v, () async {
      final json = await api.get('/courses/$courseId/stats');
      return CourseStats.fromJson(Map<String, dynamic>.from(json as Map));
    });
    return _courseStats[courseId] ?? current;
  }

  /// Guarda el comentario privado sobre un estudiante en un curso.
  /// Hay UNA nota por par: escribir dos veces reemplaza.
  Future<void> saveStaffNote({
    required String courseId,
    required String studentId,
    required String note,
  }) async {
    await api.put('/courses/$courseId/students/$studentId/note',
        body: {'note': note});
    await reloadCourseStudents(courseId);
  }

  // -------------------------------------------------------------------------
  // Laboratorios
  // -------------------------------------------------------------------------

  AsyncValue<List<Laboratory>> get laboratories {
    _lazy(_laboratories, (v) => _laboratories = v, _fetchLaboratories);
    return _laboratories;
  }

  Future<void> reloadLaboratories() => _refresh(
        (v) => _laboratories = v,
        _fetchLaboratories,
        _laboratories.valueOrNull,
      );

  Future<List<Laboratory>> _fetchLaboratories() async {
    final json = await api.get('/laboratories', query: {'pageSize': 100});
    return Page.fromJson(
      Map<String, dynamic>.from(json as Map),
      Laboratory.fromJson,
    ).data;
  }

  AsyncValue<List<Laboratory>> _allLaboratories = const AsyncValue.idle();

  /// TODOS los laboratorios de la red, en versión reducida (nombre,
  /// descripción y cuántos equipos trabajan en el área).
  ///
  /// Es lo que alimenta "otros laboratorios de la red": qué existe, para poder
  /// pedirle uno al administrador. No trae la estructura de la Ruta ni el
  /// avance de nadie — y esos nombres ya salen sin sesión en la portada.
  AsyncValue<List<Laboratory>> get allLaboratories {
    _lazy(_allLaboratories, (v) => _allLaboratories = v, () async {
      final json = await api
          .get('/laboratories', query: {'pageSize': 100, 'scope': 'all'});
      return Page.fromJson(
        Map<String, dynamic>.from(json as Map),
        Laboratory.fromJson,
      ).data;
    });
    return _allLaboratories;
  }

  AsyncValue<Laboratory> labById(String id) {
    final current = _labById[id] ?? const AsyncValue<Laboratory>.idle();
    _lazy(current, (v) => _labById[id] = v, () async {
      final json = await api.get('/laboratories/$id');
      return Laboratory.fromJson(Map<String, dynamic>.from(json as Map));
    });
    return _labById[id] ?? current;
  }

  Future<void> reloadLab(String id) => _refresh(
        (v) => _labById[id] = v,
        () async {
          final json = await api.get('/laboratories/$id');
          return Laboratory.fromJson(Map<String, dynamic>.from(json as Map));
        },
        _labById[id]?.valueOrNull,
      );

  // -------------------------------------------------------------------------
  // Autoría de laboratorios y de la Ruta de Impacto (Admin)
  // -------------------------------------------------------------------------

  /// Crea el laboratorio. El servidor le arma **sus tres fases**: un
  /// laboratorio sin fases no tiene Ruta y nadie podría cursarlo.
  Future<Laboratory> createLab({
    required String name,
    String description = '',
    String objectives = '',
    String? sponsorCompanyId,
  }) async {
    final json = await api.post('/laboratories', body: {
      'name': name,
      'description': description,
      'objectives': objectives,
      'sponsorCompanyId': sponsorCompanyId,
    });
    final lab = Laboratory.fromJson(Map<String, dynamic>.from(json as Map));
    await reloadLaboratories();
    return lab;
  }

  Future<Laboratory> updateLab(String id, Map<String, dynamic> changes) async {
    final json = await api.patch('/laboratories/$id', body: changes);
    final lab = Laboratory.fromJson(Map<String, dynamic>.from(json as Map));
    await _refreshAfterLabMutation(id);
    return lab;
  }

  /// Borrado lógico. Con estudiantes o certificados el servidor responde 409
  /// con cuántos: borrarlo dejaría su avance apuntando a una Ruta inexistente.
  Future<void> deleteLab(String id) async {
    await api.delete('/laboratories/$id');
    _labById.remove(id);
    await reloadLaboratories();
    await reloadAllLaboratories();
  }

  Future<void> setLabMentors(String labId, List<String> mentorIds) async {
    await api.put('/laboratories/$labId/mentors', body: {'ids': mentorIds});
    await _refreshAfterLabMutation(labId);
  }

  /// Reemplaza los estudiantes asignados.
  ///
  /// Ojo con lo que significa: la asignación al laboratorio es también lo que
  /// da acceso a sus CURSOS. Quitar a alguien le quita ese material — su
  /// avance no se borra, pero deja de verlo.
  Future<void> setLabStudents(String labId, List<String> studentIds) async {
    await api.put('/laboratories/$labId/students', body: {'ids': studentIds});
    await _refreshAfterLabMutation(labId);
  }

  Future<void> updatePhase(
    String phaseId,
    Map<String, dynamic> changes, {
    required String labId,
  }) async {
    await api.patch('/phases/$phaseId', body: changes);
    await _refreshAfterLabMutation(labId);
  }

  Future<void> createRutaModule(
    String phaseId,
    String title, {
    required String labId,
  }) async {
    await api.post('/phases/$phaseId/modules', body: {'title': title});
    await _refreshAfterLabMutation(labId);
  }

  Future<void> renameRutaModule(
    String moduleId,
    String title, {
    required String labId,
  }) async {
    await api.patch('/ruta-modules/$moduleId', body: {'title': title});
    await _refreshAfterLabMutation(labId);
  }

  Future<void> deleteRutaModule(
    String moduleId, {
    required String labId,
  }) async {
    await api.delete('/ruta-modules/$moduleId');
    await _refreshAfterLabMutation(labId);
  }

  Future<void> reorderRutaModules(
    String phaseId,
    List<String> orderedIds, {
    required String labId,
  }) async {
    await api.put('/phases/$phaseId/modules/order',
        body: {'orderedIds': orderedIds});
    await _refreshAfterLabMutation(labId);
  }

  /// Vincula cursos completos al módulo.
  ///
  /// Devuelve cuántos objetivos del curso se importaron a la fase: el
  /// servidor los copia al vincular, y la pantalla lo dice en vez de dejar que
  /// aparezcan objetivos nuevos sin explicación.
  Future<int> setRutaModuleCourses(
    String moduleId,
    List<String> courseIds, {
    required String labId,
  }) async {
    final json = await api.put('/ruta-modules/$moduleId/courses',
        body: {'ids': courseIds});
    await _refreshAfterLabMutation(labId);
    final body = Map<String, dynamic>.from(json as Map);
    return (body['importedObjectives'] as num?)?.toInt() ?? 0;
  }

  Future<Lesson> createOwnLesson(
    String moduleId, {
    required String title,
    required String type,
    String description = '',
    int durationMin = 0,
    String? externalUrl,
    required String labId,
  }) async {
    final json = await api.post('/ruta-modules/$moduleId/lessons', body: {
      'title': title,
      'type': type,
      'description': description,
      'durationMin': durationMin,
      'externalUrl': ?externalUrl,
    });
    await _refreshAfterLabMutation(labId);
    return Lesson.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<void> createObjective(
    String phaseId, {
    required String category,
    required String text,
    required String labId,
  }) async {
    await api.post('/phases/$phaseId/objectives',
        body: {'category': category, 'text': text});
    await _refreshAfterLabMutation(labId);
  }

  Future<void> updateObjective(
    String objectiveId,
    Map<String, dynamic> changes, {
    required String labId,
  }) async {
    await api.patch('/objectives/$objectiveId', body: changes);
    await _refreshAfterLabMutation(labId);
  }

  Future<void> deleteObjective(
    String objectiveId, {
    required String labId,
  }) async {
    await api.delete('/objectives/$objectiveId');
    await _refreshAfterLabMutation(labId);
  }

  /// Los cursos que dan el objetivo por cumplido.
  ///
  /// Devuelve `true` si quedó **sin cursos**, que es como decir que no se va a
  /// poder completar nunca — y con él se traba la fase entera. La pantalla lo
  /// avisa; el servidor no lo impide, porque un objetivo a medio armar es un
  /// estado legítimo mientras se edita.
  Future<bool> setObjectiveCourses(
    String objectiveId,
    List<String> courseIds, {
    required String labId,
  }) async {
    final json = await api.put('/objectives/$objectiveId/courses',
        body: {'ids': courseIds});
    await _refreshAfterLabMutation(labId);
    final body = Map<String, dynamic>.from(json as Map);
    return (body['neverCompletable'] as bool?) ?? courseIds.isEmpty;
  }

  /// El detalle del laboratorio se vuelve a pedir después de escribirlo: la
  /// respuesta de una escritura de Ruta no trae la estructura completa.
  Future<void> _refreshAfterLabMutation(String labId) async {
    await reloadLab(labId);
    await reloadLaboratories();
  }

  Future<void> reloadAllLaboratories() => _refresh(
        (v) => _allLaboratories = v,
        () async {
          final json = await api
              .get('/laboratories', query: {'pageSize': 100, 'scope': 'all'});
          return Page.fromJson(
            Map<String, dynamic>.from(json as Map),
            Laboratory.fromJson,
          ).data;
        },
        _allLaboratories.valueOrNull,
      );

  // -------------------------------------------------------------------------
  // Proyectos y equipos
  // -------------------------------------------------------------------------

  AsyncValue<List<Project>> get projects {
    _lazy(_projects, (v) => _projects = v, _fetchProjects);
    return _projects;
  }

  Future<void> reloadProjects() =>
      _refresh((v) => _projects = v, _fetchProjects, _projects.valueOrNull);

  /// Los proyectos con sus ODS y el resumen de sus equipos: es lo que el
  /// directorio necesita para filtrar y contar sin pedir nada más.
  Future<List<Project>> _fetchProjects() async {
    final json = await api
        .get('/projects', query: {'pageSize': 100, 'include': 'ods,teams'});
    return Page.fromJson(
      Map<String, dynamic>.from(json as Map),
      Project.fromJson,
    ).data;
  }

  /// Proyecto con su equipo y el rol de cada integrante.
  AsyncValue<Project> projectById(String id) {
    final current = _projectById[id] ?? const AsyncValue<Project>.idle();
    _lazy(current, (v) => _projectById[id] = v, () async {
      final json = await api.get('/projects/$id');
      return Project.fromJson(Map<String, dynamic>.from(json as Map));
    });
    return _projectById[id] ?? current;
  }

  Future<void> reloadProject(String id) => _refresh(
        (v) => _projectById[id] = v,
        () async {
          final json = await api.get('/projects/$id');
          return Project.fromJson(Map<String, dynamic>.from(json as Map));
        },
        _projectById[id]?.valueOrNull,
      );

  AsyncValue<Group> groupById(String id) {
    final current = _groupById[id] ?? const AsyncValue<Group>.idle();
    _lazy(current, (v) => _groupById[id] = v, () async {
      final json = await api.get('/groups/$id');
      return Group.fromJson(Map<String, dynamic>.from(json as Map));
    });
    return _groupById[id] ?? current;
  }

  AsyncValue<List<Group>> _groups = const AsyncValue.idle();

  AsyncValue<List<Group>> get groups {
    _lazy(_groups, (v) => _groups = v, _fetchGroups);
    return _groups;
  }

  Future<void> reloadGroups() =>
      _refresh((v) => _groups = v, _fetchGroups, _groups.valueOrNull);

  Future<List<Group>> _fetchGroups() async {
    final json = await api.get('/groups', query: {'pageSize': 100});
    return Page.fromJson(
      Map<String, dynamic>.from(json as Map),
      Group.fromJson,
    ).data;
  }

  // -------------------------------------------------------------------------
  // Autoría de proyectos y equipos (Admin, Asesor)
  // -------------------------------------------------------------------------

  Future<Project> createProject(Map<String, dynamic> fields) async {
    final json = await api.post('/projects', body: fields);
    final project = Project.fromJson(Map<String, dynamic>.from(json as Map));
    await reloadProjects();
    return project;
  }

  Future<Project> updateProject(
    String id,
    Map<String, dynamic> changes,
  ) async {
    final json = await api.patch('/projects/$id', body: changes);
    final project = Project.fromJson(Map<String, dynamic>.from(json as Map));
    await reloadProject(id);
    await reloadProjects();
    return project;
  }

  Future<void> deleteProject(String id) async {
    await api.delete('/projects/$id');
    _projectById.remove(id);
    await reloadProjects();
  }

  Future<Group> createGroup(Map<String, dynamic> fields) async {
    final json = await api.post('/groups', body: fields);
    final group = Group.fromJson(Map<String, dynamic>.from(json as Map));
    await reloadGroups();
    return group;
  }

  Future<Group> updateGroup(String id, Map<String, dynamic> changes) async {
    final json = await api.patch('/groups/$id', body: changes);
    final group = Group.fromJson(Map<String, dynamic>.from(json as Map));
    _groupById[id] = AsyncValue.data(group);
    await reloadGroups();
    return group;
  }

  Future<void> deleteGroup(String id) async {
    await api.delete('/groups/$id');
    _groupById.remove(id);
    await reloadGroups();
  }

  /// Reemplaza los integrantes del equipo, cada uno con su rol en el proyecto.
  ///
  /// `members` son mapas `{userId, roleInProject}`: el rol dentro del proyecto
  /// (investigación, finanzas, …) no es el rol de la plataforma.
  Future<void> setGroupMembers(
    String groupId,
    List<Map<String, dynamic>> members,
  ) async {
    await api.put('/groups/$groupId/members', body: {'members': members});
    await reloadGroups();
    final current = _groupById[groupId]?.valueOrNull;
    if (current != null) {
      final json = await api.get('/groups/$groupId');
      _groupById[groupId] =
          AsyncValue.data(Group.fromJson(Map<String, dynamic>.from(json as Map)));
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // Certificados
  // -------------------------------------------------------------------------

  AsyncValue<List<Certificate>> get certificates {
    _lazy(_certificates, (v) => _certificates = v, _fetchCertificates);
    return _certificates;
  }

  Future<void> reloadCertificates() => _refresh(
        (v) => _certificates = v,
        _fetchCertificates,
        _certificates.valueOrNull,
      );

  Future<List<Certificate>> _fetchCertificates() async {
    final json = await api.get('/certificates', query: {'pageSize': 100});
    return Page.fromJson(
      Map<String, dynamic>.from(json as Map),
      Certificate.fromJson,
    ).data;
  }

  /// Emite el certificado de Ruta de Impacto.
  ///
  /// Si la Ruta no está completa, el servidor responde 409 y acá llega como
  /// [ConflictError] con el detalle de QUÉ falta — que es justo lo que la
  /// pantalla necesita para explicarlo.
  Future<Certificate> issueRutaCertificate({
    required String studentId,
    required String laboratoryId,
  }) async {
    final json = await api.post('/certificates/ruta', body: {
      'studentId': studentId,
      'laboratoryId': laboratoryId,
    });
    final cert = Certificate.fromJson(Map<String, dynamic>.from(json as Map));
    await reloadCertificates();
    unawaited(reloadRutaProgress());
    return cert;
  }

  // -------------------------------------------------------------------------
  // Entregas
  // -------------------------------------------------------------------------

  AsyncValue<List<Submission>> get submissions {
    _lazy(_submissions, (v) => _submissions = v, _fetchSubmissions);
    return _submissions;
  }

  Future<void> reloadSubmissions() => _refresh(
        (v) => _submissions = v,
        _fetchSubmissions,
        _submissions.valueOrNull,
      );

  Future<List<Submission>> _fetchSubmissions() async {
    final json = await api.get('/submissions', query: {'pageSize': 100});
    return Page.fromJson(
      Map<String, dynamic>.from(json as Map),
      Submission.fromJson,
    ).data;
  }

  Future<Submission> createSubmission({
    String? courseId,
    String? rutaModuleId,
    String? lessonId,
    required String taskName,
    String comment = '',
    List<Map<String, dynamic>> files = const [],
  }) async {
    final json = await api.post('/submissions', body: {
      'courseId': ?courseId,
      'rutaModuleId': ?rutaModuleId,
      'lessonId': ?lessonId,
      'taskName': taskName,
      'comment': comment,
      'files': files,
    });
    await reloadSubmissions();
    return Submission.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<Submission> gradeSubmission({
    required String submissionId,
    required String gradingMode,
    double? grade,
    String feedback = '',
  }) async {
    final json = await api.post('/submissions/$submissionId/grade', body: {
      'gradingMode': gradingMode,
      'grade': grade,
      'feedback': feedback,
    });
    await reloadSubmissions();
    return Submission.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// El Mentor comenta, sin poner nota.
  Future<Submission> reviewSubmission({
    required String submissionId,
    required String feedback,
  }) async {
    final json = await api
        .post('/submissions/$submissionId/review', body: {'feedback': feedback});
    await reloadSubmissions();
    return Submission.fromJson(Map<String, dynamic>.from(json as Map));
  }

  // -------------------------------------------------------------------------
  // Notificaciones
  // -------------------------------------------------------------------------

  AsyncValue<List<AppNotification>> get notifications {
    _lazy(_notifications, (v) => _notifications = v, _fetchNotifications);
    return _notifications;
  }

  int get unreadNotifications => _unreadNotifications;

  Future<void> reloadNotifications() => _refresh(
        (v) => _notifications = v,
        _fetchNotifications,
        _notifications.valueOrNull,
      );

  Future<List<AppNotification>> _fetchNotifications() async {
    final json = await api.get('/notifications', query: {'pageSize': 50});
    final map = Map<String, dynamic>.from(json as Map);
    _unreadNotifications = (map['unread'] as num?)?.toInt() ?? 0;
    return Page.fromJson(map, AppNotification.fromJson).data;
  }

  Future<void> markNotificationsRead() async {
    await api.post('/notifications/read');
    _unreadNotifications = 0;
    await reloadNotifications();
  }

  // -------------------------------------------------------------------------
  // Calendario
  // -------------------------------------------------------------------------

  AsyncValue<List<CalendarEvent>> get calendarEvents {
    _lazy(_calendarEvents, (v) => _calendarEvents = v, _fetchCalendarEvents);
    return _calendarEvents;
  }

  Future<void> reloadCalendarEvents() => _refresh(
        (v) => _calendarEvents = v,
        _fetchCalendarEvents,
        _calendarEvents.valueOrNull,
      );

  Future<List<CalendarEvent>> _fetchCalendarEvents() async {
    // 100 es el tope del servidor. Con 200 respondía 400 y el calendario
    // quedaba vacío en los cuatro portales que lo muestran.
    final json = await api.get('/calendar-events', query: {'pageSize': 100});
    return Page.fromJson(
      Map<String, dynamic>.from(json as Map),
      CalendarEvent.fromJson,
    ).data;
  }

  Future<void> saveCalendarEvent(CalendarEvent event, {String? id}) async {
    if (id == null) {
      await api.post('/calendar-events', body: event.toJson());
    } else {
      await api.patch('/calendar-events/$id', body: event.toJson());
    }
    await reloadCalendarEvents();
  }

  Future<void> deleteCalendarEvent(String id) async {
    await api.delete('/calendar-events/$id');
    await reloadCalendarEvents();
  }

  // -------------------------------------------------------------------------
  // Foro
  // -------------------------------------------------------------------------

  AsyncValue<List<ForumPost>> get forumPosts {
    _lazy(_forumPosts, (v) => _forumPosts = v, _fetchForumPosts);
    return _forumPosts;
  }

  Future<void> reloadForumPosts() => _refresh(
        (v) => _forumPosts = v,
        _fetchForumPosts,
        _forumPosts.valueOrNull,
      );

  Future<List<ForumPost>> _fetchForumPosts() async {
    final json = await api.get('/forum-posts', query: {'pageSize': 50});
    return Page.fromJson(
      Map<String, dynamic>.from(json as Map),
      ForumPost.fromJson,
    ).data;
  }

  /// Cifras del encabezado. Las calcula el servidor: antes eran agregados que
  /// recorrían todas las publicaciones y todos los usuarios en memoria.
  AsyncValue<ForumStats> get forumStats {
    _lazy(_forumStats, (v) => _forumStats = v, () async {
      final json = await api.get('/forum-posts/stats');
      return ForumStats.fromJson(Map<String, dynamic>.from(json as Map));
    });
    return _forumStats;
  }

  AsyncValue<ForumPost> forumPostById(String id) {
    final current = _forumPostById[id] ?? const AsyncValue<ForumPost>.idle();
    _lazy(current, (v) => _forumPostById[id] = v, () async {
      final json = await api.get('/forum-posts/$id');
      return ForumPost.fromJson(Map<String, dynamic>.from(json as Map));
    });
    return _forumPostById[id] ?? current;
  }

  Future<void> createForumPost(String body, String category) async {
    await api.post('/forum-posts', body: {'body': body, 'category': category});
    _forumStats = const AsyncValue.idle();
    await reloadForumPosts();
  }

  Future<void> replyToForumPost(String postId, String body) async {
    await api.post('/forum-posts/$postId/replies', body: {'body': body});
    _forumPostById.remove(postId);
    await reloadForumPosts();
  }

  Future<void> toggleForumLike(String postId) async {
    await api.post('/forum-posts/$postId/like');
    await reloadForumPosts();
  }

  Future<void> toggleForumPin(String postId) async {
    await api.post('/forum-posts/$postId/pin');
    await reloadForumPosts();
  }

  Future<void> deleteForumPost(String postId) async {
    await api.delete('/forum-posts/$postId');
    _forumPostById.remove(postId);
    await reloadForumPosts();
  }

  // -------------------------------------------------------------------------
  // Recursos de comunicaciones y evidencias
  // -------------------------------------------------------------------------

  AsyncValue<List<CommunicationResource>> get communicationResources {
    _lazy(_commResources, (v) => _commResources = v, _fetchCommResources);
    return _commResources;
  }

  Future<void> reloadCommunicationResources() => _refresh(
        (v) => _commResources = v,
        _fetchCommResources,
        _commResources.valueOrNull,
      );

  Future<List<CommunicationResource>> _fetchCommResources() async {
    final json =
        await api.get('/communication-resources', query: {'pageSize': 100});
    return Page.fromJson(
      Map<String, dynamic>.from(json as Map),
      CommunicationResource.fromJson,
    ).data;
  }

  AsyncValue<List<Evidence>> get evidences {
    _lazy(_evidences, (v) => _evidences = v, _fetchEvidences);
    return _evidences;
  }

  Future<void> reloadEvidences() =>
      _refresh((v) => _evidences = v, _fetchEvidences, _evidences.valueOrNull);

  Future<List<Evidence>> _fetchEvidences() async {
    final json = await api.get('/evidences', query: {'pageSize': 100});
    return Page.fromJson(
      Map<String, dynamic>.from(json as Map),
      Evidence.fromJson,
    ).data;
  }

  Future<Evidence> createEvidence(Map<String, dynamic> fields) async {
    final json = await api.post('/evidences', body: fields);
    final evidence = Evidence.fromJson(Map<String, dynamic>.from(json as Map));
    await reloadEvidences();
    return evidence;
  }

  Future<Evidence> updateEvidence(
    String id,
    Map<String, dynamic> changes,
  ) async {
    final json = await api.patch('/evidences/$id', body: changes);
    final evidence = Evidence.fromJson(Map<String, dynamic>.from(json as Map));
    await reloadEvidences();
    return evidence;
  }

  Future<void> deleteEvidence(String id) async {
    await api.delete('/evidences/$id');
    await reloadEvidences();
  }

  Future<CommunicationResource> createCommunicationResource(
    Map<String, dynamic> fields,
  ) async {
    final json = await api.post('/communication-resources', body: fields);
    final resource =
        CommunicationResource.fromJson(Map<String, dynamic>.from(json as Map));
    await reloadCommunicationResources();
    return resource;
  }

  Future<void> deleteCommunicationResource(String id) async {
    await api.delete('/communication-resources/$id');
    await reloadCommunicationResources();
  }

  // -------------------------------------------------------------------------
  // Contenido público de la portada
  // -------------------------------------------------------------------------

  /// Contenido de la página principal. Es el único dato que NO necesita
  /// sesión: la portada se ve sin entrar.
  AsyncValue<SiteContent> get siteContent {
    _lazy(_siteContent, (v) => _siteContent = v, _fetchSiteContent);
    return _siteContent;
  }

  Future<void> reloadSiteContent() => _refresh(
        (v) => _siteContent = v,
        _fetchSiteContent,
        _siteContent.valueOrNull,
      );

  Future<SiteContent> _fetchSiteContent() async {
    // Sin sesión: es el único endpoint público además de `/health`.
    final json = await api.get('/site-content', authenticated: false);
    return SiteContent.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Edita la portada. Solo Admin; el servidor lo comprueba.
  ///
  /// Se recarga en vez de guardar la respuesta: el `PATCH` devuelve la fila de
  /// configuración a secas, sin los laboratorios ni la galería firmada, y
  /// ponerla donde estaba el contenido completo dejaría la portada sin ellos
  /// hasta la próxima recarga.
  Future<void> saveSiteContent(Map<String, dynamic> changes) async {
    await api.patch('/site-content', body: changes);
    await reloadSiteContent();
  }

  /// Agrega una imagen ya subida a la galería de la portada.
  Future<void> addGalleryImage(String s3Key) async {
    await api.post('/site-content/gallery', body: {'s3Key': s3Key});
    await reloadSiteContent();
  }

  Future<void> removeGalleryImage(String imageId) async {
    await api.delete('/site-content/gallery/$imageId');
    await reloadSiteContent();
  }

  // -------------------------------------------------------------------------
  // Archivos
  // -------------------------------------------------------------------------

  final Map<String, AsyncValue<String>> _fileUrls = {};

  /// Cuándo vence cada URL firmada. Se guarda un poco antes del vencimiento
  /// real para no entregar una URL que caduque mientras carga la imagen.
  final Map<String, DateTime> _fileUrlExpiry = {};

  /// URL firmada para mostrar o descargar un archivo de S3.
  ///
  /// El servidor decide si esta persona puede leer esa key —resolviéndola
  /// contra la fila que la referencia— así que un archivo ajeno llega acá como
  /// [NotFoundError] o [ForbiddenError], nunca como una imagen rota silenciosa.
  ///
  /// La URL dura una hora. Al vencer se vuelve a pedir sola: una pestaña
  /// abierta toda la tarde no se queda con avatares muertos.
  AsyncValue<String> fileUrl(String? s3Key) {
    if (s3Key == null || s3Key.isEmpty) {
      return const AsyncValue.idle();
    }

    final expiry = _fileUrlExpiry[s3Key];
    if (expiry != null && DateTime.now().isAfter(expiry)) {
      _fileUrls.remove(s3Key);
      _fileUrlExpiry.remove(s3Key);
    }

    final current = _fileUrls[s3Key] ?? const AsyncValue<String>.idle();
    _lazy(current, (v) => _fileUrls[s3Key] = v, () async {
      final json = await api.post('/files/download-url', body: {'key': s3Key});
      final info = Map<String, dynamic>.from(json as Map);
      final seconds = (info['expiresInSeconds'] as num?)?.toInt() ?? 3600;
      _fileUrlExpiry[s3Key] =
          DateTime.now().add(Duration(seconds: (seconds * 0.9).round()));
      return info['url'] as String;
    });
    return _fileUrls[s3Key] ?? current;
  }

  final Map<String, AsyncValue<String>> _videoUrls = {};
  final Map<String, DateTime> _videoUrlExpiry = {};

  /// URL firmada de CloudFront para reproducir el video PROPIO de una lección.
  ///
  /// No pasa por [fileUrl] a propósito: el servidor rechaza con 400 cualquier
  /// key de video en `/files/download-url` —servir video desde S3 firmado
  /// cuesta varias veces más que por CDN— y expone `GET /lessons/:id/video-url`
  /// como único camino.
  ///
  /// Vence en 5 minutos, mucho antes que un archivo normal, así que se
  /// refresca sola. Alcanza igual: CloudFront valida la firma al abrir la
  /// conexión, no durante la reproducción, así que un video de una hora se ve
  /// entero con una URL de cinco minutos.
  AsyncValue<String> lessonVideoUrl(String lessonId) {
    final expiry = _videoUrlExpiry[lessonId];
    if (expiry != null && DateTime.now().isAfter(expiry)) {
      _videoUrls.remove(lessonId);
      _videoUrlExpiry.remove(lessonId);
    }

    final current = _videoUrls[lessonId] ?? const AsyncValue<String>.idle();
    _lazy(current, (v) => _videoUrls[lessonId] = v, () async {
      final json = await api.get('/lessons/$lessonId/video-url');
      final info = Map<String, dynamic>.from(json as Map);
      final seconds = (info['expiresInSeconds'] as num?)?.toInt() ?? 300;
      _videoUrlExpiry[lessonId] =
          DateTime.now().add(Duration(seconds: (seconds * 0.9).round()));
      return info['url'] as String;
    });
    return _videoUrls[lessonId] ?? current;
  }

  /// Vuelve a pedir la URL del video. Lo usa el botón de reintentar del
  /// reproductor: sin esto, un fallo de red dejaría la lección muerta hasta
  /// recargar la página entera.
  Future<void> reloadLessonVideoUrl(String lessonId) {
    _videoUrls.remove(lessonId);
    _videoUrlExpiry.remove(lessonId);
    notifyListeners();
    return Future.value();
  }

  /// La misma URL, pero para quien necesita esperar el valor: descargar un
  /// adjunto al tocar un botón, por ejemplo, donde no hay estado que mostrar.
  Future<String> resolveFileUrl(String s3Key) async {
    final cached = _fileUrls[s3Key]?.valueOrNull;
    final expiry = _fileUrlExpiry[s3Key];
    if (cached != null && expiry != null && DateTime.now().isBefore(expiry)) {
      return cached;
    }
    final json = await api.post('/files/download-url', body: {'key': s3Key});
    final info = Map<String, dynamic>.from(json as Map);
    final seconds = (info['expiresInSeconds'] as num?)?.toInt() ?? 3600;
    final url = info['url'] as String;
    _fileUrls[s3Key] = AsyncValue.data(url);
    _fileUrlExpiry[s3Key] =
        DateTime.now().add(Duration(seconds: (seconds * 0.9).round()));
    return url;
  }

  /// Sube un archivo en los tres pasos: pedir permiso, subir directo a S3,
  /// devolver los metadatos para adjuntarlos donde correspondan.
  ///
  /// El archivo NUNCA pasa por la API — API Gateway corta en 10 MB.
  Future<Map<String, dynamic>> uploadFile({
    required String purpose,
    required String fileName,
    required String contentType,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  }) async {
    final signed = await api.post('/files/upload-url', body: {
      'purpose': purpose,
      'fileName': fileName,
      'contentType': contentType,
      'sizeBytes': bytes.length,
    });
    final info = Map<String, dynamic>.from(signed as Map);

    await api.uploadToSignedUrl(
      uploadUrl: info['uploadUrl'] as String,
      bytes: bytes,
      contentType: contentType,
      onProgress: onProgress,
    );

    return {
      's3Key': info['key'],
      'fileName': fileName,
      'contentType': contentType,
      'sizeBytes': bytes.length,
    };
  }

  // -------------------------------------------------------------------------
  // Mecánica de carga
  // -------------------------------------------------------------------------

  String _requireUser() {
    final id = _currentUserId;
    if (id == null) {
      throw const AuthError('No hay una sesión activa.');
    }
    return id;
  }

  /// Dispara el pedido la primera vez que alguien lee el getter.
  ///
  /// Pasa a `loading` de forma SÍNCRONA y sin notificar —para que la misma
  /// construcción ya vea el esqueleto y para que un segundo acceso no dispare
  /// otro pedido— y deja el `notifyListeners` para cuando responda la red.
  void _lazy<T>(
    AsyncValue<T> current,
    void Function(AsyncValue<T>) set,
    Future<T> Function() fetch,
  ) {
    if (current is! AsyncIdle<T>) return;
    set(AsyncValue<T>.loading());
    scheduleMicrotask(() => _load<T>(set, fetch, null));
  }

  /// Vuelve a pedir un dato, conservando el anterior mientras llega. Es lo que
  /// usa el botón "Reintentar" de [ErrorState].
  Future<void> _refresh<T>(
    void Function(AsyncValue<T>) set,
    Future<T> Function() fetch,
    T? previous,
  ) async {
    set(AsyncValue.loading(previous: previous));
    notifyListeners();
    await _load(set, fetch, previous);
  }

  Future<void> _load<T>(
    void Function(AsyncValue<T>) set,
    Future<T> Function() fetch,
    T? previous,
  ) async {
    try {
      set(AsyncValue.data(await fetch()));
    } on ApiException catch (e) {
      // El error se GUARDA en el estado, no se traga: la pantalla lo muestra
      // con su botón de reintentar. Un 403 llega como error, nunca como una
      // lista vacía.
      set(AsyncValue.error(e, previous: previous));
    } catch (e, stack) {
      // Algo que no es un error de la API: casi siempre una respuesta con una
      // forma distinta a la esperada. Se registra completo y se muestra como
      // error de servidor, en vez de tumbar la pantalla.
      debugPrint('DataProvider: error inesperado — $e\n$stack');
      set(AsyncValue.error(
        ServerError(0, 'Recibimos una respuesta inesperada del servidor.'),
        previous: previous,
      ));
    }
    notifyListeners();
  }
}
