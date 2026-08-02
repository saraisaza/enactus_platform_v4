import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common.dart';
import '../../widgets/video_player_dialog.dart';
import '../lxd/lesson_editor.dart' show lessonTypeIcon, lessonTypeLabel;

/// Detalle de un curso para el estudiante: módulos y lecciones de todos los
/// tipos (video, PDF, recurso, enlace, quiz, actividad, encuesta), progreso
/// y entregas.
class CourseDetailView extends StatelessWidget {
  final String courseId;
  const CourseDetailView({super.key, required this.courseId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final course = data.courseById(courseId);
    if (course == null) {
      return const Scaffold(body: Center(child: Text('Curso no encontrado')));
    }
    final progress = data.progressFor(student.id, course.id);
    final mySubmissions = data
        .submissionsForStudent(student.id)
        .where((s) => s.courseId == course.id)
        .toList();

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(portalTitle: 'Curso'),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
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
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(course.name,
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.gold)),
                                  if (course.subtitle.isNotEmpty)
                                    Text(course.subtitle,
                                        style: const TextStyle(
                                            color:
                                                AppColors.textSecondary,
                                            fontSize: 14)),
                                ],
                              ),
                            ),
                            StatusChip(
                                label: course.level,
                                color: AppColors.slateLight,
                                icon: Icons.signal_cellular_alt),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 56),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  course.fullDescription.isNotEmpty
                                      ? course.fullDescription
                                      : course.description,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                      height: 1.5)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 14,
                                runSpacing: 6,
                                children: [
                                  if (course.estimatedHours > 0)
                                    _meta(Icons.schedule,
                                        '${course.estimatedHours} h estimadas'),
                                  _meta(Icons.language, course.language),
                                  if (course.generatesCertificate)
                                    _meta(Icons.workspace_premium_outlined,
                                        'Genera certificado'),
                                  for (final t in course.tags.take(4))
                                    _meta(Icons.tag, t),
                                ],
                              ),
                              if (course.objectives.isNotEmpty) ...[
                                const SectionTitle('Objetivos'),
                                for (final o in course.objectives)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                            Icons.check_circle_outline,
                                            size: 15,
                                            color: AppColors.gold),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(o,
                                                style: const TextStyle(
                                                    fontSize: 13.5))),
                                      ],
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 56, right: 16),
                          child: ThinProgressBar(
                            value: data.courseProgress(student.id, course),
                            tooltip:
                                '${progress.completedLessonIds.length} de '
                                '${course.lessonCount} lecciones',
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Módulos y lecciones
                        for (final module in course.modules) ...[
                          SectionTitle(module.title),
                          for (final lesson in module.lessons)
                            _LessonTile(
                              lesson: lesson,
                              course: course,
                              done: progress.completedLessonIds
                                  .contains(lesson.id),
                              onToggle: () {
                                final wasDone = progress
                                    .completedLessonIds
                                    .contains(lesson.id);
                                data.toggleLesson(
                                    student.id, course.id, lesson.id);
                                if (!wasDone) {
                                  showSuccessCheck(
                                      context, '¡Lección completada!');
                                }
                              },
                            ),
                        ],
                        const SectionTitle('Mis entregas'),
                        _SubmissionsSection(
                            course: course,
                            student: student,
                            submissions: mySubmissions),
                      ],
                    ),
                  ),
                ),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AppFooter(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.gold),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12)),
        ],
      );
}

