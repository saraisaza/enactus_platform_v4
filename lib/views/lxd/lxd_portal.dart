import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../models/progress.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../services/pdf_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/async_value.dart';
import '../../utils/responsive.dart';
import '../../widgets/async_states.dart';
import '../../widgets/calendar_view.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import 'course_editor_view.dart';
import 'course_tracking_view.dart';

/// Portal del LXD (Learning Experience Designer): crea cursos, sigue a sus
/// estudiantes, califica entregas y emite certificados de Ruta.
///
/// Dos permisos separados gobiernan lo que puede hacer, y **los dos los
/// decide el servidor**: `canGradeOpenLearning` y `canGradeEnactus`. Acá se
/// leen para explicar por qué algo está deshabilitado — nunca para conceder:
/// la API rechaza igual una calificación sin permiso.
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
            builder: (_) => const _LxdStudents()),
        PortalTab(
            label: 'Proyectos',
            icon: Icons.lightbulb_outline,
            builder: (_) => const _LxdProjects()),
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
// Mis Estudiantes
// ---------------------------------------------------------------------------

/// Quiénes cursan lo que este LXD creó.
///
/// El alcance lo decide el servidor: `/users` para un LXD devuelve exactamente
/// las personas con acceso a alguno de sus cursos. Antes la pantalla se traía
/// la tabla completa de usuarios y filtraba en el navegador.
class _LxdStudents extends StatefulWidget {
  const _LxdStudents();

  @override
  State<_LxdStudents> createState() => _LxdStudentsState();
}

class _LxdStudentsState extends State<_LxdStudents> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Mis Estudiantes',
      subtitle: 'Estudiantes inscritos en cursos que usted creó',
      children: [
        ConstrainedBox(
          // Un máximo, no un ancho fijo: en un teléfono tiene que poder
          // encogerse.
          constraints: const BoxConstraints(maxWidth: 320),
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
        // `include=team,progress`: el equipo, el proyecto y el avance general
        // llegan con la lista. Sin eso, cada fila haría cuatro peticiones.
        data
            .users(role: 'student,alumni', include: 'team,progress')
            .when(
              loading: () => const CardListSkeleton(count: 4, height: 90),
              error: (e) => ErrorState(e, onRetry: data.reloadCourses),
              data: (all) => _table(context, _apply(all)),
            ),
      ],
    );
  }

  List<AppUser> _apply(List<AppUser> students) {
    final f = _filter.trim().toLowerCase();
    if (f.isEmpty) return students;
    return students
        .where((s) =>
            s.name.toLowerCase().contains(f) ||
            s.university.toLowerCase().contains(f))
        .toList();
  }

  Widget _table(BuildContext context, List<AppUser> students) {
    if (students.isEmpty) {
      return const EmptyState(
          icon: Icons.groups_outlined,
          message: 'No hay estudiantes inscritos en sus cursos.');
    }

    // Ocho columnas no caben en un teléfono: se apilan en tarjetas.
    if (context.breakpoint != AppBreakpoint.expanded) {
      return Column(
        children: [
          for (final s in students)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StudentCard(student: s),
            ),
        ],
      );
    }

    return Container(
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
            DataColumn(label: Text('Progreso')),
          ],
          rows: [for (final s in students) _row(s)],
        ),
      ),
    );
  }

  DataRow _row(AppUser s) {
    final progress = s.overallProgress?.ratio ?? 0;
    return DataRow(
      color: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.hovered)
              ? AppColors.gold.withValues(alpha: 0.06)
              : null),
      cells: [
        DataCell(Tooltip(
          message: _summary(s),
          child: Text(s.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        )),
        DataCell(Text(s.team?.projectName ?? '—')),
        DataCell(Text(s.team?.stageLabel ?? '—')),
        DataCell(Text(_need(progress))),
        DataCell(Text(s.university.isEmpty ? '—' : s.university)),
        DataCell(SizedBox(
            width: 120,
            child: ThinProgressBar(
                value: progress,
                tooltip: 'Promedio de todos sus cursos'))),
      ],
    );
  }
}

/// Qué tanto acompañamiento necesita, según su avance. Es una lectura del
/// número, no un dato guardado: se calcula igual en la tabla y en la tarjeta.
String _need(double progress) => progress < 0.3
    ? 'Acompañamiento urgente'
    : progress < 0.7
        ? 'Seguimiento regular'
        : 'Autónomo';

