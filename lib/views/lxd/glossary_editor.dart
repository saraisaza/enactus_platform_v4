import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/glossary.dart';
import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../widgets/file_upload_field.dart';
import '../../widgets/lesson_visuals.dart';

/// Sección «Glosario» de un módulo, dentro del constructor de cursos.
///
/// Escribe en el momento, como módulos y lecciones: crear, editar, reordenar
/// y borrar van al servidor apenas se hacen. El formulario de un término sí
/// tiene botón de guardar, porque son varios campos que van juntos.
class ModuleGlossaryEditor extends StatefulWidget {
  final Course course;
  final CourseModule module;

  const ModuleGlossaryEditor({
    super.key,
    required this.course,
    required this.module,
  });

  @override
  State<ModuleGlossaryEditor> createState() => _ModuleGlossaryEditorState();
}

class _ModuleGlossaryEditorState extends State<ModuleGlossaryEditor> {
  bool _open = false;
  bool _working = false;
  ApiException? _error;

  /// El orden que se acaba de arrastrar, mientras el servidor lo confirma.
  /// Sin esto la lista vuelve un instante al orden viejo hasta que llega la
  /// recarga, y parece que el arrastre no funcionó.
  List<String>? _ordenLocal;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _ordenLocal = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final glossary = data.glossaryOf(widget.course.id);
    final terms = glossary.valueOrNull?.forModule(widget.module.id) ?? const [];
    final orden = _ordenLocal;
    final visibles = orden == null
        ? terms
        : [
            for (final id in orden)
              ...terms.where((t) => t.id == id),
          ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            expanded: _open,
            child: InkWell(
              key: ValueKey('glosario-editor-${widget.module.id}'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_outlined,
                        size: 17, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        glossary.valueOrNull == null
                            ? 'Glosario del módulo'
                            : 'Glosario del módulo · ${_cuantos(terms.length)}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more,
                          size: 20, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: glossary.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(12),
                        child: LinearProgressIndicator(color: AppColors.gold),
                      ),
                      error: (e) => ErrorBanner(e,
                          onRetry: () => data.reloadGlossary(widget.course.id)),
                      data: (all) => _lista(data, all, visibles),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _lista(
    DataProvider data,
    CourseGlossary all,
    List<GlossaryTerm> terms,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null) ErrorBanner(_error!),
        if (terms.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Este módulo todavía no tiene términos. Los que agregue aparecen '
              'al final de las lecciones que marque y al final del módulo.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: terms.length,
            onReorderItem: (fromIndex, toIndex) {
              final ids = terms.map((t) => t.id).toList();
              ids.insert(toIndex, ids.removeAt(fromIndex));
              setState(() => _ordenLocal = ids);
              _run(() => data.reorderGlossaryTerms(widget.module.id, ids,
                  courseId: widget.course.id));
            },
            itemBuilder: (context, i) =>
                _fila(data, all, terms[i], i, key: ValueKey(terms[i].id)),
          ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          key: ValueKey('glosario-agregar-${widget.module.id}'),
          icon: const Icon(Icons.add, size: 17),
          label: const Text('Agregar término'),
          onPressed: _working
              ? null
              : () => showGlossaryTermEditor(context,
                  course: widget.course, module: widget.module, glossary: all),
        ),
      ],
    );
  }

  Widget _fila(
    DataProvider data,
    CourseGlossary all,
    GlossaryTerm term,
    int index, {
    required Key key,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.drag_indicator,
                    color: AppColors.textMuted,
                    size: 16,
                    semanticLabel: 'Arrastrar para reordenar «${term.word}»'),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(term.word,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(term.shortDefinition,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
          if (term.imageS3Key != null)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Tooltip(
                message: 'Tiene imagen',
                child: Icon(Icons.image_outlined,
                    size: 15, color: AppColors.textMuted),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Tooltip(
              message: term.lessonIds.isEmpty
                  ? 'No está marcado en ninguna lección'
                  : 'Aparece en ${term.lessonIds.length} '
                      '${term.lessonIds.length == 1 ? 'lección' : 'lecciones'}',
              child: Text('${term.lessonIds.length}',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            color: AppColors.textSecondary,
            tooltip: 'Editar «${term.word}»',
            onPressed: _working
                ? null
                : () => showGlossaryTermEditor(context,
                    course: widget.course,
                    module: widget.module,
                    glossary: all,
                    term: term),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            color: AppColors.statusCritical,
            tooltip: 'Eliminar «${term.word}»',
            onPressed: _working
                ? null
                : () async {
                    final ok = await confirmDialog(
                      context,
                      'Eliminar término',
                      '¿Eliminar «${term.word}» del glosario? También se quita '
                          'de los relacionados de otros términos y del repaso '
                          'de los estudiantes.',
                    );
                    if (ok) {
                      await _run(() => data.deleteGlossaryTerm(term.id,
                          courseId: widget.course.id));
                    }
                  },
          ),
        ],
      ),
    );
  }

  static String _cuantos(int n) => n == 1 ? '1 término' : '$n términos';
}

