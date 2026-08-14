import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/db_service.dart';
import '../utils/constants.dart';

/// Estado global de datos: expone todas las entidades y las operaciones CRUD.
///
/// Toda mutación pasa por aquí y notifica a la UI. Al migrar a AWS, esta capa
/// se conecta a la API en lugar de a Hive sin tocar las vistas.
class DataProvider extends ChangeNotifier {
  final DbService db;
  DataProvider(this.db);

  static final _rnd = Random();
  String newId(String prefix) =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_rnd.nextInt(9999)}';

  // ---------------- Usuarios ----------------
  List<AppUser> get users =>
      db.getAll('users').map(AppUser.fromJson).toList();

  List<AppUser> usersByRole(String role) =>
      users.where((u) => u.role == role).toList();

  /// Estudiantes Y Alumni juntos: un Alumni tiene exactamente el mismo
  /// acceso que un estudiante (ver [Roles.isStudentLike]), así que en
  /// cualquier consulta donde antes solo importaban los estudiantes
  /// (laboratorios, cursos, entregas, certificados, foro, BuscaTalento,
  /// rosters de Asesor/Empresa/Donante/Mentor/LXD), ahora cuentan ambos.
  List<AppUser> get studentsAndAlumni =>
      users.where((u) => Roles.isStudentLike(u.role)).toList();

  AppUser? userById(String id) {
    final j = db.get('users', id);
    return j == null ? null : AppUser.fromJson(j);
  }

  AppUser? findByCredentials(String email, String password) {
    try {
      return users.firstWhere((u) =>
          u.email.toLowerCase() == email.trim().toLowerCase() &&
          u.password == password);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(AppUser u) async {
    await db.put('users', u.id, u.toJson());
    notifyListeners();
  }

  Future<void> deleteUser(String id) async {
    await db.delete('users', id);
    notifyListeners();
  }

  // ---------------- Proyectos ----------------
  List<Project> get projects =>
      db.getAll('projects').map(Project.fromJson).toList();

  Project? projectById(String id) {
    final j = db.get('projects', id);
    return j == null ? null : Project.fromJson(j);
  }

  Future<void> saveProject(Project p) async {
    await db.put('projects', p.id, p.toJson());
    notifyListeners();
  }

  Future<void> deleteProject(String id) async {
    await db.delete('projects', id);
    notifyListeners();
  }

  /// Proyectos reales de un conjunto de estudiantes (vía su equipo/grupo),
  /// sin duplicados — la fuente única para "mis proyectos" en Mentor, LXD
  /// y Empresa, cada uno con su propio criterio de "mis estudiantes".
  List<Project> projectsForStudents(List<AppUser> students) {
    final projectIds = <String>{};
    for (final s in students) {
      final group = groupById(s.groupId);
      if (group != null) projectIds.add(group.projectId);
    }
    return projectIds.map(projectById).whereType<Project>().toList();
  }

  // ---------------- Grupos ----------------
  List<Group> get groups => db.getAll('groups').map(Group.fromJson).toList();

  Group? groupById(String? id) {
    if (id == null) return null;
    final j = db.get('groups', id);
    return j == null ? null : Group.fromJson(j);
  }

  Future<void> saveGroup(Group g) async {
    await db.put('groups', g.id, g.toJson());
    notifyListeners();
  }

  Future<void> deleteGroup(String id) async {
    await db.delete('groups', id);
    notifyListeners();
  }

  // ---------------- Laboratorios ----------------
  List<Laboratory> get labs =>
      db.getAll('labs').map(Laboratory.fromJson).toList();

  Laboratory? labById(String? id) {
    if (id == null || id.isEmpty) return null;
    final j = db.get('labs', id);
    return j == null ? null : Laboratory.fromJson(j);
  }

  Future<void> saveLab(Laboratory l) async {
    await db.put('labs', l.id, l.toJson());
    notifyListeners();
  }

  Future<void> deleteLab(String id) async {
    await db.delete('labs', id);
    notifyListeners();
  }

  // ---------------- Cursos ----------------
  List<Course> get courses =>
      db.getAll('courses').map(Course.fromJson).toList();

  Course? courseById(String id) {
    final j = db.get('courses', id);
    return j == null ? null : Course.fromJson(j);
  }

  List<Course> coursesByLab(String labId) =>
      courses.where((c) => c.labId == labId).toList();

  /// Si un estudiante tiene acceso a un curso. Enactus: automático — todo
  /// curso de un laboratorio que tenga asignado (no hace falta asignar el
  /// curso aparte). Open Learning: solo los cursos asignados directamente.
  bool studentHasCourse(AppUser student, Course course) {
    if (student.studentType == StudentType.openLearning) {
      return student.courseIds.contains(course.id);
    }
    return course.labId.isNotEmpty && student.labIds.contains(course.labId);
  }

  List<Course> coursesForStudent(AppUser student) =>
      courses.where((c) => studentHasCourse(student, c)).toList();

  Future<void> saveCourse(Course c) async {
    await db.put('courses', c.id, c.toJson());
    notifyListeners();
  }

  Future<void> deleteCourse(String id) async {
    await db.delete('courses', id);
    notifyListeners();
  }

  // ---------------- Progreso ----------------
  Progress progressFor(String studentId, String courseId) {
    final j = db.get('progress', '$studentId::$courseId');
    return j == null
        ? Progress(studentId: studentId, courseId: courseId)
        : Progress.fromJson(j);
  }

  /// Progreso 0..1 de un estudiante en un curso.
  double courseProgress(String studentId, Course course) {
    final total = course.lessonCount;
    if (total == 0) return 0;
    final done = progressFor(studentId, course.id).completedLessonIds.length;
    return (done / total).clamp(0.0, 1.0);
  }

  /// Progreso promedio 0..1 de un estudiante en todos sus cursos.
  double overallProgress(AppUser student) {
    final cs = coursesForStudent(student);
    if (cs.isEmpty) return 0;
    final sum =
        cs.fold<double>(0, (acc, c) => acc + courseProgress(student.id, c));
    return sum / cs.length;
  }

  Future<void> toggleLesson(
      String studentId, String courseId, String lessonId) async {
    final p = progressFor(studentId, courseId);
    if (p.completedLessonIds.contains(lessonId)) {
      p.completedLessonIds.remove(lessonId);
    } else {
      p.completedLessonIds.add(lessonId);
    }
    p.updatedAt = DateTime.now();
    await db.put('progress', p.id, p.toJson());
    notifyListeners();
  }

  /// Marca una lección como completada sin alternar (a diferencia de
  /// [toggleLesson]): la usa la calificación de actividades, donde revisar
  /// una entrega nunca debe des-completar la lección si ya lo estaba.
  Future<void> markLessonComplete(
      String studentId, String courseId, String lessonId) async {
    final p = progressFor(studentId, courseId);
    if (p.completedLessonIds.contains(lessonId)) return;
    p.completedLessonIds.add(lessonId);
    p.updatedAt = DateTime.now();
    await db.put('progress', p.id, p.toJson());
    notifyListeners();
  }

  // ---------------- Ruta de Impacto ----------------

  /// Progreso de un estudiante en la Ruta de Impacto de UN laboratorio.
  RutaProgress rutaProgressFor(String studentId, String labId) {
    final j = db.get('ruta_progress', '$studentId::$labId');
    return j == null
        ? RutaProgress(studentId: studentId, labId: labId)
        : RutaProgress.fromJson(j);
  }

  Future<void> saveRutaProgress(RutaProgress p) async {
    await db.put('ruta_progress', p.id, p.toJson());
    notifyListeners();
  }

  /// Marca/desmarca una entrega o lectura propia de un módulo de la Ruta
  /// de Impacto (distinto de las lecciones de un curso: ver [toggleLesson]).
  Future<void> toggleOwnLesson(
      String studentId, String labId, String lessonId) async {
    final p = rutaProgressFor(studentId, labId);
    if (p.completedOwnLessonIds.contains(lessonId)) {
      p.completedOwnLessonIds.remove(lessonId);
    } else {
      p.completedOwnLessonIds.add(lessonId);
    }
    p.updatedAt = DateTime.now();
    await saveRutaProgress(p);
  }

  /// Un objetivo se completa cuando el estudiante completó el 100% de
  /// TODOS los cursos vinculados (si no tiene cursos vinculados aún, no
  /// puede marcarse solo).
  bool isObjectiveComplete(String studentId, Objective o) {
    if (o.sourceCourseIds.isEmpty) return false;
    return o.sourceCourseIds.every((cid) {
      final c = courseById(cid);
      return c != null && courseProgress(studentId, c) >= 1.0;
    });
  }

  /// Un módulo se completa cuando TODAS sus entregas/lecturas propias
  /// están marcadas Y TODOS sus cursos asignados están al 100%. Un módulo
  /// sin ningún componente configurado aún NO cuenta como completo
  /// (evita que un módulo vacío se vea "listo" antes de que el
  /// Administrador lo configure).
  bool isModuleComplete(String studentId, String labId, RutaModule m) {
    if (m.ownLessons.isEmpty && m.courseIds.isEmpty) return false;
    final progress = rutaProgressFor(studentId, labId);
    final ownDone = m.ownLessons
        .every((l) => progress.completedOwnLessonIds.contains(l.id));
    final coursesDone = m.courseIds.every((cid) {
      final c = courseById(cid);
      return c != null && courseProgress(studentId, c) >= 1.0;
    });
    return ownDone && coursesDone;
  }

  /// Una fase se completa cuando tiene al menos un módulo y todos sus
  /// módulos están completos.
  bool isPhaseComplete(String studentId, String labId, Phase phase) =>
      phase.modules.isNotEmpty &&
      phase.modules.every((m) => isModuleComplete(studentId, labId, m));

  /// El primer módulo de una fase (ya desbloqueada) siempre está
  /// desbloqueado; los siguientes requieren que el anterior esté completo.
  bool isModuleUnlocked(String studentId, String labId, Phase phase, int index) {
    if (index <= 0) return true;
    if (index >= phase.modules.length) return false;
    return isModuleComplete(studentId, labId, phase.modules[index - 1]);
  }

  /// Fase 1 siempre desbloqueada; las siguientes requieren que la anterior
  /// esté completa.
  bool isPhaseUnlocked(
      String studentId, String labId, Laboratory lab, int index) {
    if (index <= 0) return true;
    if (index >= lab.phases.length) return false;
    return isPhaseComplete(studentId, labId, lab.phases[index - 1]);
  }

  /// Ruta de Impacto completa (las 3 fases) de un laboratorio para un
  /// estudiante: requisito para emitir el certificado.
  bool isRutaComplete(String studentId, String labId, Laboratory lab) =>
      lab.phases.isNotEmpty &&
      lab.phases.every((p) => isPhaseComplete(studentId, labId, p));

  /// Laboratorios donde el estudiante completó la Ruta de Impacto
  /// completa (candidatos a certificado).
  List<Laboratory> completedLabsForStudent(String studentId) => labs
      .where((l) => l.phases.isNotEmpty)
      .where((l) => isRutaComplete(studentId, l.id, l))
      .toList();

  // ---------------- BuscaTalento (Donantes y Empresas) ----------------

  /// Objetivos de Ruta de Impacto completados por un estudiante, sumando
  /// entre TODOS sus laboratorios y separados por categoría.
  ({int business, int entrepreneurship}) completedObjectivesFor(
      AppUser student) {
    var business = 0;
    var entrepreneurship = 0;
    for (final lab in labsForStudent(student)) {
      for (final phase in lab.phases) {
        for (final o in phase.objectives) {
          if (!isObjectiveComplete(student.id, o)) continue;
          if (o.category == ObjectiveCategory.business) {
            business++;
          } else {
            entrepreneurship++;
          }
        }
      }
    }
    return (business: business, entrepreneurship: entrepreneurship);
  }

  /// Estudiantes Enactus visibles en BuscaTalento (los de Open Learning no
  /// tienen Ruta de Impacto, así que no aplican): primero quienes más
  /// objetivos EMPRESARIALES completaron —ya demostraron competencias de
  /// negocio—, luego por objetivos de emprendimiento y por avance general.
  List<AppUser> talentSearchStudents() {
    final students = studentsAndAlumni
        .where((s) => s.studentType == StudentType.enactus)
        .toList();
    students.sort((a, b) {
      final oa = completedObjectivesFor(a);
      final ob = completedObjectivesFor(b);
      if (ob.business != oa.business) return ob.business.compareTo(oa.business);
      if (ob.entrepreneurship != oa.entrepreneurship) {
        return ob.entrepreneurship.compareTo(oa.entrepreneurship);
      }
      return overallProgress(b).compareTo(overallProgress(a));
    });
    return students;
  }

  // ---------------- Deadlines de fase y alertas ----------------

  /// Ventana de aviso: si faltan estos días o menos para el deadline (y
  /// todavía no venció), la fase cuenta como "próxima a vencer".
  static const deadlineWarningWindow = Duration(days: 3);

  /// Estado del deadline de una fase para un estudiante puntual: una fase
  /// ya completada nunca aparece atrasada, sin importar la fecha.
  DeadlineStatus phaseDeadlineStatus(
      String studentId, String labId, Phase phase) {
    if (phase.deadline.isEmpty) return DeadlineStatus.none;
    final deadline = DateTime.tryParse(phase.deadline);
    if (deadline == null) return DeadlineStatus.none;
    if (isPhaseComplete(studentId, labId, phase)) return DeadlineStatus.none;
    final now = DateTime.now();
    if (now.isAfter(deadline)) return DeadlineStatus.overdue;
    if (deadline.difference(now) <= deadlineWarningWindow) {
      return DeadlineStatus.approaching;
    }
    return DeadlineStatus.onTrack;
  }

  /// Revisa el deadline de cada fase de cada laboratorio y notifica (una
  /// sola vez por fase+estado, ver dedup por título más abajo) a los
  /// estudiantes que aún no la completan y a los Mentores del laboratorio.
  /// Se llama una vez al iniciar la app (ver main.dart) — no hay tareas
  /// programadas en el servidor porque todo vive en Hive local.
  Future<void> checkPhaseDeadlineAlerts() async {
    final now = DateTime.now();
    for (final lab in labs) {
      for (final phase in lab.phases) {
        if (phase.deadline.isEmpty) continue;
        final deadline = DateTime.tryParse(phase.deadline);
        if (deadline == null) continue;
        final overdue = now.isAfter(deadline);
        final approaching =
            !overdue && deadline.difference(now) <= deadlineWarningWindow;
        if (!overdue && !approaching) continue;

        final phaseLabel = phase.title.isEmpty
            ? 'Fase ${lab.phases.indexOf(phase) + 1}'
            : phase.title;
        final deadlineLabel = DateFormat('d MMM yyyy').format(deadline);

        final atRiskStudents = studentsAndAlumni
            .where((s) => s.labIds.contains(lab.id))
            .where((s) => !isPhaseComplete(s.id, lab.id, phase))
            .toList();
        if (atRiskStudents.isEmpty) continue;

        final studentTitle = overdue
            ? '🚨 Fase vencida: ${lab.name} · $phaseLabel'
            : '⏰ Fase próxima a vencer: ${lab.name} · $phaseLabel';
        final studentBody = overdue
            ? 'No completaste "$phaseLabel" antes del $deadlineLabel. Ponte al día lo antes posible.'
            : 'Te queda hasta el $deadlineLabel para completar "$phaseLabel" en ${lab.name}.';
        for (final s in atRiskStudents) {
          if (notificationsFor(s.id).any((n) => n.title == studentTitle)) {
            continue;
          }
          await notify(s.id, studentTitle, studentBody);
        }

        final mentorTitle = overdue
            ? '🚨 Estudiantes atrasados: ${lab.name} · $phaseLabel'
            : '⏰ Deadline próximo: ${lab.name} · $phaseLabel';
        final mentorBody = overdue
            ? '${atRiskStudents.length} estudiante(s) de ${lab.name} no completaron "$phaseLabel" (venció el $deadlineLabel).'
            : '${atRiskStudents.length} estudiante(s) de ${lab.name} todavía no completan "$phaseLabel" (vence el $deadlineLabel).';
        for (final m in mentorsForLab(lab.id)) {
          if (notificationsFor(m.id).any((n) => n.title == mentorTitle)) {
            continue;
          }
          await notify(m.id, mentorTitle, mentorBody);
        }
      }
    }
  }

  // ---------------- Vinculación Curso → Fase → Módulo ----------------
  // Un mismo mecanismo lo usan tanto el Admin (editor de Ruta de Impacto)
  // como el LXD (desde su propio curso), para que la regla quede en un
  // solo lugar.

  /// El último módulo de cada fase es SIEMPRE el módulo de mentoría: se
  /// recalcula tras cualquier cambio (agregar, borrar, reordenar) en vez
  /// de depender de que alguien lo marque a mano.
  void normalizeMentorshipFlags(Phase phase) {
    for (var i = 0; i < phase.modules.length; i++) {
      phase.modules[i].isMentorshipModule = i == phase.modules.length - 1;
    }
  }

  /// Sección 5.4: los objetivos propios de un curso se agregan como
  /// objetivos de la fase a la que se vincula (o se suman al objetivo ya
  /// existente si el texto coincide, para poder exigir "todos los cursos"
  /// en un mismo objetivo).
  void importCourseObjectives(Phase phase, Course course) {
    void importList(List<String> texts, String category) {
      for (final raw in texts) {
        final text = raw.trim();
        if (text.isEmpty) continue;
        Objective? match;
        for (final o in phase.objectives) {
          if (o.category == category && o.text == text) {
            match = o;
            break;
          }
        }
        if (match != null) {
          if (!match.sourceCourseIds.contains(course.id)) {
            match.sourceCourseIds = [...match.sourceCourseIds, course.id];
          }
        } else {
          phase.objectives.add(Objective(
              id: newId('obj'),
              category: category,
              text: text,
              sourceCourseIds: [course.id]));
        }
      }
    }

    importList(course.entrepreneurshipObjectives, ObjectiveCategory.entrepreneurship);
    importList(course.businessObjectives, ObjectiveCategory.business);
  }

  /// Vincula un curso a un módulo específico de una fase de un
  /// laboratorio: lo saca de cualquier otro módulo del mismo laboratorio
  /// (un curso vive en un solo módulo a la vez), lo agrega al módulo
  /// elegido, suma sus objetivos a los de la fase, y si el curso todavía
  /// no tenía laboratorio asignado, lo deja asignado a este. Lo puede usar
  /// tanto el Admin (editor de Ruta de Impacto) como el LXD (desde su
  /// propio curso).
  Future<void> linkCourseToModule({
    required String labId,
    required int phaseIndex,
    required int moduleIndex,
    required String courseId,
  }) async {
    final lab = labById(labId);
    final course = courseById(courseId);
    if (lab == null || course == null) return;
    for (final phase in lab.phases) {
      for (final m in phase.modules) {
        m.courseIds.remove(courseId);
      }
    }
    final targetModule = lab.phases[phaseIndex].modules[moduleIndex];
    if (!targetModule.courseIds.contains(courseId)) {
      targetModule.courseIds = [...targetModule.courseIds, courseId];
    }
    normalizeMentorshipFlags(lab.phases[phaseIndex]);
    importCourseObjectives(lab.phases[phaseIndex], course);
    if (course.labId != labId) {
      course.labId = labId;
      await saveCourse(course);
    }
    await saveLab(lab);
  }

  /// Desvincula un curso de todos los módulos de su laboratorio (el curso
  /// sigue existiendo y sigue perteneciendo al laboratorio, solo deja de
  /// estar dentro de un módulo específico).
  Future<void> unlinkCourseFromModules(String labId, String courseId) async {
    final lab = labById(labId);
    if (lab == null) return;
    for (final phase in lab.phases) {
      for (final m in phase.modules) {
        m.courseIds.remove(courseId);
      }
      normalizeMentorshipFlags(phase);
    }
    await saveLab(lab);
  }

  /// LXD que pertenecen a una empresa aliada (crean cursos que se vuelven
  /// requisito de su laboratorio patrocinado).
  List<AppUser> lxdsForCompany(String companyId) => usersByRole(Roles.lxd)
      .where((u) => u.companyId == companyId)
      .toList();

  /// Cursos creados por cualquiera de los LXD de una empresa aliada, sin
  /// importar en qué laboratorio quedaron (una empresa puede tener varios
  /// LXD y cursos en varios laboratorios distintos a la vez).
  List<Course> coursesForCompany(String companyId) {
    final lxdIds = lxdsForCompany(companyId).map((u) => u.id).toSet();
    return courses.where((c) => lxdIds.contains(c.creatorId)).toList();
  }

  /// Laboratorios de una empresa aliada: automáticos (cursos de sus LXD ya
  /// vinculados a un módulo, igual que el acceso de un estudiante a los
  /// cursos de su lab) MÁS los que un Admin marcó a mano como patrocinados
  /// (Laboratory.sponsorCompanyId) aunque la empresa aún no tenga un LXD
  /// propio ahí — mismo criterio que [sponsoredHoursByCompany], para que el
  /// portal de la empresa nunca muestre menos de lo que ya cuenta el
  /// dashboard del Admin.
  List<Laboratory> labsForCompany(String companyId) {
    final labIds = coursesForCompany(companyId)
        .map((c) => c.labId)
        .where((id) => id.isNotEmpty)
        .toSet();
    return labs
        .where((l) => labIds.contains(l.id) || l.sponsorCompanyId == companyId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// La relación inversa de [labsForCompany]: empresas con presencia real
  /// en un laboratorio (alguno de sus LXD tiene un curso vinculado ahí).
  List<AppUser> companiesForLab(String labId) => usersByRole(Roles.company)
      .where((c) => labsForCompany(c.id).any((l) => l.id == labId))
      .toList();

  // ---------------- Entregas ----------------
  List<Submission> get submissions =>
      db.getAll('submissions').map(Submission.fromJson).toList();

  List<Submission> submissionsForStudent(String studentId) =>
      submissions.where((s) => s.studentId == studentId).toList();

  List<Submission> submissionsForGroup(String groupId) =>
      submissions.where((s) => s.groupId == groupId).toList();

  List<Submission> submissionsForCourse(String courseId) =>
      submissions.where((s) => s.courseId == courseId).toList();

  Future<void> saveSubmission(Submission s) async {
    await db.put('submissions', s.id, s.toJson());
    notifyListeners();
  }

  Future<void> deleteSubmission(String id) async {
    await db.delete('submissions', id);
    notifyListeners();
  }

  // ---------------- Certificados ----------------
  List<Certificate> get certificates =>
      db.getAll('certificates').map(Certificate.fromJson).toList();

  List<Certificate> certificatesForStudent(String studentId) =>
      certificates.where((c) => c.studentId == studentId).toList();

  /// Certificado por completar la Ruta de Impacto COMPLETA de un
  /// laboratorio (las 3 fases) — ya no existe certificado por curso.
  /// Lo emite quien tenga el permiso de calificar activo en ese contexto
  /// (ver [AppUser.canGradeEnactus]).
  Future<Certificate> issueRutaCertificate({
    required AppUser student,
    required Laboratory lab,
    required String issuerName,
  }) async {
    final cert = Certificate(
      id: newId('cert'),
      code: 'ENC-${DateTime.now().year}-${_rnd.nextInt(90000) + 10000}',
      studentId: student.id,
      studentName: student.name,
      labId: lab.id,
      labName: lab.name,
      issuerName: issuerName,
      hours: _rutaHours(lab),
    );
    await db.put('certificates', cert.id, cert.toJson());
    await notify(student.id, 'Nuevo certificado',
        'Recibiste el certificado por completar la Ruta de Impacto de ${lab.name}.');
    notifyListeners();
    return cert;
  }

  /// Suma las horas de todos los cursos únicos asignados a los módulos de
  /// las 3 fases del laboratorio (certificadas si el curso las tiene
  /// configuradas, si no las horas estimadas).
  int _rutaHours(Laboratory lab) {
    final courseIds = <String>{};
    for (final phase in lab.phases) {
      for (final m in phase.modules) {
        courseIds.addAll(m.courseIds);
      }
    }
    return courseIds.fold(0, (sum, cid) {
      final c = courseById(cid);
      return sum + (c == null ? 0 : _courseHours(c));
    });
  }

  // ---------------- Checklist RUTA NATIONAL EXPO ----------------
  ExpoChecklist checklistFor(String groupId) {
    final j = db.get('expo_checklists', groupId);
    return j == null ? ExpoChecklist(groupId: groupId) : ExpoChecklist.fromJson(j);
  }

  Future<void> saveChecklist(ExpoChecklist c) async {
    await db.put('expo_checklists', c.groupId, c.toJson());
    notifyListeners();
  }

  // ---------------- Evidencias ----------------
  List<Evidence> get evidences =>
      db.getAll('evidences').map(Evidence.fromJson).toList();

  List<Evidence> evidencesForDonor(String donorId) =>
      evidences.where((e) => e.donorId == donorId).toList();

  Future<void> saveEvidence(Evidence e) async {
    await db.put('evidences', e.id, e.toJson());
    notifyListeners();
  }

  Future<void> deleteEvidence(String id) async {
    await db.delete('evidences', id);
    notifyListeners();
  }

  // ---------------- Notificaciones ----------------
  List<AppNotification> notificationsFor(String userId) {
    final list = db
        .getAll('notifications')
        .map(AppNotification.fromJson)
        .where((n) => n.userId == userId)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> notify(String userId, String title, String body) async {
    final n = AppNotification(
        id: newId('not'), userId: userId, title: title, body: body);
    await db.put('notifications', n.id, n.toJson());
    notifyListeners();
  }

  Future<void> markNotificationsRead(String userId) async {
    for (final n in notificationsFor(userId)) {
      if (!n.read) {
        n.read = true;
        await db.put('notifications', n.id, n.toJson());
      }
    }
    notifyListeners();
  }

  // ---------------- Foro de la comunidad ----------------
  // Único espacio compartido por Admin, Super Admin, Asesores y
  // estudiantes Enactus: no está aislado por laboratorio, universidad ni
  // empresa (los de Open Learning no participan todavía, por no ser parte
  // de la comunidad Enactus en sí).

  bool canAccessForum(AppUser user) {
    if (Roles.isStudentLike(user.role)) {
      return user.studentType == StudentType.enactus;
    }
    return user.role == Roles.admin ||
        user.role == Roles.superAdmin ||
        user.role == Roles.advisor;
  }

  List<ForumPost> get forumPosts {
    final list = db.getAll('forum_posts').map(ForumPost.fromJson).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> saveForumPost(ForumPost post) async {
    await db.put('forum_posts', post.id, post.toJson());
    notifyListeners();
  }

  Future<void> deleteForumPost(String id) async {
    await db.delete('forum_posts', id);
    notifyListeners();
  }

  ForumPost? forumPostById(String id) {
    final j = db.get('forum_posts', id);
    return j == null ? null : ForumPost.fromJson(j);
  }

  /// Un apoyo por persona por publicación: si ya apoyó, lo retira.
  Future<void> toggleForumLike(String postId, String userId) async {
    final post = forumPostById(postId);
    if (post == null) return;
    if (post.likedBy.contains(userId)) {
      post.likedBy.remove(userId);
    } else {
      post.likedBy.add(userId);
    }
    await saveForumPost(post);
  }

  Future<void> addForumReply(String postId, ForumReply reply) async {
    final post = forumPostById(postId);
    if (post == null) return;
    post.replies.add(reply);
    await saveForumPost(post);
  }

  /// Fijar un anuncio arriba del feed: moderación de Admin/Super Admin,
  /// igual que borrar (ver [canAccessForum] — LXD/Mentor no tienen acceso
  /// al foro hoy, así que no se les da este permiso tampoco).
  Future<void> setForumPinned(String postId, bool pinned) async {
    final post = forumPostById(postId);
    if (post == null) return;
    post.pinned = pinned;
    await saveForumPost(post);
  }

  /// Autores distintos con al menos una publicación en los últimos 7 días
  /// — respalda el eyebrow "`<n>` personas activas esta semana" con un dato
  /// real en vez de un número inventado.
  int activeForumUsersThisWeek() {
    final since = DateTime.now().subtract(const Duration(days: 7));
    return forumPosts
        .where((p) => p.date.isAfter(since))
        .map((p) => p.authorId)
        .toSet()
        .length;
  }

  /// Equipos con más publicaciones en el foro, resuelto desde el `Group`
  /// real de cada autor (solo cuenta autores con equipo — LXD/Mentor/
  /// Advisor no tienen uno). Real, no inventado: con pocos posts el
  /// ranking simplemente sale corto.
  List<({Group group, int count})> mostActiveForumTeams({int take = 3}) {
    final counts = <String, int>{};
    for (final post in forumPosts) {
      final author = userById(post.authorId);
      final groupId = author?.groupId;
      if (groupId == null) continue;
      counts[groupId] = (counts[groupId] ?? 0) + 1;
    }
    final result = <({Group group, int count})>[];
    for (final entry in counts.entries) {
      final group = groupById(entry.key);
      if (group != null) result.add((group: group, count: entry.value));
    }
    result.sort((a, b) => b.count.compareTo(a.count));
    return result.take(take).toList();
  }

  // ---------------- Contenido de la página principal ----------------
  SiteContent get siteContent {
    final j = db.get('content', 'site');
    return j == null ? SiteContent() : SiteContent.fromJson(j);
  }

  Future<void> saveSiteContent(SiteContent c) async {
    await db.put('content', 'site', c.toJson());
    notifyListeners();
  }

  // ---------------- Consultas cruzadas ----------------

  /// Laboratorios donde este Mentor está asignado como revisor (varios
  /// mentores pueden compartir el mismo laboratorio y sus estudiantes).
  List<Laboratory> labsForMentor(AppUser mentor) =>
      labs.where((l) => l.mentorIds.contains(mentor.id)).toList();

  /// Estudiantes de los laboratorios donde este Mentor está asignado.
  List<AppUser> studentsForMentor(AppUser mentor) {
    final labIds = labsForMentor(mentor).map((l) => l.id).toSet();
    return studentsAndAlumni
        .where((s) => s.labIds.any(labIds.contains))
        .toList();
  }

  /// Cursos que este Mentor revisa: los que tiene asignados específicamente
  /// (por Admin o por la empresa aliada de su laboratorio), o si no tiene
  /// ninguno asignado, todos los cursos de sus laboratorios.
  List<Course> reviewableCoursesForMentor(AppUser mentor) {
    if (mentor.reviewCourseIds.isNotEmpty) {
      return mentor.reviewCourseIds
          .map(courseById)
          .whereType<Course>()
          .toList();
    }
    final labIds = labsForMentor(mentor).map((l) => l.id).toSet();
    return courses.where((c) => labIds.contains(c.labId)).toList();
  }

  /// Entregas que este Mentor ya revisó (dejó comentario) entre las de sus
  /// cursos asignados.
  int reviewsCountForMentor(AppUser mentor) {
    final courseIds =
        reviewableCoursesForMentor(mentor).map((c) => c.id).toSet();
    return submissions
        .where((s) =>
            courseIds.contains(s.courseId) && s.feedback.isNotEmpty)
        .length;
  }

  /// Mentores asignados a un laboratorio (para que Empresa o Admin los
  /// gestionen).
  List<AppUser> mentorsForLab(String labId) {
    final lab = labById(labId);
    if (lab == null) return [];
    return usersByRole(Roles.mentor)
        .where((u) => lab.mentorIds.contains(u.id))
        .toList();
  }

  /// Estudiantes con acceso a algún curso creado por este LXD (automático
  /// por laboratorio para Enactus, o asignado directo para Open Learning).
  List<AppUser> studentsForCreator(String creatorId) {
    final myCourses = courses.where((c) => c.creatorId == creatorId).toList();
    return studentsAndAlumni
        .where((s) => myCourses.any((c) => studentHasCourse(s, c)))
        .toList();
  }

  /// Laboratorios asignados a un estudiante (cada uno con su propia Ruta
  /// de Impacto).
  List<Laboratory> labsForStudent(AppUser student) =>
      student.labIds.map(labById).whereType<Laboratory>().toList();

  /// Módulos hechos/totales de TODA la Ruta de Impacto de un laboratorio,
  /// sumando sus fases. Única fuente de verdad: el anillo del detalle, la
  /// cifra "módulos publicados" y cada tarjeta de fase leen de aquí — no
  /// existe un campo `modulesDone`/`modulesTotal` separado en [Laboratory]
  /// que pueda desincronizarse (ver `design_handoff_portal_estudiante`,
  /// pantalla 9, "una sola fuente de verdad para el avance").
  ({int done, int total}) labModuleProgress(String studentId, Laboratory lab) {
    var total = 0;
    var done = 0;
    for (final phase in lab.phases) {
      for (final module in phase.modules) {
        total++;
        if (isModuleComplete(studentId, lab.id, module)) done++;
      }
    }
    return (done: done, total: total);
  }

  /// Si una fase ya tiene contenido publicado por el LXD (objetivos o
  /// módulos) — una fase desbloqueada pero vacía no es lo mismo que una
  /// fase con trabajo pendiente: el estudiante no puede hacer nada en ella
  /// todavía.
  bool labPhaseContentPublished(Phase phase) =>
      phase.objectives.isNotEmpty || phase.modules.isNotEmpty;

  /// El LXD "dueño" de un laboratorio: quien creó sus cursos. `null` si
  /// ninguno de sus cursos tiene un creador real (laboratorios del seed
  /// sin LXD asignado aún) — no se inventa uno.
  AppUser? lxdForLab(String labId) {
    for (final course in coursesByLab(labId)) {
      if (course.creatorId.isNotEmpty) {
        final lxd = userById(course.creatorId);
        if (lxd != null) return lxd;
      }
    }
    return null;
  }

  /// Equipos reales que ya trabajan en un área de laboratorio: grupos con
  /// al menos un estudiante que tiene ese `labId` asignado. Fuente real
  /// para "Otros laboratorios de la red" (no el conteo inventado del
  /// prototipo).
  int teamsInLabArea(String labId) {
    final studentIdsInLab =
        studentsAndAlumni.where((s) => s.labIds.contains(labId)).map((s) => s.id).toSet();
    return groups.where((g) => g.studentIds.any(studentIdsInLab.contains)).length;
  }

  /// Estudiantes de la universidad de un asesor.
  List<AppUser> studentsForAdvisor(AppUser advisor) =>
      studentsAndAlumni
          .where((s) => s.university == advisor.university)
          .toList();

  // ---------------- Calendario ----------------

  List<CalendarEvent> get calendarEvents => db
      .getAll('calendar_events')
      .map(CalendarEvent.fromJson)
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  Future<void> saveCalendarEvent(CalendarEvent e) async {
    await db.put('calendar_events', e.id, e.toJson());
    notifyListeners();
  }

  Future<void> deleteCalendarEvent(String id) async {
    await db.delete('calendar_events', id);
    notifyListeners();
  }

  /// Cursos Open Learning creados por este LXD (para agendar sus propias
  /// sesiones sincrónicas).
  List<Course> openLearningCoursesForCreator(String creatorId) => courses
      .where((c) => c.creatorId == creatorId && c.isOpenLearning)
      .toList();

  /// Eventos de calendario visibles para este usuario, filtrados según su
  /// rol y el tipo de evento:
  /// - Admin/Super Admin ven todo.
  /// - [CalendarEventType.rutaImpacto] es global: lo ve todo el mundo
  ///   Enactus (estudiantes/alumni Enactus, mentores, asesores), sin
  ///   importar el laboratorio — son los encuentros con invitados
  ///   externos cada ~15 días, no algo de un solo laboratorio.
  /// - [CalendarEventType.mentoria] sigue ligado a un laboratorio: solo
  ///   lo ven los estudiantes/mentores de ESE laboratorio.
  /// - [CalendarEventType.openLearningSync] sigue ligado a un curso: solo
  ///   quien está inscrito en ESE curso (y el LXD que lo creó).
  /// Empresa y Donante no tienen calendario (ver portales).
  List<CalendarEvent> calendarEventsFor(AppUser user) {
    if (user.role == Roles.superAdmin || user.role == Roles.admin) {
      return calendarEvents;
    }
    if (user.role == Roles.lxd) {
      final courseIds =
          courses.where((c) => c.creatorId == user.id).map((c) => c.id).toSet();
      return calendarEvents
          .where((e) => e.courseId.isNotEmpty && courseIds.contains(e.courseId))
          .toList();
    }
    if (user.role == Roles.mentor) {
      final labIds = labsForMentor(user).map((l) => l.id).toSet();
      return calendarEvents
          .where((e) =>
              e.type == CalendarEventType.rutaImpacto ||
              (e.labId.isNotEmpty && labIds.contains(e.labId)))
          .toList();
    }
    if (user.role == Roles.advisor) {
      final myStudents = studentsForAdvisor(user);
      final labIds = myStudents.expand((s) => s.labIds).toSet();
      final courseIds = myStudents
          .expand((s) => coursesForStudent(s).map((c) => c.id))
          .toSet();
      return calendarEvents
          .where((e) =>
              e.type == CalendarEventType.rutaImpacto ||
              (e.labId.isNotEmpty && labIds.contains(e.labId)) ||
              (e.courseId.isNotEmpty && courseIds.contains(e.courseId)))
          .toList();
    }
    if (Roles.isStudentLike(user.role)) {
      final isEnactus = user.studentType == StudentType.enactus;
      final labIds = user.labIds.toSet();
      final courseIds = coursesForStudent(user).map((c) => c.id).toSet();
      return calendarEvents
          .where((e) =>
              (e.type == CalendarEventType.rutaImpacto && isEnactus) ||
              (e.type == CalendarEventType.mentoria &&
                  e.labId.isNotEmpty &&
                  labIds.contains(e.labId)) ||
              (e.type == CalendarEventType.openLearningSync &&
                  e.courseId.isNotEmpty &&
                  courseIds.contains(e.courseId)))
          .toList();
    }
    return [];
  }

  /// Estudiantes patrocinados por una empresa.
  List<AppUser> studentsForCompany(String companyUserId) =>
      studentsAndAlumni
          .where((s) => s.companyId == companyUserId)
          .toList();

  /// Estudiantes apoyados por un donante.
  List<AppUser> studentsForDonor(String donorUserId) =>
      studentsAndAlumni.where((s) => s.donorId == donorUserId).toList();

  // ---------------- Seguimiento y analíticas de curso ----------------

  /// Estudiantes inscritos en un curso (automático por laboratorio para
  /// Enactus, asignado directo para Open Learning).
  List<AppUser> studentsInCourse(String courseId) {
    final course = courseById(courseId);
    if (course == null) return [];
    return studentsAndAlumni
        .where((s) => studentHasCourse(s, course))
        .toList();
  }

  /// Estadísticas de seguimiento del curso para el mentor.
  ({
    int enrolled,
    int completed,
    double avgProgress,
    double avgGrade,
    int pending
  }) courseStats(Course course) {
    final students = studentsInCourse(course.id);
    var completed = 0;
    var progressSum = 0.0;
    final grades = <double>[];
    for (final s in students) {
      final p = courseProgress(s.id, course);
      progressSum += p;
      if (p >= 1.0) completed++;
      for (final sub in submissionsForCourse(course.id)
          .where((x) => x.studentId == s.id && x.grade != null)) {
        grades.add(sub.grade!);
      }
    }
    return (
      enrolled: students.length,
      completed: completed,
      avgProgress: students.isEmpty ? 0 : progressSum / students.length,
      avgGrade: grades.isEmpty
          ? 0
          : grades.reduce((a, b) => a + b) / grades.length,
      pending: students.length - completed,
    );
  }

  /// Última actividad registrada de un estudiante en un curso.
  DateTime? lastActivity(String studentId, String courseId) {
    final progressDate = progressFor(studentId, courseId).updatedAt;
    DateTime? submissionDate;
    for (final s in submissionsForCourse(courseId)
        .where((x) => x.studentId == studentId)) {
      if (submissionDate == null || s.date.isAfter(submissionDate)) {
        submissionDate = s.date;
      }
    }
    if (progressDate == null) return submissionDate;
    if (submissionDate == null) return progressDate;
    return progressDate.isAfter(submissionDate)
        ? progressDate
        : submissionDate;
  }

  // ---------------- Notas privadas del mentor ----------------

  /// Nota privada del mentor sobre un estudiante en un curso
  /// (comentarios, retroalimentación, observaciones).
  String mentorNote(String studentId, String courseId) {
    final j = db.get('mentor_notes', '$studentId::$courseId');
    return (j?['note'] as String?) ?? '';
  }

  Future<void> saveMentorNote(
      String studentId, String courseId, String note) async {
    await db.put('mentor_notes', '$studentId::$courseId',
        {'studentId': studentId, 'courseId': courseId, 'note': note});
    notifyListeners();
  }

  // ---------------- Métricas de impacto formativo (Enactus) ----------------

  /// Horas del curso a contabilizar en métricas (certificadas o estimadas).
  int _courseHours(Course c) =>
      c.certifiedHours > 0 ? c.certifiedHours : c.estimatedHours;

  /// Horas de formación completadas, agrupadas por competencia.
  /// "Se han impartido 1.250 horas de formación en Innovación."
  Map<String, int> hoursByCompetency() {
    final result = <String, int>{};
    for (final course in courses) {
      final hours = _courseHours(course);
      if (hours == 0 || course.competencies.isEmpty) continue;
      for (final s in studentsInCourse(course.id)) {
        final p = courseProgress(s.id, course);
        final earned = (hours * p).round();
        if (earned == 0) continue;
        for (final comp in course.competencies) {
          result[comp] = (result[comp] ?? 0) + earned;
        }
      }
    }
    return result;
  }

  /// % de estudiantes que completaron al menos un curso de cada ODS.
  Map<String, double> odsCompletionRate() {
    final students = studentsAndAlumni;
    if (students.isEmpty) return {};
    final result = <String, double>{};
    final odsCourses = <String, List<Course>>{};
    for (final c in courses) {
      for (final o in c.ods) {
        odsCourses.putIfAbsent(o, () => []).add(c);
      }
    }
    for (final e in odsCourses.entries) {
      final done = students.where((s) => e.value.any((c) =>
          studentHasCourse(s, c) &&
          courseProgress(s.id, c) >= 1.0)).length;
      result[e.key] = done / students.length;
    }
    return result;
  }

  /// Horas de formación patrocinadas por cada empresa: cursos marcados a
  /// mano como patrocinados (curso o laboratorio) MÁS los cursos creados
  /// por cualquiera de los LXD de la empresa (ver [coursesForCompany]) —
  /// una empresa patrocina un laboratorio en cuanto uno de sus LXD tiene un
  /// curso ahí, sin necesidad de marcarlo aparte.
  Map<String, int> sponsoredHoursByCompany() {
    final result = <String, int>{};
    for (final company in usersByRole(Roles.company)) {
      var total = 0;
      final autoSponsoredIds =
          coursesForCompany(company.id).map((c) => c.id).toSet();
      for (final course in courses) {
        final sponsors = autoSponsoredIds.contains(course.id) ||
            course.sponsorCompanyId == company.id ||
            (course.labId.isNotEmpty &&
                labById(course.labId)?.sponsorCompanyId == company.id);
        if (!sponsors) continue;
        final hours = _courseHours(course);
        if (hours == 0) continue;
        for (final s in studentsInCourse(course.id)) {
          total += (hours * courseProgress(s.id, course)).round();
        }
      }
      if (total > 0) result[company.companyName] = total;
    }
    return result;
  }

  // ---------------- Copia de seguridad ----------------

  /// Toda la base de datos como JSON legible (para descargar).
  String exportBackupJson() =>
      const JsonEncoder.withIndent('  ').convert(db.exportAll());

  /// Restaura una copia de seguridad. Lanza FormatException si el
  /// archivo no es un respaldo válido.
  Future<void> importBackupJson(String json) async {
    final decoded = Map<String, dynamic>.from(jsonDecode(json) as Map);
    if (!decoded.containsKey('users')) {
      throw const FormatException('El archivo no es un respaldo válido.');
    }
    await db.importAll(decoded);
    notifyListeners();
  }
}
