import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/pdf_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import 'course_editor_view.dart';
import 'course_tracking_view.dart';

class MentorPortal extends StatelessWidget {
  const MentorPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      portalTitle: 'Portal Mentor',
      tabs: [
        PortalTab(
            label: 'Mis Estudiantes',
            icon: Icons.groups_outlined,
            builder: (_) => const _MentorDashboard()),
        PortalTab(
            label: 'Mis Cursos',
            icon: Icons.video_library_outlined,
            builder: (_) => const _MentorCourses()),
        PortalTab(
            label: 'Calificaciones',
            icon: Icons.grading_outlined,
            builder: (_) => const _MentorGrading()),
        PortalTab(
            label: 'Certificaciones',
            icon: Icons.workspace_premium_outlined,
            builder: (_) => const _MentorCertificates()),
        PortalTab(
            label: 'Mi Perfil',
            icon: Icons.person_outline,
            builder: (_) => const _MentorProfile()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard: tabla de estudiantes asignados
// ---------------------------------------------------------------------------

class _MentorDashboard extends StatefulWidget {
  const _MentorDashboard();

  @override
  State<_MentorDashboard> createState() => _MentorDashboardState();
}

class _MentorDashboardState extends State<_MentorDashboard> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final mentor = context.watch<AuthProvider>().currentUser!;
    final lab = data.labById(mentor.labId);
    var students = data.studentsForMentor(mentor);
    if (_filter.isNotEmpty) {
      final f = _filter.toLowerCase();
      students = students
          .where((s) =>
              s.name.toLowerCase().contains(f) ||
              s.university.toLowerCase().contains(f))
          .toList();
    }

    return TabBody(
      title: 'Mis Estudiantes',
      subtitle: lab == null
          ? 'Sin laboratorio asignado'
          : 'Estudiantes inscritos en cursos de ${lab.name}',
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Filtrar por nombre o institución',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _filter = v),
          ),
        ),
        const SizedBox(height: 16),
        if (students.isEmpty)
          const EmptyState(
              icon: Icons.groups_outlined,
              message: 'No hay estudiantes inscritos en tus cursos.')
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Estudiante')),
                  DataColumn(label: Text('Proyecto')),
                  DataColumn(label: Text('Etapa')),
                  DataColumn(label: Text('Necesidad')),
                  DataColumn(label: Text('Institución')),
                  DataColumn(label: Text('Tipo')),
                  DataColumn(label: Text('Ubicación')),
                  DataColumn(label: Text('Progreso')),
                ],
                rows: [
                  for (final s in students) _studentRow(context, data, s),
                ],
              ),
            ),
          ),
      ],
    );
  }

  DataRow _studentRow(BuildContext context, DataProvider data, AppUser s) {
    final group = data.groupById(s.groupId);
    final project = group == null ? null : data.projectById(group.projectId);
    final progress = data.overallProgress(s);
    final sponsor = s.companyId == null ? null : data.userById(s.companyId!);
    final need = progress < 0.3
        ? 'Acompañamiento urgente'
        : progress < 0.7
            ? 'Seguimiento regular'
            : 'Autónomo';

    // Mini tarjeta flotante con el resumen del estudiante (hover)
    final summary = '${s.name}\n'
        '${s.university}\n'
        'Proyecto: ${project?.name ?? '—'}\n'
        'Avance: ${(progress * 100).round()}%'
        '${sponsor != null ? '\nEmpresa: ${sponsor.companyName}' : ''}';

    return DataRow(
      color: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.hovered)
              ? AppColors.gold.withValues(alpha: 0.06)
              : null),
      cells: [
        DataCell(Tooltip(
          message: summary,
          child: Text(s.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        )),
        DataCell(Text(project?.name ?? '—')),
        DataCell(Text(project?.stage ?? '—')),
        DataCell(Text(need)),
        DataCell(Text(s.university)),
        const DataCell(Text('Universidad')),
        const DataCell(Text('Colombia')),
        DataCell(SizedBox(
            width: 120,
            child: ThinProgressBar(
                value: progress, tooltip: 'Promedio de todos sus cursos'))),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mis Cursos: tarjetas con acceso al constructor y al seguimiento
// ---------------------------------------------------------------------------

class _MentorCourses extends StatelessWidget {
  const _MentorCourses();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final mentor = context.watch<AuthProvider>().currentUser!;
    final lab = data.labById(mentor.labId);
    final courses = lab == null ? <Course>[] : data.coursesByLab(lab.id);

    return TabBody(
      title: 'Mis Cursos',
      subtitle: lab == null
          ? 'Sin laboratorio asignado'
          : 'Cursos de ${lab.name} — crea experiencias de aprendizaje completas',
      actions: [
        if (lab != null)
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuevo curso'),
            onPressed: () => _createCourse(context, lab.id, mentor.id),
          ),
      ],
      children: [
        if (courses.isEmpty)
          const EmptyState(
              icon: Icons.video_library_outlined,
              message: 'Aún no hay cursos en tu laboratorio. Crea el primero.')
        else
          ...courses.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CourseAdminCard(course: c),
              )),
      ],
    );
  }

  Future<void> _createCourse(
      BuildContext context, String labId, String mentorId) async {
    final data = context.read<DataProvider>();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Nuevo curso', style: TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: ctrl,
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: 'Nombre del curso'),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Crear y abrir constructor')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || !context.mounted) return;

    final course = Course(
      id: data.newId('crs'),
      name: name,
      labId: labId,
      mentorId: mentorId,
      status: 'Borrador',
    );
    await data.saveCourse(course);
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CourseEditorView(courseId: course.id)),
      );
    }
  }
}

