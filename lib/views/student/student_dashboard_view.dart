import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../models/progress.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/async_states.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../shared/projects_directory_view.dart' show ProjectDetailView;
import 'course_detail_view.dart';

/// Dashboard del estudiante: progreso general, curso a continuar, progreso por
/// curso, pendientes priorizados, última entrega calificada y estado del
/// proyecto.
///
/// Nada de esto se calcula acá. El avance por curso, el desbloqueo de módulos
/// y el estado de cada fecha límite los resuelve el servidor y llegan ya
/// hechos: antes se recalculaban en cada `build()`, y dos tarjetas de la misma
/// pantalla podían discrepar.
class StudentDashboardView extends StatelessWidget {
  const StudentDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final team = student.team;

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final eyebrow = monday.month == sunday.month
        ? 'Semana del ${DateFormat('d', 'es').format(monday)} al '
            '${DateFormat("d 'de' MMMM", 'es').format(sunday)}'
        : 'Semana del ${DateFormat("d 'de' MMM", 'es').format(monday)} al '
            '${DateFormat("d 'de' MMM", 'es').format(sunday)}';

    return ContentScreenShell(
      eyebrow: eyebrow,
      title: 'Hola, ${student.name.split(' ').first}',
      subtitle: team != null
          ? 'Proyecto ${team.projectName}'
              '${student.university.isEmpty ? '' : ' · ${student.university}'}'
          : 'Aún no tienes proyecto asignado',
      searchHint: 'Buscar en el portal',
      trailingBuilder: (context, colors, isDark) =>
          _OverallProgress(student: student, colors: colors),
      bodyBuilder: (context, colors, isDark) => data.courses.when(
        loading: () => const CardListSkeleton(count: 3),
        error: (e) => ErrorState(e, onRetry: data.reloadCourses),
        data: (courses) {
          if (courses.isEmpty) {
            return EmptyState(
              icon: Icons.school_outlined,
              title: 'Todo por empezar',
              message: 'Aún no tienes cursos asignados. Cuando tu administrador '
                  'te asigne uno, tu progreso aparecerá aquí.',
              primaryLabel: 'Actualizar',
              onPrimary: data.reloadCourses,
              colors: colors,
            );
          }
          return _DashboardBody(
              student: student, courses: courses, colors: colors);
        },
      ),
    );
  }
}

/// El anillo de avance del encabezado.
///
/// Se cuentan lecciones, no se promedian porcentajes: un curso de 40 lecciones
/// y uno de 4 no pesan lo mismo, y promediar sus porcentajes diría que sí.
class _OverallProgress extends StatelessWidget {
  final AppUser student;
  final ContentColors colors;
  const _OverallProgress({required this.student, required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final courses = data.courses.valueOrNull;

    var totalLessons = 0;
    var doneLessons = 0;
    if (courses != null) {
      for (final course in courses) {
        final progress = data.courseProgress(course.id).valueOrNull;
        if (progress == null) continue;
        totalLessons += progress.totalLessons;
        doneLessons += progress.completedLessons;
      }
    }
    final ratio = totalLessons == 0 ? 0.0 : doneLessons / totalLessons;
    final labCount = student.isEnactusStudent
        ? data.rutaProgress.valueOrNull?.laboratories.length
        : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProgressRing(
              value: ratio,
              size: 96,
              strokeWidth: 10,
              percentFontSize: 24,
              colors: colors),
          const SizedBox(width: 20),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Progreso general',
                    style: TextStyle(fontSize: 13, color: colors.text3)),
                const SizedBox(height: 4),
                Text('$doneLessons de $totalLessons lecciones',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.text)),
                const SizedBox(height: 4),
                Text(
                    '${courses?.length ?? 0} cursos activos'
                    '${labCount == null ? '' : ' · $labCount laboratorios'}',
                    style: TextStyle(fontSize: 12.5, color: colors.text3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final AppUser student;
  final List<Course> courses;
  final ContentColors colors;
  const _DashboardBody(
      {required this.student, required this.courses, required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final team = student.team;
    final project =
        team == null ? null : data.projectById(team.projectId).valueOrNull;

    return LayoutBuilder(builder: (context, c) {
      final left = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Entrance(child: _ContinueCard(courses: courses, colors: colors)),
          const SizedBox(height: 20),
          Entrance(
              delayMs: 90,
              child: _CourseProgressCard(courses: courses, colors: colors)),
        ],
      );
      final right = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Entrance(
              delayMs: 60,
              child: _PendingCard(
                  student: student, courses: courses, colors: colors)),
          const SizedBox(height: 20),
          Entrance(delayMs: 150, child: _RecentActivityCard(colors: colors)),
          if (project != null) ...[
            const SizedBox(height: 20),
            Entrance(
                delayMs: 210,
                child: _ProjectCard(project: project, colors: colors)),
          ],
        ],
      );
      if (c.maxWidth > 800) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 155, child: left),
            const SizedBox(width: 20),
            Expanded(flex: 100, child: right),
          ],
        );
      }
      return Column(children: [left, const SizedBox(height: 20), right]);
    });
  }
}

