import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../models/progress.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/async_value.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_header.dart';
import '../../widgets/async_states.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';

/// Seguimiento de un curso: cifras, tabla de estudiantes con comentarios
/// privados y analíticas.
///
/// Todo lo que la tabla muestra por estudiante —avance, nota, última
/// actividad y comentario— llega en UNA respuesta
/// (`GET /courses/:id/students`). Antes cada celda lo calculaba por su cuenta
/// leyendo Hive: con treinta estudiantes eran ciento veinte cálculos por
/// cada `build()`.
class CourseTrackingView extends StatelessWidget {
  final String courseId;
  const CourseTrackingView({super.key, required this.courseId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(portalTitle: 'Seguimiento del Curso'),
          Expanded(
            child: combine3(
              data.courseById(courseId),
              data.courseStats(courseId),
              data.courseStudents(courseId),
            ).when(
              loading: () => const Center(child: BrandLoader()),
              // Un 404 acá es un curso ajeno: el servidor no confirma que
              // exista. Se muestra tal cual, sin inventar "no encontrado".
              error: (e) => ErrorState(e, onRetry: () async {
                await data.reloadCourse(courseId);
                await data.reloadCourseStudents(courseId);
              }),
              data: (values) {
                final (course, stats, students) = values;
                return _Body(
                    course: course, stats: stats, students: students);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Course course;
  final CourseStats stats;
  final List<CourseStudent> students;
  const _Body(
      {required this.course, required this.stats, required this.students});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold)),
              ),
              StatusChip(
                  label: course.statusLabel,
                  color: course.isPublished
                      ? AppColors.statusGood
                      : AppColors.statusWarning,
                  icon: course.isPublished ? Icons.public : Icons.edit_note),
            ],
          ),
          const SizedBox(height: 16),
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
            // Un guion, no un 0: "nadie tiene nota todavía" y "todos sacaron
            // cero" son cosas distintas.
            StatTile(
                value: stats.avgGrade == null
                    ? '—'
                    : stats.avgGrade!.toStringAsFixed(1),
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
                message: 'Aún no hay estudiantes asignados a este curso.\n'
                    'El admin los asigna desde su portal.')
          else
            _StudentsTable(courseId: course.id, students: students),
          const SectionTitle('Analíticas'),
          _Analytics(course: course, students: students),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Estudiantes
// ---------------------------------------------------------------------------

/// La tabla en pantalla ancha; tarjetas apiladas en una angosta.
///
/// Una tabla de seis columnas en un teléfono no se lee: obliga a desplazarse
/// en horizontal para cada fila. Las tarjetas muestran lo mismo, ordenado en
/// vertical.
class _StudentsTable extends StatelessWidget {
  final String courseId;
  final List<CourseStudent> students;
  const _StudentsTable({required this.courseId, required this.students});

