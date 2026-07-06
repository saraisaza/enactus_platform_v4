import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common.dart';
import 'lesson_editor.dart';

/// Constructor de cursos (LMS): información general, categorización,
/// contenido con drag & drop, certificado y restricciones.
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
  Course? _course;

  // Controladores de la sección 1
  late TextEditingController _name;
  late TextEditingController _subtitle;
  late TextEditingController _shortDesc;
  late TextEditingController _fullDesc;
  late TextEditingController _cover;
  late TextEditingController _introVideo;
  late TextEditingController _hours;
  // Sección 4
  late TextEditingController _certName;
  late TextEditingController _certHours;
  late TextEditingController _certSigner;
  // Sección 5
  late TextEditingController _maxStudents;

  @override
  void initState() {
    super.initState();
    final c = context.read<DataProvider>().courseById(widget.courseId);
    _course = c;
    _name = TextEditingController(text: c?.name ?? '');
    _subtitle = TextEditingController(text: c?.subtitle ?? '');
    _shortDesc = TextEditingController(text: c?.description ?? '');
    _fullDesc = TextEditingController(text: c?.fullDescription ?? '');
    _cover = TextEditingController(text: c?.coverImagePath ?? '');
    _introVideo = TextEditingController(text: c?.introVideoPath ?? '');
    _hours =
        TextEditingController(text: (c?.estimatedHours ?? 0).toString());
    _certName = TextEditingController(text: c?.certificateName ?? '');
    _certHours =
        TextEditingController(text: (c?.certifiedHours ?? 0).toString());
    _certSigner = TextEditingController(text: c?.certificateSigner ?? '');
    _maxStudents =
        TextEditingController(text: (c?.maxStudents ?? 0).toString());
  }

  Future<void> _save() async {
    final c = _course!;
    c.name = _name.text.trim();
    c.subtitle = _subtitle.text.trim();
    c.description = _shortDesc.text.trim();
    c.fullDescription = _fullDesc.text.trim();
    c.coverImagePath = _cover.text.trim();
    c.introVideoPath = _introVideo.text.trim();
    c.estimatedHours = int.tryParse(_hours.text) ?? 0;
    c.certificateName = _certName.text.trim();
    c.certifiedHours = int.tryParse(_certHours.text) ?? 0;
    c.certificateSigner = _certSigner.text.trim();
    c.maxStudents = int.tryParse(_maxStudents.text) ?? 0;
    await context.read<DataProvider>().saveCourse(c);
    if (mounted) showSuccessCheck(context, 'Curso guardado ✓');
  }

  /// Guardado silencioso tras cambios estructurales (módulos/lecciones).
  Future<void> _persistStructure() =>
      context.read<DataProvider>().saveCourse(_course!);

  @override
  Widget build(BuildContext context) {
    final course = _course;
    if (course == null) {
      return const Scaffold(
          body: Center(child: Text('Curso no encontrado')));
    }

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(portalTitle: 'Constructor de Curso'),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Rail de secciones
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
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
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
                      const SizedBox(height: 16),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: const Text('Guardar'),
                          onPressed: _save,
                        ),
                      ),
                    ],
                  ),
                ),
                // Contenido de la sección
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: switch (_section) {
                      0 => _generalSection(),
                      1 => _categorySection(),
                      2 => _builderSection(),
                      3 => _certificateSection(),
                      _ => _restrictionsSection(),
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Sección 1: Información general
  // ------------------------------------------------------------------
  Widget _generalSection() {
    final c = _course!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Información general'),
        TextField(
            controller: _name,
            decoration:
                const InputDecoration(labelText: 'Nombre del curso')),
        const SizedBox(height: 12),
        TextField(
            controller: _subtitle,
            decoration: const InputDecoration(labelText: 'Subtítulo')),
        const SizedBox(height: 12),
        TextField(
            controller: _shortDesc,
            maxLines: 2,
            decoration:
                const InputDecoration(labelText: 'Descripción corta')),
        const SizedBox(height: 12),
        TextField(
            controller: _fullDesc,
            maxLines: 4,
            decoration:
                const InputDecoration(labelText: 'Descripción completa')),
        const SizedBox(height: 12),
        TextField(
            controller: _cover,
            decoration: const InputDecoration(
                labelText: 'Imagen de portada',
                hintText: 'ruta en course_resources/ o URL')),
        const SizedBox(height: 12),
        TextField(
            controller: _introVideo,
            decoration: const InputDecoration(
                labelText: 'Video de presentación (opcional)',
                hintText: 'lab_x/curso_y/intro.mp4')),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: c.level,
                decoration: const InputDecoration(labelText: 'Nivel'),
                items: [
                  for (final l in courseLevels)
                    DropdownMenuItem(value: l, child: Text(l)),
                ],
                onChanged: (v) => setState(() => c.level = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _hours,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Duración estimada (horas)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: c.language,
                decoration: const InputDecoration(labelText: 'Idioma'),
                items: [
                  for (final l in courseLanguages)
                    DropdownMenuItem(value: l, child: Text(l)),
                ],
                onChanged: (v) => setState(() => c.language = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Estado',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final s in courseStatuses)
              ChoiceChip(
                label: Text(s),
                selected: c.status == s,
                selectedColor: switch (s) {
                  'Publicado' =>
                    AppColors.statusGood.withValues(alpha: 0.25),
                  'Archivado' =>
                    AppColors.statusSerious.withValues(alpha: 0.25),
                  _ => AppColors.gold.withValues(alpha: 0.25),
                },
                onSelected: (_) => setState(() => c.status = s),
              ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Sección 2: Categorización, objetivos y prerrequisitos
  // ------------------------------------------------------------------
  Widget _categorySection() {
    final c = _course!;
    final data = context.watch<DataProvider>();
    final lab = data.labById(c.labId);
    final otherCourses = data.courses
        .where((x) => x.id != c.id && !x.isRutaExpo)
        .toList();

    Widget chips(String title, List<String> catalog, List<String> selected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in catalog)
                FilterChip(
                  label:
                      Text(item, style: const TextStyle(fontSize: 12)),
                  selected: selected.contains(item),
                  selectedColor: AppColors.gold.withValues(alpha: 0.25),
                  onSelected: (sel) => setState(() =>
                      sel ? selected.add(item) : selected.remove(item)),
                ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Laboratorio'),
        HoverCard(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.science_outlined, color: AppColors.gold),
              const SizedBox(width: 10),
              Text(lab?.name ?? 'Sin laboratorio (curso especial)'),
            ],
          ),
        ),
        chips('Etiquetas', courseTags, c.tags),
        chips('Competencias que desarrolla (métricas de impacto)',
            enactusCompetencies, c.competencies),
        chips('ODS relacionados', odsList, c.ods),
        _EditableList(
          title: 'Objetivos del curso',
          items: c.objectives,
          hint: 'p. ej. Comprender los fundamentos de la IA aplicada',
          onChanged: () => setState(() {}),
        ),
        _EditableList(
          title: 'Resultados de aprendizaje',
          items: c.learningOutcomes,
          hint: 'p. ej. Construye un prototipo con datos reales',
          onChanged: () => setState(() {}),
        ),
        const SectionTitle('Prerrequisitos'),
        const Text(
          'Cursos que el estudiante debería completar antes (o ninguno).',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final other in otherCourses)
              FilterChip(
                label: Text(other.name,
                    style: const TextStyle(fontSize: 12)),
                selected: c.prerequisiteCourseIds.contains(other.id),
                selectedColor: AppColors.gold.withValues(alpha: 0.25),
                onSelected: (sel) => setState(() => sel
                    ? c.prerequisiteCourseIds.add(other.id)
                    : c.prerequisiteCourseIds.remove(other.id)),
              ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Sección 3: Constructor (módulos y lecciones con drag & drop)
  // ------------------------------------------------------------------
  Widget _builderSection() {
    final c = _course!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('Constructor del curso')),
            ElevatedButton.icon(
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              label: const Text('Nuevo módulo'),
              onPressed: () async {
                final title = await _promptText(
                    context, 'Nuevo módulo', 'Título del módulo');
                if (title == null || title.isEmpty) return;
                setState(() => c.modules.add(CourseModule(
                    id: context.read<DataProvider>().newId('mod'),
                    title: title)));
                await _persistStructure();
              },
            ),
          ],
        ),
        const Text(
          'Arrastra con el ícono ⠿ para reordenar módulos y lecciones.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        if (c.modules.isEmpty)
          const EmptyState(
              icon: Icons.view_agenda_outlined,
              message: 'Crea el primer módulo para empezar.')
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: c.modules.length,
            onReorder: (oldIndex, newIndex) async {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final m = c.modules.removeAt(oldIndex);
                c.modules.insert(newIndex, m);
              });
              await _persistStructure();
            },
            itemBuilder: (context, mi) =>
                _moduleCard(c, mi, key: ValueKey(c.modules[mi].id)),
          ),
      ],
    );
  }

  Widget _moduleCard(Course c, int mi, {required Key key}) {
    final module = c.modules[mi];
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
          // Encabezado del módulo
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
                      style:
                          const TextStyle(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.gold,
                  tooltip: 'Renombrar módulo',
                  onPressed: () async {
                    final title = await _promptText(context,
                        'Renombrar módulo', 'Título', module.title);
                    if (title == null || title.isEmpty) return;
                    setState(() => module.title = title);
                    await _persistStructure();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  color: AppColors.gold,
                  tooltip: 'Agregar lección',
                  onPressed: () => _addLesson(module),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppColors.statusCritical,
                  tooltip: 'Eliminar módulo',
                  onPressed: () async {
                    if (await confirmDoubleDialog(
                        context,
                        'Eliminar módulo',
                        'Vas a eliminar "${module.title}" con sus '
                        '${module.lessons.length} lecciones.')) {
                      setState(() => c.modules.removeAt(mi));
                      await _persistStructure();
                    }
                  },
                ),
              ],
            ),
          ),
          // Lecciones (reordenables dentro del módulo)
          if (module.lessons.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(48, 4, 16, 12),
              child: Text('Sin lecciones — usa + para agregar contenido.',
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 12)),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 4, 8, 8),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: module.lessons.length,
                onReorder: (oldIndex, newIndex) async {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final l = module.lessons.removeAt(oldIndex);
                    module.lessons.insert(newIndex, l);
                  });
                  await _persistStructure();
                },
                itemBuilder: (context, li) => _lessonRow(module, li,
                    key: ValueKey(module.lessons[li].id)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lessonRow(CourseModule module, int li, {required Key key}) {
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
          Icon(lessonTypeIcon(lesson.type),
              size: 16, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${lesson.title}'
              '${lesson.durationMin > 0 ? ' · ${lesson.durationMin} min' : ''}',
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(lessonTypeLabel(lesson.type),
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11)),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            color: AppColors.textSecondary,
            tooltip: 'Editar lección',
            onPressed: () async {
              final updated =
                  await showLessonEditor(context, lesson: lesson);
              if (updated != null) {
                setState(() => module.lessons[li] = updated);
                await _persistStructure();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            color: AppColors.statusCritical,
            tooltip: 'Eliminar lección',
            onPressed: () async {
              if (await confirmDialog(context, 'Eliminar lección',
                  '¿Eliminar "${lesson.title}"?')) {
                setState(() => module.lessons.removeAt(li));
                await _persistStructure();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addLesson(CourseModule module) async {
    final lesson = await showLessonEditor(context);
    if (lesson != null) {
      setState(() => module.lessons.add(lesson));
      await _persistStructure();
    }
  }

  // ------------------------------------------------------------------
  // Sección 4: Evaluación y certificado
  // ------------------------------------------------------------------
  Widget _certificateSection() {
    final c = _course!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Certificado'),
        SwitchListTile(
          title: const Text('¿Este curso genera certificado?'),
          subtitle: const Text(
              'Al completarlo, el mentor podrá emitir el certificado en PDF',
              style: TextStyle(fontSize: 12)),
          value: c.generatesCertificate,
          activeThumbColor: AppColors.gold,
          onChanged: (v) => setState(() => c.generatesCertificate = v),
        ),
        if (c.generatesCertificate) ...[
          const SizedBox(height: 8),
          TextField(
              controller: _certName,
              decoration: const InputDecoration(
                  labelText: 'Nombre del certificado',
                  hintText:
                      'p. ej. Certificado en Fundamentos de IA Social')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                    controller: _certHours,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Horas certificadas')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                    controller: _certSigner,
                    decoration: const InputDecoration(
                        labelText: 'Firmante (por defecto: el mentor)')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'El certificado incluye automáticamente el logo de Enactus '
            'Colombia y un código único de verificación.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------------
  // Sección 5: Restricciones y patrocinio
  // ------------------------------------------------------------------
  Widget _restrictionsSection() {
    final c = _course!;
    final data = context.watch<DataProvider>();
    final companies = data.usersByRole(Roles.company);

    Future<void> pickDate(bool isOpen) async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 3),
        initialDate: now,
      );
      if (picked != null) {
        setState(() {
          if (isOpen) {
            c.openDate = picked.toIso8601String();
          } else {
            c.closeDate = picked.toIso8601String();
          }
        });
      }
    }

    String fmt(String iso) => iso.isEmpty
        ? 'Sin definir'
        : DateFormat('d MMM yyyy').format(DateTime.parse(iso));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Disponibilidad'),
        Row(
          children: [
            Expanded(
              child: HoverCard(
                onTap: () => pickDate(true),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.event_available,
                        color: AppColors.gold, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                        child:
                            Text('Apertura: ${fmt(c.openDate)}')),
                    if (c.openDate.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () =>
                            setState(() => c.openDate = ''),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HoverCard(
                onTap: () => pickDate(false),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.event_busy,
                        color: AppColors.gold, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text('Cierre: ${fmt(c.closeDate)}')),
                    if (c.closeDate.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () =>
                            setState(() => c.closeDate = ''),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _maxStudents,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Máximo de estudiantes (0 = sin límite)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SwitchListTile(
                title: Text(c.visible ? 'Visible' : 'Oculto'),
                subtitle: const Text(
                    'Los cursos ocultos no aparecen para asignación',
                    style: TextStyle(fontSize: 12)),
                value: c.visible,
                activeThumbColor: AppColors.gold,
                onChanged: (v) => setState(() => c.visible = v),
              ),
            ),
          ],
        ),
        const SectionTitle('Patrocinio'),
        DropdownButtonFormField<String>(
          initialValue:
              c.sponsorCompanyId.isEmpty ? null : c.sponsorCompanyId,
          decoration: const InputDecoration(
              labelText: 'Empresa patrocinadora del curso (opcional)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Ninguna')),
            for (final comp in companies)
              DropdownMenuItem(
                  value: comp.id, child: Text(comp.companyName)),
          ],
          onChanged: (v) =>
              setState(() => c.sponsorCompanyId = v ?? ''),
        ),
        const SizedBox(height: 10),
        const Text(
          'Las horas de formación completadas en cursos patrocinados '
          'alimentan las métricas de impacto de la empresa.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Auxiliares
// ---------------------------------------------------------------------------

class _RailItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _RailItem(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                  color: selected
                      ? AppColors.gold
                      : AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color: selected
                            ? AppColors.gold
                            : AppColors.textSecondary,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista editable de textos (objetivos, resultados de aprendizaje).
class _EditableList extends StatelessWidget {
  final String title;
  final List<String> items;
  final String hint;
  final VoidCallback onChanged;
  const _EditableList(
      {required this.title,
      required this.items,
      required this.hint,
      required this.onChanged});

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
                    child:
                        Text(items[i], style: const TextStyle(fontSize: 13.5))),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: AppColors.textMuted,
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
            final text = await _promptText(context, title, hint);
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

Future<String?> _promptText(BuildContext context, String title, String label,
    [String initial = '']) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar')),
        ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Aceptar')),
      ],
    ),
  );
}