/// Abre el formulario de un término. Sin [term] lo crea al final del módulo.
///
/// Devuelve `true` si se guardó. El glosario se recarga solo (lo hace el
/// `DataProvider`), así que quien lo abre no tiene que hacer nada más.
Future<bool> showGlossaryTermEditor(
  BuildContext context, {
  required Course course,
  required CourseModule module,
  required CourseGlossary glossary,
  GlossaryTerm? term,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TermEditorDialog(
      course: course,
      module: module,
      glossary: glossary,
      original: term,
    ),
  );
  return saved ?? false;
}

class _TermEditorDialog extends StatefulWidget {
  final Course course;
  final CourseModule module;
  final CourseGlossary glossary;
  final GlossaryTerm? original;

  const _TermEditorDialog({
    required this.course,
    required this.module,
    required this.glossary,
    this.original,
  });

  @override
  State<_TermEditorDialog> createState() => _TermEditorDialogState();
}

class _TermEditorDialogState extends State<_TermEditorDialog> {
  late final TextEditingController _word;
  late final TextEditingController _definition;
  late final TextEditingController _explanation;
  late final TextEditingController _example;

  /// La imagen que ya tenía; `null` si no tenía o si se la quitaron.
  String? _imagenGuardada;

  /// La imagen recién subida, si hay.
  final List<UploadedFile> _imagenNueva = [];

  late final Set<String> _lessonIds;
  late final Set<String> _relatedIds;

  bool _saving = false;
  ApiException? _error;

  /// Se intentó guardar: desde ahí los campos obligatorios vacíos lo dicen.
  bool _intentado = false;

  /// Lo que dijo el servidor sobre la palabra (un 409 de duplicado que el
  /// aviso local no vio, por ejemplo porque otra persona la acababa de crear).
  String? _wordServerError;

  late final String _firmaInicial;