  @override
  Widget build(BuildContext context) {
    if (context.breakpoint != AppBreakpoint.expanded) {
      return Column(
        children: [
          for (final student in students)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StudentCard(courseId: courseId, student: student),
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
            DataColumn(label: Text('Progreso')),
            DataColumn(label: Text('Nota')),
            DataColumn(label: Text('Última actividad')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Comentarios')),
          ],
          rows: [
            for (final student in students) _row(context, student),
          ],
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, CourseStudent s) {
    final status = _statusOf(s);
    return DataRow(
      color: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.hovered)
              ? AppColors.gold.withValues(alpha: 0.06)
              : null),
      cells: [
        DataCell(Tooltip(
          message: [s.name, s.university, s.career]
              .where((x) => x.isNotEmpty)
              .join('\n'),
          child: Text(s.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        )),
        DataCell(SizedBox(
            width: 130, child: ThinProgressBar(value: s.progress.ratio))),
        DataCell(Text(
            s.avgGrade == null ? '—' : s.avgGrade!.toStringAsFixed(1))),
        DataCell(Text(_lastActivity(s))),
        DataCell(StatusChip(
            label: status.$1, color: status.$2, icon: status.$3)),
        DataCell(_NoteButton(courseId: courseId, student: s)),
      ],
    );
  }
}

(String, Color, IconData) _statusOf(CourseStudent s) => s.progress.isComplete
    ? ('Completado', AppColors.statusGood, Icons.check)
    : s.hasStarted
        ? ('En curso', AppColors.gold, Icons.play_arrow)
        : ('Sin iniciar', AppColors.statusWarning, Icons.pause);

String _lastActivity(CourseStudent s) => s.lastActivityAt == null
    ? '—'
    : DateFormat('d MMM, h:mm a').format(s.lastActivityAt!);

class _StudentCard extends StatelessWidget {
  final String courseId;
  final CourseStudent student;
  const _StudentCard({required this.courseId, required this.student});

  @override
  Widget build(BuildContext context) {
    final status = _statusOf(student);
    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(student.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              StatusChip(
                  label: status.$1, color: status.$2, icon: status.$3),
            ],
          ),
          if (student.university.isNotEmpty)
            Text(student.university,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 10),
          ThinProgressBar(
            value: student.progress.ratio,
            tooltip: '${student.progress.completedLessons} de '
                '${student.progress.totalLessons} lecciones',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                    'Nota: ${student.avgGrade == null ? '—' : student.avgGrade!.toStringAsFixed(1)}'
                    '  ·  ${_lastActivity(student)}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ),
              _NoteButton(courseId: courseId, student: student),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteButton extends StatelessWidget {
  final String courseId;
  final CourseStudent student;
  const _NoteButton({required this.courseId, required this.student});

  @override
  Widget build(BuildContext context) {
    final hasNote = student.note.isNotEmpty;
    return Tooltip(
      message: hasNote
          ? 'Nota privada: ${student.note}'
          : 'Agregar comentario privado',
      child: IconButton(
        icon: Icon(
          hasNote ? Icons.chat_bubble : Icons.chat_bubble_outline,
          size: 18,
          color: hasNote ? AppColors.gold : AppColors.textMuted,
        ),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => _NoteDialog(courseId: courseId, student: student),
        ),
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  final String courseId;
  final CourseStudent student;
  const _NoteDialog({required this.courseId, required this.student});

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _note =
      TextEditingController(text: widget.student.note);
  bool _saving = false;
  ApiException? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<DataProvider>().saveStaffNote(
            courseId: widget.courseId,
            studentId: widget.student.id,
            note: _note.text.trim(),
          );
      if (mounted) Navigator.pop(context);
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
      title: Text('Comentarios privados — ${widget.student.name}',
          style: const TextStyle(fontSize: 18)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _note,
              enabled: !_saving,
              maxLines: 5,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Retroalimentación y observaciones',
                // Es literal: no hay ningún endpoint que le devuelva esta
                // nota a un estudiante.
                hintText:
                    'Solo para el equipo docente. El estudiante NO la ve.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(_error!),
            ],
          ],
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
// Analíticas
// ---------------------------------------------------------------------------

class _Analytics extends StatelessWidget {
  final Course course;
  final List<CourseStudent> students;
  const _Analytics({required this.course, required this.students});

  @override
  Widget build(BuildContext context) {
    var completed = 0, inProgress = 0, notStarted = 0;
    for (final s in students) {
      if (s.progress.isComplete) {
        completed++;
      } else if (s.hasStarted) {
        inProgress++;
      } else {
        notStarted++;
      }
    }

    final byUniversity = <String, List<double>>{};
    final bySponsor = <String, List<double>>{};
    for (final s in students) {
      if (s.university.isNotEmpty) {
        byUniversity.putIfAbsent(s.university, () => []).add(s.progress.ratio);
      }
      final sponsor = s.sponsorName;
      if (sponsor != null && sponsor.isNotEmpty) {
        bySponsor.putIfAbsent(sponsor, () => []).add(s.progress.ratio);
      }
    }

    double avg(List<double> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

    final abandonRate =
        students.isEmpty ? 0.0 : notStarted / students.length;
    final avgTimeHours = course.estimatedHours == 0 || students.isEmpty
        ? 0.0
        : students.fold<double>(
                0, (acc, s) => acc + course.estimatedHours * s.progress.ratio) /
            students.length;

    return Column(
      children: [
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 900;
          final donut = ChartCard(
            title: 'Avance del curso',
            height: 210,
            child: students.isEmpty
                ? const EmptyState(
                    icon: Icons.donut_large, message: 'Sin datos')
                : DonutChart(data: [
                    if (completed > 0)
                      (label: 'Completado', value: completed.toDouble()),
                    if (inProgress > 0)
                      (label: 'En curso', value: inProgress.toDouble()),
                    if (notStarted > 0)
                      (label: 'Sin iniciar', value: notStarted.toDouble()),
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
                        (label: e.key.split(' ').last, value: avg(e.value) * 100),
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
          if (bySponsor.isNotEmpty)
            StatTile(
                value:
                    '${(avg(bySponsor.values.expand((x) => x).toList()) * 100).round()}%',
                label: 'Avance de patrocinados',
                icon: Icons.business_outlined,
                detail: [
                  for (final e in bySponsor.entries)
                    '${e.key}: ${(avg(e.value) * 100).round()}%',
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