String _summary(AppUser s) => [
      s.name,
      if (s.university.isNotEmpty) s.university,
      'Proyecto: ${s.team?.projectName ?? '—'}',
      'Avance: ${((s.overallProgress?.ratio ?? 0) * 100).round()}%',
      if (s.sponsorName != null) 'Empresa: ${s.sponsorName}',
    ].join('\n');

class _StudentCard extends StatelessWidget {
  final AppUser student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final progress = student.overallProgress?.ratio ?? 0;
    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(student.name,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (student.university.isNotEmpty)
            Text(student.university,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (student.team != null) ...[
                StatusChip(
                    label: student.team!.projectName,
                    color: AppColors.slateLight,
                    icon: Icons.lightbulb_outline),
                StatusChip(
                    label: student.team!.stageLabel,
                    color: AppColors.slateLight,
                    icon: Icons.timeline),
              ],
              StatusChip(
                  label: _need(progress),
                  color: progress < 0.3
                      ? AppColors.statusCritical
                      : progress < 0.7
                          ? AppColors.statusWarning
                          : AppColors.statusGood,
                  icon: Icons.flag_outlined),
            ],
          ),
          const SizedBox(height: 10),
          ThinProgressBar(
              value: progress, tooltip: 'Promedio de todos sus cursos'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Proyectos
// ---------------------------------------------------------------------------

/// Los proyectos de los equipos de sus estudiantes.
///
/// Se arman desde la lista de estudiantes —que ya trae su equipo— en vez de
/// pedir la lista completa de proyectos de la plataforma: lo que le interesa
/// al LXD es dónde está SU gente.
class _LxdProjects extends StatelessWidget {
  const _LxdProjects();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Proyectos',
      subtitle: 'Equipos y avance en la Ruta de Impacto de sus estudiantes',
      children: [
        data.users(role: 'student,alumni', include: 'team,progress').when(
              loading: () => const CardListSkeleton(count: 3),
              error: (e) => ErrorState(e, onRetry: data.reloadCourses),
              data: (students) {
                // Cuántos de sus estudiantes hay en cada proyecto.
                final counts = <String, int>{};
                final names = <String, UserTeam>{};
                for (final s in students) {
                  final team = s.team;
                  if (team == null) continue;
                  counts[team.projectId] = (counts[team.projectId] ?? 0) + 1;
                  names[team.projectId] = team;
                }

                if (counts.isEmpty) {
                  return const EmptyState(
                      icon: Icons.lightbulb_outline,
                      message:
                          'Ninguno de sus estudiantes tiene proyecto asignado todavía.');
                }

                return Column(
                  children: [
                    for (final entry in counts.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ProjectRow(
                            team: names[entry.key]!, students: entry.value),
                      ),
                  ],
                );
              },
            ),
      ],
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final UserTeam team;
  final int students;
  const _ProjectRow({required this.team, required this.students});

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: AppColors.gold, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.projectName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                    '${team.groupName} · $students '
                    '${students == 1 ? 'estudiante suyo' : 'estudiantes suyos'}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12.5)),
              ],
            ),
          ),
          StatusChip(
              label: team.stageLabel,
              color: AppColors.slateLight,
              icon: Icons.timeline),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendario
// ---------------------------------------------------------------------------