class _CourseAdminCard extends StatelessWidget {
  final Course course;
  const _CourseAdminCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final stats = data.courseStats(course);

    final (statusColor, statusIcon) = switch (course.status) {
      'Publicado' => (AppColors.statusGood, Icons.public),
      'Archivado' => (AppColors.statusSerious, Icons.archive_outlined),
      _ => (AppColors.statusWarning, Icons.edit_note),
    };

    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories_outlined,
                  color: AppColors.gold, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    if (course.subtitle.isNotEmpty)
                      Text(course.subtitle,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12.5)),
                  ],
                ),
              ),
              StatusChip(
                  label: course.status,
                  color: statusColor,
                  icon: statusIcon),
              const SizedBox(width: 8),
              StatusChip(
                  label: course.level,
                  color: AppColors.slateLight,
                  icon: Icons.signal_cellular_alt),
            ],
          ),
          const SizedBox(height: 8),
          Text(course.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          // Resumen tipo "Curso IA · 120 inscritos · 84 completados · 70%"
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _miniStat(Icons.people_outline, '${stats.enrolled} inscritos'),
              _miniStat(Icons.check_circle_outline,
                  '${stats.completed} completados'),
              _miniStat(Icons.trending_up,
                  '${(stats.avgProgress * 100).round()}% avance'),
              _miniStat(
                  Icons.grade_outlined,
                  stats.avgGrade == 0
                      ? 'Sin notas'
                      : 'Promedio ${stats.avgGrade.toStringAsFixed(1)}'),
              _miniStat(Icons.hourglass_empty,
                  '${stats.pending} pendientes'),
              _miniStat(Icons.view_module_outlined,
                  '${course.modules.length} módulos · ${course.lessonCount} lecciones'),
            ],
          ),
          if (course.competencies.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final comp in course.competencies.take(5))
                  Chip(
                    label: Text(comp, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.build_outlined, size: 16),
                label: const Text('Constructor'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          CourseEditorView(courseId: course.id)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.insights_outlined, size: 16),
                label: const Text('Seguimiento'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          CourseTrackingView(courseId: course.id)),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 19),
                color: AppColors.statusCritical,
                tooltip: 'Eliminar curso',
                onPressed: () async {
                  final data = context.read<DataProvider>();
                  if (await confirmDoubleDialog(
                      context,
                      'Eliminar curso',
                      'Vas a eliminar "${course.name}" con todos sus '
                      'módulos, lecciones y configuración.')) {
                    await data.deleteCourse(course.id);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12.5)),
        ],
      );
}

// ---------------------------------------------------------------------------
// Calificaciones (respeta el modo de calificación de cada actividad)
// ---------------------------------------------------------------------------

