import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/textos.dart';
import '../../models/models.dart';
import '../../models/progress.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../services/pdf_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/async_value.dart';
import '../../utils/formatos.dart';
import '../../utils/responsive.dart';
import '../../widgets/async_states.dart';
import '../../widgets/calendar_view.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../../widgets/submission_attachment.dart';
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
      portalTitle: tr.lxdPortal,
      tabs: [
        PortalTab(
            label: tr.tabMisEstudiantes,
            shortLabel: tr.tabEstudiantesCorto,
            destacada: true,
            icon: Icons.groups_outlined,
            builder: (_) => const _LxdStudents()),
        PortalTab(
            label: tr.tabProyectosCorto,
            icon: Icons.lightbulb_outline,
            builder: (_) => const _LxdProjects()),
        PortalTab(
            label: tr.tabCalendario,
            destacada: true,
            icon: Icons.calendar_month_outlined,
            builder: (_) => const _LxdCalendar()),
        PortalTab(
            label: tr.tabMisCursos,
            shortLabel: tr.tabCursosCorto,
            destacada: true,
            icon: Icons.video_library_outlined,
            builder: (_) => const _LxdCourses()),
        PortalTab(
            label: tr.tabCalificaciones,
            shortLabel: tr.tabCalificarCorto,
            destacada: true,
            icon: Icons.grading_outlined,
            builder: (_) => const _LxdGrading()),
        PortalTab(
            label: tr.tabCertificaciones,
            icon: Icons.workspace_premium_outlined,
            builder: (_) => const _LxdCertificates()),
        PortalTab(
            label: tr.tabMiPerfil,
            shortLabel: tr.tabPerfilCorto,
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
      title: tr.tabMisEstudiantes,
      subtitle: tr.lxdEstudiantesSubtitulo,
      children: [
        ConstrainedBox(
          // Un máximo, no un ancho fijo: en un teléfono tiene que poder
          // encogerse.
          constraints: const BoxConstraints(maxWidth: 320),
          child: TextField(
            decoration: InputDecoration(
              labelText: tr.lxdFiltrarNombre,
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
      return EmptyState(
          icon: Icons.groups_outlined,
          message: tr.lxdSinEstudiantes);
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
          columns: [
            DataColumn(label: Text(tr.comunEstudiante)),
            DataColumn(label: Text(tr.busquedaTipoProyecto)),
            DataColumn(label: Text(tr.comunEtapa)),
            DataColumn(label: Text(tr.lxdNecesidad)),
            DataColumn(label: Text(tr.comunInstitucion)),
            DataColumn(label: Text(tr.comunProgreso)),
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
                tooltip: tr.lxdPromedioCursos))),
      ],
    );
  }
}

/// Qué tanto acompañamiento necesita, según su avance. Es una lectura del
/// número, no un dato guardado: se calcula igual en la tabla y en la tarjeta.
String _need(double progress) => progress < 0.3
    ? tr.lxdAcompanamientoUrgente
    : progress < 0.7
        ? tr.lxdSeguimientoRegular
        : tr.lxdAutonomo;

