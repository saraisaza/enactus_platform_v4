import 'dart:async';

import 'package:flutter/foundation.dart';

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
    // `_siteContent` NO se limpia: es público y no depende de quién mire.
    _unreadNotifications = 0;
    _courseById.clear();
    _projectById.clear();
    _labById.clear();
    _groupById.clear();
    _forumPostById.clear();
    _courseProgress.clear();
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
      if (courseId != null) 'courseId': courseId,
      if (rutaModuleId != null) 'rutaModuleId': rutaModuleId,
      if (lessonId != null) 'lessonId': lessonId,
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
    final json = await api.get('/calendar-events', query: {'pageSize': 200});
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
    final json = await api.get('/site-content');
    return SiteContent.fromJson(Map<String, dynamic>.from(json as Map));
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
