import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/common.dart';

IconData lessonTypeIcon(LessonType t) => switch (t) {
      LessonType.video => Icons.play_circle_outline,
      LessonType.pdf => Icons.picture_as_pdf_outlined,
      LessonType.resource => Icons.attach_file,
      LessonType.link => Icons.link,
      LessonType.quiz => Icons.quiz_outlined,
      LessonType.activity => Icons.assignment_outlined,
      LessonType.survey => Icons.poll_outlined,
    };

String lessonTypeLabel(LessonType t) => switch (t) {
      LessonType.video => 'Video',
      LessonType.pdf => 'PDF',
      LessonType.resource => 'Recurso',
      LessonType.link => 'Enlace',
      LessonType.quiz => 'Quiz',
      LessonType.activity => 'Actividad',
      LessonType.survey => 'Encuesta',
    };

const quizKinds = [
  ('multiple', 'Selección múltiple'),
  ('truefalse', 'Verdadero / Falso'),
  ('short', 'Respuesta corta'),
  ('order', 'Ordenar'),
  ('fill', 'Completar'),
];

/// Abre el editor de lección. Devuelve la lección creada/actualizada
/// o null si se canceló.
Future<Lesson?> showLessonEditor(BuildContext context, {Lesson? lesson}) {
  return showDialog<Lesson>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LessonEditorDialog(original: lesson),
  );
}

class _LessonEditorDialog extends StatefulWidget {
  final Lesson? original;
  const _LessonEditorDialog({this.original});

  @override
  State<_LessonEditorDialog> createState() => _LessonEditorDialogState();
}

