import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/pdf_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/calendar_view.dart';
import '../../widgets/common.dart';
import '../../widgets/link_to_ruta_dialog.dart';
import '../../widgets/portal_shell.dart';
import 'course_editor_view.dart';
import 'course_tracking_view.dart';

class LxdPortal extends StatelessWidget {
  const LxdPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      portalTitle: 'Portal LXD',
      tabs: [
        PortalTab(
            label: 'Mis Estudiantes',
            icon: Icons.groups_outlined,
            builder: (_) => const _LxdDashboard()),
        PortalTab(
            label: 'Calendario',
            icon: Icons.calendar_month_outlined,
            builder: (_) => const _LxdCalendar()),
        PortalTab(
            label: 'Mis Cursos',
            icon: Icons.video_library_outlined,
            builder: (_) => const _LxdCourses()),
        PortalTab(
            label: 'Calificaciones',
            icon: Icons.grading_outlined,
            builder: (_) => const _LxdGrading()),
        PortalTab(
            label: 'Certificaciones',
            icon: Icons.workspace_premium_outlined,
            builder: (_) => const _LxdCertificates()),
        PortalTab(
            label: 'Mi Perfil',
            icon: Icons.person_outline,
            builder: (_) => const _LxdProfile()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard: tabla de estudiantes asignados
// ---------------------------------------------------------------------------

class _LxdDashboard extends StatefulWidget {
  const _LxdDashboard();

  @override
  State<_LxdDashboard> createState() => _LxdDashboardState();
}

class _LxdDashboardState extends State<_LxdDashboard> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final lxd = context.watch<AuthProvider>().currentUser!;
    var students = data.studentsForCreator(lxd.id);
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
      subtitle: 'Estudiantes inscritos en cursos que creaste',
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
// Calendario: sesiones sincrónicas de los cursos Open Learning del LXD
// ---------------------------------------------------------------------------

class _LxdCalendar extends StatelessWidget {
  const _LxdCalendar();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final user = context.watch<AuthProvider>().currentUser!;
    final myCourses = data.openLearningCoursesForCreator(user.id);
    return TabBody(
      title: 'Calendario',
      subtitle: 'Agenda las sesiones sincrónicas de tus cursos Open Learning',
      children: [
        CalendarView(
          events: data.calendarEventsFor(user),
          canManage: true,
          onAddEvent: (day) => showCalendarEventDialog(
            context,
            initialDay: day,
            allowedTypes: const [CalendarEventType.openLearningSync],
            courses: myCourses,
            labs: const [],
            defaultMeetLink: data.siteContent.meetingLink,
            onSave: (events) async {
              for (final e in events) {
                await data.saveCalendarEvent(e);
              }
            },
          ),
          onEditEvent: (event) => showCalendarEventDialog(
            context,
            existing: event,
            allowedTypes: const [CalendarEventType.openLearningSync],
            courses: myCourses,
            labs: const [],
            defaultMeetLink: data.siteContent.meetingLink,
            onSave: (events) async {
              for (final e in events) {
                await data.saveCalendarEvent(e);
              }
            },
          ),
          onDeleteEvent: (event) => data.deleteCalendarEvent(event.id),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mis Cursos: tarjetas con acceso al constructor y al seguimiento
// ---------------------------------------------------------------------------

class _LxdCourses extends StatelessWidget {
  const _LxdCourses();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final lxd = context.watch<AuthProvider>().currentUser!;
    final courses =
        data.courses.where((c) => c.creatorId == lxd.id).toList();

    return TabBody(
      title: 'Mis Cursos',
      subtitle:
          'Cursos que creaste — Enactus (asignados o no a un laboratorio) y Open Learning',
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nuevo curso'),
          onPressed: () => _createCourse(context, lxd.id),
        ),
      ],
      children: [
        if (courses.isEmpty)
          const EmptyState(
              icon: Icons.video_library_outlined,
              message: 'Aún no has creado ningún curso. Crea el primero.')
        else
          ...courses.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CourseAdminCard(course: c),
              )),
      ],
    );
  }

  Future<void> _createCourse(BuildContext context, String creatorId) async {
    final data = context.read<DataProvider>();
    final nameCtrl = TextEditingController();
    String? labId;
    var isOpenLearning = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nuevo curso', style: TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration:
                      const InputDecoration(labelText: 'Nombre del curso'),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Curso de Open Learning',
                      style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                      'Se asigna directo a estudiantes externos, sin laboratorio ni Ruta de Impacto',
                      style: TextStyle(fontSize: 12)),
                  value: isOpenLearning,
                  activeThumbColor: AppColors.gold,
                  onChanged: (v) => setState(() {
                    isOpenLearning = v;
                    if (v) labId = null;
                  }),
                ),
                if (!isOpenLearning) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: labId,
                    decoration: const InputDecoration(
                        labelText: 'Laboratorio (opcional)'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Sin asignar por ahora')),
                      for (final l in data.labs)
                        DropdownMenuItem(value: l.id, child: Text(l.name)),
                    ],
                    onChanged: (v) => setState(() => labId = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Crear y abrir constructor')),
          ],
        ),
      ),
    );
    if (created != true || nameCtrl.text.trim().isEmpty || !context.mounted) {
      return;
    }

    final course = Course(
      id: data.newId('crs'),
      name: nameCtrl.text.trim(),
      labId: isOpenLearning ? '' : (labId ?? ''),
      creatorId: creatorId,
      isOpenLearning: isOpenLearning,
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
                            fontWeight: FontWeight.w700, fontSize: 16)),
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
          if (!course.isOpenLearning) ...[
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final linked = linkedModuleLabel(data, course);
              return Row(
                children: [
                  Icon(
                      linked == null
                          ? Icons.link_off
                          : Icons.check_circle_outline,
                      size: 14,
                      color: linked == null
                          ? AppColors.textMuted
                          : AppColors.statusGood),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                        linked ?? 'Sin vincular a ningún módulo todavía',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ),
                ],
              );
            }),
          ],
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
              if (!course.isOpenLearning) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.route_outlined, size: 16),
                  label: const Text('Vincular a Ruta de Impacto'),
                  onPressed: () => showLinkToRutaDialog(context, course),
                ),
              ],
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