  bool get _isNew => widget.original == null;

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    _word = TextEditingController(text: o?.word ?? '');
    _definition = TextEditingController(text: o?.shortDefinition ?? '');
    _explanation = TextEditingController(text: o?.explanation ?? '');
    _example = TextEditingController(text: o?.example ?? '');
    _imagenGuardada = o?.imageS3Key;
    _lessonIds = {...?o?.lessonIds};
    _relatedIds = {...?o?.relatedTermIds};
    _firmaInicial = _firma();
  }

  @override
  void dispose() {
    _word.dispose();
    _definition.dispose();
    _explanation.dispose();
    _example.dispose();
    super.dispose();
  }

  String _firma() => jsonEncode({
        'palabra': _word.text,
        'definicion': _definition.text,
        'explicacion': _explanation.text,
        'ejemplo': _example.text,
        'imagen': _imagenGuardada,
        'nueva': [for (final f in _imagenNueva) f.s3Key],
        'lecciones': [..._lessonIds]..sort(),
        'relacionados': [..._relatedIds]..sort(),
      });

  bool get _hayCambios => _firma() != _firmaInicial;

  /// El término que ya usa esta palabra, mientras se escribe.
  GlossaryTerm? get _duplicado => widget.glossary
      .duplicateOf(_word.text, exceptId: widget.original?.id);

  String? get _wordError {
    if (_wordServerError != null) return _wordServerError;
    if (_intentado && _word.text.trim().isEmpty) {
      return 'La palabra es obligatoria.';
    }
    final dup = _duplicado;
    if (dup == null) return null;
    final modulo = widget.course.modules
        .where((m) => m.id == dup.moduleId)
        .map((m) => m.title)
        .firstOrNull;
    return modulo == null || dup.moduleId == widget.module.id
        ? 'Ya existe «${dup.word}» en este módulo.'
        : 'Ya existe «${dup.word}» en el módulo «$modulo».';
  }

  bool get _valido =>
      _word.text.trim().isNotEmpty &&
      _definition.text.trim().isNotEmpty &&
      _wordError == null;

  Future<void> _salir() async {
    if (_saving) return;
    if (_hayCambios &&
        !await confirmDialog(context, 'Descartar cambios',
            'Hay cambios sin guardar en este término. ¿Desea salir de todas formas?')) {
      return;
    }
    if (mounted) Navigator.pop(context, false);
  }

  Future<void> _guardar() async {
    if (_saving) return;
    if (!_valido) {
      setState(() => _intentado = true);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _wordServerError = null;
    });

    // Las listas en el orden en que se ven: lecciones como en el módulo,
    // relacionados como en el glosario.
    final draft = GlossaryTermDraft(
      word: _word.text,
      shortDefinition: _definition.text,
      explanation: _explanation.text,
      example: _example.text,
      imageS3Key:
          _imagenNueva.isNotEmpty ? _imagenNueva.first.s3Key : _imagenGuardada,
      lessonIds: [
        for (final l in widget.module.lessons)
          if (_lessonIds.contains(l.id)) l.id,
      ],
      relatedTermIds: [
        for (final t in widget.glossary.terms)
          if (_relatedIds.contains(t.id)) t.id,
      ],
    );

    final data = context.read<DataProvider>();
    try {
      if (_isNew) {
        await data.createGlossaryTerm(widget.module.id, draft,
            courseId: widget.course.id);
      } else {
        await data.updateGlossaryTerm(widget.original!.id, draft,
            courseId: widget.course.id);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      showSuccessCheck(context, _isNew ? 'Término agregado ✓' : 'Guardado ✓');
    } on ConflictError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (e.details['field'] == 'word') {
          _wordServerError = e.message;
        } else {
          _error = e;
        }
      });
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
    final otros = widget.glossary.terms
        .where((t) => t.id != widget.original?.id)
        .toList();

    return PopScope(
      canPop: !_hayCambios && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir();
      },
      child: AdaptiveFormShell(
        title: _isNew ? 'Nuevo término' : 'Editar término',
        maxWidth: 560,
        saving: _saving,
        onCancel: _salir,
        onSave: _guardar,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Módulo: ${widget.module.title}',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12.5)),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('glosario-palabra'),
              controller: _word,
              enabled: !_saving,
              autofocus: _isNew,
              maxLength: 120,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() => _wordServerError = null),
              decoration: InputDecoration(
                labelText: 'Palabra o expresión *',
                errorText: _wordError,
                errorMaxLines: 2,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const ValueKey('glosario-definicion'),
              controller: _definition,
              enabled: !_saving,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Definición corta *',
                errorText: _intentado && _definition.text.trim().isEmpty
                    ? 'La definición corta es obligatoria.'
                    : null,
                helperText:
                    'Una o dos frases. Es lo que se ve en la tarjeta y al pasar '
                    'el mouse sobre la palabra.',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const ValueKey('glosario-explicacion'),
              controller: _explanation,
              enabled: !_saving,
              minLines: 2,
              maxLines: 8,
              maxLength: 5000,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  labelText: 'Explicación ampliada (opcional)'),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const ValueKey('glosario-ejemplo'),
              controller: _example,
              enabled: !_saving,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              onChanged: (_) => setState(() {}),
              decoration:
                  const InputDecoration(labelText: 'Ejemplo (opcional)'),
            ),
            const SizedBox(height: 10),
            _titulo('Imagen (opcional)'),
            if (_imagenGuardada != null && _imagenNueva.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 96,
                        height: 64,
                        child: AppImage(
                          s3Key: _imagenGuardada,
                          placeholderBuilder: (_) =>
                              Container(color: AppColors.surfaceAlt),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Quitar imagen'),
                      onPressed: _saving
                          ? null
                          : () => setState(() => _imagenGuardada = null),
                    ),
                  ],
                ),
              ),
            if (_imagenGuardada == null || _imagenNueva.isNotEmpty)
              FileUploadField(
                purpose: 'glossary_image',
                files: _imagenNueva,
                enabled: !_saving,
                onChanged: () => setState(() {}),
              ),
            const Text('PNG o JPG.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            const SizedBox(height: 14),
            _titulo('Lecciones donde aparece'),
            if (widget.module.lessons.isEmpty)
              const Text('Este módulo todavía no tiene lecciones.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final lesson in widget.module.lessons)
                    FilterChip(
                      avatar: Icon(lessonTypeIcon(lesson.type), size: 15),
                      label: Text(lesson.title,
                          style: const TextStyle(fontSize: 12.5)),
                      selected: _lessonIds.contains(lesson.id),
                      onSelected: _saving
                          ? null
                          : (on) => setState(() => on
                              ? _lessonIds.add(lesson.id)
                              : _lessonIds.remove(lesson.id)),
                    ),
                ],
              ),
            const SizedBox(height: 14),
            _titulo('Términos relacionados'),
            if (otros.isEmpty)
              const Text(
                  'Cuando el curso tenga más términos, podrá relacionarlos acá.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in otros)
                    FilterChip(
                      label: Text(t.word, style: const TextStyle(fontSize: 12.5)),
                      tooltip: t.moduleId == widget.module.id
                          ? null
                          : 'De otro módulo',
                      selected: _relatedIds.contains(t.id),
                      onSelected: _saving
                          ? null
                          : (on) => setState(() => on
                              ? _relatedIds.add(t.id)
                              : _relatedIds.remove(t.id)),
                    ),
                ],
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(_error!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(texto,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      );
}