class _LessonEditorDialogState extends State<_LessonEditorDialog> {
  late LessonType _type;
  late TextEditingController _title;
  late TextEditingController _desc;
  late TextEditingController _path;
  late TextEditingController _duration;
  late List<QuizQuestion> _questions;
  late ActivityConfig _activity;

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    _type = o?.type ?? LessonType.video;
    _title = TextEditingController(text: o?.title ?? '');
    _desc = TextEditingController(text: o?.description ?? '');
    _path = TextEditingController(text: o?.resourcePath ?? '');
    _duration =
        TextEditingController(text: (o?.durationMin ?? 0).toString());
    _questions = o?.quiz
            .map((q) => QuizQuestion.fromJson(q.toJson()))
            .toList() ??
        [];
    _activity = o?.activity == null
        ? ActivityConfig()
        : ActivityConfig.fromJson(o!.activity!.toJson());
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    final lesson = Lesson(
      id: widget.original?.id ??
          context.read<DataProvider>().newId('les'),
      title: _title.text.trim(),
      type: _type,
      resourcePath: _path.text.trim(),
      description: _desc.text.trim(),
      durationMin: int.tryParse(_duration.text) ?? 0,
      quiz: (_type == LessonType.quiz || _type == LessonType.survey)
          ? _questions
          : [],
      activity: _type == LessonType.activity ? _activity : null,
    );
    Navigator.pop(context, lesson);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.original == null ? 'Nueva lección' : 'Editar lección',
          style: const TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tipo de contenido
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in LessonType.values)
                    ChoiceChip(
                      avatar: Icon(lessonTypeIcon(t),
                          size: 15,
                          color: _type == t
                              ? AppColors.gold
                              : AppColors.textMuted),
                      label: Text(lessonTypeLabel(t),
                          style: const TextStyle(fontSize: 12)),
                      selected: _type == t,
                      selectedColor:
                          AppColors.gold.withValues(alpha: 0.2),
                      onSelected: (_) => setState(() => _type = t),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                  controller: _title,
                  decoration:
                      const InputDecoration(labelText: 'Título')),
              const SizedBox(height: 12),
              TextField(
                  controller: _desc,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Descripción')),
              const SizedBox(height: 12),
              // Campos según el tipo
              ..._typeFields(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }

  List<Widget> _typeFields() {
    switch (_type) {
      case LessonType.video:
        return [
          TextField(
            controller: _path,
            decoration: const InputDecoration(
              labelText: 'Video en course_resources/',
              hintText: 'lab_ia_tecnologia/curso_intro_ia/leccion_1.mp4',
              helperText: 'Más adelante será una key de AWS S3',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Duración (minutos)'),
          ),
        ];
      case LessonType.pdf:
      case LessonType.resource:
        return [
          TextField(
            controller: _path,
            decoration: const InputDecoration(
              labelText: 'Archivo en course_resources/',
              hintText: 'lab_x/curso_y/material.pdf (PDF, PPT, Word, Excel, ZIP)',
            ),
          ),
        ];
      case LessonType.link:
        return [
          TextField(
            controller: _path,
            decoration: const InputDecoration(
                labelText: 'URL', hintText: 'https://...'),
          ),
        ];
      case LessonType.quiz:
      case LessonType.survey:
        return [_quizBuilder(isSurvey: _type == LessonType.survey)];
      case LessonType.activity:
        return [_activityBuilder()];
    }
  }

  // ------------------------------------------------------------------
  // Constructor de preguntas (quiz y encuesta)
  // ------------------------------------------------------------------
  Widget _quizBuilder({required bool isSurvey}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                  isSurvey
                      ? 'Preguntas de la encuesta (sin calificación)'
                      : 'Preguntas (puntaje automático)',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Pregunta'),
              onPressed: () => setState(() => _questions.add(
                  QuizQuestion(kind: isSurvey ? 'short' : 'multiple'))),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _questions.length; i++)
          _questionCard(i, isSurvey: isSurvey),
      ],
    );
  }

  Widget _questionCard(int i, {required bool isSurvey}) {
    final q = _questions[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Pregunta ${i + 1}',
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              const Spacer(),
              if (!isSurvey)
                DropdownButton<String>(
                  value: q.kind,
                  isDense: true,
                  dropdownColor: AppColors.surfaceAlt,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textPrimary),
                  items: [
                    for (final (kind, label) in quizKinds)
                      DropdownMenuItem(value: kind, child: Text(label)),
                  ],
                  onChanged: (v) => setState(() => q.kind = v!),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16),
                color: AppColors.statusCritical,
                onPressed: () => setState(() => _questions.removeAt(i)),
              ),
            ],
          ),
          TextFormField(
            initialValue: q.question,
            decoration: const InputDecoration(
                labelText: 'Enunciado', isDense: true),
            onChanged: (v) => q.question = v,
          ),
          const SizedBox(height: 8),
          ..._kindFields(q, isSurvey: isSurvey),
        ],
      ),
    );
  }

  List<Widget> _kindFields(QuizQuestion q, {required bool isSurvey}) {
    if (isSurvey) return const []; // encuesta: solo texto libre
    switch (q.kind) {
      case 'multiple':
        return [
          for (var o = 0; o < q.options.length; o++)
            Row(
              children: [
                Radio<int>(
                  value: o,
                  groupValue: q.answerIndex,
                  activeColor: AppColors.gold,
                  onChanged: (v) => setState(() => q.answerIndex = v!),
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: q.options[o],
                    decoration: InputDecoration(
                        labelText: 'Opción ${o + 1}'
                            '${q.answerIndex == o ? ' (correcta)' : ''}',
                        isDense: true),
                    onChanged: (v) => q.options[o] = v,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  onPressed: () => setState(() {
                    q.options.removeAt(o);
                    if (q.answerIndex >= q.options.length) {
                      q.answerIndex = 0;
                    }
                  }),
                ),
              ],
            ),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Opción', style: TextStyle(fontSize: 12)),
            onPressed: () => setState(() => q.options.add('')),
          ),
        ];
      case 'truefalse':
        return [
          Row(
            children: [
              const Text('Respuesta correcta:  ',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textMuted)),
              ChoiceChip(
                label: const Text('Verdadero'),
                selected: q.answerIndex == 0,
                selectedColor:
                    AppColors.statusGood.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => q.answerIndex = 0),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Falso'),
                selected: q.answerIndex == 1,
                selectedColor:
                    AppColors.statusCritical.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => q.answerIndex = 1),
              ),
            ],
          ),
        ];
      case 'short':
      case 'fill':
        return [
          TextFormField(
            initialValue: q.answerText,
            decoration: InputDecoration(
              labelText: q.kind == 'short'
                  ? 'Respuesta correcta (comparación flexible)'
                  : 'Palabra/frase que completa el enunciado',
              isDense: true,
            ),
            onChanged: (v) => q.answerText = v,
          ),
        ];
      case 'order':
        return [
          const Text('Elementos en el orden CORRECTO:',
              style:
                  TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          for (var o = 0; o < q.options.length; o++)
            Row(
              children: [
                Text('${o + 1}. ',
                    style: const TextStyle(color: AppColors.gold)),
                Expanded(
                  child: TextFormField(
                    initialValue: q.options[o],
                    decoration:
                        const InputDecoration(isDense: true),
                    onChanged: (v) => q.options[o] = v,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  onPressed: () =>
                      setState(() => q.options.removeAt(o)),
                ),
              ],
            ),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 14),
            label:
                const Text('Elemento', style: TextStyle(fontSize: 12)),
            onPressed: () => setState(() => q.options.add('')),
          ),
        ];
      default:
        return const [];
    }
  }

  // ------------------------------------------------------------------
  // Constructor de actividades (entregables)
  // ------------------------------------------------------------------
  Widget _activityBuilder() {
    final a = _activity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: a.description,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Instrucciones de la actividad'),
          onChanged: (v) => a.description = v,
        ),
        const SizedBox(height: 12),
        // Fecha límite
        HoverCard(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              firstDate: now,
              lastDate: DateTime(now.year + 2),
              initialDate: now,
            );
            if (picked != null) {
              setState(() => a.deadline = picked.toIso8601String());
            }
          },
          child: Row(
            children: [
              const Icon(Icons.schedule, color: AppColors.gold, size: 18),
              const SizedBox(width: 10),
              Text(a.deadline.isEmpty
                  ? 'Fecha límite: sin definir'
                  : 'Fecha límite: ${DateFormat('d MMM yyyy').format(DateTime.parse(a.deadline))}'),
              const Spacer(),
              if (a.deadline.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 14),
                  onPressed: () => setState(() => a.deadline = ''),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                dense: true,
                title: const Text('Archivo obligatorio',
                    style: TextStyle(fontSize: 13)),
                value: a.requiresFile,
                activeColor: AppColors.gold,
                onChanged: (v) => setState(() => a.requiresFile = v!),
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                dense: true,
                title: const Text('Texto obligatorio',
                    style: TextStyle(fontSize: 13)),
                value: a.requiresText,
                activeColor: AppColors.gold,
                onChanged: (v) => setState(() => a.requiresText = v!),
              ),
            ),
            SizedBox(
              width: 120,
              child: TextFormField(
                initialValue: a.maxFiles.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Máx. archivos', isDense: true),
                onChanged: (v) => a.maxFiles = int.tryParse(v) ?? 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Tipos de entregable aceptados',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (final t in deliverableTypes)
              FilterChip(
                label: Text(t, style: const TextStyle(fontSize: 12)),
                selected: a.allowedTypes.contains(t),
                selectedColor: AppColors.gold.withValues(alpha: 0.2),
                onSelected: (sel) => setState(() => sel
                    ? a.allowedTypes.add(t)
                    : a.allowedTypes.remove(t)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: a.gradingMode,
          decoration: const InputDecoration(labelText: 'Calificación'),
          items: const [
            DropdownMenuItem(
                value: 'points100', child: Text('Puntaje 0 a 100')),
            DropdownMenuItem(
                value: 'passfail', child: Text('Aprobado / Reprobado')),
            DropdownMenuItem(
                value: 'review', child: Text('Solo revisión')),
          ],
          onChanged: (v) => setState(() => a.gradingMode = v!),
        ),
        const SizedBox(height: 14),
        // Rúbrica
        Row(
          children: [
            const Expanded(
              child: Text('Rúbrica (criterios y puntos)',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Criterio'),
              onPressed: () => setState(() =>
                  a.rubric.add({'criterion': '', 'points': 20})),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < a.rubric.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: a.rubric[i]['criterion'] as String,
                    decoration: const InputDecoration(
                        labelText: 'Criterio', isDense: true),
                    onChanged: (v) => a.rubric[i]['criterion'] = v,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: a.rubric[i]['points'].toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Puntos', isDense: true),
                    onChanged: (v) =>
                        a.rubric[i]['points'] = int.tryParse(v) ?? 0,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  onPressed: () => setState(() => a.rubric.removeAt(i)),
                ),
              ],
            ),
          ),
        if (a.rubric.isNotEmpty)
          Text(
            'Total: ${a.rubric.fold<int>(0, (s, r) => s + (r['points'] as num).toInt())} puntos',
            style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
      ],
    );
  }
}