class _ContinueCard extends StatelessWidget {
  final List<Course> courses;
  final ContentColors colors;
  const _ContinueCard({required this.courses, required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    Course? course;
    CourseProgress? progress;
    for (final candidate in courses) {
      final state = data.courseProgress(candidate.id).valueOrNull;
      if (state != null && !state.isComplete) {
        course = candidate;
        progress = state;
        break;
      }
    }

    if (course == null || progress == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: colors.goldInk, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Text('Ya completaste todos tus cursos asignados.',
                  style: TextStyle(fontSize: 14, color: colors.text2)),
            ),
          ],
        ),
      );
    }

    final accent = labColorFor(course.laboratoryId ?? '');
    final courseId = course.id;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
            decoration: BoxDecoration(color: accent),
            child: Stack(
              children: [
                const Positioned.fill(
                    child: CustomPaint(painter: StripePainter())),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('CONTINÚA DONDE IBAS',
                        style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 12 * 0.16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 8),
                    Text(course.name.toUpperCase(),
                        style: displayHeading(
                            fontSize: 38,
                            fontWeight: AppWeights.display,
                            color: Colors.white)),
                    // El nombre del laboratorio viene con el curso: no hace
                    // falta pedirlo aparte por cada tarjeta.
                    if (course.laboratoryName != null) ...[
                      const SizedBox(height: 4),
                      Text(course.laboratoryName!,
                          style: TextStyle(
                              fontSize: 13.5,
                              color: Colors.white.withValues(alpha: 0.88))),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ThinProgressBar(value: progress.ratio, color: accent),
                      const SizedBox(height: 6),
                      Text(
                          '${progress.completedLessons} de ${progress.totalLessons} lecciones',
                          style:
                              TextStyle(fontSize: 12.5, color: colors.text3)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 19),
                  label: const Text('Continuar'),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          settings: RouteSettings(
                              name: '${AppRoutes.courses}/$courseId'),
                          builder: (_) =>
                              CourseDetailView(courseId: courseId))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseProgressCard extends StatelessWidget {
  final List<Course> courses;
  final ContentColors colors;
  const _CourseProgressCard({required this.courses, required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Progreso por curso'.toUpperCase(),
              style: displayHeading(
                  fontSize: 24,
                  fontWeight: AppWeights.display,
                  color: colors.text)),
          const SizedBox(height: 16),
          for (final course in courses)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: KeyboardHoverBuilder(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        settings: RouteSettings(
                            name: '${AppRoutes.courses}/${course.id}'),
                        builder: (_) =>
                            CourseDetailView(courseId: course.id))),
                builder: (context, hover) => Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(course.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: colors.text)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: ThinProgressBar(
                          value:
                              data.courseProgress(course.id).valueOrNull?.ratio ??
                                  0,
                          color: labColorFor(course.laboratoryId ?? '')),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingRow {
  final IconData icon;
  final Color color;
  final String title;
  final String meta;
  final VoidCallback? onTap;
  const _PendingRow(
      {required this.icon,
      required this.color,
      required this.title,
      required this.meta,
      this.onTap});
}

/// Pendientes, en orden de urgencia: fases vencidas, mentorías por confirmar,
/// cursos a medias y tareas del checklist del equipo.
///
/// Qué está vencido, qué está desbloqueado y qué está completo lo dice el
/// servidor. Un Open Learning no tiene fases ni mentorías —y pedirlas le daría
/// 403— así que para esas cuentas la tarjeta solo lista cursos.
class _PendingCard extends StatelessWidget {
  final AppUser student;
  final List<Course> courses;
  final ContentColors colors;
  const _PendingCard(
      {required this.student, required this.courses, required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final overdue = <_PendingRow>[];
    final mentoring = <_PendingRow>[];
    final toContinue = <_PendingRow>[];
    final teamTasks = <_PendingRow>[];

    if (student.isEnactusStudent) {
      final ruta = data.rutaProgress.valueOrNull;
      for (final lab in ruta?.laboratories ?? const <LabProgress>[]) {
        for (final phase in lab.phases) {
          if (phase.deadlineStatus == DeadlineStatus.overdue) {
            overdue.add(_PendingRow(
              icon: Icons.warning_amber_rounded,
              color: AppColors.statusCritical,
              title:
                  'Fase vencida: ${phase.title.isEmpty ? 'Fase' : phase.title}',
              meta: lab.laboratoryName,
              onTap: () => Navigator.pushNamed(context,
                  '${AppRoutes.forRole(student.role)}/lab/${lab.laboratoryId}'),
            ));
          }
          for (final module in phase.modules) {
            if (!module.isMentorshipModule) continue;
            if (module.isUnlocked && !module.isComplete) {
              mentoring.add(_PendingRow(
                icon: Icons.diversity_3,
                color: AppColors.gold,
                title:
                    'Confirmar mentoría: ${phase.title.isEmpty ? 'Fase' : phase.title}',
                meta: lab.laboratoryName,
                onTap: () => Navigator.pushNamed(
                    context,
                    '${AppRoutes.forRole(student.role)}'
                    '/lab/${lab.laboratoryId}'),
              ));
            }
          }
        }
      }
    }

    for (final course in courses) {
      final progress = data.courseProgress(course.id).valueOrNull;
      if (progress == null || progress.isComplete) continue;
      toContinue.add(_PendingRow(
        icon: Icons.play_circle_outline,
        color: labColorFor(course.laboratoryId ?? ''),
        title: 'Continuar "${course.name}"',
        meta: course.laboratoryName ??
            (course.isRutaExpo ? 'Ruta National Expo' : 'Open Learning'),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                settings:
                    RouteSettings(name: '${AppRoutes.courses}/${course.id}'),
                builder: (_) => CourseDetailView(courseId: course.id))),
      ));
    }

    final team = student.team;
    final group = team == null ? null : data.groupById(team.groupId).valueOrNull;
    if (group != null) {
      for (final item in group.pendingChecklist) {
        teamTasks.add(_PendingRow(
          icon: Icons.description_outlined,
          color: AppColors.textMuted,
          title: item.label,
          meta: 'Checklist National Expo',
          onTap: () => _showChecklistDialog(context, colors, group.checklist),
        ));
      }
    }

    final items =
        [...overdue, ...mentoring, ...toContinue, ...teamTasks].take(6).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Pendientes'.toUpperCase(),
              style: displayHeading(
                  fontSize: 24,
                  fontWeight: AppWeights.display,
                  color: colors.text)),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text('¡Estás al día! No tienes pendientes.',
                style: TextStyle(fontSize: 13.5, color: colors.text3))
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: KeyboardHoverBuilder(
                  onTap: item.onTap,
                  builder: (context, hover) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: colors.surface2,
                      borderRadius: BorderRadius.circular(11),
                      border:
                          Border(left: BorderSide(color: item.color, width: 3)),
                    ),
                    child: Row(
                      children: [
                        Icon(item.icon, size: 19, color: item.color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13.5, color: colors.text)),
                              Text(item.meta,
                                  style: TextStyle(
                                      fontSize: 12, color: colors.text3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Checklist RUTA NATIONAL EXPO del equipo, de solo lectura.
///
/// No existe ninguna pantalla que lo edite, y la API tampoco expone escritura:
/// llega dentro del equipo (`GET /groups/:id`). Construir esa edición sería
/// una función nueva, no una migración.
void _showChecklistDialog(
    BuildContext context, ContentColors colors, List<ChecklistItem> items) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.surface,
      title: const Text('Checklist RUTA NATIONAL EXPO'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                        item.done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color:
                            item.done ? AppColors.statusGood : colors.text3),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(item.label,
                            style: TextStyle(
                                fontSize: 13.5, color: colors.text))),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
      ],
    ),
  );
}

class _RecentActivityCard extends StatelessWidget {
  final ContentColors colors;
  const _RecentActivityCard({required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Actividad reciente'.toUpperCase(),
              style: displayHeading(
                  fontSize: 24,
                  fontWeight: AppWeights.display,
                  color: colors.text)),
          const SizedBox(height: 14),
          // `/submissions` ya devuelve solo las propias cuando quien pregunta
          // es un estudiante.
          data.submissions.when(
            loading: () => const CardSkeleton(height: 80),
            error: (e) =>
                ErrorState(e, onRetry: data.reloadSubmissions, compact: true),
            data: (all) => _lastGraded(context, all),
          ),
        ],
      ),
    );
  }

  Widget _lastGraded(BuildContext context, List<Submission> all) {
    final graded = all.where((s) => s.isGraded).toList()
      ..sort((a, b) => b.gradedAt!.compareTo(a.gradedAt!));

    if (graded.isEmpty) {
      return Text('Aún no tienes entregas calificadas.',
          style: TextStyle(fontSize: 13.5, color: colors.text3));
    }

    final data = context.watch<DataProvider>();
    final submission = graded.first;
    final courseId = submission.courseId;
    final course =
        courseId == null ? null : data.courseById(courseId).valueOrNull;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: colors.goldSoft,
                  borderRadius: BorderRadius.circular(14)),
              // La nota se muestra en SU escala: un 100 significa cosas
              // distintas en `passfail` y en `points100`.
              child: Text(submission.gradeLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.goldInk,
                      height: 1.1)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(submission.taskName,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: colors.text)),
                  Text(
                      'Calificado el '
                      '${DateFormat('d MMM yyyy', 'es').format(submission.gradedAt!)}'
                      '${course?.creatorName == null ? '' : ' · ${course!.creatorName}'}',
                      style: TextStyle(fontSize: 12, color: colors.text3)),
                ],
              ),
            ),
          ],
        ),
        if (submission.feedback.isNotEmpty) ...[
          const SizedBox(height: 14),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 14),
          Text('"${submission.feedback}"',
              style:
                  TextStyle(fontSize: 13, height: 1.55, color: colors.text2)),
        ],
      ],
    );

    if (course == null) return content;
    return KeyboardHoverBuilder(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              settings:
                  RouteSettings(name: '${AppRoutes.courses}/${course.id}'),
              builder: (_) => CourseDetailView(courseId: course.id))),
      builder: (context, hover) => content,
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final ContentColors colors;
  const _ProjectCard({required this.project, required this.colors});

  @override
  Widget build(BuildContext context) {
    final odsColor =
        project.ods.isNotEmpty ? odsColorFor(project.ods.first) : AppColors.gold;
    final stageIndex = projectStages.indexOf(project.stage);
    final currentIndex = stageIndex < 0 ? 0 : stageIndex;

    return KeyboardHoverBuilder(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              settings:
                  RouteSettings(name: '${AppRoutes.projects}/${project.id}'),
              builder: (_) => ProjectDetailView(projectId: project.id))),
      builder: (context, hover) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: hover ? AppColors.gold : colors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tu proyecto'.toUpperCase(),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.text3,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(project.name.toUpperCase(),
                style: displayHeading(
                    fontSize: 30,
                    fontWeight: AppWeights.display,
                    color: colors.text)),
            const SizedBox(height: 14),
            StageRail(
                accentColor: odsColor,
                colors: colors,
                currentIndex: currentIndex),
            if (project.impactIndicators.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(project.impactIndicators,
                  style: TextStyle(fontSize: 13, color: colors.text2)),
            ],
          ],
        ),
      ),
    );
  }
}
