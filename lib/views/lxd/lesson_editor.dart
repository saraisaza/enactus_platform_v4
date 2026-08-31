import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/authoring.dart';
import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../widgets/file_upload_field.dart';

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

/// Abre el constructor de lecciones.
///
/// Devuelve `true` si se guardó algo. Antes devolvía la `Lesson` construida en
/// memoria y quien lo llamaba la insertaba en la lista; ahora **la lección se
/// guarda acá adentro**, contra la API, y el llamador solo tiene que recargar
/// el curso. El cambio no es de estilo: crear una lección de quiz son dos
/// escrituras (la lección y sus preguntas) y la segunda necesita el id que
/// asigna la primera, así que no se puede armar todo y mandarlo al final.
Future<bool> showLessonEditor(
  BuildContext context, {
  required String courseId,
  required String moduleId,
  Lesson? lesson,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LessonEditorDialog(
      courseId: courseId,
      moduleId: moduleId,
      original: lesson,
    ),
  );
  return saved ?? false;
}

class _LessonEditorDialog extends StatefulWidget {
  final String courseId;
  final String moduleId;
  final Lesson? original;

  const _LessonEditorDialog({
    required this.courseId,
    required this.moduleId,
    this.original,
  });

  @override
  State<_LessonEditorDialog> createState() => _LessonEditorDialogState();
}

class _LessonEditorDialogState extends State<_LessonEditorDialog> {
  late LessonType _type;
  late TextEditingController _title;
  late TextEditingController _desc;
  late TextEditingController _duration;
  late TextEditingController _externalUrl;
  late TextEditingController _videoUrl;

  List<QuizQuestionDraft> _questions = [];
  late ActivityDraft _activity;

  /// El archivo que se acaba de subir para una lección de PDF o recurso.
  final List<UploadedFile> _resource = [];

  bool _loadingQuiz = false;
  bool _saving = false;
  ApiException? _error;

  /// Problemas por pregunta que devolvió el servidor: `{ nº → motivo }`.
  Map<int, String> _problems = const {};

  bool get _isNew => widget.original == null;
  bool get _isSurvey => _type == LessonType.survey;

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    _type = o?.type ?? LessonType.video;
    _title = TextEditingController(text: o?.title ?? '');
    _desc = TextEditingController(text: o?.description ?? '');
    _duration = TextEditingController(text: (o?.durationMin ?? 0).toString());
    _externalUrl = TextEditingController(text: o?.externalUrl ?? '');
    _videoUrl = TextEditingController(
        text: o?.videoType == VideoSourceType.external ? (o?.videoUrl ?? '') : '');
    _activity = o?.activity == null
        ? ActivityDraft()
        : ActivityDraft.from(o!.activity!);

    if (o != null && (o.type == LessonType.quiz || o.type == LessonType.survey)) {
      _loadQuiz(o.id);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _duration.dispose();
    _externalUrl.dispose();
    _videoUrl.dispose();
    super.dispose();
  }

