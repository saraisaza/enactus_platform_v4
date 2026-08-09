import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import 'course_detail_view.dart';

/// Dashboard del estudiante — rediseño de alta fidelidad según
/// `design_handoff_portal_estudiante/README.md` (pantalla 1): progreso
/// general (lecciones completadas / lecciones totales, no promedio de
/// porcentajes), curso a continuar, progreso por curso, pendientes
/// priorizados, última entrega calificada y el estado del proyecto —
/// todo derivado de [DataProvider], nada hardcodeado.
class StudentDashboardView extends StatelessWidget {
  const StudentDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final courses = data.coursesForStudent(student);
    final labs = data.labsForStudent(student);
    final group = data.groupById(student.groupId);
    final project = group == null ? null : data.projectById(group.projectId);

    var totalLessons = 0;
    var doneLessons = 0;
    for (final c in courses) {
      totalLessons += c.lessonCount;
      doneLessons += data.progressFor(student.id, c.id).completedLessonIds.length;
    }
    final overallPct = totalLessons == 0 ? 0.0 : doneLessons / totalLessons;

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
      subtitle: project != null
          ? 'Proyecto ${project.name} · Etapa ${project.stage}'
              '${student.university.isEmpty ? '' : ' · ${student.university}'}'
          : 'Aún no tienes proyecto asignado',
      searchHint: 'Buscar en el portal',
      trailingBuilder: (context, colors, isDark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
        constraints: const BoxConstraints(minWidth: 360),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProgressRing(value: overallPct, size: 96, strokeWidth: 10, percentFontSize: 24, colors: colors),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Progreso general', style: TextStyle(fontSize: 13, color: colors.text3)),
                const SizedBox(height: 4),
                Text('$doneLessons de $totalLessons lecciones',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: colors.text)),
                const SizedBox(height: 4),
                Text('${courses.length} cursos activos · ${labs.length} laboratorios',
                    style: TextStyle(fontSize: 12.5, color: colors.text3)),
              ],
            ),
          ],
        ),
      ),
      bodyBuilder: (context, colors, isDark) {
        if (courses.isEmpty) {
          return EmptyState(
            icon: Icons.school_outlined,
            title: 'Todo por empezar',
            message: 'Aún no tienes cursos asignados. Cuando tu administrador '
                'te asigne uno, tu progreso aparecerá aquí.',
            primaryLabel: 'Actualizar',
            onPrimary: () => showAppSnack(context, 'Actualizado'),
            colors: colors,
          );
        }
        return LayoutBuilder(builder: (context, c) {
          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Entrance(child: _ContinueCard(courses: courses, student: student, colors: colors)),
              const SizedBox(height: 20),
              Entrance(
                  delayMs: 90,
                  child: _CourseProgressCard(courses: courses, student: student, colors: colors)),
            ],
          );
          final right = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Entrance(
                  delayMs: 60,
                  child: _PendingCard(
                      student: student, labs: labs, courses: courses, group: group, colors: colors)),
              const SizedBox(height: 20),
              Entrance(
                  delayMs: 150,
                  child: _RecentActivityCard(student: student, colors: colors)),
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
      },
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final List<Course> courses;
  final AppUser student;
  final ContentColors colors;
  const _ContinueCard({required this.courses, required this.student, required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    Course? course;
    for (final c in courses) {
      if (data.courseProgress(student.id, c) < 1.0) {
        course = c;
        break;
      }
    }
    if (course == null) {
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

    final labId = course.labId;
    final lab = data.labById(labId);
    final progress = data.courseProgress(student.id, course);
    final done = data.progressFor(student.id, course.id).completedLessonIds;
    final total = course.lessonCount;
    String? nextLesson;
    for (final m in course.modules) {
      for (final l in m.lessons) {
        if (!done.contains(l.id)) {
          nextLesson = l.title;
          break;
        }
      }
      if (nextLesson != null) break;
    }
    final accent = labColorFor(labId);

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
                const Positioned.fill(child: CustomPaint(painter: StripePainter())),
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
                        style: knockoutHeading(
                            fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white)),
                    if (lab != null) ...[
                      const SizedBox(height: 4),
                      Text(lab.name,
                          style: TextStyle(
                              fontSize: 13.5, color: Colors.white.withValues(alpha: 0.88))),
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
                      ThinProgressBar(value: progress, color: accent),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (nextLesson != null)
                            Expanded(
                              child: Text('Siguiente: $nextLesson',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12.5, color: colors.text3)),
                            ),
                          Text('${done.length} de $total',
                              style: TextStyle(fontSize: 12.5, color: colors.text3)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 19),
                  label: const Text('Continuar'),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => CourseDetailView(courseId: course!.id))),
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
  final AppUser student;
  final ContentColors colors;
  const _CourseProgressCard({required this.courses, required this.student, required this.colors});

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
              style: knockoutHeading(fontSize: 24, fontWeight: FontWeight.w800, color: colors.text)),
          const SizedBox(height: 16),
          for (final c in courses)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: colors.text)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: ThinProgressBar(
                        value: data.courseProgress(student.id, c), color: labColorFor(c.labId)),
                  ),
                ],
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
  const _PendingRow(
      {required this.icon, required this.color, required this.title, required this.meta});
}