class _MentorGrading extends StatelessWidget {
  const _MentorGrading();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final mentor = context.watch<AuthProvider>().currentUser!;
    final labCourseIds =
        data.coursesByLab(mentor.labId ?? '').map((c) => c.id).toSet();
    final submissions = data.submissions
        .where((s) => labCourseIds.contains(s.courseId))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return TabBody(
      title: 'Calificaciones',
      subtitle: 'Entregas de estudiantes en tus cursos',
      children: [
        if (submissions.isEmpty)
          const EmptyState(
              icon: Icons.grading_outlined,
              message: 'No hay entregas para calificar.')
        else
          ...submissions.map((s) {
            final student =
                s.studentId.isEmpty ? null : data.userById(s.studentId);
            final course = data.courseById(s.courseId);
            final lesson = _lessonFor(course, s.lessonId);
            final mode = lesson?.activity?.gradingMode ?? 'scale5';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: HoverCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.taskName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          Text(
                            '${student?.name ?? 'Entrega grupal'} · '
                            '${course?.name ?? ''} · '
                            '${DateFormat('d MMM yyyy').format(s.date)}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(s.comment,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _gradeChip(s, mode),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () =>
                          _grade(context, s, mode, lesson),
                      child: Text(s.grade == null &&
                              s.feedback.isEmpty
                          ? (mode == 'review' ? 'Revisar' : 'Calificar')
                          : 'Editar'),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Lesson? _lessonFor(Course? course, String lessonId) {
    if (course == null || lessonId.isEmpty) return null;
    for (final m in course.modules) {
      for (final l in m.lessons) {
        if (l.id == lessonId) return l;
      }
    }
    return null;
  }

  Widget _gradeChip(Submission s, String mode) {
    if (s.grade == null) {
      return const StatusChip(
          label: 'Pendiente',
          color: AppColors.statusWarning,
          icon: Icons.hourglass_empty);
    }
    return switch (mode) {
      'passfail' => s.grade! > 0
          ? const StatusChip(
              label: 'Aprobado',
              color: AppColors.statusGood,
              icon: Icons.check)
          : const StatusChip(
              label: 'Reprobado',
              color: AppColors.statusCritical,
              icon: Icons.close),
      'points100' => StatusChip(
          label: '${s.grade!.round()}/100',
          color: s.grade! >= 60
              ? AppColors.statusGood
              : AppColors.statusCritical,
          icon: Icons.grade),
      _ => StatusChip(
          label: 'Nota: ${s.grade}',
          color:
              s.grade! >= 3 ? AppColors.statusGood : AppColors.statusCritical,
          icon: Icons.grade),
    };
  }

  Future<void> _grade(BuildContext context, Submission s, String mode,
      Lesson? lesson) async {
    final data = context.read<DataProvider>();
    final gradeCtrl =
        TextEditingController(text: s.grade?.toString() ?? '');
    final feedbackCtrl = TextEditingController(text: s.feedback);
    bool? passed = s.grade == null ? null : s.grade! > 0;
    final rubric = lesson?.activity?.rubric ?? [];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Calificar: ${s.taskName}',
              style: const TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rubric.isNotEmpty) ...[
                    const Text('Rúbrica',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold)),
                    const SizedBox(height: 6),
                    for (final r in rubric)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(r['criterion'] as String,
                                    style:
                                        const TextStyle(fontSize: 13))),
                            Text('${r['points']} pts',
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    const Divider(height: 20),
                  ],
                  switch (mode) {
                    'passfail' => Row(
                        children: [
                          const Text('Resultado:  '),
                          ChoiceChip(
                            label: const Text('Aprobado'),
                            selected: passed == true,
                            selectedColor: AppColors.statusGood
                                .withValues(alpha: 0.25),
                            onSelected: (_) =>
                                setState(() => passed = true),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Reprobado'),
                            selected: passed == false,
                            selectedColor: AppColors.statusCritical
                                .withValues(alpha: 0.25),
                            onSelected: (_) =>
                                setState(() => passed = false),
                          ),
                        ],
                      ),
                    'review' => const Text(
                        'Esta actividad es de solo revisión: deja tu '
                        'retroalimentación sin nota.',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                    'points100' => TextField(
                        controller: gradeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Puntaje (0 - 100)'),
                      ),
                    _ => TextField(
                        controller: gradeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Nota (0.0 - 5.0)'),
                      ),
                  },
                  const SizedBox(height: 12),
                  TextField(
                    controller: feedbackCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Retroalimentación'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                switch (mode) {
                  case 'passfail':
                    if (passed == null) return;
                    s.grade = passed! ? 100 : 0;
                  case 'review':
                    s.grade = null;
                  case 'points100':
                    final g = double.tryParse(gradeCtrl.text);
                    if (g == null || g < 0 || g > 100) return;
                    s.grade = g;
                  default:
                    final g = double.tryParse(gradeCtrl.text);
                    if (g == null || g < 0 || g > 5) return;
                    s.grade = g;
                }
                s.feedback = feedbackCtrl.text.trim();
                await data.saveSubmission(s);
                if (s.studentId.isNotEmpty) {
                  await data.notify(s.studentId, 'Entrega revisada',
                      '"${s.taskName}" tiene nueva retroalimentación.');
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Certificaciones
// ---------------------------------------------------------------------------

class _MentorCertificates extends StatefulWidget {
  const _MentorCertificates();

  @override
  State<_MentorCertificates> createState() => _MentorCertificatesState();
}

class _MentorCertificatesState extends State<_MentorCertificates> {
  String? _studentId;
  String? _courseId;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final mentor = context.watch<AuthProvider>().currentUser!;
    final students = data.studentsForMentor(mentor);
    final courses = data.coursesByLab(mentor.labId ?? '');
    final issued =
        data.certificates.where((c) => c.mentorName == mentor.name).toList();

    return TabBody(
      title: 'Certificaciones',
      subtitle:
          'Genera certificados en PDF para estudiantes que completaron un curso',
      children: [
        HoverCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Emitir nuevo certificado',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _studentId,
                      decoration:
                          const InputDecoration(labelText: 'Estudiante'),
                      items: [
                        for (final s in students)
                          DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ],
                      onChanged: (v) => setState(() => _studentId = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _courseId,
                      decoration: const InputDecoration(labelText: 'Curso'),
                      items: [
                        for (final c in courses)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() => _courseId = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.workspace_premium, size: 18),
                    label: const Text('Emitir'),
                    onPressed: _studentId == null || _courseId == null
                        ? null
                        : () => _issue(context, mentor),
                  ),
                ],
              ),
              if (_studentId != null && _courseId != null) ...[
                const SizedBox(height: 10),
                Builder(builder: (context) {
                  final course = data.courseById(_courseId!)!;
                  final progress = data.courseProgress(_studentId!, course);
                  return Wrap(spacing: 8, runSpacing: 6, children: [
                    progress < 1.0
                        ? const StatusChip(
                            label:
                                'Atención: el estudiante no ha completado el 100% del curso',
                            color: AppColors.statusWarning,
                            icon: Icons.warning_amber_outlined)
                        : const StatusChip(
                            label: 'Curso completado ✓',
                            color: AppColors.statusGood,
                            icon: Icons.check),
                    if (!course.generatesCertificate)
                      const StatusChip(
                          label:
                              'Este curso no tiene certificado configurado (se emitirá genérico)',
                          color: AppColors.slateLight,
                          icon: Icons.info_outline),
                  ]);
                }),
              ],
            ],
          ),
        ),
        const SectionTitle('Certificados emitidos'),
        if (issued.isEmpty)
          const EmptyState(
              icon: Icons.workspace_premium_outlined,
              message: 'Aún no has emitido certificados.')
        else
          ...issued.map((cert) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: HoverCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium,
                          color: AppColors.gold),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                            '${cert.studentName} · ${cert.courseName} · ${cert.code}'
                            '${cert.hours > 0 ? ' · ${cert.hours} h' : ''}',
                            style: const TextStyle(fontSize: 13.5)),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('PDF'),
                        onPressed: () => PdfService.preview(cert),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Future<void> _issue(BuildContext context, AppUser mentor) async {
    final data = context.read<DataProvider>();
    final student = data.userById(_studentId!)!;
    final course = data.courseById(_courseId!)!;
    final cert = await data.issueCertificate(
        student: student, course: course, mentorName: mentor.name);
    if (context.mounted) {
      showSuccessCheck(context, 'Certificado ${cert.code} emitido 🏆');
      await PdfService.preview(cert);
    }
  }
}

// ---------------------------------------------------------------------------
// Perfil del mentor
// ---------------------------------------------------------------------------

class _MentorProfile extends StatelessWidget {
  const _MentorProfile();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final mentor = context.watch<AuthProvider>().currentUser!;
    final lab = data.labById(mentor.labId);
    final e = mentor.extra;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: 160,
                  child: Text(label,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13))),
              Expanded(
                  child: Text(value.isEmpty ? '—' : value,
                      style: const TextStyle(fontSize: 14))),
            ],
          ),
        );

    return TabBody(
      title: 'Mi Perfil',
      subtitle: 'Información visible para administradores y estudiantes',
      children: [
        HoverCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mentor.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              Text(mentor.email,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
              const Divider(height: 32),
              row('Laboratorio', lab?.name ?? '—'),
              row('Empresa', (e['company'] as String?) ?? ''),
              row('Cargo', (e['position'] as String?) ?? ''),
              row('Especialidad', (e['specialty'] as String?) ?? ''),
              row('Idiomas', (e['languages'] as String?) ?? ''),
              row('Disponibilidad', (e['availability'] as String?) ?? ''),
              row('Experiencia', (e['experience'] as String?) ?? ''),
              row('Intereses', (e['interests'] as String?) ?? ''),
            ],
          ),
        ),
      ],
    );
  }
}
