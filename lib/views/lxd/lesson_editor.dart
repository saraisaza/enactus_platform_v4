import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/textos.dart';
import '../../models/authoring.dart';
import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatos.dart';
import '../../utils/responsive.dart';
import '../../utils/youtube.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../services/video_upload/upload_resume_store.dart';
import '../../services/video_upload/upload_types.dart';
import '../../services/video_upload/video_upload_controller.dart';
import '../../widgets/file_upload_field.dart';
import '../../widgets/video_upload_panel.dart';
import '../../widgets/youtube_lesson_player.dart';

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
      LessonType.video => tr.tipoArchivoVideo,
      LessonType.pdf => 'PDF',
      LessonType.resource => tr.leccionTipoRecurso,
      LessonType.link => tr.leccionTipoEnlace,
      LessonType.quiz => tr.leccionTipoQuiz,
      LessonType.activity => tr.leccionTipoActividad,
      LessonType.survey => tr.leccionTipoEncuesta,
    };

/// Tipos de pregunta: `(identificador de la API, rótulo en el idioma activo)`.
List<(String, String)> get quizKinds => [
      ('multiple', tr.quizTipoMultiple),
      ('truefalse', tr.quizTipoVerdaderoFalso),
      ('short', tr.quizTipoCorta),
      ('order', tr.quizTipoOrdenar),
      ('fill', tr.quizTipoCompletar),
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

  /// Lo que hay escrito en el campo de video, ya leído. Se recalcula con
  /// cada tecla para avisar ANTES de guardar, no con un 400 después.
  VideoLink _videoLink = VideoLink.parse('');

  List<QuizQuestionDraft> _questions = [];
  late ActivityDraft _activity;

  /// El archivo que se acaba de subir para una lección de PDF o recurso.
  final List<UploadedFile> _resource = [];

  /// De dónde sale el video: un enlace de YouTube o un archivo subido. Son
  /// dos opciones aparte, y se guarda solo la que está elegida.
  late VideoSourceMode _mode;
  final VideoUploadController _upload = VideoUploadController.forEditor();

  /// La lección que creó ESTE diálogo para subirle un video. Si la subida
  /// falla, el próximo «Guardar» la reusa y retoma la subida; si se cancela,
  /// se borra — no quedan lecciones nuevas a medias.
  String? _creada;

  bool _loadingQuiz = false;
  bool _saving = false;

  /// Cuántas veces se quitó una opción de cada pregunta.
  ///
  /// Las opciones son `String` sueltos, sin identidad propia: la llave de cada
  /// campo combina pregunta, posición y esta generación, así que quitar una
  /// opción rearma los campos con el texto que de verdad les toca. Sin llave,
  /// Flutter reutilizaba el estado por posición: el texto de la opción borrada
  /// seguía en pantalla y lo que se escribía iba a parar a la siguiente.
  final _generacion = Expando<int>('generación de opciones');
  ApiException? _error;

  /// Problemas por pregunta que devolvió el servidor: `{ nº → motivo }`.
  Map<int, String> _problems = const {};

  bool get _isNew => widget.original == null;
  bool get _isSurvey => _type == LessonType.survey;

  /// Cómo estaba la lección al abrirse (o al terminar de cargar su quiz).
  ///
  /// Preguntas, clave de respuestas y rúbrica viven solo en memoria hasta
  /// "Guardar": antes el botón atrás de Android, la X o tocar fuera los
  /// descartaban sin preguntar.
  String? _firmaInicial;

  String _firma() => jsonEncode({
        'tipo': _type.name,
        'titulo': _title.text,
        'descripcion': _desc.text,
        'duracion': _duration.text,
        'enlace': _externalUrl.text,
        'video': _videoUrl.text,
        'preguntas': [for (final q in _questions) q.toJson()],
        'actividad': _activity.toJson(),
        'recurso': [for (final r in _resource) r.s3Key],
      });

  bool get _hayCambios => _firmaInicial != null && _firma() != _firmaInicial;

  Future<void> _salir() async {
    if (_saving) return;
    if (_hayCambios &&
        !await confirmDialog(context, tr.formularioDescartarTitulo,
            tr.leccionDescartarTexto)) {
      return;
    }
    // [_cerrar] además descarta la lección que se creó para subirle un video
    // que nunca llegó.
    await _cerrar();
  }

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    _type = o?.type ?? LessonType.video;
    _title = TextEditingController(text: o?.title ?? '');
    _desc = TextEditingController(text: o?.description ?? '');
    _duration = TextEditingController(text: (o?.durationMin ?? 0).toString());
    _externalUrl = TextEditingController(text: o?.externalUrl ?? '');
    // Una lección de YouTube guarda solo el id; al editarla se muestra el
    // enlace canónico, que es lo que el LXD reconoce y vuelve a dar el id.
    _videoUrl = TextEditingController(
        text: switch (o?.videoType) {
      VideoSourceType.youtube when o?.videoYoutubeId != null =>
        youtubeWatchUrl(o!.videoYoutubeId!),
      VideoSourceType.external => o?.videoUrl ?? '',
      _ => '',
    });
    _videoLink = VideoLink.parse(_videoUrl.text);
    _videoUrl.addListener(() {
      final link = VideoLink.parse(_videoUrl.text);
      if (link.kind != _videoLink.kind ||
          link.youtubeId != _videoLink.youtubeId) {
        setState(() => _videoLink = link);
      }
    });
    _activity = o?.activity == null
        ? ActivityDraft()
        : ActivityDraft.from(o!.activity!);
    _mode = o?.isUploadedVideo == true
        ? VideoSourceMode.upload
        : VideoSourceMode.youtube;
    _upload.addListener(_alCambiarSubida);
    _upload.loadPending(o?.id);

    if (o != null && (o.type == LessonType.quiz || o.type == LessonType.survey)) {
      _loadQuiz(o.id);
    } else {
      _firmaInicial = _firma();
    }
  }

  /// La duración del video la sabe el navegador: se completa sola si el
  /// campo estaba vacío.
  void _alCambiarSubida() {
    final segundos = _upload.probe?.duration.inSeconds ?? 0;
    final actual = int.tryParse(_duration.text) ?? 0;
    if (segundos > 0 && actual == 0) {
      _duration.text = ((segundos + 59) ~/ 60).toString();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _upload.removeListener(_alCambiarSubida);
    _upload.dispose();
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
          _firmaInicial = _firma();
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
          ValidationError(tr.leccionNecesitaTitulo));
      return;
    }
    if (_type == LessonType.link && _externalUrl.text.trim().isEmpty) {
      setState(() => _error =
          ValidationError(tr.leccionEnlaceNecesitaUrl));
      return;
    }
    // Antes de crear nada: un enlace o un archivo inválido detectado DESPUÉS
    // de crear la lección la dejaría guardada a medias, sin video.
    final subir = _type == LessonType.video && _mode == VideoSourceMode.upload;
    if (subir) {
      if (_upload.checking) {
        setState(() => _error = ValidationError(
            tr.leccionEspereRevision));
        return;
      }
      final problema = _upload.file == null ? null : _upload.problem;
      if (problema != null) {
        setState(() => _error = ValidationError(problema));
        return;
      }
    } else {
      final videoProblem = _videoLink.problem;
      if (_type == LessonType.video && videoProblem != null) {
        setState(() => _error = ValidationError(videoProblem));
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
      _problems = const {};
    });

    final data = context.read<DataProvider>();
    try {
      final lessonId =
          await _saveLesson(data, conSubida: subir && _upload.ready);
      if (subir) {
        try {
          await _saveUpload(data, lessonId);
        } on UploadCancelled {
          rethrow;
        } catch (_) {
          // El panel ya muestra qué pasó, y que guardar de nuevo retoma.
          if (mounted) setState(() => _saving = false);
          return;
        }
      } else {
        await _saveTypeSpecific(data, lessonId);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on UploadCancelled {
      await _descartarCreada(data);
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context,
          tr.leccionSubidaCancelada);
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

  /// Sube el video elegido, o cambia solo la portada del que ya estaba.
  Future<void> _saveUpload(DataProvider data, String lessonId) async {
    if (_upload.ready) {
      await _upload.upload(api: data.api, lessonId: lessonId);
    } else if (_upload.customCover != null &&
        widget.original?.isUploadedVideo == true) {
      await _upload.saveCoverOnly(api: data.api, lessonId: lessonId);
    }
    // Ya tiene su video: dejó de ser una lección a medias.
    _creada = null;
    await data.reloadCourse(widget.courseId);
  }

  /// Borra la lección que creó este diálogo y no llegó a tener su video.
  Future<void> _descartarCreada(DataProvider data) async {
    final id = _creada;
    if (id == null) return;
    _creada = null;
    try {
      await data.deleteLesson(id, courseId: widget.courseId);
    } on ApiException {
      // Queda en el curso, sin video, y se puede borrar a mano.
    }
    await const UploadResumeStore().clear(id);
  }

  Future<void> _cerrar() async {
    final data = context.read<DataProvider>();
    if (_creada != null) {
      setState(() => _saving = true);
      await _descartarCreada(data);
    }
    if (mounted) Navigator.pop(context, false);
  }

  /// Crea o actualiza la lección y devuelve su id.
  ///
  /// [conSubida]: la lección nueva se crea para subirle un video, así que se
  /// recuerda en [_creada] hasta que el video llegue.
  Future<String> _saveLesson(DataProvider data,
      {bool conSubida = false}) async {
    final fields = {
      'title': _title.text.trim(),
      'type': _type.name,
      'description': _desc.text.trim(),
      'durationMin': int.tryParse(_duration.text) ?? 0,
      'externalUrl':
          _type == LessonType.link ? _externalUrl.text.trim() : null,
    };

    final creada = _creada;
    if (_isNew && creada != null) {
      await data.updateLesson(creada, fields);
      return creada;
    }
    if (_isNew) {
      final created = await data.createLesson(
        widget.moduleId,
        title: fields['title']! as String,
        type: _type.name,
        description: fields['description']! as String,
        durationMin: fields['durationMin']! as int,
        externalUrl: fields['externalUrl'] as String?,
      );
      if (conSubida) _creada = created.id;
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
        final link = _videoLink;
        switch (link.kind) {
          case VideoLinkKind.youtube:
            // Viaja y se guarda SOLO el id, nunca el enlace pegado.
            await data.setLessonYoutubeVideo(lessonId, link.youtubeId!,
                courseId: widget.courseId);
          case VideoLinkKind.vimeo:
            await data.setLessonExternalVideo(lessonId, link.url!,
                courseId: widget.courseId);
          case VideoLinkKind.empty:
          case VideoLinkKind.youtubeNotVideo:
          case VideoLinkKind.unsupported:
            // Vacío: queda como está (sin video, o con su archivo propio).
            // Los inválidos no llegan acá: `_save` los frena antes.
            await data.reloadCourse(widget.courseId);
        }
      case LessonType.link:
        await data.reloadCourse(widget.courseId);
    }
  }

  /// El enlace de YouTube (o de Vimeo) y su vista previa.
  List<Widget> _camposYoutube() {
    final link = _videoLink;
    final tieneArchivo = widget.original?.isUploadedVideo == true &&
        link.kind == VideoLinkKind.empty;
    return [
          TextField(
            key: const ValueKey('lesson-video-url'),
            controller: _videoUrl,
            enabled: !_saving,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: tr.leccionEnlaceYoutube,
              hintText: 'https://www.youtube.com/watch?v=…',
              prefixIcon: const Icon(Icons.smart_display_outlined),
              suffixIcon: link.kind == VideoLinkKind.youtube ||
                      link.kind == VideoLinkKind.vimeo
                  ? const Icon(Icons.check_circle, color: AppColors.statusGood)
                  : null,
              errorText: link.problem,
              errorMaxLines: 3,
              helperMaxLines: 3,
              helperText: switch (link.kind) {
                VideoLinkKind.youtube =>
                  tr.leccionYoutubeEncontrado(link.youtubeId ?? ''),
                VideoLinkKind.vimeo =>
                  tr.leccionEnlaceVimeo,
                _ when tieneArchivo =>
                  tr.leccionYaTieneVideo,
                _ => tr.leccionPegueEnlace,
              },
            ),
          ),
          if (link.kind == VideoLinkKind.youtube) ...[
            const SizedBox(height: 12),
            Text(tr.subidaVistaPreviaAsi,
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            const SizedBox(height: 6),
            // Reproducirlo acá es la única forma de enterarse ANTES de
            // publicar de que el dueño del video no deja verlo fuera de
            // YouTube. La vista previa no guarda avance de nadie.
            YoutubeLessonPlayer(
              key: ValueKey('preview-${link.youtubeId}'),
              videoId: link.youtubeId!,
              title: _title.text.trim().isEmpty
                  ? tr.subidaVistaPrevia
                  : _title.text.trim(),
            ),
          ],
    ];
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

  /// Siempre intercepta el "atrás": la decisión se toma en [_salir], con lo
  /// que haya en los campos en ESE momento (escribir no redibuja todo el
  /// editor, así que un `canPop` calculado al construir quedaría viejo).
  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _salir();
        },
        child: _construir(context),
      );

  Widget _construir(BuildContext context) {
    final title = _isNew ? tr.leccionNueva : tr.leccionEditar;
    final subiendo = _upload.uploading;
    final actions = [
      TextButton(
        onPressed: subiendo
            ? _upload.cancelUpload
            : _saving
                ? null
                : _salir,
        child: Text(subiendo ? tr.subidaCancelar : tr.comunCancelar),
      ),
      ElevatedButton(
        onPressed: _saving ? null : _save,
        child: Text(subiendo
            ? tr.leccionSubiendo
            : _saving
                ? tr.comunGuardando
                : tr.comunGuardar),
      ),
    ];

    return PopScope(
      // Con una subida en curso no se cierra por Esc ni por el gesto de
      // volver: la subida se perdería sin que nadie la cancele.
      canPop: !_saving,
      child: _dialogo(context, title, actions),
    );
  }

  Widget _dialogo(BuildContext context, String title, List<Widget> actions) {
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
                  tooltip: tr.comunCerrar,
                  onPressed: _saving ? null : _salir,
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
          decoration: InputDecoration(labelText: tr.comunTitulo),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _desc,
          enabled: !_saving,
          maxLines: 2,
          decoration: InputDecoration(labelText: tr.comunDescripcion),
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
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<VideoSourceMode>(
              key: const ValueKey('origen-del-video'),
              segments: [
                ButtonSegment(
                  value: VideoSourceMode.youtube,
                  icon: Icon(Icons.smart_display_outlined),
                  label: Text(tr.leccionPegarYoutube),
                ),
                ButtonSegment(
                  value: VideoSourceMode.upload,
                  icon: Icon(Icons.upload_file),
                  label: Text(tr.leccionSubirVideo),
                ),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              // La elegida tiene que verse elegida: con el tema oscuro, sin
              // esto las dos opciones quedan iguales.
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.gold.withValues(alpha: 0.18),
                selectedForegroundColor: AppColors.gold,
                foregroundColor: AppColors.textSecondary,
              ),
              onSelectionChanged: _saving
                  ? null
                  : (s) => setState(() {
                        _mode = s.first;
                        _error = null;
                      }),
            ),
          ),
          const SizedBox(height: 12),
          if (_mode == VideoSourceMode.upload)
            VideoUploadPanel(
              controller: _upload,
              title: _title.text.trim(),
              original: widget.original,
              enabled: !_saving,
            )
          else
            ..._camposYoutube(),
          const SizedBox(height: 12),
          TextField(
            controller: _duration,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            decoration:
                InputDecoration(labelText: tr.leccionDuracionMinutos),
          ),
        ];
      case LessonType.pdf:
      case LessonType.resource:
        return [
          Text(tr.leccionArchivoDescargable,
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
                      tr.leccionArchivoActual(widget.original!.resourceFileName ?? ''),
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
            keyboardType: TextInputType.url,
            autocorrect: false,
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
                    ? tr.leccionPreguntasEncuesta
                    : tr.leccionPreguntasQuiz,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(tr.leccionPregunta),
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
          Text(
            tr.leccionSinPreguntas,
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
      // Llave por identidad de la pregunta: al quitar una, los campos de las
      // que siguen conservan SU texto en vez de heredar el de la borrada.
      key: ObjectKey(q),
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
              Text(tr.leccionPreguntaNumero(i + 1),
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
                tooltip: tr.leccionQuitarPregunta,
                onPressed:
                    _saving ? null : () => setState(() => _questions.removeAt(i)),
              ),
            ],
          ),
          TextFormField(
            initialValue: q.question,
            enabled: !_saving,
            decoration:
                InputDecoration(labelText: tr.leccionEnunciado, isDense: true),
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
              key: ValueKey((q, o, _generacion[q] ?? 0)),
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
                        labelText: q.answerIndex == o
                            ? tr.leccionOpcionCorrecta(o + 1)
                            : tr.leccionOpcionNumero(o + 1),
                        isDense: true),
                    onChanged: (v) => q.options[o] = v,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  tooltip: tr.leccionQuitarOpcion,
                  onPressed: _saving ? null : () => _removeOption(q, o),
                ),
              ],
            ),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 14),
            label: Text(tr.leccionOpcion, style: TextStyle(fontSize: 12)),
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
              Text(tr.leccionRespuestaCorrecta,
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ChoiceChip(
                label: Text(tr.quizVerdadero),
                selected: q.answerIndex == 0,
                selectedColor: AppColors.statusGood.withValues(alpha: 0.25),
                onSelected:
                    _saving ? null : (_) => setState(() => q.answerIndex = 0),
              ),
              ChoiceChip(
                label: Text(tr.quizFalso),
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
                  ? tr.leccionRespuestaFlexible
                  : tr.leccionPalabraCompleta,
              isDense: true,
            ),
            onChanged: (v) => q.answerText = v,
          ),
        ];
      case 'order':
        return [
          Text(
            tr.leccionOrdenCorrecto,
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          for (var o = 0; o < q.options.length; o++)
            Row(
              key: ValueKey((q, o, _generacion[q] ?? 0)),
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
                  tooltip: tr.leccionQuitarElemento,
                  onPressed: _saving ? null : () => _removeOption(q, o),
                ),
              ],
            ),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 14),
            label: Text(tr.leccionElemento, style: TextStyle(fontSize: 12)),
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
      _generacion[q] = (_generacion[q] ?? 0) + 1;
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
          decoration: InputDecoration(
              labelText: tr.leccionInstrucciones),
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
                      ? tr.leccionFechaSinDefinir
                      : tr.labFechaLimite(
                          fechaCorta(DateTime.parse(a.deadline!))),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (a.deadline != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 14),
                  tooltip: tr.constructorQuitarFecha,
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
                title: Text(tr.actividadArchivoObligatorio,
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
                title: Text(tr.actividadTextoObligatorio,
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
              decoration: InputDecoration(
                  labelText: tr.leccionMaxArchivos, isDense: true),
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
          Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              tr.leccionPedirAlgo,
              style: TextStyle(fontSize: 12, color: AppColors.statusCritical),
            ),
          ),
        const SizedBox(height: 8),
        Text(tr.leccionTiposEntregable,
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
          isExpanded: true,
          initialValue: a.gradingMode,
          decoration: InputDecoration(labelText: tr.leccionCalificacion),
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
            Text(tr.leccionRubrica,
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(tr.leccionCriterio),
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
            // Cada criterio es un objeto: su identidad es la llave.
            key: ObjectKey(a.rubric[i]),
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: a.rubric[i].criterion,
                    enabled: !_saving,
                    decoration: InputDecoration(
                        labelText: tr.leccionCriterio, isDense: true),
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
                    decoration: InputDecoration(
                        labelText: tr.leccionPuntos, isDense: true),
                    onChanged: (v) =>
                        a.rubric[i].points = int.tryParse(v) ?? 0,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  tooltip: tr.leccionQuitarCriterio,
                  onPressed: _saving
                      ? null
                      : () => setState(() => a.rubric.removeAt(i)),
                ),
              ],
            ),
          ),
        if (a.rubric.isNotEmpty)
          Text(
            tr.leccionTotalPuntos(a.totalPoints),
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
