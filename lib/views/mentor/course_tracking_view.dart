import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';

/// Seguimiento de un curso: estadísticas, tabla de estudiantes con
/// comentarios privados del mentor y analíticas con gráficas.
class CourseTrackingView extends StatelessWidget {
  final String courseId;
  const CourseTrackingView({super.key, required this.courseId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final course = data.courseById(courseId);
    if (course == null) {
      return const Scaffold(
          body: Center(child: Text('Curso no encontrado')));
    }
    final stats = data.courseStats(course);
    final students = data.studentsInCourse(course.id);

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(portalTitle: 'Seguimiento del Curso'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        color: AppColors.gold,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(course.name,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.gold)),
                      ),
                      StatusChip(
                          label: course.status,
                          color: course.isPublished
                              ? AppColors.statusGood
                              : AppColors.statusWarning,
                          icon: course.isPublished
                              ? Icons.public
                              : Icons.edit_note),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Números clave
                  StatRow(tiles: [
                    StatTile(
                        value: '${stats.enrolled}',
                        label: 'Inscritos',
                        icon: Icons.people_outline),
                    StatTile(
                        value: '${stats.completed}',
                        label: 'Completados',
                        icon: Icons.check_circle_outline),
                    StatTile(
                        value: '${(stats.avgProgress * 100).round()}%',
                        label: 'Avance promedio',
                        icon: Icons.trending_up),
                    StatTile(
                        value: stats.avgGrade == 0
                            ? '—'
                            : stats.avgGrade.toStringAsFixed(1),
                        label: 'Nota promedio',
                        icon: Icons.grade_outlined),
                    StatTile(
                        value: '${stats.pending}',
                        label: 'Pendientes',
                        icon: Icons.hourglass_empty),
                  ]),
                  const SectionTitle('Estudiantes'),
                  if (students.isEmpty)
                    const EmptyState(
                        icon: Icons.people_outline,
                        message:
                            'Aún no hay estudiantes asignados a este curso.\n'
                            'El admin los asigna desde su portal.')
                  else
                    _StudentsTable(course: course, students: students),
                  const SectionTitle('Analíticas'),
                  _Analytics(course: course, students: students),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tabla de estudiantes
// ---------------------------------------------------------------------------

class _StudentsTable extends StatelessWidget {
  final Course course;
  final List<AppUser> students;
  const _StudentsTable({required this.course, required this.students});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

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
            DataColumn(label: Text('Progreso')),
            DataColumn(label: Text('Nota')),
            DataColumn(label: Text('Última actividad')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Comentarios')),
          ],
          rows: [
            for (final s in students)
              _row(context, data, s),
          ],
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, DataProvider data, AppUser s) {
    final progress = data.courseProgress(s.id, course);
    final grades = data
        .submissionsForCourse(course.id)
        .where((x) => x.studentId == s.id && x.grade != null)
        .map((x) => x.grade!)
        .toList();
    final avgGrade = grades.isEmpty
        ? null
        : grades.reduce((a, b) => a + b) / grades.length;
    final last = data.lastActivity(s.id, course.id);
    final note = data.mentorNote(s.id, course.id);

    final (statusLabel, statusColor, statusIcon) = progress >= 1.0
        ? ('Completado', AppColors.statusGood, Icons.check)
        : progress > 0
            ? ('En curso', AppColors.gold, Icons.play_arrow)
            : ('Sin iniciar', AppColors.statusWarning, Icons.pause);

    return DataRow(
      color: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.hovered)
              ? AppColors.gold.withValues(alpha: 0.06)
              : null),
      cells: [
        DataCell(Tooltip(
          message: '${s.name}\n${s.university}\n${s.career}',
          child: Text(s.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        )),
        DataCell(SizedBox(
            width: 130, child: ThinProgressBar(value: progress))),
        DataCell(Text(avgGrade == null
            ? '—'
            : avgGrade.toStringAsFixed(1))),
        DataCell(Text(last == null
            ? '—'
            : DateFormat('d MMM, h:mm a').format(last))),
        DataCell(StatusChip(
            label: statusLabel, color: statusColor, icon: statusIcon)),
        DataCell(
          Tooltip(
            message: note.isEmpty
                ? 'Agregar comentario privado'
                : 'Nota privada: $note',
            child: IconButton(
              icon: Icon(
                note.isEmpty
                    ? Icons.chat_bubble_outline
                    : Icons.chat_bubble,
                size: 18,
                color: note.isEmpty
                    ? AppColors.textMuted
                    : AppColors.gold,
              ),
              onPressed: () => _editNote(context, data, s),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editNote(
      BuildContext context, DataProvider data, AppUser s) async {
    final ctrl =
        TextEditingController(text: data.mentorNote(s.id, course.id));
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Comentarios privados — ${s.name}',
            style: const TextStyle(fontSize: 18)),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: ctrl,
            maxLines: 5,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Retroalimentación y observaciones',
              hintText:
                  'Solo visible para ti. El estudiante NO ve estas notas.',
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await data.saveMentorNote(
                  s.id, course.id, ctrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Analíticas
// ---------------------------------------------------------------------------

class _Analytics extends StatelessWidget {
  final Course course;
  final List<AppUser> students;
  const _Analytics({required this.course, required this.students});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    // Distribución de avance
    var completed = 0, inProgress = 0, notStarted = 0;
    for (final s in students) {
      final p = data.courseProgress(s.id, course);
      if (p >= 1.0) {
        completed++;
      } else if (p > 0) {
        inProgress++;
      } else {
        notStarted++;
      }
    }

    // Promedio por universidad
    final byUniversity = <String, List<double>>{};
    for (final s in students) {
      if (s.university.isEmpty) continue;
      byUniversity
          .putIfAbsent(s.university, () => [])
          .add(data.courseProgress(s.id, course));
    }

    // Promedio por empresa patrocinadora del estudiante
    final byCompany = <String, List<double>>{};
    for (final s in students) {
      final sponsor =
          s.companyId == null ? null : data.userById(s.companyId!);
      if (sponsor == null) continue;
      byCompany
          .putIfAbsent(sponsor.companyName, () => [])
          .add(data.courseProgress(s.id, course));
    }

    final abandonRate =
        students.isEmpty ? 0.0 : notStarted / students.length;
    final avgTimeHours = course.estimatedHours == 0 || students.isEmpty
        ? 0.0
        : students.fold<double>(
                0,
                (acc, s) =>
                    acc +
                    course.estimatedHours *
                        data.courseProgress(s.id, course)) /
            students.length;

    double avg(List<double> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

    return Column(
      children: [
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 900;
          final donut = ChartCard(
            title: 'Avance del curso',
            height: 210,
            child: (students.isEmpty)
                ? const EmptyState(
                    icon: Icons.donut_large, message: 'Sin datos')
                : DonutChart(data: [
                    if (completed > 0)
                      (label: 'Completado', value: completed.toDouble()),
                    if (inProgress > 0)
                      (label: 'En curso', value: inProgress.toDouble()),
                    if (notStarted > 0)
                      (
                        label: 'Sin iniciar',
                        value: notStarted.toDouble()
                      ),
                  ]),
          );
          final uniBar = ChartCard(
            title: 'Avance promedio por universidad (%)',
            height: 210,
            child: byUniversity.isEmpty
                ? const EmptyState(
                    icon: Icons.account_balance_outlined,
                    message: 'Sin datos')
                : SimpleBarChart(
                    maxY: 100,
                    data: [
                      for (final e in byUniversity.entries)
                        (
                          label: e.key.split(' ').last,
                          value: avg(e.value) * 100
                        ),
                    ],
                  ),
          );
          return wide
              ? Row(children: [
                  Expanded(child: donut),
                  const SizedBox(width: 12),
                  Expanded(child: uniBar),
                ])
              : Column(children: [
                  donut,
                  const SizedBox(height: 12),
                  uniBar,
                ]);
        }),
        const SizedBox(height: 12),
        StatRow(tiles: [
          StatTile(
              value: '${(abandonRate * 100).round()}%',
              label: 'Riesgo de abandono (sin iniciar)',
              icon: Icons.warning_amber_outlined),
          StatTile(
              value: '${avgTimeHours.toStringAsFixed(1)} h',
              label: 'Tiempo promedio invertido',
              icon: Icons.schedule),
          if (byCompany.isNotEmpty)
            StatTile(
                value:
                    '${(avg(byCompany.values.expand((x) => x).toList()) * 100).round()}%',
                label: 'Avance de patrocinados',
                icon: Icons.business_outlined,
                detail: [
                  for (final e in byCompany.entries)
                    '${e.key}: ${(avg(e.value) * 100).round()}%'
                ].join('\n')),
          StatTile(
              value: '${course.lessonCount}',
              label: 'Lecciones totales',
              icon: Icons.list_alt),
        ]),
      ],
    );
  }
}
