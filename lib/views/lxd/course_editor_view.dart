import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/authoring.dart';
import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_header.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../widgets/file_upload_field.dart';
import 'lesson_editor.dart';

/// Constructor de cursos: información general, categorización, contenido,
/// certificado y restricciones.
///
/// Cada sección guarda **lo suyo y nada más**, contra el endpoint que le
/// corresponde: las secciones 1, 4 y 5 parchean el curso; la 2 reemplaza la
/// categorización entera (`PUT /courses/:id/meta`); la 3 escribe módulos y
/// lecciones en el momento, sin botón de guardar.
///
/// Antes existía un solo `saveCourse(course)` que mandaba el objeto completo
/// —módulos, lecciones, preguntas y clave de respuestas incluidos— cada vez
/// que se tocaba cualquier campo. Con la API eso significaría reescribir el
/// curso entero para cambiarle el subtítulo, y pisar el trabajo de quien
/// estuviera editando otra sección al mismo tiempo.
class CourseEditorView extends StatefulWidget {
  final String courseId;
  const CourseEditorView({super.key, required this.courseId});

  @override
  State<CourseEditorView> createState() => _CourseEditorViewState();
}

class _CourseEditorViewState extends State<CourseEditorView> {
  static const _sections = [
    ('Información general', Icons.info_outline),
    ('Categorización y objetivos', Icons.category_outlined),
    ('Constructor del curso', Icons.view_agenda_outlined),
    ('Evaluación y certificado', Icons.workspace_premium_outlined),
    ('Restricciones y patrocinio', Icons.tune),
  ];

  int _section = 0;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(portalTitle: 'Constructor de Curso'),
          Expanded(
            child: data.courseById(widget.courseId).when(
                  loading: () => const Center(child: BrandLoader()),
                  // Un 404 acá es un curso ajeno: el servidor no confirma que
                  // exista.
                  error: (e) => ErrorState(e,
                      onRetry: () => data.reloadCourse(widget.courseId)),
                  data: (course) => _layout(context, course),
                ),
          ),
        ],
      ),
    );
  }

  /// En pantallas anchas, el riel de secciones a la izquierda. En angostas se
  /// convierte en una fila de fichas arriba: un riel fijo de 250px se comería
  /// dos tercios del ancho de un teléfono y dejaría el formulario inutilizable.
  Widget _layout(BuildContext context, Course course) {
    final body = _CourseSection(
      key: ValueKey('${course.id}-$_section'),
      course: course,
      section: _section,
    );

    if (context.isExpanded) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 250,
            color: AppColors.slate,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        color: AppColors.gold,
                        tooltip: 'Volver',
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          course.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < _sections.length; i++)
                  _RailItem(
                    label: _sections[i].$1,
                    icon: _sections[i].$2,
                    selected: _section == i,
                    onTap: () => setState(() => _section = i),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: body,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          color: AppColors.slate,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: AppColors.gold,
                      tooltip: 'Volver',
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(course.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (var i = 0; i < _sections.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          avatar: Icon(_sections[i].$2,
                              size: 15,
                              color: _section == i
                                  ? AppColors.gold
                                  : AppColors.textMuted),
                          label: Text(_sections[i].$1,
                              style: const TextStyle(fontSize: 12)),
                          selected: _section == i,
                          selectedColor:
                              AppColors.gold.withValues(alpha: 0.2),
                          onSelected: (_) => setState(() => _section = i),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: body,
          ),
        ),
      ],
    );
  }
}

/// La sección visible. Es un widget aparte —y con `key` por sección— para que
/// sus controladores se creen y se destruyan al cambiar de sección, en vez de
/// quedar todos vivos con datos viejos de un curso que se recargó.
class _CourseSection extends StatelessWidget {
  final Course course;
  final int section;

  const _CourseSection({
    super.key,
    required this.course,
    required this.section,
  });

  @override
  Widget build(BuildContext context) => switch (section) {
        0 => _GeneralSection(course: course),
        1 => _CategorySection(course: course),
        2 => _BuilderSection(course: course),
        3 => _CertificateSection(course: course),
        _ => _RestrictionsSection(course: course),
      };
}

// ---------------------------------------------------------------------------
// Sección 1: Información general
// ---------------------------------------------------------------------------

class _GeneralSection extends StatefulWidget {
  final Course course;
  const _GeneralSection({required this.course});

