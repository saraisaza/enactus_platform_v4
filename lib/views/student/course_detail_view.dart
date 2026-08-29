import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../models/progress.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/async_value.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../widgets/file_upload_field.dart';
import '../../widgets/lesson_visuals.dart';
import '../../widgets/video_player_dialog.dart';

/// Detalle de un curso: módulos y lecciones de todos los tipos, avance y
/// entregas.
///
/// Por defecto ([studentId] nulo) muestra y deja editar el avance de quien
/// tiene la sesión abierta. Con [studentId] muestra el de ESE estudiante en
/// solo lectura — es como lo abre un Mentor, Asesor o LXD desde el perfil de
/// alguien. El servidor decide si quien pregunta puede: un estudiante pidiendo
/// el avance de otro recibe 403, no una pantalla vacía.
class CourseDetailView extends StatelessWidget {
  final String courseId;
  final String? studentId;
  const CourseDetailView({super.key, required this.courseId, this.studentId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final viewer = context.watch<AuthProvider>().currentUser;
    final readOnly = studentId != null && studentId != viewer?.id;

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(portalTitle: 'Curso'),
          Expanded(
            child: combine2(
              data.courseById(courseId),
              data.courseProgress(courseId, studentId: studentId),
            ).when(
              loading: () => const Center(child: BrandLoader()),
              error: (e) => ErrorState(e, onRetry: () async {
                await data.reloadCourse(courseId);
                await data.reloadCourseProgress(courseId,
                    studentId: studentId);
              }),
              data: (values) {
                final (course, progress) = values;
                return _CourseBody(
                  course: course,
                  progress: progress,
                  studentId: studentId,
                  readOnly: readOnly,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseBody extends StatelessWidget {
  final Course course;
  final CourseProgress progress;
  final String? studentId;
  final bool readOnly;

  const _CourseBody({
    required this.course,
    required this.progress,
    required this.studentId,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return CustomScrollView(
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(course.name,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold)),
                          if (course.subtitle.isNotEmpty)
                            Text(course.subtitle,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14)),
                        ],
                      ),
                    ),
                    StatusChip(
                        label: course.levelLabel,
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
                          if (course.laboratoryName != null)
                            _meta(Icons.science_outlined,
                                course.laboratoryName!),
                          for (final tag in course.tags.take(4))
                            _meta(Icons.tag, tag),
                        ],
                      ),
                      if (course.objectives.isNotEmpty) ...[
                        const SectionTitle('Objetivos'),
                        for (final objective in course.objectives)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 15, color: AppColors.gold),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(objective.text,
                                        style:
                                            const TextStyle(fontSize: 13.5))),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                if (readOnly) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 56, right: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.visibility_outlined,
                              size: 17, color: AppColors.textMuted),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                                'Estás viendo el progreso de otro estudiante — '
                                'modo de solo lectura.',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textMuted)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 56, right: 16),
                  child: ThinProgressBar(
                    value: progress.ratio,
                    tooltip: '${progress.completedLessons} de '
                        '${progress.totalLessons} lecciones',
                  ),
                ),
                const SizedBox(height: 16),
                if (course.modules.isEmpty)
                  const EmptyState(
                      icon: Icons.menu_book_outlined,
                      message: 'Este curso todavía no tiene contenido publicado.')
                else
                  for (final module in course.modules) ...[
                    SectionTitle(module.title),
                    for (final lesson in module.lessons)
                      _LessonTile(
                        lesson: lesson,
                        course: course,
                        done: progress.isLessonComplete(lesson.id),
                        readOnly: readOnly,
                      ),
                  ],
                const SectionTitle('Mis entregas'),
                data.submissions.when(
                  loading: () => const CardListSkeleton(count: 2, height: 90),
                  error: (e) =>
                      ErrorState(e, onRetry: data.reloadSubmissions),
                  data: (all) => _SubmissionsSection(
                    course: course,
                    submissions: all
                        .where((s) => s.courseId == course.id)
                        .toList(),
                    readOnly: readOnly,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
              alignment: Alignment.bottomCenter, child: AppFooter()),
        ),
      ],
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.gold),
          const SizedBox(width: 4),
          Text(text,
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      );
}

