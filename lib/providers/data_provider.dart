import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/db_service.dart';

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

  List<Course> coursesForStudent(AppUser student) {
    final ids = student.courseIds;
    return courses.where((c) => ids.contains(c.id)).toList();
  }

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

  Future<Certificate> issueCertificate({
    required AppUser student,
    required Course course,
    required String mentorName,
  }) async {
    final cert = Certificate(
      id: newId('cert'),
      code:
          'ENC-${DateTime.now().year}-${_rnd.nextInt(90000) + 10000}',
      studentId: student.id,
      studentName: student.name,
      courseId: course.id,
      // Usa la configuración de certificado del curso cuando existe
      courseName: course.certificateName.isNotEmpty
          ? course.certificateName
          : course.name,
      mentorName: course.certificateSigner.isNotEmpty
          ? course.certificateSigner
          : mentorName,
      hours: course.certifiedHours,
    );
    await db.put('certificates', cert.id, cert.toJson());
    await notify(student.id, 'Nuevo certificado',
        'Recibiste el certificado del curso "${course.name}".');
    notifyListeners();
    return cert;
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

  /// Estudiantes asignados a un mentor (los inscritos en cursos de su lab).
  List<AppUser> studentsForMentor(AppUser mentor) {
    final labCourses =
        courses.where((c) => c.labId == (mentor.labId ?? '')).map((c) => c.id).toSet();
    return usersByRole('student')
        .where((s) => s.courseIds.any(labCourses.contains))
        .toList();
  }

  /// Estudiantes de la universidad de un asesor.
  List<AppUser> studentsForAdvisor(AppUser advisor) =>
      usersByRole('student')
          .where((s) => s.university == advisor.university)
          .toList();

  /// Estudiantes patrocinados por una empresa.
  List<AppUser> studentsForCompany(String companyUserId) =>
      usersByRole('student')
          .where((s) => s.companyId == companyUserId)
          .toList();

  /// Estudiantes apoyados por un donante.
  List<AppUser> studentsForDonor(String donorUserId) =>
      usersByRole('student').where((s) => s.donorId == donorUserId).toList();

  // ---------------- Seguimiento y analíticas de curso ----------------

  /// Estudiantes inscritos en un curso.
  List<AppUser> studentsInCourse(String courseId) =>
      usersByRole('student')
          .where((s) => s.courseIds.contains(courseId))
          .toList();

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
    final students = usersByRole('student');
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
          s.courseIds.contains(c.id) &&
          courseProgress(s.id, c) >= 1.0)).length;
      result[e.key] = done / students.length;
    }
    return result;
  }

  /// Horas de formación patrocinadas por cada empresa (curso patrocinado o
  /// del laboratorio que patrocina).
  Map<String, int> sponsoredHoursByCompany() {
    final result = <String, int>{};
    for (final company in usersByRole('company')) {
      var total = 0;
      for (final course in courses) {
        final sponsors = course.sponsorCompanyId == company.id ||
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