  @override
  State<_GeneralSection> createState() => _GeneralSectionState();
}

class _GeneralSectionState extends State<_GeneralSection> {
  late final TextEditingController _name;
  late final TextEditingController _subtitle;
  late final TextEditingController _shortDesc;
  late final TextEditingController _fullDesc;
  late final TextEditingController _hours;

  late String _level;
  late String _language;
  final List<UploadedFile> _cover = [];

  bool _saving = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _name = TextEditingController(text: c.name);
    _subtitle = TextEditingController(text: c.subtitle);
    _shortDesc = TextEditingController(text: c.description);
    _fullDesc = TextEditingController(text: c.fullDescription);
    _hours = TextEditingController(text: c.estimatedHours.toString());
    _level = c.level;
    _language =
        CourseLanguage.all.contains(c.language) ? c.language : 'es';
  }

  @override
  void dispose() {
    _name.dispose();
    _subtitle.dispose();
    _shortDesc.dispose();
    _fullDesc.dispose();
    _hours.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() =>
          _error = const ValidationError('El curso necesita un nombre.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<DataProvider>().updateCourse(widget.course.id, {
        'name': _name.text.trim(),
        'subtitle': _subtitle.text.trim(),
        'description': _shortDesc.text.trim(),
        'fullDescription': _fullDesc.text.trim(),
        'level': _level,
        'language': _language,
        'estimatedHours': int.tryParse(_hours.text) ?? 0,
        if (_cover.isNotEmpty) 'coverS3Key': _cover.first.s3Key,
      });
      if (!mounted) return;
      setState(() => _saving = false);
      showSuccessCheck(context, 'Curso guardado ✓');
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Información general'),
        if (_error != null) ...[
          ErrorBanner(_error!),
          const SizedBox(height: 12),
        ],
        TextField(
            controller: _name,
            enabled: !_saving,
            decoration:
                const InputDecoration(labelText: 'Nombre del curso')),
        const SizedBox(height: 12),
        TextField(
            controller: _subtitle,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Subtítulo')),
        const SizedBox(height: 12),
        TextField(
            controller: _shortDesc,
            enabled: !_saving,
            maxLines: 2,
            decoration:
                const InputDecoration(labelText: 'Descripción corta')),
        const SizedBox(height: 12),
        TextField(
            controller: _fullDesc,
            enabled: !_saving,
            maxLines: 4,
            decoration:
                const InputDecoration(labelText: 'Descripción completa')),
        const SizedBox(height: 16),
        const Text('Imagen de portada',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        if (widget.course.coverS3Key != null && _cover.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Ya tiene portada. Subir otra la reemplaza.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ),
        FileUploadField(
          purpose: 'course_cover',
          files: _cover,
          enabled: !_saving,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 16),
        // Tres columnas en escritorio, apiladas cuando no caben.
        LayoutBuilder(
          builder: (context, constraints) {
            final fields = [
              DropdownButtonFormField<String>(
                initialValue: _level,
                decoration: const InputDecoration(labelText: 'Nivel'),
                items: [
                  for (final l in CourseLevel.all)
                    DropdownMenuItem(
                        value: l, child: Text(CourseLevel.label(l))),
                ],
                onChanged:
                    _saving ? null : (v) => setState(() => _level = v!),
              ),
              TextField(
                controller: _hours,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Duración estimada (horas)'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: const InputDecoration(labelText: 'Idioma'),
                items: [
                  for (final l in CourseLanguage.all)
                    DropdownMenuItem(
                        value: l, child: Text(CourseLanguage.label(l))),
                ],
                onChanged:
                    _saving ? null : (v) => setState(() => _language = v!),
              ),
            ];
            if (constraints.maxWidth < 620) {
              return Column(
                children: [
                  for (final field in fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: field,
                    ),
                ],
              );
            }
            return Row(
              children: [
                for (final (i, field) in fields.indexed) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: field),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _StatusRow(course: widget.course),
        const SizedBox(height: 20),
        _SaveButton(saving: _saving, onPressed: _save),
      ],
    );
  }
}

/// Estado del curso.
///
/// No es un campo más: publicar y archivar son acciones con sus propias reglas
/// —el servidor rechaza publicar un curso sin lecciones o con videos a medio
/// cargar, y dice cuáles— así que van por sus endpoints, no por el parcheo
/// general.
class _StatusRow extends StatefulWidget {
  final Course course;
  const _StatusRow({required this.course});

  @override
  State<_StatusRow> createState() => _StatusRowState();
}

class _StatusRowState extends State<_StatusRow> {
  bool _working = false;
  ApiException? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) setState(() => _working = false);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _working = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.read<DataProvider>();
    final course = widget.course;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Estado: ',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            StatusChip(
              label: course.statusLabel,
              color: switch (course.status) {
                CourseStatus.published => AppColors.statusGood,
                CourseStatus.archived => AppColors.statusSerious,
                _ => AppColors.gold,
              },
              icon: switch (course.status) {
                CourseStatus.published => Icons.check_circle_outline,
                CourseStatus.archived => Icons.archive_outlined,
                _ => Icons.edit_note,
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!course.isPublished)
              ElevatedButton.icon(
                icon: const Icon(Icons.publish_outlined, size: 18),
                label: const Text('Publicar'),
                onPressed: _working
                    ? null
                    : () => _run(() => data.publishCourse(course.id)),
              ),
            if (course.status != CourseStatus.archived)
              OutlinedButton.icon(
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: const Text('Archivar'),
                onPressed: _working
                    ? null
                    : () async {
                        final ok = await confirmDialog(
                          context,
                          'Archivar curso',
                          'Deja de asignarse a estudiantes nuevos, pero quienes '
                              'ya tienen avance no se bloquean.',
                        );
                        if (ok) await _run(() => data.archiveCourse(course.id));
                      },
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          ErrorBanner(_error!),
          if (_error is ConflictError) _publishBlockers(_error! as ConflictError),
        ],
      ],
    );
  }

  /// El 409 de publicar trae QUÉ falta. Mostrarlo es la mitad del valor del
  /// endpoint: "no se puede publicar" a secas obligaría a buscar a mano.
  Widget _publishBlockers(ConflictError error) {
    final lessons = error.details['lessons'];
    if (lessons is! List || lessons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lecciones a completar:',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          for (final lesson in lessons)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: AppColors.statusSerious),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lesson is Map
                          ? '${lesson['title'] ?? lesson}'
                          : '$lesson',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sección 2: Categorización, objetivos y prerrequisitos
// ---------------------------------------------------------------------------

class _CategorySection extends StatefulWidget {
  final Course course;
  const _CategorySection({required this.course});

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  late CourseMetaDraft _meta;
  bool _saving = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _meta = CourseMetaDraft.from(widget.course);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context
          .read<DataProvider>()
          .saveCourseMeta(widget.course.id, _meta);
      if (!mounted) return;
      setState(() => _saving = false);
      showSuccessCheck(context, 'Categorización guardada ✓');
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
    final data = context.watch<DataProvider>();
    final lab = widget.course.laboratoryName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null) ...[
          ErrorBanner(_error!),
          const SizedBox(height: 12),
        ],
        const SectionTitle('Laboratorio'),
        HoverCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.science_outlined, color: AppColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(lab ?? 'Sin laboratorio (curso especial)'),
              ),
            ],
          ),
        ),
        _chips(
          'Etiquetas',
          [for (final tag in courseTags) (tag, tag)],
          _meta.tags,
        ),
        // Competencias y ODS salen de la base, no de una lista copiada acá:
        // son claves ajenas y una etiqueta inventada la rechazaría el guardado.
        data.catalogs.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: CardListSkeleton(count: 2, height: 70),
          ),
          error: (e) => ErrorBanner(e),
          data: (catalogs) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _chips(
                'Competencias que desarrolla (métricas de impacto)',
                [for (final c in catalogs.competencies) (c.code, c.name)],
                _meta.competencies,
              ),
              _chips(
                'ODS relacionados',
                [
                  for (final o in catalogs.ods)
                    (o.code, 'ODS ${o.number}: ${o.title}')
                ],
                _meta.ods,
              ),
            ],
          ),
        ),
        _EditableList(
          title: 'Objetivos del curso',
          items: _meta.byCategory(null),
          hint: 'p. ej. Comprender los fundamentos de la IA aplicada',
          onAdd: (text) => _addObjective(null, text),
          onRemove: _removeObjective,
        ),
        const SectionTitle('Objetivos para la Ruta de Impacto'),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
              'Si este curso se vincula a un módulo de un laboratorio, estos '
              'objetivos se agregan automáticamente a los de esa fase.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
        _EditableList(
          title: 'Objetivos de Emprendimiento',
          items: _meta.byCategory('entrepreneurship'),
          hint: 'p. ej. Identificar oportunidades de IA en proyectos sociales',
          onAdd: (text) => _addObjective('entrepreneurship', text),
          onRemove: _removeObjective,
        ),
        _EditableList(
          title: 'Objetivos Empresariales',
          items: _meta.byCategory('business'),
          hint: 'p. ej. Comprender los fundamentos del aprendizaje automático',
          onAdd: (text) => _addObjective('business', text),
          onRemove: _removeObjective,
        ),
        _StringList(
          title: 'Resultados de aprendizaje',
          items: _meta.learningOutcomes,
          hint: 'p. ej. Construye un prototipo con datos reales',
          onChanged: () => setState(() {}),
        ),
        const SectionTitle('Prerrequisitos'),
        const Text(
          'Cursos que el estudiante debería completar antes (o ninguno).',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        data.courses.when(
          loading: () => const CardListSkeleton(count: 1, height: 60),
          error: (e) => ErrorBanner(e),
          data: (courses) {
            final others = courses
                .where((x) => x.id != widget.course.id && !x.isRutaExpo)
                .toList();
            if (others.isEmpty) {
              return const Text('No hay otros cursos disponibles.',
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 12.5));
            }
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final other in others)
                  FilterChip(
                    label: Text(other.name,
                        style: const TextStyle(fontSize: 12)),
                    selected: _meta.prerequisiteCourseIds.contains(other.id),
                    selectedColor: AppColors.gold.withValues(alpha: 0.25),
                    onSelected: _saving
                        ? null
                        : (sel) => setState(() => sel
                            ? _meta.prerequisiteCourseIds.add(other.id)
                            : _meta.prerequisiteCourseIds.remove(other.id)),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _SaveButton(saving: _saving, onPressed: _save),
      ],
    );
  }

  void _addObjective(String? category, String text) => setState(
      () => _meta.objectives.add(ObjectiveDraft(category: category, text: text)));

  void _removeObjective(ObjectiveDraft objective) =>
      setState(() => _meta.objectives.remove(objective));

  /// Fichas de selección múltiple sobre `(código, etiqueta)`: lo que se guarda
  /// es el código, lo que se lee es la etiqueta.
  Widget _chips(
    String title,
    List<(String, String)> catalog,
    List<String> selected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (code, label) in catalog)
              FilterChip(
                label: Text(label, style: const TextStyle(fontSize: 12)),
                selected: selected.contains(code),
                selectedColor: AppColors.gold.withValues(alpha: 0.25),
                onSelected: _saving
                    ? null
                    : (sel) => setState(
                        () => sel ? selected.add(code) : selected.remove(code)),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sección 3: Constructor (módulos y lecciones)
// ---------------------------------------------------------------------------

class _BuilderSection extends StatefulWidget {
  final Course course;
  const _BuilderSection({required this.course});

  @override
  State<_BuilderSection> createState() => _BuilderSectionState();
}

class _BuilderSectionState extends State<_BuilderSection> {
  bool _working = false;
  ApiException? _error;

  /// Toda acción estructural va al servidor en el momento. No hay botón de
  /// guardar acá: el orden de los módulos es una escritura transaccional
  /// (`unique(course_id, order_index)` hace que un intercambio de a uno falle
  /// en el primer paso), así que no tiene sentido acumularla.
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
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.read<DataProvider>();
    final course = widget.course;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            const SectionTitle('Constructor del curso'),
            ElevatedButton.icon(
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              label: const Text('Nuevo módulo'),
              onPressed: _working
                  ? null
                  : () async {
                      final title = await promptText(
                          context, 'Nuevo módulo', 'Título del módulo');
                      if (title == null || title.isEmpty) return;
                      await _run(() => data.createModule(course.id, title));
                    },
            ),
          ],
        ),
        const Text(
          'Arrastra con el ícono ⠿ para reordenar módulos y lecciones.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          ErrorBanner(_error!),
        ],
        const SizedBox(height: 12),
        if (course.modules.isEmpty)
          const EmptyState(
              icon: Icons.view_agenda_outlined,
              message: 'Crea el primer módulo para empezar.')
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: course.modules.length,
            // `onReorderItem`, no `onReorder`: el índice de destino ya viene
            // ajustado por el elemento que se sacó, así que no hace falta el
            // clásico `if (newIndex > oldIndex) newIndex--`.
            onReorderItem: (fromIndex, toIndex) {
              final ids = course.modules.map((m) => m.id).toList();
              ids.insert(toIndex, ids.removeAt(fromIndex));
              _run(() => data.reorderModules(course.id, ids));
            },
            itemBuilder: (context, mi) => _moduleCard(data, course, mi,
                key: ValueKey(course.modules[mi].id)),
          ),
      ],
    );
  }

  Widget _moduleCard(
    DataProvider data,
    Course course,
    int mi, {
    required Key key,
  }) {
    final module = course.modules[mi];
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: mi,
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_indicator,
                          color: AppColors.textMuted, size: 20),
                    ),
                  ),
                ),
                const Icon(Icons.folder_outlined,
                    color: AppColors.gold, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Módulo ${mi + 1}: ${module.title}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.gold,
                  tooltip: 'Renombrar módulo',
                  onPressed: _working
                      ? null
                      : () async {
                          final title = await promptText(context,
                              'Renombrar módulo', 'Título', module.title);
                          if (title == null || title.isEmpty) return;
                          await _run(() => data.renameModule(module.id, title,
                              courseId: course.id));
                        },
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  color: AppColors.gold,
                  tooltip: 'Agregar lección',
                  onPressed: _working
                      ? null
                      : () => showLessonEditor(context,
                          courseId: course.id, moduleId: module.id),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppColors.statusCritical,
                  tooltip: 'Eliminar módulo',
                  onPressed: _working
                      ? null
                      : () async {
                          final ok = await confirmDoubleDialog(
                            context,
                            'Eliminar módulo',
                            'Vas a eliminar "${module.title}" con sus '
                                '${module.lessons.length} lecciones.',
                          );
                          if (ok) {
                            await _run(() => data.deleteModule(module.id,
                                courseId: course.id));
                          }
                        },
                ),
              ],
            ),
          ),
          if (module.lessons.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(48, 4, 16, 12),
              child: Text('Sin lecciones — usa + para agregar contenido.',
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 12)),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 8, 8),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: module.lessons.length,
                onReorderItem: (fromIndex, toIndex) {
                  final ids = module.lessons.map((l) => l.id).toList();
                  ids.insert(toIndex, ids.removeAt(fromIndex));
                  _run(() => data.reorderLessons(module.id, ids,
                      courseId: course.id));
                },
                itemBuilder: (context, li) => _lessonRow(
                    data, course, module, li,
                    key: ValueKey(module.lessons[li].id)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lessonRow(
    DataProvider data,
    Course course,
    CourseModule module,
    int li, {
    required Key key,
  }) {
    final lesson = module.lessons[li];
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: li,
            child: const MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_indicator,
                    color: AppColors.textMuted, size: 16),
              ),
            ),
          ),
          Icon(lessonTypeIcon(lesson.type), size: 16, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${lesson.title}'
              '${lesson.durationMin > 0 ? ' · ${lesson.durationMin} min' : ''}',
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            color: AppColors.textSecondary,
            tooltip: 'Editar ${lessonTypeLabel(lesson.type).toLowerCase()}',
            onPressed: _working
                ? null
                : () => showLessonEditor(context,
                    courseId: course.id,
                    moduleId: module.id,
                    lesson: lesson),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            color: AppColors.statusCritical,
            tooltip: 'Eliminar lección',
            onPressed: _working
                ? null
                : () async {
                    final ok = await confirmDialog(context, 'Eliminar lección',
                        '¿Eliminar "${lesson.title}"?');
                    if (ok) {
                      await _run(() =>
                          data.deleteLesson(lesson.id, courseId: course.id));
                    }
                  },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sección 4: Evaluación y certificado
// ---------------------------------------------------------------------------

class _CertificateSection extends StatefulWidget {
  final Course course;
  const _CertificateSection({required this.course});

  @override
  State<_CertificateSection> createState() => _CertificateSectionState();
}

class _CertificateSectionState extends State<_CertificateSection> {
  late bool _generates;
  late final TextEditingController _certHours;
  bool _saving = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _generates = widget.course.generatesCertificate;
    _certHours =
        TextEditingController(text: widget.course.certifiedHours.toString());
  }

  @override
  void dispose() {
    _certHours.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<DataProvider>().updateCourse(widget.course.id, {
        'generatesCertificate': _generates,
        'certifiedHours': _generates ? (int.tryParse(_certHours.text) ?? 0) : 0,
      });
      if (!mounted) return;
      setState(() => _saving = false);
      showSuccessCheck(context, 'Guardado ✓');
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Certificado'),
        if (_error != null) ...[
          ErrorBanner(_error!),
          const SizedBox(height: 12),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('¿Este curso cuenta para certificado?'),
          subtitle: const Text(
              'Se ve un sello en el curso y sus horas cuentan para el '
              'certificado de la Ruta de Impacto del laboratorio (el PDF lo '
              'emite el LXD al completar toda la Ruta, no por curso '
              'individual)',
              style: TextStyle(fontSize: 12)),
          value: _generates,
          activeThumbColor: AppColors.gold,
          onChanged:
              _saving ? null : (v) => setState(() => _generates = v),
        ),
        if (_generates) ...[
          const SizedBox(height: 8),
          TextField(
              controller: _certHours,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Horas certificadas')),
        ],
        const SizedBox(height: 20),
        _SaveButton(saving: _saving, onPressed: _save),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sección 5: Restricciones y patrocinio
// ---------------------------------------------------------------------------

class _RestrictionsSection extends StatefulWidget {
  final Course course;
  const _RestrictionsSection({required this.course});

  @override
  State<_RestrictionsSection> createState() => _RestrictionsSectionState();
}

class _RestrictionsSectionState extends State<_RestrictionsSection> {
  late final TextEditingController _maxStudents;
  late bool _visible;
  String? _openDate;
  String? _closeDate;
  String? _sponsorId;

  bool _saving = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _maxStudents = TextEditingController(text: c.maxStudents.toString());
    _visible = c.visible;
    _openDate = c.openDate;
    _closeDate = c.closeDate;
    _sponsorId = c.sponsorCompanyId;
  }

  @override
  void dispose() {
    _maxStudents.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<DataProvider>().updateCourse(widget.course.id, {
        'maxStudents': int.tryParse(_maxStudents.text) ?? 0,
        'visible': _visible,
        'openDate': _openDate,
        'closeDate': _closeDate,
        'sponsorCompanyId': _sponsorId,
      });
      if (!mounted) return;
      setState(() => _saving = false);
      showSuccessCheck(context, 'Guardado ✓');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _pickDate({required bool isOpen}) async {
    final now = DateTime.now();
    final current = isOpen ? _openDate : _closeDate;
    final initial =
        current == null ? now : DateTime.tryParse(current) ?? now;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDate: initial,
    );
    if (picked == null || !mounted) return;
    // `date` en PostgreSQL: AAAA-MM-DD, sin hora ni zona.
    final value = DateFormat('yyyy-MM-dd').format(picked);
    setState(() {
      if (isOpen) {
        _openDate = value;
      } else {
        _closeDate = value;
      }
    });
  }

  String _fmt(String? iso) => iso == null
      ? 'Sin definir'
      : DateFormat('d MMM yyyy').format(DateTime.parse(iso));

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final invalidWindow = _openDate != null &&
        _closeDate != null &&
        _closeDate!.compareTo(_openDate!) < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Disponibilidad'),
        if (_error != null) ...[
          ErrorBanner(_error!),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _dateCard(
                icon: Icons.event_available,
                label: 'Apertura: ${_fmt(_openDate)}',
                onTap: () => _pickDate(isOpen: true),
                onClear:
                    _openDate == null ? null : () => setState(() => _openDate = null),
              ),
              _dateCard(
                icon: Icons.event_busy,
                label: 'Cierre: ${_fmt(_closeDate)}',
                onTap: () => _pickDate(isOpen: false),
                onClear: _closeDate == null
                    ? null
                    : () => setState(() => _closeDate = null),
              ),
            ];
            if (constraints.maxWidth < 520) {
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 10),
                  cards[1],
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ],
            );
          },
        ),
        if (invalidWindow)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('El curso no puede cerrar antes de abrir.',
                style:
                    TextStyle(fontSize: 12, color: AppColors.statusCritical)),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _maxStudents,
          enabled: !_saving,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Máximo de estudiantes (0 = sin límite)'),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_visible ? 'Visible' : 'Oculto'),
          subtitle: const Text(
              'Los cursos ocultos no aparecen para asignación',
              style: TextStyle(fontSize: 12)),
          value: _visible,
          activeThumbColor: AppColors.gold,
          onChanged: _saving ? null : (v) => setState(() => _visible = v),
        ),
        const SectionTitle('Patrocinio'),
        data.users(role: Roles.company).when(
              loading: () => const CardListSkeleton(count: 1, height: 60),
              error: (e) => ErrorBanner(e),
              data: (companies) => DropdownButtonFormField<String?>(
                initialValue:
                    companies.any((c) => c.id == _sponsorId) ? _sponsorId : null,
                decoration: const InputDecoration(
                    labelText: 'Empresa patrocinadora del curso (opcional)'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Ninguna')),
                  for (final company in companies)
                    DropdownMenuItem<String?>(
                      value: company.id,
                      child: Text(company.companyName.isEmpty
                          ? company.name
                          : company.companyName),
                    ),
                ],
                onChanged:
                    _saving ? null : (v) => setState(() => _sponsorId = v),
              ),
            ),
        const SizedBox(height: 10),
        const Text(
          'Las horas de formación completadas en cursos patrocinados '
          'alimentan las métricas de impacto de la empresa.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 20),
        _SaveButton(
            saving: _saving, onPressed: invalidWindow ? null : _save),
      ],
    );
  }

  Widget _dateCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return HoverCard(
      onTap: _saving ? null : onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          if (onClear != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 16),
              tooltip: 'Quitar fecha',
              onPressed: _saving ? null : onClear,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auxiliares
// ---------------------------------------------------------------------------

class _SaveButton extends StatelessWidget {
  final bool saving;
  final VoidCallback? onPressed;

  const _SaveButton({required this.saving, required this.onPressed});

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        icon: const Icon(Icons.save_outlined, size: 18),
        label: Text(saving ? 'Guardando…' : 'Guardar'),
        onPressed: saving ? null : onPressed,
      );
}