class _PendingCard extends StatelessWidget {
  final AppUser student;
  final List<Laboratory> labs;
  final List<Course> courses;
  final Group? group;
  final ContentColors colors;
  const _PendingCard(
      {required this.student,
      required this.labs,
      required this.courses,
      required this.group,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final overdue = <_PendingRow>[];
    final mentoring = <_PendingRow>[];
    final toContinue = <_PendingRow>[];
    final teamTasks = <_PendingRow>[];

    for (final lab in labs) {
      for (final phase in lab.phases) {
        final status = data.phaseDeadlineStatus(student.id, lab.id, phase);
        if (status == DeadlineStatus.overdue) {
          overdue.add(_PendingRow(
            icon: Icons.warning_amber_rounded,
            color: AppColors.statusCritical,
            title: 'Fase vencida: ${phase.title.isEmpty ? 'Fase' : phase.title}',
            meta: lab.name,
          ));
        }
        for (var i = 0; i < phase.modules.length; i++) {
          final module = phase.modules[i];
          if (!module.isMentorshipModule) continue;
          final unlocked = data.isModuleUnlocked(student.id, lab.id, phase, i);
          final complete = data.isModuleComplete(student.id, lab.id, module);
          if (unlocked && !complete) {
            mentoring.add(_PendingRow(
              icon: Icons.diversity_3,
              color: AppColors.gold,
              title: 'Confirmar mentoría: ${phase.title.isEmpty ? 'Fase' : phase.title}',
              meta: lab.name,
            ));
          }
        }
      }
    }
    for (final c in courses) {
      if (data.courseProgress(student.id, c) < 1.0) {
        toContinue.add(_PendingRow(
          icon: Icons.play_circle_outline,
          color: labColorFor(c.labId),
          title: 'Continuar "${c.name}"',
          meta: c.labId.isEmpty ? 'Ruta National Expo' : (data.labById(c.labId)?.name ?? ''),
        ));
      }
    }
    if (group != null) {
      final checklist = data.checklistFor(group!.id);
      for (final item in checklist.items) {
        if (item['done'] != true) {
          teamTasks.add(_PendingRow(
            icon: Icons.description_outlined,
            color: AppColors.textMuted,
            title: (item['label'] as String?) ?? '',
            meta: 'Checklist National Expo',
          ));
        }
      }
    }

    final items = [...overdue, ...mentoring, ...toContinue, ...teamTasks].take(6).toList();

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
              style: knockoutHeading(fontSize: 24, fontWeight: FontWeight.w800, color: colors.text)),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text('¡Estás al día! No tienes pendientes.',
                style: TextStyle(fontSize: 13.5, color: colors.text3))
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: colors.surface2,
                    borderRadius: BorderRadius.circular(11),
                    border: Border(left: BorderSide(color: item.color, width: 3)),
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
                                style: TextStyle(fontSize: 13.5, color: colors.text)),
                            Text(item.meta, style: TextStyle(fontSize: 12, color: colors.text3)),
                          ],
                        ),
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

class _RecentActivityCard extends StatelessWidget {
  final AppUser student;
  final ContentColors colors;
  const _RecentActivityCard({required this.student, required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final graded = data.submissionsForStudent(student.id).where((s) => s.grade != null).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

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
              style: knockoutHeading(fontSize: 24, fontWeight: FontWeight.w800, color: colors.text)),
          const SizedBox(height: 14),
          if (graded.isEmpty)
            Text('Aún no tienes entregas calificadas.',
                style: TextStyle(fontSize: 13.5, color: colors.text3))
          else
            Builder(builder: (context) {
              final sub = graded.first;
              final course = data.courseById(sub.courseId);
              final teacher =
                  course == null || course.creatorId.isEmpty ? null : data.userById(course.creatorId);
              return Column(
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
                            color: colors.goldSoft, borderRadius: BorderRadius.circular(14)),
                        child: Text(sub.grade!.toStringAsFixed(1),
                            style: knockoutHeading(
                                fontSize: 26, fontWeight: FontWeight.w800, color: colors.goldInk)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(sub.taskName,
                                style: TextStyle(
                                    fontSize: 13.5, fontWeight: FontWeight.w600, color: colors.text)),
                            Text(
                                'Calificado el ${DateFormat('d MMM yyyy', 'es').format(sub.date)}'
                                '${teacher == null ? '' : ' · ${teacher.name}'}',
                                style: TextStyle(fontSize: 12, color: colors.text3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (sub.feedback.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Divider(height: 1, color: colors.border),
                    const SizedBox(height: 14),
                    Text('"${sub.feedback}"',
                        style: TextStyle(fontSize: 13, height: 1.55, color: colors.text2)),
                  ],
                ],
              );
            }),
        ],
      ),
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

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Tu proyecto'.toUpperCase(),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.text3, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(project.name.toUpperCase(),
              style: knockoutHeading(fontSize: 30, fontWeight: FontWeight.w800, color: colors.text)),
          const SizedBox(height: 14),
          StageRail(accentColor: odsColor, colors: colors, currentIndex: currentIndex),
          if (project.impactIndicators.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(project.impactIndicators, style: TextStyle(fontSize: 13, color: colors.text2)),
          ],
        ],
      ),
    );
  }
}