String _summary(AppUser s) => [
      s.name,
      if (s.university.isNotEmpty) s.university,
      tr.lxdResumenProyecto(s.team?.projectName ?? '—'),
      tr.lxdResumenAvance(((s.overallProgress?.ratio ?? 0) * 100).round()),
      if (s.sponsorName != null) tr.lxdResumenEmpresa(s.sponsorName!),
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
              value: progress, tooltip: tr.lxdPromedioCursos),
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
      title: tr.tabProyectosCorto,
      subtitle: tr.lxdProyectosSubtitulo,
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
                  return EmptyState(
                      icon: Icons.lightbulb_outline,
                      message:
                          tr.lxdSinProyectos);
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
          Icon(Icons.lightbulb_outline, color: AppColors.gold, size: 24),
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
      title: tr.tabCalendario,
      subtitle: tr.lxdCalendarioSubtitulo,
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
      title: tr.tabMisCursos,
      subtitle: tr.lxdCursosSubtitulo,
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: Text(tr.lxdNuevoCurso),
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
              return EmptyState(
                  icon: Icons.video_library_outlined,
                  message: tr.lxdSinCursos);
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
          _error = ValidationError(tr.lxdNombreCurso));
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
      title: Text(tr.lxdNuevoCurso, style: TextStyle(fontSize: 18)),
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
                    InputDecoration(labelText: tr.lxdNombreDelCurso),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr.lxdCursoOpenLearning,
                    style: TextStyle(fontSize: 14)),
                subtitle: Text(
                    tr.lxdCursoOpenLearningTexto,
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
                  error: (_) => Text(
                      tr.lxdLabsNoCargan,
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12.5)),
                  data: (labs) => DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _labId,
                    decoration: InputDecoration(
                        labelText: tr.lxdLaboratorioOpcional),
                    items: [
                      DropdownMenuItem(
                          value: null, child: Text(tr.lxdSinAsignarAun)),
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
            child: Text(tr.comunCancelar)),
        ElevatedButton(
          onPressed: _creating ? null : _create,
          child: Text(_creating ? tr.comunCreando : tr.lxdCrearAbrir),
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
          LayoutBuilder(builder: (context, caja) {
            final titulo = Column(
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
            );
            final fichas = Wrap(
              spacing: 8,
              runSpacing: 6,
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
            );
            final fila = [
              Icon(Icons.auto_stories_outlined,
                  color: AppColors.gold, size: 26),
              const SizedBox(width: 12),
              Expanded(child: titulo),
            ];
            // Angosto (un teléfono): las fichas debajo del nombre. Al lado,
            // un `Wrap` dentro de la fila no baja nunca de línea y al nombre
            // le quedaban 3 o 4 letras por renglón.
            if (caja.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: fila),
                  const SizedBox(height: 8),
                  fichas,
                ],
              );
            }
            return Row(children: [...fila, fichas]);
          }),
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
              _miniStat(Icons.people_outline, tr.lxdInscritos(stats.enrolled)),
              _miniStat(Icons.check_circle_outline,
                  tr.lxdCompletados(stats.completed)),
              _miniStat(Icons.trending_up,
                  tr.lxdAvance((stats.avgProgress * 100).round())),
              _miniStat(
                  Icons.grade_outlined,
                  stats.avgGrade == null
                      ? tr.lxdSinNotas
                      : tr.lxdPromedio(decimal(stats.avgGrade!))),
              _miniStat(
                  Icons.hourglass_empty, tr.lxdPendientes(stats.pending)),
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
                          ? tr.lxdSinVincular
                          : tr.lxdVinculadoA(course.linkedModule!),
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
                label: Text(tr.lxdConstructor),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CourseEditorView(courseId: course.id)),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.insights_outlined, size: 16),
                label: Text(tr.lxdSeguimiento),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CourseTrackingView(courseId: course.id)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 19),
                color: AppColors.statusCritical,
                tooltip: tr.lxdEliminarCurso,
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
      tr.lxdEliminarCurso,
      tr.lxdEliminarCursoTexto(course.name),
    );
    if (!confirmed || !context.mounted) return;

    try {
      await data.deleteCourse(course.id);
      if (context.mounted) showSuccessCheck(context, tr.lxdCursoEliminado);
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
      title: tr.tabCalificaciones,
      subtitle: tr.lxdCalificacionesSubtitulo,
      children: [
        // El permiso lo decide el Admin y lo verifica el servidor. Acá solo
        // se explica por qué no hay nada que hacer.
        if (!canGradeAnything)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: StatusChip(
                label: tr.lxdSinPermisoCalificar,
                color: AppColors.statusWarning,
                icon: Icons.lock_outline),
          ),
        // `/submissions` ya devuelve solo las de los cursos de este LXD.
        data.submissions.when(
          loading: () => const CardListSkeleton(count: 3, height: 100),
          error: (e) => ErrorState(e, onRetry: data.reloadSubmissions),
          data: (all) {
            if (all.isEmpty) {
              return EmptyState(
                  icon: Icons.grading_outlined,
                  message: tr.lxdSinEntregas);
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
          // Angosto (un teléfono): el texto ocupa todo el ancho y el estado y
          // el botón van debajo. En una sola fila, a 360 dp le quedaban ~50 dp
          // a la tarea, el autor y la fecha: una palabra por línea.
          LayoutBuilder(builder: (context, caja) {
            final info = Column(
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
                        fechaCorta(s.submittedAt),
                      ].join(' · '),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                );
            final estado = StatusChip(
                label: s.gradeLabel,
                color: s.isGraded
                    ? (GradingMode.isPassing(s.grade, s.gradingMode)
                        ? AppColors.statusGood
                        : AppColors.statusCritical)
                    : AppColors.statusWarning,
                icon: s.isGraded ? Icons.grade : Icons.hourglass_empty,
              );
            final boton = ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _GradeDialog(submission: s),
                ),
                child: Text(!s.isGraded && s.feedback.isEmpty
                    ? (s.gradingMode == GradingMode.review
                        ? tr.foroRevisar
                        : tr.quizCalificar)
                    : tr.comunEditar),
              );
            if (caja.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  info,
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [estado, boton],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 10),
                estado,
                const SizedBox(width: 10),
                boton,
              ],
            );
          }),
          if (s.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(s.comment,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
          for (final file in s.files) SubmissionAttachmentRow(file: file),
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

  /// Acepta coma o punto: en un teclado en español la tecla decimal suele ser
  /// la coma, y "4,5" es tan válido como "4.5".
  static double? _numero(String texto) =>
      double.tryParse(texto.trim().replaceAll(',', '.'));

  /// Traduce lo que se escribió a la nota que espera el servidor, o devuelve
  /// el motivo por el que no se puede.
  (double?, String?) _resolveGrade() {
    switch (_mode) {
      case GradingMode.passfail:
        if (_passed == null) return (null, tr.calificarElija);
        return (_passed! ? 100 : 0, null);
      case GradingMode.review:
        return (null, null);
      case GradingMode.points100:
        final g = _numero(_grade.text);
        if (g == null || g < 0 || g > 100) {
          return (null, tr.calificarPuntajeRango);
        }
        return (g, null);
      default:
        final g = _numero(_grade.text);
        if (g == null || g < 0 || g > 5) {
          return (null, tr.calificarNotaRango);
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
      showSuccessCheck(context, tr.calificarEntregaCalificada);
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
      title: Text(tr.calificarTitulo(widget.submission.taskName),
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
                      InputDecoration(labelText: tr.calificarEscala),
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
                      Text(tr.calificarResultado),
                      ChoiceChip(
                        label: Text(tr.calificacionAprobado),
                        selected: _passed == true,
                        selectedColor:
                            AppColors.statusGood.withValues(alpha: 0.25),
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _passed = true),
                      ),
                      ChoiceChip(
                        label: Text(tr.calificacionReprobado),
                        selected: _passed == false,
                        selectedColor:
                            AppColors.statusCritical.withValues(alpha: 0.25),
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _passed = false),
                      ),
                    ],
                  ),
                GradingMode.review => Text(
                    tr.calificarSoloRevision,
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13)),
                GradingMode.points100 => TextField(
                    controller: _grade,
                    enabled: !_saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        InputDecoration(labelText: tr.calificarPuntaje),
                  ),
                _ => TextField(
                    controller: _grade,
                    enabled: !_saving,
                    // Con `number` a secas, el iPhone abre un teclado SIN
                    // punto decimal: no se podía escribir 4.5.
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        InputDecoration(labelText: tr.calificarNota),
                  ),
              },
              const SizedBox(height: 12),
              TextField(
                controller: _feedback,
                enabled: !_saving,
                maxLines: 3,
                decoration:
                    InputDecoration(labelText: tr.calificarRetroalimentacion),
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
            child: Text(tr.comunCancelar)),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? tr.comunGuardando : tr.comunGuardar),
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
      showSuccessCheck(context, tr.certificadoEmitido(cert.code));
      if (mounted) await PdfService.ver(context, cert);
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
      title: tr.tabCertificaciones,
      subtitle: tr.certificacionesSubtitulo,
      children: [
        if (!canIssue)
          StatusChip(
              label: tr.certificacionesSinPermiso,
              color: AppColors.statusWarning,
              icon: Icons.lock_outline)
        else
          _issueCard(data),
        SectionTitle(tr.certificacionesEmitidos),
        data.certificates.when(
          loading: () => const CardListSkeleton(count: 2, height: 58),
          error: (e) => ErrorState(e, onRetry: data.reloadCertificates),
          data: (certs) => certs.isEmpty
              ? EmptyState(
                  icon: Icons.workspace_premium_outlined,
                  message: tr.certificacionesVacio)
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
          Text(tr.certificacionesEmitirNuevo,
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
                            InputDecoration(labelText: tr.comunEstudiante),
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
                        decoration: InputDecoration(
                            labelText: tr.certificacionesLabRuta),
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
                      label: Text(_issuing ? tr.certificacionesEmitiendo : tr.certificacionesEmitir),
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
            Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(tr.certificacionesComprobando,
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            )
          else if (_studentId != null && _available.isEmpty && _error == null)
            Padding(
              padding: EdgeInsets.only(top: 10),
              child: StatusChip(
                  label: tr.certificacionesNoCompleto,
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
          Icon(Icons.workspace_premium, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
                tr.certificadoLinea(
                        cert.studentName, cert.laboratoryName, cert.code) +
                    (cert.hours > 0 ? ' · ${cert.hours} h' : ''),
                style: const TextStyle(fontSize: 13.5)),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('PDF'),
            onPressed: () => PdfService.ver(context, cert),
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
      title: tr.tabMiPerfil,
      subtitle: tr.lxdPerfilSubtitulo,
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
              _row(tr.perfilCiudad, lxd.city),
              const Divider(height: 32),
              // Los dos permisos, tal como los ve el servidor. Solo el Admin
              // los cambia, y cada cambio queda en el registro de auditoría.
              _row(tr.lxdPermisoOL,
                  lxd.canGradeOpenLearning ? tr.comunActivado : tr.comunDesactivado),
              _row(tr.lxdPermisoEduxaction,
                  lxd.canGradeEnactus ? tr.comunActivado : tr.comunDesactivado),
              const Divider(height: 32),
              for (final field in [
                // El campo de perfil (dónde trabaja), no el rol «Empresa
                // aliada».
                (tr.perfilCampoEmpresa, 'company'),
                (tr.perfilCargo, 'position'),
                (tr.perfilEspecialidad, 'specialty'),
                (tr.perfilIdiomas, 'languages'),
                (tr.perfilDisponibilidad, 'availability'),
                (tr.perfilExperiencia, 'experience'),
                (tr.perfilIntereses, 'interests'),
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