class _RailItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RailItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          // 48dp de alto mínimo: por debajo de eso el objetivo táctil queda
          // más chico de lo que una persona puede tocar con confianza.
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.12)
                : (hover ? Colors.white.withValues(alpha: 0.05) : null),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                  color: selected ? AppColors.gold : Colors.transparent,
                  width: 3),
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 18,
                  color:
                      selected ? AppColors.gold : AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color: selected
                            ? AppColors.gold
                            : AppColors.textSecondary,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista editable de objetivos, que llevan categoría además del texto.
class _EditableList extends StatelessWidget {
  final String title;
  final List<ObjectiveDraft> items;
  final String hint;
  final void Function(String text) onAdd;
  final void Function(ObjectiveDraft item) onRemove;

  const _EditableList({
    required this.title,
    required this.items,
    required this.hint,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 16, color: AppColors.gold),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(item.text,
                        style: const TextStyle(fontSize: 13.5))),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: AppColors.textMuted,
                  tooltip: 'Quitar',
                  onPressed: () => onRemove(item),
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Agregar'),
          onPressed: () async {
            final text = await promptText(context, title, hint);
            if (text != null && text.isNotEmpty) onAdd(text);
          },
        ),
      ],
    );
  }
}

/// Lista editable de textos sueltos (resultados de aprendizaje).
class _StringList extends StatelessWidget {
  final String title;
  final List<String> items;
  final String hint;
  final VoidCallback onChanged;

  const _StringList({
    required this.title,
    required this.items,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 16, color: AppColors.gold),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(items[i],
                        style: const TextStyle(fontSize: 13.5))),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: AppColors.textMuted,
                  tooltip: 'Quitar',
                  onPressed: () {
                    items.removeAt(i);
                    onChanged();
                  },
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Agregar'),
          onPressed: () async {
            final text = await promptText(context, title, hint);
            if (text != null && text.isNotEmpty) {
              items.add(text);
              onChanged();
            }
          },
        ),
      ],
    );
  }
}

/// Pide un texto corto. Adaptativo: en pantallas angostas ocupa toda la
/// pantalla, así el teclado no le tapa el campo.
Future<String?> promptText(
  BuildContext context,
  String title,
  String label, [
  String initial = '',
]) {
  final ctrl = TextEditingController(text: initial);
  return showAdaptiveFormDialog<String>(
    context: context,
    title: title,
    maxWidth: 420,
    contentBuilder: (ctx) => TextField(
      controller: ctrl,
      autofocus: true,
      decoration: InputDecoration(labelText: label),
      onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
    ),
    actionsBuilder: (ctx) => [
      TextButton(
          onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
      ElevatedButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Aceptar')),
    ],
  );
}