// ---------------------------------------------------------------------------
// Lección
// ---------------------------------------------------------------------------

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final Course course;
  final bool done;
  final bool readOnly;

  const _LessonTile({
    required this.lesson,
    required this.course,
    required this.done,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HoverCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        onTap: () => _open(context),
        child: Row(
          children: [
            Icon(lessonTypeIcon(lesson.type), color: AppColors.gold, size: 22),
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
              message: readOnly
                  ? (done ? 'Completada' : 'Pendiente')
                  : (done
                      ? 'Marcar como pendiente'
                      : 'Marcar como completada'),
              child: IconButton(
                icon: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? AppColors.statusGood : AppColors.textMuted,
                ),
                // En solo lectura no se completa en nombre de otra persona.
                onPressed: readOnly ? null : () => _toggle(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Marcar la lección. La respuesta trae el recálculo de curso, módulo, fase
  /// y Ruta, así que si con esto quedó una Ruta lista para certificar, se
  /// puede celebrar sin preguntar nada más.
  Future<void> _toggle(BuildContext context) async {
    final data = context.read<DataProvider>();
    try {
      final impact = await data.toggleLesson(lesson.id, course.id);
      if (!context.mounted) return;
      if (impact.newlyCertifiable != null) {
        showSuccessCheck(context, '¡Completaste la Ruta de Impacto! 🎉');
      } else if (impact.completed) {
        showSuccessCheck(context, '¡Lección completada!');
      }
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message);
    }
  }

  void _open(BuildContext context) {
    // Video, PDF, recurso y enlace no escriben nada: se abren igual en solo
    // lectura. Quiz, encuesta y actividad SÍ escriben a nombre de quien tiene
    // la sesión, así que atribuirían la respuesta a la persona equivocada.
    if (readOnly &&
        (lesson.type == LessonType.quiz ||
            lesson.type == LessonType.survey ||
            lesson.type == LessonType.activity)) {
      showAppSnack(context,
          'Estás viendo el progreso de otro estudiante — no puedes responder en su nombre.');
      return;
    }

    switch (lesson.type) {
      case LessonType.video:
        VideoPlayerDialog.show(context, lesson);
      case LessonType.pdf:
      case LessonType.resource:
        _openResource(context);
      case LessonType.link:
        _openExternal(context, lesson.externalUrl);
      case LessonType.quiz:
        showDialog(
            context: context,
            builder: (_) => _QuizDialog(lesson: lesson, course: course));
      case LessonType.survey:
        showDialog(
            context: context,
            builder: (_) => _SurveyDialog(lesson: lesson, course: course));
      case LessonType.activity:
        showDialog(
            context: context,
            builder: (_) => _ActivityDialog(lesson: lesson, course: course));
    }
  }

  /// Abre el PDF o recurso pidiendo su URL firmada.
  ///
  /// La firma la emite el servidor tras comprobar que esta persona puede leer
  /// esa key: un archivo de un curso ajeno responde 404 y acá se dice, en vez
  /// de abrir una pestaña en blanco.
  Future<void> _openResource(BuildContext context) async {
    final key = lesson.resourceS3Key;
    if (key == null || key.isEmpty) {
      showAppSnack(context, 'Esta lección todavía no tiene material cargado.');
      return;
    }
    final data = context.read<DataProvider>();
    try {
      final url = await data.resolveFileUrl(key);
      if (context.mounted) _openExternal(context, url);
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message);
    }
  }

  Future<void> _openExternal(BuildContext context, String? url) async {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null) {
      showAppSnack(context, 'Esta lección no tiene un enlace válido.');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showAppSnack(context, 'No se pudo abrir el enlace.');
    }
  }
}

// ---------------------------------------------------------------------------
// Quiz
// ---------------------------------------------------------------------------

/// Quiz con los cinco tipos de pregunta.
///
/// **La corrección la hace el servidor.** La clave de respuestas ya no viaja
/// al navegador —antes venía dentro del curso y cualquiera podía leerla desde
/// las herramientas de desarrollo— así que acá no hay nada que comparar: se
/// mandan las respuestas y vuelve el puntaje con qué preguntas estuvieron
/// bien.
class _QuizDialog extends StatefulWidget {
  final Lesson lesson;
  final Course course;
  const _QuizDialog({required this.lesson, required this.course});

  @override
  State<_QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends State<_QuizDialog> {
  /// Respuesta por id de pregunta: índice para `multiple`/`truefalse`, texto
  /// para `short`/`fill`.
  final Map<String, Object> _answers = {};

  /// Orden actual de las opciones en las preguntas de tipo `order`.
  final Map<String, List<String>> _order = {};

  QuizResult? _result;
  bool _sending = false;
  ApiException? _error;

  bool _isAnswered(QuizQuestion question) => switch (question.kind) {
        'multiple' || 'truefalse' => _answers.containsKey(question.id),
        'short' || 'fill' =>
          ((_answers[question.id] as String?) ?? '').trim().isNotEmpty,
        'order' => true,
        _ => false,
      };

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await context
          .read<DataProvider>()
          .submitQuiz(widget.lesson.id, _answers);
      if (!mounted) return;
      setState(() => _result = result);

      // Aprobar el quiz marca la lección: es el mismo acto para quien lo
      // resuelve. Se hace acá y no en el servidor porque completar una
      // lección es reversible y de la persona, no del quiz.
      if (result.passed) {
        await context
            .read<DataProvider>()
            .toggleLessonIfPending(widget.lesson.id, widget.course.id);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiz = widget.lesson.quiz;
    final allAnswered = quiz.every(_isAnswered);
    final result = _result;

    return AlertDialog(
      title: Text(widget.lesson.title, style: const TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (quiz.isEmpty)
                const Text('Este quiz todavía no tiene preguntas.',
                    style: TextStyle(color: AppColors.textMuted)),
              for (var i = 0; i < quiz.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text('${i + 1}. ${quiz[i].question}',
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    // Tras corregir se marca cada pregunta, pero nunca se
                    // muestra cuál era la respuesta correcta.
                    if (result != null)
                      Icon(
                          result.isCorrect(quiz[i].id)
                              ? Icons.check_circle
                              : Icons.cancel,
                          size: 18,
                          color: result.isCorrect(quiz[i].id)
                              ? AppColors.statusGood
                              : AppColors.statusCritical),
                  ],
                ),
                const SizedBox(height: 4),
                ..._questionWidget(quiz[i]),
                const SizedBox(height: 12),
              ],
              if (result != null)
                StatusChip(
                  label: result.passed
                      ? '¡Aprobado! ${result.score}%'
                      : 'Puntaje: ${result.score}% (mínimo 60%)',
                  color: result.passed
                      ? AppColors.statusGood
                      : AppColors.statusCritical,
                  icon: result.passed ? Icons.check : Icons.close,
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar')),
        ElevatedButton(
          onPressed: allAnswered && !_sending && quiz.isNotEmpty
              ? _submit
              : null,
          child: Text(_sending ? 'Calificando…' : 'Calificar'),
        ),
      ],
    );
  }

  List<Widget> _questionWidget(QuizQuestion question) {
    // Tras corregir, las respuestas quedan fijas: cambiarlas no volvería a
    // calificar y daría a entender que sí.
    final locked = _result != null || _sending;

    switch (question.kind) {
      case 'multiple':
        return [
          for (var o = 0; o < question.options.length; o++)
            RadioListTile<int>(
              dense: true,
              title: Text(question.options[o],
                  style: const TextStyle(fontSize: 13)),
              value: o,
              // ignore: deprecated_member_use
              groupValue: _answers[question.id] as int?,
              activeColor: AppColors.gold,
              // ignore: deprecated_member_use
              onChanged: locked
                  ? null
                  : (v) => setState(() => _answers[question.id] = v!),
            ),
        ];
      case 'truefalse':
        return [
          Wrap(
            spacing: 8,
            children: [
              for (final (value, label) in [(0, 'Verdadero'), (1, 'Falso')])
                ChoiceChip(
                  label: Text(label),
                  selected: _answers[question.id] == value,
                  selectedColor: AppColors.gold.withValues(alpha: 0.25),
                  onSelected: locked
                      ? null
                      : (_) => setState(() => _answers[question.id] = value),
                ),
            ],
          ),
        ];
      case 'short':
      case 'fill':
        return [
          TextField(
            enabled: !locked,
            decoration: InputDecoration(
              hintText: question.kind == 'fill'
                  ? 'Completa la frase…'
                  : 'Tu respuesta…',
              isDense: true,
            ),
            onChanged: (v) => setState(() => _answers[question.id] = v),
          ),
        ];
      case 'order':
        final current =
            _order.putIfAbsent(question.id, () => [...question.options]..shuffle());
        return [
          const Text('Usa las flechas para ordenar:',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          for (var o = 0; o < current.length; o++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text('${o + 1}',
                        textAlign: TextAlign.center,
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
                    onPressed: o == 0 || locked
                        ? null
                        : () => setState(() => _swap(question.id, o, o - 1)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 15),
                    onPressed: o == current.length - 1 || locked
                        ? null
                        : () => setState(() => _swap(question.id, o, o + 1)),
                  ),
                ],
              ),
            ),
        ];
      default:
        return const [];
    }
  }

  void _swap(String questionId, int a, int b) {
    final list = _order[questionId]!;
    final tmp = list[a];
    list[a] = list[b];
    list[b] = tmp;
    _answers[questionId] = list.join('|');
  }
}

// ---------------------------------------------------------------------------
// Encuesta (sin calificación)
// ---------------------------------------------------------------------------

class _SurveyDialog extends StatefulWidget {
  final Lesson lesson;
  final Course course;
  const _SurveyDialog({required this.lesson, required this.course});

  @override
  State<_SurveyDialog> createState() => _SurveyDialogState();
}

class _SurveyDialogState extends State<_SurveyDialog> {
  final Map<String, String> _answers = {};
  bool _sending = false;
  ApiException? _error;

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final data = context.read<DataProvider>();
    final body = [
      for (final question in widget.lesson.quiz)
        '${question.question}: ${_answers[question.id] ?? '—'}',
    ].join('\n');

    try {
      await data.createSubmission(
        courseId: widget.course.id,
        lessonId: widget.lesson.id,
        taskName: 'Encuesta: ${widget.lesson.title}',
        comment: body,
      );
      // Responder la encuesta la da por vista.
      await data.toggleLessonIfPending(widget.lesson.id, widget.course.id);
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessCheck(context, '¡Gracias por responder!');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e;
        });
      }
    }
  }

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
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 12),
              for (var i = 0; i < questions.length; i++) ...[
                Text('${i + 1}. ${questions[i].question}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                TextField(
                  enabled: !_sending,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      hintText: 'Tu respuesta…', isDense: true),
                  onChanged: (v) => _answers[questions[i].id] = v,
                ),
                const SizedBox(height: 12),
              ],
              if (_error != null) ErrorBanner(_error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _sending ? null : () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _sending ? null : _send,
          child: Text(_sending ? 'Enviando…' : 'Enviar'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Actividad
// ---------------------------------------------------------------------------

class _ActivityDialog extends StatelessWidget {
  final Lesson lesson;
  final Course course;
  const _ActivityDialog({required this.lesson, required this.course});

  @override
  Widget build(BuildContext context) {
    final activity = lesson.activity ?? const ActivityConfig();
    final data = context.watch<DataProvider>();
    final mine = (data.submissions.valueOrNull ?? const <Submission>[])
        .where((s) => s.lessonId == lesson.id)
        .toList();

    final deadline =
        activity.deadline == null ? null : DateTime.tryParse(activity.deadline!);
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
              if (activity.description.isNotEmpty) ...[
                Text(activity.description,
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
                  if (activity.requiresFile)
                    const StatusChip(
                        label: 'Archivo obligatorio',
                        color: AppColors.slateLight,
                        icon: Icons.attach_file),
                  if (activity.requiresText)
                    const StatusChip(
                        label: 'Texto obligatorio',
                        color: AppColors.slateLight,
                        icon: Icons.notes),
                  StatusChip(
                    label: GradingMode.label(activity.gradingMode),
                    color: AppColors.gold,
                    icon: Icons.grade_outlined,
                  ),
                ],
              ),
              if (activity.rubric.isNotEmpty) ...[
                const SectionTitle('Rúbrica de evaluación'),
                for (final item in activity.rubric)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.rule, size: 14, color: AppColors.gold),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(item.criterion,
                                style: const TextStyle(fontSize: 13))),
                        Text('${item.points} pts',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
              if (mine.isNotEmpty) ...[
                const SectionTitle('Tu entrega'),
                for (final submission in mine)
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
                                      .format(submission.submittedAt),
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12)),
                            ),
                            StatusChip(
                              label: submission.gradeLabel,
                              color: submission.isGraded
                                  ? (GradingMode.isPassing(submission.grade,
                                          submission.gradingMode)
                                      ? AppColors.statusGood
                                      : AppColors.statusCritical)
                                  : AppColors.statusWarning,
                              icon: submission.isGraded
                                  ? Icons.grade
                                  : Icons.hourglass_empty,
                            ),
                          ],
                        ),
                        if (submission.feedback.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                                'Retroalimentación: ${submission.feedback}',
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
          label: Text(mine.isEmpty ? 'Entregar actividad' : 'Nueva entrega'),
          onPressed: () {
            Navigator.pop(context);
            showSubmitActivityDialog(context, course, lesson, activity);
          },
        ),
      ],
    );
  }
}