class _LxdGrading extends StatelessWidget {
  const _LxdGrading();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final lxd = context.watch<AuthProvider>().currentUser!;
    final myCourses =
        data.courses.where((c) => c.creatorId == lxd.id).toList();
    // El permiso de calificar lo controla el Admin, por contexto: Open
    // Learning (activo por defecto) y Enactus (desactivado por defecto).
    final gradableCourseIds = myCourses
        .where((c) =>
            c.isOpenLearning ? lxd.canGradeOpenLearning : lxd.canGradeEnactus)
        .map((c) => c.id)
        .toSet();
    final submissions = data.submissions
        .where((s) => gradableCourseIds.contains(s.courseId))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final hasBlockedCourses = myCourses.isNotEmpty && gradableCourseIds.isEmpty;

    return TabBody(
      title: 'Calificaciones',
      subtitle: 'Entregas de estudiantes en tus cursos',
      children: [
        if (hasBlockedCourses)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: StatusChip(
                label:
                    'Tu Admin no te ha dado permiso de calificar en este contexto todavía',
                color: AppColors.statusWarning,
                icon: Icons.lock_outline),
          ),
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
                // Calificar una actividad de curso es lo que la completa:
                // a diferencia del quiz/encuesta (que se auto-completan al
                // responder), la actividad depende de esta revisión.
                if (s.courseId.isNotEmpty &&
                    s.lessonId.isNotEmpty &&
                    s.studentId.isNotEmpty) {
                  await data.markLessonComplete(
                      s.studentId, s.courseId, s.lessonId);
                }
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

class _LxdCertificates extends StatefulWidget {
  const _LxdCertificates();

  @override
  State<_LxdCertificates> createState() => _LxdCertificatesState();
}

class _LxdCertificatesState extends State<_LxdCertificates> {
  String? _studentId;
  String? _labId;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final lxd = context.watch<AuthProvider>().currentUser!;
    final students = data.studentsAndAlumni;
    final completedLabs =
        _studentId == null ? <Laboratory>[] : data.completedLabsForStudent(_studentId!);
    final issued =
        data.certificates.where((c) => c.issuerName == lxd.name).toList();

    return TabBody(
      title: 'Certificaciones',
      subtitle:
          'El certificado se emite al completar la Ruta de Impacto completa de un laboratorio (ya no hay certificado por curso)',
      children: [
        if (!lxd.canGradeEnactus)
          const StatusChip(
              label:
                  'Tu Admin no te ha dado permiso de calificar en Enactus: no puedes emitir certificados todavía',
              color: AppColors.statusWarning,
              icon: Icons.lock_outline)
        else
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
                            DropdownMenuItem(
                                value: s.id, child: Text(s.name)),
                        ],
                        onChanged: (v) =>
                            setState(() {
                              _studentId = v;
                              _labId = null;
                            }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _labId,
                        decoration: const InputDecoration(
                            labelText: 'Laboratorio (Ruta completa)'),
                        items: [
                          for (final l in completedLabs)
                            DropdownMenuItem(value: l.id, child: Text(l.name)),
                        ],
                        onChanged: (v) => setState(() => _labId = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.workspace_premium, size: 18),
                      label: const Text('Emitir'),
                      onPressed: _studentId == null || _labId == null
                          ? null
                          : () => _issue(context, lxd),
                    ),
                  ],
                ),
                if (_studentId != null && completedLabs.isEmpty) ...[
                  const SizedBox(height: 10),
                  const StatusChip(
                      label:
                          'Este estudiante aún no completó la Ruta de Impacto de ningún laboratorio',
                      color: AppColors.statusWarning,
                      icon: Icons.warning_amber_outlined),
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
                            '${cert.studentName} · Ruta de Impacto ${cert.labName} · ${cert.code}'
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

  Future<void> _issue(BuildContext context, AppUser lxd) async {
    final data = context.read<DataProvider>();
    final student = data.userById(_studentId!)!;
    final lab = data.labById(_labId!)!;
    final cert = await data.issueRutaCertificate(
        student: student, lab: lab, issuerName: lxd.name);
    if (context.mounted) {
      showSuccessCheck(context, 'Certificado ${cert.code} emitido 🏆');
      await PdfService.preview(cert);
    }
  }
}

// ---------------------------------------------------------------------------
// Perfil del LXD
// ---------------------------------------------------------------------------

class _LxdProfile extends StatelessWidget {
  const _LxdProfile();

  @override
  Widget build(BuildContext context) {
    context.watch<DataProvider>();
    final lxd = context.watch<AuthProvider>().currentUser!;
    final e = lxd.extra;

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
              Text(lxd.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              Text(lxd.email,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
              const Divider(height: 32),
              row('Permiso de calificar · Open Learning',
                  lxd.canGradeOpenLearning ? 'Activado' : 'Desactivado'),
              row('Permiso de calificar · Enactus',
                  lxd.canGradeEnactus ? 'Activado' : 'Desactivado'),
              const Divider(height: 32),
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