  /// Trae las preguntas CON su clave.
  ///
  /// La lectura del curso no la devuelve —ningún estudiante puede verla— así
  /// que hay que pedirla por el endpoint de autoría. Sin esto, abrir una
  /// lección ya hecha mostraría las respuestas en blanco y el primer guardado
  /// borraría la clave sin que nadie se enterara.
  Future<void> _loadQuiz(String lessonId) async {
    setState(() => _loadingQuiz = true);
    try {
      final questions = await context.read<DataProvider>().lessonQuiz(lessonId);
      if (mounted) {
        setState(() {
          _questions = questions;
          _loadingQuiz = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loadingQuiz = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error =
          const ValidationError('La lección necesita un título.'));
      return;
    }
    if (_type == LessonType.link && _externalUrl.text.trim().isEmpty) {
      setState(() => _error =
          const ValidationError('Una lección de tipo enlace necesita su URL.'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _problems = const {};
    });

    final data = context.read<DataProvider>();
    try {
      final lessonId = await _saveLesson(data);
      await _saveTypeSpecific(data, lessonId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ConflictError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e;
        _problems = _problemsFrom(e);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e;
      });
    }
  }

  /// Crea o actualiza la lección y devuelve su id.
  Future<String> _saveLesson(DataProvider data) async {
    final fields = {
      'title': _title.text.trim(),
      'type': _type.name,
      'description': _desc.text.trim(),
      'durationMin': int.tryParse(_duration.text) ?? 0,
      'externalUrl':
          _type == LessonType.link ? _externalUrl.text.trim() : null,
    };

    if (_isNew) {
      final created = await data.createLesson(
        widget.moduleId,
        title: fields['title']! as String,
        type: _type.name,
        description: fields['description']! as String,
        durationMin: fields['durationMin']! as int,
        externalUrl: fields['externalUrl'] as String?,
      );
      return created.id;
    }
    await data.updateLesson(widget.original!.id, fields);
    return widget.original!.id;
  }

  /// Lo que cuelga de la lección según su tipo: preguntas, actividad,
  /// archivo o video externo.
  Future<void> _saveTypeSpecific(DataProvider data, String lessonId) async {
    switch (_type) {
      case LessonType.quiz:
      case LessonType.survey:
        await data.saveLessonQuiz(lessonId, _questions,
            courseId: widget.courseId);
      case LessonType.activity:
        await data.saveLessonActivity(lessonId, _activity,
            courseId: widget.courseId);
      case LessonType.pdf:
      case LessonType.resource:
        if (_resource.isNotEmpty) {
          await data.setLessonResource(lessonId, _resource.first.toJson(),
              courseId: widget.courseId);
        } else {
          await data.reloadCourse(widget.courseId);
        }
      case LessonType.video:
        final url = _videoUrl.text.trim();
        if (url.isNotEmpty) {
          await data.setLessonExternalVideo(lessonId, url,
              courseId: widget.courseId);
        } else {
          await data.reloadCourse(widget.courseId);
        }
      case LessonType.link:
        await data.reloadCourse(widget.courseId);
    }
  }

  /// Traduce el 409 del servidor a "qué le falta a cada pregunta".
  Map<int, String> _problemsFrom(ConflictError error) {
    final raw = error.details['problems'];
    if (raw is! List) return const {};
    return {
      for (final item in raw)
        if (item is Map && item['question'] is num)
          (item['question'] as num).toInt(): '${item['problem']}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final title = _isNew ? 'Nueva lección' : 'Editar lección';
    final actions = [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      ElevatedButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Guardando…' : 'Guardar'),
      ),
    ];

    if (context.isCompact) {
      return Dialog.fullscreen(
        backgroundColor: AppColors.background,
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: AppColors.background,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cerrar',
                  onPressed:
                      _saving ? null : () => Navigator.pop(context, false),
                ),
                title: Text(title, style: const TextStyle(fontSize: 17)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    16 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: _form(),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    actions[0],
                    const SizedBox(width: 8),
                    actions[1],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 18)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(child: _form()),
      ),
      actions: actions,
    );
  }

  Widget _form() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null) ...[
          ErrorBanner(_error!),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in LessonType.values)
              ChoiceChip(
                avatar: Icon(lessonTypeIcon(t),
                    size: 15,
                    color: _type == t ? AppColors.gold : AppColors.textMuted),
                label: Text(lessonTypeLabel(t),
                    style: const TextStyle(fontSize: 12)),
                selected: _type == t,
                selectedColor: AppColors.gold.withValues(alpha: 0.2),
                onSelected: _saving ? null : (_) => _changeType(t),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          enabled: !_saving,
          decoration: const InputDecoration(labelText: 'Título'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _desc,
          enabled: !_saving,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Descripción'),
        ),
        const SizedBox(height: 12),
        ..._typeFields(),
      ],
    );
  }

  /// Cambiar el tipo de una lección ya guardada no borra lo que tenía del tipo
  /// anterior hasta que se guarda: el servidor solo escribe lo que corresponde
  /// al tipo nuevo.
  void _changeType(LessonType t) => setState(() {
        _type = t;
        _problems = const {};
      });

  List<Widget> _typeFields() {
    switch (_type) {
      case LessonType.video:
        return [
          TextField(
            controller: _videoUrl,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Enlace del video (YouTube o Vimeo)',
              hintText: 'https://www.youtube.com/watch?v=…',
              helperText: 'Para subir un archivo propio, usá el botón de video '
                  'de la lección una vez creada.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _duration,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Duración (minutos)'),
          ),
        ];
      case LessonType.pdf:
      case LessonType.resource:
        return [
          const Text('Archivo descargable',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          if (widget.original?.resourceFileName != null && _resource.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.attach_file,
                      size: 16, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Actual: ${widget.original!.resourceFileName}',
                      style: const TextStyle(fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          FileUploadField(
            purpose: 'lesson_resource',
            files: _resource,
            enabled: !_saving,
            onChanged: () => setState(() {}),
          ),
        ];
      case LessonType.link:
        return [
          TextField(
            controller: _externalUrl,
            enabled: !_saving,
            decoration: const InputDecoration(
                labelText: 'URL', hintText: 'https://…'),
          ),
        ];
      case LessonType.quiz:
      case LessonType.survey:
        return [_quizBuilder()];
      case LessonType.activity:
        return [_activityBuilder()];
    }
  }

  // ------------------------------------------------------------------
  // Constructor de preguntas (quiz y encuesta)
  // ------------------------------------------------------------------
  Widget _quizBuilder() {
    if (_loadingQuiz) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: BrandLoader()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
                _isSurvey
                    ? 'Preguntas de la encuesta (sin calificación)'
                    : 'Preguntas (las califica el servidor)',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Pregunta'),
              onPressed: _saving
                  ? null
                  : () => setState(() => _questions.add(QuizQuestionDraft(
                        kind: _isSurvey ? 'short' : 'multiple',
                      ))),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_questions.isEmpty)
          const Text(
            'Sin preguntas todavía. Una lección de quiz sin preguntas se '
            'guarda, pero quien la abra recibe un aviso en vez de una nota.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        for (var i = 0; i < _questions.length; i++) _questionCard(i),
      ],
    );
  }

  Widget _questionCard(int i) {
    final q = _questions[i];
    final problem = _problems[i + 1];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: problem == null ? AppColors.border : AppColors.statusCritical),
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
              if (!_isSurvey)
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
                  onChanged: _saving
                      ? null
                      : (v) => setState(() {
                            q.kind = v!;
                            // La clave del tipo anterior no sirve para el
                            // nuevo: dejarla mandaría un índice donde va texto.
                            q.answerIndex = null;
                            q.answerText = null;
                          }),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16),
                color: AppColors.statusCritical,
                tooltip: 'Quitar pregunta',
                onPressed:
                    _saving ? null : () => setState(() => _questions.removeAt(i)),
              ),
            ],
          ),
          TextFormField(
            initialValue: q.question,
            enabled: !_saving,
            decoration:
                const InputDecoration(labelText: 'Enunciado', isDense: true),
            onChanged: (v) => q.question = v,
          ),
          if (problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 14, color: AppColors.statusCritical),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(problem,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.statusCritical)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          ..._kindFields(q),
        ],
      ),
    );
  }

  List<Widget> _kindFields(QuizQuestionDraft q) {
    if (_isSurvey) return const []; // encuesta: solo texto libre
    switch (q.kind) {
      case 'multiple':
        return [
          for (var o = 0; o < q.options.length; o++)
            Row(
              children: [
                Radio<int>(
                  // ignore: deprecated_member_use
                  value: o,
                  // ignore: deprecated_member_use
                  groupValue: q.answerIndex,
                  activeColor: AppColors.gold,
                  // ignore: deprecated_member_use
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => q.answerIndex = v),
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: q.options[o],
                    enabled: !_saving,
                    decoration: InputDecoration(
                        labelText: 'Opción ${o + 1}'
                            '${q.answerIndex == o ? ' (correcta)' : ''}',
                        isDense: true),
                    onChanged: (v) => q.options[o] = v,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  tooltip: 'Quitar opción',
                  onPressed: _saving ? null : () => _removeOption(q, o),
                ),
              ],
            ),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Opción', style: TextStyle(fontSize: 12)),
            onPressed: _saving ? null : () => setState(() => q.options.add('')),
          ),
        ];
      case 'truefalse':
        return [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Respuesta correcta:',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ChoiceChip(
                label: const Text('Verdadero'),
                selected: q.answerIndex == 0,
                selectedColor: AppColors.statusGood.withValues(alpha: 0.25),
                onSelected:
                    _saving ? null : (_) => setState(() => q.answerIndex = 0),
              ),
              ChoiceChip(
                label: const Text('Falso'),
                selected: q.answerIndex == 1,
                selectedColor:
                    AppColors.statusCritical.withValues(alpha: 0.25),
                onSelected:
                    _saving ? null : (_) => setState(() => q.answerIndex = 1),
              ),
            ],
          ),
        ];
      case 'short':
      case 'fill':
        return [
          TextFormField(
            initialValue: q.answerText ?? '',
            enabled: !_saving,
            decoration: InputDecoration(
              labelText: q.kind == 'short'
                  ? 'Respuesta correcta (se comparan tildes y mayúsculas de forma flexible)'
                  : 'Palabra o frase que completa el enunciado',
              isDense: true,
            ),
            onChanged: (v) => q.answerText = v,
          ),
        ];
      case 'order':
        return [
          const Text(
            'Elementos en el orden CORRECTO — así se guardan, y así se '
            'califica quien los ordene igual:',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          for (var o = 0; o < q.options.length; o++)
            Row(
              children: [
                Text('${o + 1}. ',
                    style: const TextStyle(color: AppColors.gold)),
                Expanded(
                  child: TextFormField(
                    initialValue: q.options[o],
                    enabled: !_saving,
                    decoration: const InputDecoration(isDense: true),
                    onChanged: (v) => q.options[o] = v,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  tooltip: 'Quitar elemento',
                  onPressed: _saving
                      ? null
                      : () => setState(() => q.options.removeAt(o)),
                ),
              ],
            ),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Elemento', style: TextStyle(fontSize: 12)),
            onPressed: _saving ? null : () => setState(() => q.options.add('')),
          ),
        ];
      default:
        return const [];
    }
  }

  /// Quitar una opción corre las que siguen: si la correcta era una de esas,
  /// su índice tiene que moverse con ella o la clave apuntaría a otra.
  void _removeOption(QuizQuestionDraft q, int index) {
    setState(() {
      q.options.removeAt(index);
      final answer = q.answerIndex;
      if (answer == null) return;
      if (answer == index) {
        q.answerIndex = null;
      } else if (answer > index) {
        q.answerIndex = answer - 1;
      }
    });
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
          enabled: !_saving,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Instrucciones de la actividad'),
          onChanged: (v) => a.description = v,
        ),
        const SizedBox(height: 12),
        HoverCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: _saving ? null : _pickDeadline,
          child: Row(
            children: [
              const Icon(Icons.schedule, color: AppColors.gold, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  a.deadline == null
                      ? 'Fecha límite: sin definir'
                      : 'Fecha límite: '
                          '${DateFormat('d MMM yyyy').format(DateTime.parse(a.deadline!))}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (a.deadline != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 14),
                  tooltip: 'Quitar fecha',
                  onPressed:
                      _saving ? null : () => setState(() => a.deadline = null),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // En una ventana angosta las tres columnas no caben: se apilan.
        LayoutBuilder(
          builder: (context, constraints) {
            final checkboxes = [
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Archivo obligatorio',
                    style: TextStyle(fontSize: 13)),
                value: a.requiresFile,
                activeColor: AppColors.gold,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => a.requiresFile = v!),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Texto obligatorio',
                    style: TextStyle(fontSize: 13)),
                value: a.requiresText,
                activeColor: AppColors.gold,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => a.requiresText = v!),
              ),
            ];
            final maxFiles = TextFormField(
              initialValue: a.maxFiles.toString(),
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Máx. archivos', isDense: true),
              onChanged: (v) => a.maxFiles = int.tryParse(v) ?? 1,
            );

            if (constraints.maxWidth < 460) {
              return Column(children: [...checkboxes, maxFiles]);
            }
            return Row(
              children: [
                Expanded(child: checkboxes[0]),
                Expanded(child: checkboxes[1]),
                SizedBox(width: 120, child: maxFiles),
              ],
            );
          },
        ),
        if (!a.requiresFile && !a.requiresText)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'La actividad tiene que pedir al menos texto o archivo: si no, '
              'no hay nada que entregar.',
              style: TextStyle(fontSize: 12, color: AppColors.statusCritical),
            ),
          ),
        const SizedBox(height: 8),
        const Text('Tipos de entregable aceptados (ninguno = cualquiera)',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in DeliverableType.all)
              FilterChip(
                label: Text(DeliverableType.label(t),
                    style: const TextStyle(fontSize: 12)),
                selected: a.allowedTypes.contains(t),
                selectedColor: AppColors.gold.withValues(alpha: 0.2),
                onSelected: _saving
                    ? null
                    : (sel) => setState(() => sel
                        ? a.allowedTypes.add(t)
                        : a.allowedTypes.remove(t)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: a.gradingMode,
          decoration: const InputDecoration(labelText: 'Calificación'),
          items: [
            for (final mode in const [
              GradingMode.points100,
              GradingMode.passfail,
              GradingMode.review,
            ])
              DropdownMenuItem(
                  value: mode, child: Text(GradingMode.label(mode))),
          ],
          onChanged:
              _saving ? null : (v) => setState(() => a.gradingMode = v!),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            const Text('Rúbrica (criterios y puntos)',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Criterio'),
              onPressed: _saving
                  ? null
                  : () => setState(
                      () => a.rubric.add(RubricDraft(points: 20))),
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
                    initialValue: a.rubric[i].criterion,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                        labelText: 'Criterio', isDense: true),
                    onChanged: (v) => a.rubric[i].criterion = v,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: a.rubric[i].points.toString(),
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Puntos', isDense: true),
                    onChanged: (v) =>
                        a.rubric[i].points = int.tryParse(v) ?? 0,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  tooltip: 'Quitar criterio',
                  onPressed: _saving
                      ? null
                      : () => setState(() => a.rubric.removeAt(i)),
                ),
              ],
            ),
          ),
        if (a.rubric.isNotEmpty)
          Text(
            'Total: ${a.totalPoints} puntos',
            style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
      ],
    );
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final current = _activity.deadline == null
        ? now
        : DateTime.tryParse(_activity.deadline!) ?? now;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDate: current.isBefore(DateTime(now.year - 1)) ? now : current,
    );
    if (picked != null && mounted) {
      // La API espera AAAA-MM-DD, no un ISO con hora: `date` en PostgreSQL.
      setState(() => _activity.deadline =
          DateFormat('yyyy-MM-dd').format(picked));
    }
  }
}