/// Entregar una actividad, con las validaciones de su configuración.
Future<void> showSubmitActivityDialog(BuildContext context, Course course,
    Lesson lesson, ActivityConfig config) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _SubmitDialog(course: course, lesson: lesson, config: config),
  );
}

class _SubmitDialog extends StatefulWidget {
  final Course course;
  final Lesson lesson;
  final ActivityConfig config;
  const _SubmitDialog(
      {required this.course, required this.lesson, required this.config});

  @override
  State<_SubmitDialog> createState() => _SubmitDialogState();
}

class _SubmitDialogState extends State<_SubmitDialog> {
  final _comment = TextEditingController();
  final List<UploadedFile> _files = [];
  bool _sending = false;
  ApiException? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (widget.config.requiresText && _comment.text.trim().isEmpty) {
      setState(() => _error = const ValidationError(
          'Esta actividad requiere una respuesta escrita.'));
      return;
    }
    if (widget.config.requiresFile && _files.isEmpty) {
      setState(() => _error = const ValidationError(
          'Esta actividad requiere adjuntar un archivo.'));
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final data = context.read<DataProvider>();
      await data.createSubmission(
        courseId: widget.course.id,
        lessonId: widget.lesson.id,
        taskName: widget.lesson.title,
        comment: _comment.text.trim(),
        files: _files.map((f) => f.toJson()).toList(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessCheck(context, 'Actividad entregada ✓');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Entregar: ${widget.lesson.title}',
          style: const TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _comment,
                enabled: !_sending,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: widget.config.requiresText
                      ? 'Tu respuesta (obligatoria)'
                      : 'Comentario (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              FileUploadField(
                purpose: 'submission',
                maxFiles: widget.config.maxFiles,
                files: _files,
                enabled: !_sending,
                onChanged: () => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                ErrorBanner(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _sending ? null : () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _sending ? null : _send,
          child: Text(_sending ? 'Enviando…' : 'Enviar'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Entregas del curso
// ---------------------------------------------------------------------------

class _SubmissionsSection extends StatelessWidget {
  final Course course;
  final List<Submission> submissions;
  final bool readOnly;
  const _SubmissionsSection({
    required this.course,
    required this.submissions,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (submissions.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Todavía no hiciste ninguna entrega en este curso.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
        for (final submission in submissions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SubmissionCard(submission: submission),
          ),
        if (!readOnly) ...[
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Nueva entrega libre'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _FreeSubmissionDialog(course: course),
            ),
          ),
        ],
      ],
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final Submission submission;
  const _SubmissionCard({required this.submission});

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(submission.taskName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              // La nota se muestra en SU escala: 100 no significa lo mismo en
              // `passfail` que en `points100`.
              StatusChip(
                label: submission.gradeLabel,
                color: submission.isGraded
                    ? (GradingMode.isPassing(
                            submission.grade, submission.gradingMode)
                        ? AppColors.statusGood
                        : AppColors.statusCritical)
                    : AppColors.statusWarning,
                icon: submission.isGraded
                    ? Icons.grade
                    : Icons.hourglass_empty,
              ),
            ],
          ),
          if (submission.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(submission.comment,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
          for (final file in submission.files)
            _AttachmentRow(file: file),
          if (submission.feedback.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Retroalimentación: ${submission.feedback}',
                style: const TextStyle(color: AppColors.gold, fontSize: 13)),
          ],
          Text(DateFormat('d MMM yyyy').format(submission.submittedAt),
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

/// Un adjunto, que se abre pidiendo su URL firmada al servidor.
class _AttachmentRow extends StatelessWidget {
  final SubmissionFile file;
  const _AttachmentRow({required this.file});

  Future<void> _open(BuildContext context) async {
    final data = context.read<DataProvider>();
    try {
      final url = await data.resolveFileUrl(file.s3Key);
      final uri = Uri.tryParse(url);
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: () => _open(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined,
                size: 14, color: AppColors.gold),
            const SizedBox(width: 6),
            Flexible(
              child: Text(file.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeSubmissionDialog extends StatefulWidget {
  final Course course;
  const _FreeSubmissionDialog({required this.course});

  @override
  State<_FreeSubmissionDialog> createState() => _FreeSubmissionDialogState();
}

class _FreeSubmissionDialogState extends State<_FreeSubmissionDialog> {
  final _task = TextEditingController();
  final _comment = TextEditingController();
  final List<UploadedFile> _files = [];
  bool _sending = false;
  ApiException? _error;

  @override
  void dispose() {
    _task.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_task.text.trim().isEmpty) {
      setState(() => _error =
          const ValidationError('Ponle un nombre a la entrega.'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<DataProvider>().createSubmission(
            courseId: widget.course.id,
            taskName: _task.text.trim(),
            comment: _comment.text.trim(),
            files: _files.map((f) => f.toJson()).toList(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessCheck(context, 'Entrega enviada ✓');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva entrega', style: TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: _task,
                  enabled: !_sending,
                  decoration: const InputDecoration(
                      labelText: 'Nombre de la tarea')),
              const SizedBox(height: 12),
              TextField(
                  controller: _comment,
                  enabled: !_sending,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Comentario')),
              const SizedBox(height: 12),
              FileUploadField(
                purpose: 'submission',
                maxFiles: 3,
                files: _files,
                enabled: !_sending,
                onChanged: () => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                ErrorBanner(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _sending ? null : () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _sending ? null : _send,
          child: Text(_sending ? 'Enviando…' : 'Enviar'),
        ),
      ],
    );
  }
}