class _LxdCalendar extends StatelessWidget {
  const _LxdCalendar();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Calendario',
      subtitle: 'Agenda las sesiones sincrónicas de sus cursos Open Learning',
      children: [
        combine2(data.calendarEvents, data.coursesWithStats).when(
          loading: () => const CardSkeleton(height: 320),
          error: (e) => ErrorState(e, onRetry: data.reloadCalendarEvents),
          data: (values) {
            final (events, courses) = values;
            final openLearning =
                courses.where((c) => c.isOpenLearning).toList();

            Future<void> save(
              List<CalendarEvent> list,
              String? idQueSeEdita,
            ) async {
              for (final event in list) {
                await data.saveCalendarEvent(event, id: idQueSeEdita);
              }
            }

            return CalendarView(
              events: events,
              canManage: true,
              onAddEvent: (day) => showCalendarEventDialog(
                context,
                initialDay: day,
                // Un LXD solo agenda sesiones de Open Learning: la mentoría
                // la agenda el Mentor, y el servidor lo verifica igual.
                allowedTypes: const [CalendarEventType.openLearningSync],
                courses: openLearning,
                labs: const [],
                defaultMeetLink:
                    data.siteContent.valueOrNull?.meetingLink ?? '',
                onSave: save,
              ),
              onEditEvent: (event) => showCalendarEventDialog(
                context,
                existing: event,
                allowedTypes: const [CalendarEventType.openLearningSync],
                courses: openLearning,
                labs: const [],
                defaultMeetLink:
                    data.siteContent.valueOrNull?.meetingLink ?? '',
                onSave: save,
              ),
              onDeleteEvent: (event) => data.deleteCalendarEvent(event.id),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mis Cursos
// ---------------------------------------------------------------------------

class _LxdCourses extends StatelessWidget {
  const _LxdCourses();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final lxd = context.watch<AuthProvider>().currentUser!;

    return TabBody(
      title: 'Mis Cursos',
      subtitle: 'Cursos que usted creó — eduXaction (asignados o no a un '
          'laboratorio) y Open Learning',
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nuevo curso'),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const _NewCourseDialog(),
          ),
        ),
      ],
      children: [
        data.coursesWithStats.when(
          loading: () => const CardListSkeleton(count: 3, height: 180),
          error: (e) => ErrorState(e, onRetry: data.reloadCoursesWithStats),
          data: (all) {
            // El servidor ya acota a lo que este LXD puede ver, pero un admin
            // también usa esta pantalla: se filtra por autoría.
            final mine = lxd.role == 'lxd'
                ? all.where((c) => c.creatorId == lxd.id).toList()
                : all;
            if (mine.isEmpty) {
              return const EmptyState(
                  icon: Icons.video_library_outlined,
                  message: 'Aún no has creado ningún curso. Crea el primero.');
            }
            return Column(
              children: [
                for (final course in mine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CourseAdminCard(course: course),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _NewCourseDialog extends StatefulWidget {
  const _NewCourseDialog();

  @override
  State<_NewCourseDialog> createState() => _NewCourseDialogState();
}

class _NewCourseDialogState extends State<_NewCourseDialog> {
  final _name = TextEditingController();
  String? _labId;
  bool _isOpenLearning = false;
  bool _creating = false;
  ApiException? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      setState(() =>
          _error = const ValidationError('Ponle un nombre al curso.'));
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      // El id lo asigna PostgreSQL: el cliente ya no lo inventa.
      final course = await context.read<DataProvider>().createCourse(
            name: _name.text.trim(),
            laboratoryId: _isOpenLearning ? null : _labId,
            isOpenLearning: _isOpenLearning,
          );
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CourseEditorView(courseId: course.id)),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _creating = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return AlertDialog(
      title: const Text('Nuevo curso', style: TextStyle(fontSize: 18)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                enabled: !_creating,
                decoration:
                    const InputDecoration(labelText: 'Nombre del curso'),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Curso de Open Learning',
                    style: TextStyle(fontSize: 14)),
                subtitle: const Text(
                    'Se asigna directo a estudiantes externos, sin '
                    'laboratorio ni Ruta de Impacto',
                    style: TextStyle(fontSize: 12)),
                value: _isOpenLearning,
                activeThumbColor: AppColors.gold,
                onChanged: _creating
                    ? null
                    : (v) => setState(() {
                          _isOpenLearning = v;
                          if (v) _labId = null;
                        }),
              ),
              if (!_isOpenLearning) ...[
                const SizedBox(height: 8),
                data.laboratories.when(
                  loading: () => const Skeleton(height: 48),
                  error: (_) => const Text(
                      'No se pudieron cargar los laboratorios. Puede '
                      'asignarlo después desde el constructor.',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12.5)),
                  data: (labs) => DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _labId,
                    decoration: const InputDecoration(
                        labelText: 'Laboratorio (opcional)'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Sin asignar por ahora')),
                      for (final lab in labs)
                        DropdownMenuItem(
                            value: lab.id, child: Text(lab.name)),
                    ],
                    onChanged:
                        _creating ? null : (v) => setState(() => _labId = v),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorBanner(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _creating ? null : () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _creating ? null : _create,
          child: Text(_creating ? 'Creando…' : 'Crear y abrir constructor'),
        ),
      ],
    );
  }
}

class _CourseAdminCard extends StatelessWidget {
  final Course course;
  const _CourseAdminCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final stats = course.stats ?? const CourseStats();
    final (statusColor, statusIcon) = switch (course.status) {
      CourseStatus.published => (AppColors.statusGood, Icons.public),
      CourseStatus.archived => (AppColors.statusSerious, Icons.archive_outlined),
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
              // En un `Wrap`, no en la fila: dos chips y un título largo
              // desbordan en cuanto la ventana se angosta.
              Wrap(
                spacing: 8,
                children: [
                  StatusChip(
                      label: course.statusLabel,
                      color: statusColor,
                      icon: statusIcon),
                  StatusChip(
                      label: course.levelLabel,
                      color: AppColors.slateLight,
                      icon: Icons.signal_cellular_alt),
                ],
              ),
            ],
          ),
          if (course.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(course.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
          const SizedBox(height: 10),
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
                  stats.avgGrade == null
                      ? 'Sin notas'
                      : 'Promedio ${stats.avgGrade!.toStringAsFixed(1)}'),
              _miniStat(
                  Icons.hourglass_empty, '${stats.pending} pendientes'),
            ],
          ),
          // Un curso de eduXaction sin vincular no le llega a nadie aunque
          // esté publicado: la tarjeta lo avisa.
          if (!course.isOpenLearning) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                    course.linkedModule == null
                        ? Icons.link_off
                        : Icons.check_circle_outline,
                    size: 14,
                    color: course.linkedModule == null
                        ? AppColors.textMuted
                        : AppColors.statusGood),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                      course.linkedModule == null
                          ? 'Sin vincular a ningún módulo todavía'
                          : 'Vinculado a: ${course.linkedModule}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // `Wrap` y no `Row` con `Spacer`: tres botones con etiquetas largas
          // no caben en una ventana angosta, y un `Spacer` no los encoge.
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.build_outlined, size: 16),
                label: const Text('Constructor'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CourseEditorView(courseId: course.id)),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.insights_outlined, size: 16),
                label: const Text('Seguimiento'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CourseTrackingView(courseId: course.id)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 19),
                color: AppColors.statusCritical,
                tooltip: 'Eliminar curso',
                onPressed: () => _delete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final data = context.read<DataProvider>();
    final confirmed = await confirmDoubleDialog(
      context,
      'Eliminar curso',
      'Vas a eliminar "${course.name}" con todos sus módulos, lecciones y '
          'configuración.',
    );
    if (!confirmed || !context.mounted) return;

    try {
      await data.deleteCourse(course.id);
      if (context.mounted) showSuccessCheck(context, 'Curso eliminado');
    } on ApiException catch (e) {
      // El servidor rechaza con 409 si está vinculado a una Ruta o si hay
      // estudiantes con avance: borrarlo dejaría el módulo de la fase
      // bloqueado en silencio para todo el laboratorio. Se dice el motivo.
      if (context.mounted) showAppSnack(context, e.message);
    }
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
// Calificaciones
// ---------------------------------------------------------------------------

class _LxdGrading extends StatelessWidget {
  const _LxdGrading();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final lxd = context.watch<AuthProvider>().currentUser!;
    final canGradeAnything =
        lxd.canGradeOpenLearning || lxd.canGradeEnactus ||
            lxd.role == 'admin' || lxd.role == 'superadmin';

    return TabBody(
      title: 'Calificaciones',
      subtitle: 'Entregas de estudiantes en sus cursos',
      children: [
        // El permiso lo decide el Admin y lo verifica el servidor. Acá solo
        // se explica por qué no hay nada que hacer.
        if (!canGradeAnything)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: StatusChip(
                label: 'Su Admin no le ha dado permiso de calificar todavía',
                color: AppColors.statusWarning,
                icon: Icons.lock_outline),
          ),
        // `/submissions` ya devuelve solo las de los cursos de este LXD.
        data.submissions.when(
          loading: () => const CardListSkeleton(count: 3, height: 100),
          error: (e) => ErrorState(e, onRetry: data.reloadSubmissions),
          data: (all) {
            if (all.isEmpty) {
              return const EmptyState(
                  icon: Icons.grading_outlined,
                  message: 'No hay entregas para calificar.');
            }
            final sorted = [...all]
              ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
            return Column(
              children: [
                for (final s in sorted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SubmissionRow(submission: s),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SubmissionRow extends StatelessWidget {
  final Submission submission;
  const _SubmissionRow({required this.submission});

  @override
  Widget build(BuildContext context) {
    final s = submission;
    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.taskName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    // Los nombres vienen con la entrega: sin eso serían tres
                    // peticiones por fila para escribir esta línea.
                    Text(
                      [
                        s.authorLabel,
                        if (s.courseName != null) s.courseName!,
                        DateFormat('d MMM yyyy').format(s.submittedAt),
                      ].join(' · '),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusChip(
                label: s.gradeLabel,
                color: s.isGraded
                    ? (GradingMode.isPassing(s.grade, s.gradingMode)
                        ? AppColors.statusGood
                        : AppColors.statusCritical)
                    : AppColors.statusWarning,
                icon: s.isGraded ? Icons.grade : Icons.hourglass_empty,
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _GradeDialog(submission: s),
                ),
                child: Text(!s.isGraded && s.feedback.isEmpty
                    ? (s.gradingMode == GradingMode.review
                        ? 'Revisar'
                        : 'Calificar')
                    : 'Editar'),
              ),
            ],
          ),
          if (s.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(s.comment,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

/// Calificar respetando la escala de la actividad.
///
/// La escala se guarda JUNTO a la nota porque el número solo no significa
/// nada: 100 es "aprobado" en `passfail` y "nota perfecta" en `points100`.
class _GradeDialog extends StatefulWidget {
  final Submission submission;
  const _GradeDialog({required this.submission});

  @override
  State<_GradeDialog> createState() => _GradeDialogState();
}

class _GradeDialogState extends State<_GradeDialog> {
  late String _mode = widget.submission.gradingMode ?? GradingMode.scale5;
  late final TextEditingController _grade =
      TextEditingController(text: widget.submission.grade?.toString() ?? '');
  late final TextEditingController _feedback =
      TextEditingController(text: widget.submission.feedback);
  late bool? _passed =
      widget.submission.grade == null ? null : widget.submission.grade! > 0;

  bool _saving = false;
  ApiException? _error;

  @override
  void dispose() {
    _grade.dispose();
    _feedback.dispose();
    super.dispose();
  }

  /// Traduce lo que se escribió a la nota que espera el servidor, o devuelve
  /// el motivo por el que no se puede.
  (double?, String?) _resolveGrade() {
    switch (_mode) {
      case GradingMode.passfail:
        if (_passed == null) return (null, 'Elija aprobado o reprobado.');
        return (_passed! ? 100 : 0, null);
      case GradingMode.review:
        return (null, null);
      case GradingMode.points100:
        final g = double.tryParse(_grade.text.trim());
        if (g == null || g < 0 || g > 100) {
          return (null, 'El puntaje va de 0 a 100.');
        }
        return (g, null);
      default:
        final g = double.tryParse(_grade.text.trim());
        if (g == null || g < 0 || g > 5) {
          return (null, 'La nota va de 0.0 a 5.0.');
        }
        return (g, null);
    }
  }

  Future<void> _save() async {
    final (grade, problem) = _resolveGrade();
    if (problem != null) {
      setState(() => _error = ValidationError(problem));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Marcar la lección como completa y avisarle al estudiante lo hace el
      // servidor en la misma llamada: calificar una actividad es lo que la
      // completa, y eso no puede depender de que el cliente se acuerde.
      await context.read<DataProvider>().gradeSubmission(
            submissionId: widget.submission.id,
            gradingMode: _mode,
            grade: grade,
            feedback: _feedback.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessCheck(context, 'Entrega calificada ✓');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Calificar: ${widget.submission.taskName}',
          style: const TextStyle(fontSize: 18)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Una entrega libre no trae escala: se elige acá.
              if (widget.submission.gradingMode == null) ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _mode,
                  decoration:
                      const InputDecoration(labelText: 'Escala de calificación'),
                  items: [
                    for (final mode in [
                      GradingMode.points100,
                      GradingMode.scale5,
                      GradingMode.passfail,
                      GradingMode.review,
                    ])
                      DropdownMenuItem(
                          value: mode, child: Text(GradingMode.label(mode))),
                  ],
                  onChanged:
                      _saving ? null : (v) => setState(() => _mode = v!),
                ),
                const SizedBox(height: 14),
              ],
              switch (_mode) {
                GradingMode.passfail => Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Resultado:'),
                      ChoiceChip(
                        label: const Text('Aprobado'),
                        selected: _passed == true,
                        selectedColor:
                            AppColors.statusGood.withValues(alpha: 0.25),
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _passed = true),
                      ),
                      ChoiceChip(
                        label: const Text('Reprobado'),
                        selected: _passed == false,
                        selectedColor:
                            AppColors.statusCritical.withValues(alpha: 0.25),
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _passed = false),
                      ),
                    ],
                  ),
                GradingMode.review => const Text(
                    'Esta actividad es de solo revisión: deja su '
                    'retroalimentación sin nota.',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13)),
                GradingMode.points100 => TextField(
                    controller: _grade,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Puntaje (0 - 100)'),
                  ),
                _ => TextField(
                    controller: _grade,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Nota (0.0 - 5.0)'),
                  ),
              },
              const SizedBox(height: 12),
              TextField(
                controller: _feedback,
                enabled: !_saving,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Retroalimentación'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorBanner(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Guardando…' : 'Guardar'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Certificaciones
// ---------------------------------------------------------------------------

/// El certificado se emite al completar la Ruta de Impacto COMPLETA de un
/// laboratorio. Ya no hay certificado por curso.
///
/// Quién está listo lo dice el servidor: se pide la Ruta del estudiante y se
/// ofrecen solo los laboratorios con `certificateAvailable`. La base lo hace
/// cumplir igual con un trigger, así que aunque la pantalla se equivocara, no
/// se emitiría uno inválido.
class _LxdCertificates extends StatefulWidget {
  const _LxdCertificates();

  @override
  State<_LxdCertificates> createState() => _LxdCertificatesState();
}

class _LxdCertificatesState extends State<_LxdCertificates> {
  String? _studentId;
  String? _labId;

  /// Los laboratorios de esta persona listos para certificar. Se piden UNA
  /// vez al elegirla, no en cada `build`.
  List<LabProgress> _available = const [];
  bool _checking = false;
  bool _issuing = false;
  ApiException? _error;

  Future<void> _selectStudent(String? id) async {
    setState(() {
      _studentId = id;
      _labId = null;
      _available = const [];
      _error = null;
      _checking = id != null;
    });
    if (id == null) return;

    try {
      final ruta = await context.read<DataProvider>().rutaProgressOf(id);
      // Otra selección pudo haber ocurrido mientras llegaba la respuesta.
      if (!mounted || _studentId != id) return;
      setState(() {
        _available = ruta.certificatesAvailable;
        _checking = false;
      });
    } on ApiException catch (e) {
      if (mounted && _studentId == id) {
        setState(() {
          _error = e;
          _checking = false;
        });
      }
    }
  }

  Future<void> _issue() async {
    setState(() {
      _issuing = true;
      _error = null;
    });
    try {
      final cert = await context.read<DataProvider>().issueRutaCertificate(
            studentId: _studentId!,
            laboratoryId: _labId!,
          );
      if (!mounted) return;
      setState(() {
        _issuing = false;
        _labId = null;
        _available = const [];
      });
      showSuccessCheck(context, 'Certificado ${cert.code} emitido 🏆');
      await PdfService.preview(cert);
    } on ApiException catch (e) {
      // El servidor responde 409 con el detalle de QUÉ falta si la Ruta no
      // está completa. Ese detalle es lo que hay que mostrar.
      if (mounted) {
        setState(() {
          _issuing = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final lxd = context.watch<AuthProvider>().currentUser!;
    final canIssue = lxd.canGradeEnactus ||
        lxd.role == 'admin' ||
        lxd.role == 'superadmin';

    return TabBody(
      title: 'Certificaciones',
      subtitle: 'El certificado se emite al completar la Ruta de Impacto '
          'completa de un laboratorio (ya no hay certificado por curso)',
      children: [
        if (!canIssue)
          const StatusChip(
              label: 'Su Admin no le ha dado permiso de calificar en '
                  'eduXaction: no puede emitir certificados todavía',
              color: AppColors.statusWarning,
              icon: Icons.lock_outline)
        else
          _issueCard(data),
        const SectionTitle('Certificados emitidos'),
        data.certificates.when(
          loading: () => const CardListSkeleton(count: 2, height: 58),
          error: (e) => ErrorState(e, onRetry: data.reloadCertificates),
          data: (certs) => certs.isEmpty
              ? const EmptyState(
                  icon: Icons.workspace_premium_outlined,
                  message: 'Aún no se han emitido certificados.')
              : Column(
                  children: [
                    for (final cert in certs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CertificateRow(cert: cert),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _issueCard(DataProvider data) {
    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Emitir nuevo certificado',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          data.users(role: 'student,alumni').when(
                loading: () => const Skeleton(height: 56),
                error: (e) => ErrorState(e, compact: true),
                data: (students) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<String>(
                        // Sin `isExpanded`, un desplegable se dimensiona al
                        // ítem MÁS ANCHO de su lista, no al ancho que se le
                        // dio: un nombre largo de estudiante desbordaba este
                        // campo por 87px. Con los nombres del seed no se veía;
                        // aparece con los reales. Va en los 23 desplegables de
                        // la app por la misma razón.
                        isExpanded: true,
                        initialValue: _studentId,
                        decoration:
                            const InputDecoration(labelText: 'Estudiante'),
                        items: [
                          for (final s in students)
                            DropdownMenuItem(
                                value: s.id, child: Text(s.name)),
                        ],
                        onChanged: _issuing ? null : _selectStudent,
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _labId,
                        decoration: const InputDecoration(
                            labelText: 'Laboratorio (Ruta completa)'),
                        items: [
                          for (final lab in _available)
                            DropdownMenuItem(
                                value: lab.laboratoryId,
                                child: Text(lab.laboratoryName)),
                        ],
                        onChanged: _issuing
                            ? null
                            : (v) => setState(() => _labId = v),
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.workspace_premium, size: 18),
                      label: Text(_issuing ? 'Emitiendo…' : 'Emitir'),
                      onPressed:
                          _studentId == null || _labId == null || _issuing
                              ? null
                              : _issue,
                    ),
                  ],
                ),
              ),
          // Mientras se comprueba no se dice que no hay nada: eso sería una
          // mentira a medias.
          if (_checking)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Comprobando su Ruta de Impacto…',
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            )
          else if (_studentId != null && _available.isEmpty && _error == null)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: StatusChip(
                  label: 'Este estudiante aún no completó la Ruta de '
                      'Impacto de ningún laboratorio',
                  color: AppColors.statusWarning,
                  icon: Icons.warning_amber_outlined),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(_error!),
          ],
        ],
      ),
    );
  }
}

class _CertificateRow extends StatelessWidget {
  final Certificate cert;
  const _CertificateRow({required this.cert});

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
                '${cert.studentName} · Ruta de Impacto ${cert.laboratoryName} '
                '· ${cert.code}'
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
    );
  }
}

// ---------------------------------------------------------------------------
// Mi Perfil
// ---------------------------------------------------------------------------

class _LxdProfile extends StatelessWidget {
  const _LxdProfile();

  @override
  Widget build(BuildContext context) {
    final lxd = context.watch<AuthProvider>().currentUser!;

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
              _row('Ciudad', lxd.city),
              const Divider(height: 32),
              // Los dos permisos, tal como los ve el servidor. Solo el Admin
              // los cambia, y cada cambio queda en el registro de auditoría.
              _row('Permiso de calificar · Open Learning',
                  lxd.canGradeOpenLearning ? 'Activado' : 'Desactivado'),
              _row('Permiso de calificar · eduXaction',
                  lxd.canGradeEnactus ? 'Activado' : 'Desactivado'),
              const Divider(height: 32),
              for (final field in const [
                ('Empresa', 'company'),
                ('Cargo', 'position'),
                ('Especialidad', 'specialty'),
                ('Idiomas', 'languages'),
                ('Disponibilidad', 'availability'),
                ('Experiencia', 'experience'),
                ('Intereses', 'interests'),
              ])
                _row(field.$1, lxd.profileField(field.$2)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
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
}