// ---------------------------------------------------------------------------
// Tile de lección
// ---------------------------------------------------------------------------

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final Course course;
  final bool done;
  final VoidCallback onToggle;
  const _LessonTile(
      {required this.lesson,
      required this.course,
      required this.done,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HoverCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        onTap: () => _open(context),
        child: Row(
          children: [
            Icon(lessonTypeIcon(lesson.type),
                color: AppColors.gold, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                      '${lessonTypeLabel(lesson.type)}'
                      '${lesson.durationMin > 0 ? ' · ${lesson.durationMin} min' : ''}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Tooltip(
              message:
                  done ? 'Marcar como pendiente' : 'Marcar como completada',
              child: IconButton(
                icon: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? AppColors.statusGood : AppColors.textMuted,
                ),
                onPressed: onToggle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    switch (lesson.type) {
      case LessonType.video:
        VideoPlayerDialog.show(context, lesson.title, lesson.resourcePath);
      case LessonType.pdf:
      case LessonType.resource:
        showAppSnack(
            context, 'Material en course_resources/${lesson.resourcePath}');
      case LessonType.link:
        showAppSnack(context, 'Enlace: ${lesson.resourcePath}');
      case LessonType.quiz:
        showDialog(
            context: context,
            builder: (_) => _QuizDialog(lesson: lesson, onPassed: onToggle));
      case LessonType.survey:
        showDialog(
            context: context,
            builder: (_) => _SurveyDialog(
                lesson: lesson, course: course, onDone: onToggle));
      case LessonType.activity:
        showDialog(
            context: context,
            builder: (_) => _ActivityDialog(lesson: lesson, course: course));
    }
  }
}

// ---------------------------------------------------------------------------
// Quiz con 5 tipos de pregunta y puntaje automático
// ---------------------------------------------------------------------------

class _QuizDialog extends StatefulWidget {
  final Lesson lesson;
  final VoidCallback onPassed;
  const _QuizDialog({required this.lesson, required this.onPassed});

  @override
  State<_QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends State<_QuizDialog> {
  final Map<int, int> _choice = {}; // multiple / truefalse
  final Map<int, String> _text = {}; // short / fill
  final Map<int, List<String>> _order = {}; // order (estado actual)
  int? _score;

  bool _answered(int i, QuizQuestion q) => switch (q.kind) {
        'multiple' || 'truefalse' => _choice.containsKey(i),
        'short' || 'fill' => (_text[i] ?? '').trim().isNotEmpty,
        'order' => true,
        _ => false,
      };

  bool _correct(int i, QuizQuestion q) {
    switch (q.kind) {
      case 'multiple':
      case 'truefalse':
        return _choice[i] == q.answerIndex;
      case 'short':
      case 'fill':
        final given = (_text[i] ?? '').trim().toLowerCase();
        final expected = q.answerText.trim().toLowerCase();
        return given == expected ||
            (expected.isNotEmpty && given.contains(expected));
      case 'order':
        final current = _order[i] ?? q.options;
        for (var k = 0; k < q.options.length; k++) {
          if (current[k] != q.options[k]) return false;
        }
        return true;
      default:
        return false;
    }
  }

  void _grade() {
    final quiz = widget.lesson.quiz;
    var correct = 0;
    for (var i = 0; i < quiz.length; i++) {
      if (_correct(i, quiz[i])) correct++;
    }
    setState(() => _score = (correct / quiz.length * 100).round());
    if (_score! >= 60) widget.onPassed();
  }

  @override
  Widget build(BuildContext context) {
    final quiz = widget.lesson.quiz;
    final allAnswered = List.generate(quiz.length, (i) => i)
        .every((i) => _answered(i, quiz[i]));

    return AlertDialog(
      title: Text(widget.lesson.title, style: const TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < quiz.length; i++) ...[
                Text('${i + 1}. ${quiz[i].question}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ..._questionWidget(i, quiz[i]),
                const SizedBox(height: 12),
              ],
              if (_score != null)
                StatusChip(
                  label: _score! >= 60
                      ? '¡Aprobado! $_score%'
                      : 'Puntaje: $_score% (mínimo 60%)',
                  color: _score! >= 60
                      ? AppColors.statusGood
                      : AppColors.statusCritical,
                  icon: _score! >= 60 ? Icons.check : Icons.close,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar')),
        ElevatedButton(
          onPressed: allAnswered ? _grade : null,
          child: const Text('Calificar'),
        ),
      ],
    );
  }

  List<Widget> _questionWidget(int i, QuizQuestion q) {
    switch (q.kind) {
      case 'multiple':
        return [
          for (var o = 0; o < q.options.length; o++)
            RadioListTile<int>(
              dense: true,
              title: Text(q.options[o],
                  style: const TextStyle(fontSize: 13)),
              value: o,
              groupValue: _choice[i],
              activeColor: AppColors.gold,
              onChanged: (v) => setState(() => _choice[i] = v!),
            ),
        ];
      case 'truefalse':
        return [
          Row(
            children: [
              ChoiceChip(
                label: const Text('Verdadero'),
                selected: _choice[i] == 0,
                selectedColor: AppColors.gold.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => _choice[i] = 0),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Falso'),
                selected: _choice[i] == 1,
                selectedColor: AppColors.gold.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => _choice[i] = 1),
              ),
            ],
          ),
        ];
      case 'short':
      case 'fill':
        return [
          TextField(
            decoration: InputDecoration(
              hintText: q.kind == 'fill'
                  ? 'Completa la frase…'
                  : 'Tu respuesta…',
              isDense: true,
            ),
            onChanged: (v) => setState(() => _text[i] = v),
          ),
        ];
      case 'order':
        final current = _order.putIfAbsent(
            i, () => [...q.options]..shuffle());
        return [
          const Text('Usa las flechas para ordenar:',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          for (var o = 0; o < current.length; o++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    alignment: Alignment.center,
                    child: Text('${o + 1}',
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(current[o],
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 15),
                    onPressed: o == 0
                        ? null
                        : () => setState(() {
                              final tmp = current[o - 1];
                              current[o - 1] = current[o];
                              current[o] = tmp;
                            }),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 15),
                    onPressed: o == current.length - 1
                        ? null
                        : () => setState(() {
                              final tmp = current[o + 1];
                              current[o + 1] = current[o];
                              current[o] = tmp;
                            }),
                  ),
                ],
              ),
            ),
        ];
      default:
        return const [];
    }
  }
}

// ---------------------------------------------------------------------------
// Encuesta (sin calificación)
// ---------------------------------------------------------------------------

class _SurveyDialog extends StatefulWidget {
  final Lesson lesson;
  final Course course;
  final VoidCallback onDone;
  const _SurveyDialog(
      {required this.lesson, required this.course, required this.onDone});

  @override
  State<_SurveyDialog> createState() => _SurveyDialogState();
}

class _SurveyDialogState extends State<_SurveyDialog> {
  final Map<int, String> _answers = {};

  @override
  Widget build(BuildContext context) {
    final questions = widget.lesson.quiz;
    return AlertDialog(
      title: Text(widget.lesson.title, style: const TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tu opinión nos ayuda a mejorar 💛',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 12),
              for (var i = 0; i < questions.length; i++) ...[
                Text('${i + 1}. ${questions[i].question}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                TextField(
                  maxLines: 2,
                  decoration: const InputDecoration(
                      hintText: 'Tu respuesta…', isDense: true),
                  onChanged: (v) => _answers[i] = v,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () async {
            final data = context.read<DataProvider>();
            final student = context.read<AuthProvider>().currentUser!;
            final body = [
              for (var i = 0; i < questions.length; i++)
                '${questions[i].question}: ${_answers[i] ?? '—'}'
            ].join('\n');
            await data.saveSubmission(Submission(
              id: data.newId('sub'),
              courseId: widget.course.id,
              studentId: student.id,
              lessonId: widget.lesson.id,
              taskName: 'Encuesta: ${widget.lesson.title}',
              comment: body,
            ));
            widget.onDone();
            if (context.mounted) {
              Navigator.pop(context);
              showSuccessCheck(context, '¡Gracias por responder!');
            }
          },
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Actividad (entregable con requisitos y rúbrica)
// ---------------------------------------------------------------------------

class _ActivityDialog extends StatelessWidget {
  final Lesson lesson;
  final Course course;
  const _ActivityDialog({required this.lesson, required this.course});

  @override
  Widget build(BuildContext context) {
    final a = lesson.activity ?? ActivityConfig();
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final mySubmission = data
        .submissionsForStudent(student.id)
        .where((s) => s.lessonId == lesson.id)
        .toList();

    final deadline =
        a.deadline.isEmpty ? null : DateTime.tryParse(a.deadline);
    final overdue = deadline != null && DateTime.now().isAfter(deadline);

    return AlertDialog(
      title: Text(lesson.title, style: const TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (a.description.isNotEmpty) ...[
                Text(a.description,
                    style: const TextStyle(fontSize: 14, height: 1.5)),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (deadline != null)
                    StatusChip(
                      label:
                          'Límite: ${DateFormat('d MMM yyyy').format(deadline)}',
                      color: overdue
                          ? AppColors.statusCritical
                          : AppColors.statusWarning,
                      icon: Icons.schedule,
                    ),
                  if (a.requiresFile)
                    const StatusChip(
                        label: 'Archivo obligatorio',
                        color: AppColors.slateLight,
                        icon: Icons.attach_file),
                  if (a.requiresText)
                    const StatusChip(
                        label: 'Texto obligatorio',
                        color: AppColors.slateLight,
                        icon: Icons.notes),
                  if (a.allowedTypes.isNotEmpty)
                    StatusChip(
                        label: a.allowedTypes.join(' / '),
                        color: AppColors.slateLight,
                        icon: Icons.category_outlined),
                  StatusChip(
                    label: switch (a.gradingMode) {
                      'passfail' => 'Aprobado / Reprobado',
                      'review' => 'Solo revisión',
                      _ => 'Puntaje 0–100',
                    },
                    color: AppColors.gold,
                    icon: Icons.grade_outlined,
                  ),
                ],
              ),
              if (a.rubric.isNotEmpty) ...[
                const SectionTitle('Rúbrica de evaluación'),
                for (final r in a.rubric)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.rule,
                            size: 14, color: AppColors.gold),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(r['criterion'] as String,
                                style: const TextStyle(fontSize: 13))),
                        Text('${r['points']} pts',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
              if (mySubmission.isNotEmpty) ...[
                const SectionTitle('Tu entrega'),
                for (final s in mySubmission)
                  HoverCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                  DateFormat('d MMM yyyy, h:mm a')
                                      .format(s.date),
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12)),
                            ),
                            _resultChip(s, a.gradingMode),
                          ],
                        ),
                        if (s.feedback.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('Retroalimentación: ${s.feedback}',
                                style: const TextStyle(
                                    color: AppColors.gold, fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar')),
        ElevatedButton.icon(
          icon: const Icon(Icons.upload_file, size: 16),
          label: Text(
              mySubmission.isEmpty ? 'Entregar actividad' : 'Nueva entrega'),
          onPressed: () {
            Navigator.pop(context);
            submitActivity(context, course, lesson, a);
          },
        ),
      ],
    );
  }

  Widget _resultChip(Submission s, String mode) {
    if (s.grade == null) {
      return const StatusChip(
          label: 'En revisión',
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
      _ => StatusChip(
          label: '${s.grade!.round()}/100',
          color: s.grade! >= 60
              ? AppColors.statusGood
              : AppColors.statusCritical,
          icon: Icons.grade),
    };
  }
}

/// Diálogo de entrega de actividad con validaciones según la configuración.
Future<void> submitActivity(BuildContext context, Course course,
    Lesson lesson, ActivityConfig config) async {
  final data = context.read<DataProvider>();
  final student = context.read<AuthProvider>().currentUser!;
  final commentCtrl = TextEditingController();
  final files = <String>[];
  String? error;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Entregar: ${lesson.title}',
            style: const TextStyle(fontSize: 18)),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: commentCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: config.requiresText
                      ? 'Tu respuesta (obligatoria)'
                      : 'Comentario (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.attach_file, size: 16),
                    label: Text(config.requiresFile
                        ? 'Adjuntar archivo (obligatorio)'
                        : 'Adjuntar archivo'),
                    onPressed: files.length >= config.maxFiles
                        ? null
                        : () async {
                            final result = await FilePicker.pickFiles();
                            if (result != null) {
                              setState(() => files.add(
                                  result.files.single.path ??
                                      result.files.single.name));
                            }
                          },
                  ),
                  const SizedBox(width: 10),
                  Text('${files.length}/${config.maxFiles}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
              for (final f in files)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file_outlined,
                          size: 14, color: AppColors.gold),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(f.split('/').last,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () => setState(() => files.remove(f)),
                      ),
                    ],
                  ),
                ),
              if (config.allowedTypes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      'Tipos aceptados: ${config.allowedTypes.join(', ')}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(error!,
                      style: const TextStyle(
                          color: AppColors.statusCritical, fontSize: 13)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              // Validaciones según la configuración de la actividad
              if (config.requiresText &&
                  commentCtrl.text.trim().isEmpty) {
                setState(() =>
                    error = 'Esta actividad requiere una respuesta escrita.');
                return;
              }
              if (config.requiresFile && files.isEmpty) {
                setState(() =>
                    error = 'Esta actividad requiere adjuntar un archivo.');
                return;
              }
              await data.saveSubmission(Submission(
                id: data.newId('sub'),
                courseId: course.id,
                studentId: student.id,
                lessonId: lesson.id,
                taskName: lesson.title,
                comment: commentCtrl.text.trim(),
                filePath: files.join(' | '),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                showSuccessCheck(context, 'Actividad entregada ✓');
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Entregas libres del curso
// ---------------------------------------------------------------------------

class _SubmissionsSection extends StatelessWidget {
  final Course course;
  final AppUser student;
  final List<Submission> submissions;
  const _SubmissionsSection(
      {required this.course,
      required this.student,
      required this.submissions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in submissions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: HoverCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(s.taskName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                      ),
                      if (s.grade != null)
                        StatusChip(
                            label: s.grade! > 5
                                ? '${s.grade!.round()}/100'
                                : 'Nota: ${s.grade}',
                            color: (s.grade! > 5
                                    ? s.grade! >= 60
                                    : s.grade! >= 3)
                                ? AppColors.statusGood
                                : AppColors.statusCritical,
                            icon: Icons.grade)
                      else
                        const StatusChip(
                            label: 'Sin calificar',
                            color: AppColors.statusWarning,
                            icon: Icons.hourglass_empty),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(s.comment,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  if (s.filePath.isNotEmpty)
                    Text('Archivo: ${s.filePath}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  if (s.feedback.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Retroalimentación: ${s.feedback}',
                        style: const TextStyle(
                            color: AppColors.gold, fontSize: 13)),
                  ],
                  Text(DateFormat('d MMM yyyy').format(s.date),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('Nueva entrega libre'),
          onPressed: () => _newSubmission(context),
        ),
      ],
    );
  }

  Future<void> _newSubmission(BuildContext context) async {
    final data = context.read<DataProvider>();
    final taskCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    String filePath = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nueva entrega', style: TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: taskCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Nombre de la tarea')),
                const SizedBox(height: 12),
                TextField(
                    controller: commentCtrl,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Comentario')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: const Text('Adjuntar archivo'),
                      onPressed: () async {
                        final result = await FilePicker.pickFiles();
                        if (result != null) {
                          setState(() => filePath =
                              result.files.single.path ??
                                  result.files.single.name);
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        filePath.isEmpty
                            ? 'Sin archivo'
                            : filePath.split('/').last,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (taskCtrl.text.trim().isEmpty) return;
                await data.saveSubmission(Submission(
                  id: data.newId('sub'),
                  courseId: course.id,
                  studentId: student.id,
                  taskName: taskCtrl.text.trim(),
                  comment: commentCtrl.text.trim(),
                  filePath: filePath,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  showSuccessCheck(context, 'Entrega enviada ✓');
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }
}
