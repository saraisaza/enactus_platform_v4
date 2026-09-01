import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/app_header.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../lxd/course_editor_view.dart' show promptText;

/// Editor de la Ruta de Impacto de un laboratorio.
///
/// Es la pantalla donde un error no da error: deja la Ruta trabada. Por eso
/// **el servidor sostiene las invariantes y esta pantalla las explica** en vez
/// de intentar imponerlas por su cuenta:
///
/// - Las fases son siempre tres. Se editan; no se agregan ni se borran.
/// - El módulo de mentoría es el último de su fase, y se recalcula solo.
/// - Un objetivo sin cursos **no se completa nunca** y traba la fase entera.
///   La pantalla lo marca en rojo; el servidor lo permite, porque a medio
///   armar es un estado legítimo.
/// - Un curso vive en un módulo por Ruta: en dos, su avance se contaría doble.
class LabRutaEditorView extends StatelessWidget {
  final String labId;
  const LabRutaEditorView({super.key, required this.labId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(portalTitle: 'Ruta de Impacto'),
          Expanded(
            child: data.labById(labId).when(
                  loading: () => const Center(child: BrandLoader()),
                  error: (e) =>
                      ErrorState(e, onRetry: () => data.reloadLab(labId)),
                  data: (lab) => _Body(lab: lab),
                ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Laboratory lab;
  const _Body({required this.lab});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: AppColors.gold,
                tooltip: 'Volver',
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lab.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 18),
                        overflow: TextOverflow.ellipsis),
                    Text('Versión de contenido ${lab.contentVersion}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Los certificados quedan anclados a la versión de contenido con la '
            'que se emitieron: agregar módulos después no invalida los que ya '
            'se entregaron.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          _StaffSection(lab: lab),
          const SizedBox(height: 8),
          for (final phase in lab.phases)
            _PhaseCard(lab: lab, phase: phase),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Personal y estudiantes del laboratorio
// ---------------------------------------------------------------------------

class _StaffSection extends StatelessWidget {
  final Laboratory lab;
  const _StaffSection({required this.lab});

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quiénes lo acompañan',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in lab.mentors)
                StatusChip(
                    label: m.name,
                    color: AppColors.gold,
                    icon: Icons.psychology_outlined),
              for (final l in lab.lxds)
                StatusChip(
                    label: l.name,
                    color: AppColors.textSecondary,
                    icon: Icons.design_services_outlined),
              if (lab.mentors.isEmpty && lab.lxds.isEmpty)
                const Text('Todavía sin mentores ni LXD.',
                    style:
                        TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.psychology_outlined, size: 16),
                label: const Text('Mentores'),
                onPressed: () => _asignar(
                  context,
                  titulo: 'Mentores de ${lab.name}',
                  role: Roles.mentor,
                  actuales: lab.mentors.map((m) => m.id).toSet(),
                  ayuda: 'Un laboratorio puede tener varios mentores, y todos '
                      'ven a sus estudiantes.',
                  onGuardar: (ids) => context
                      .read<DataProvider>()
                      .setLabMentors(lab.id, ids),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.school_outlined, size: 16),
                label: Text('Estudiantes (${lab.studentsAssigned})'),
                onPressed: () => _asignarEstudiantes(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _asignarEstudiantes(BuildContext context) async {
    final data = context.read<DataProvider>();
    // El detalle no trae la lista de estudiantes, solo cuántos son: se piden
    // filtrados por laboratorio, que es una consulta del servidor.
    final asignados = data.users(laboratoryId: lab.id).valueOrNull;
    if (!context.mounted) return;

    await _asignar(
      context,
      titulo: 'Estudiantes de ${lab.name}',
      role: '${Roles.student},${Roles.alumni}',
      actuales: (asignados ?? const <AppUser>[]).map((u) => u.id).toSet(),
      ayuda: 'Asignar a alguien acá le da acceso a los CURSOS del '
          'laboratorio. Quitarlo se lo quita: su avance no se borra, pero '
          'deja de verlo. Solo estudiantes eduXaction.',
      onGuardar: (ids) => data.setLabStudents(lab.id, ids),
    );
  }
}

Future<void> _asignar(
  BuildContext context, {
  required String titulo,
  required String role,
  required Set<String> actuales,
  required String ayuda,
  required Future<void> Function(List<String>) onGuardar,
}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AssignDialog(
        titulo: titulo,
        role: role,
        actuales: actuales,
        ayuda: ayuda,
        onGuardar: onGuardar,
      ),
    );

class _AssignDialog extends StatefulWidget {
  final String titulo;
  final String role;
  final Set<String> actuales;
  final String ayuda;
  final Future<void> Function(List<String>) onGuardar;

  const _AssignDialog({
    required this.titulo,
    required this.role,
    required this.actuales,
    required this.ayuda,
    required this.onGuardar,
  });

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  late Set<String> _seleccion;
  bool _saving = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _seleccion = {...widget.actuales};
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onGuardar(_seleccion.toList());
      if (!mounted) return;
      Navigator.pop(context);
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

    return AdaptiveFormShell(
      title: widget.titulo,
      maxWidth: 480,
      saving: _saving,
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      child: data.users(role: widget.role).when(
            loading: () => const CardListSkeleton(count: 4, height: 48),
            error: (e) => ErrorBanner(e),
            data: (personas) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ...[
                  ErrorBanner(_error!),
                  const SizedBox(height: 12),
                ],
                Text(widget.ayuda,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textMuted)),
                const SizedBox(height: 12),
                if (personas.isEmpty)
                  const Text('No hay cuentas disponibles.',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted))
                else
                  for (final p in personas)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.gold,
                      title: Text(p.name,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                      subtitle: p.university.isEmpty
                          ? null
                          : Text(p.university,
                              style: const TextStyle(fontSize: 11.5)),
                      value: _seleccion.contains(p.id),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => v == true
                              ? _seleccion.add(p.id)
                              : _seleccion.remove(p.id)),
                    ),
              ],
            ),
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Una fase
// ---------------------------------------------------------------------------

class _PhaseCard extends StatelessWidget {
  final Laboratory lab;
  final Phase phase;

  const _PhaseCard({required this.lab, required this.phase});

  @override
  Widget build(BuildContext context) {
    final data = context.read<DataProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        phase.title.isEmpty
                            ? 'Fase ${phase.orderIndex}'
                            : phase.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      if (phase.deadline != null)
                        Text(
                          'Fecha límite: '
                          '${DateFormat('d MMM yyyy').format(phase.deadlineDate!)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.gold,
                  tooltip: 'Editar la fase',
                  onPressed: () => _editarFase(context),
                ),
              ],
            ),
          ),
          if (phase.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(phase.description,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ),
          const Divider(height: 1, color: AppColors.border),
          _ObjectivesSection(lab: lab, phase: phase),
          const Divider(height: 1, color: AppColors.border),
          _ModulesSection(lab: lab, phase: phase, data: data),
        ],
      ),
    );
  }

  Future<void> _editarFase(BuildContext context) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PhaseFormDialog(lab: lab, phase: phase),
      );
}

class _PhaseFormDialog extends StatefulWidget {
  final Laboratory lab;
  final Phase phase;

  const _PhaseFormDialog({required this.lab, required this.phase});

  @override
  State<_PhaseFormDialog> createState() => _PhaseFormDialogState();
}

class _PhaseFormDialogState extends State<_PhaseFormDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  String? _deadline;

  bool _saving = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.phase.title);
    _description = TextEditingController(text: widget.phase.description);
    _deadline = widget.phase.deadline;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<DataProvider>().updatePhase(
        widget.phase.id,
        {
          'title': _title.text.trim(),
          'description': _description.text.trim(),
          'deadline': _deadline,
        },
        labId: widget.lab.id,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final actual =
        _deadline == null ? now : DateTime.tryParse(_deadline!) ?? now;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDate: actual,
    );
    if (picked != null && mounted) {
      // La API espera AAAA-MM-DD: la columna es `date`, sin hora.
      setState(() => _deadline = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveFormShell(
      title: 'Fase ${widget.phase.orderIndex}',
      maxWidth: 460,
      saving: _saving,
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          const Text(
            'Las fases son siempre tres: se editan, no se agregan ni se '
            'borran. Una Ruta con dos fases no se puede completar.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            enabled: !_saving,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Descripción'),
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
                    _deadline == null
                        ? 'Fecha límite: sin definir'
                        : 'Fecha límite: '
                            '${DateFormat('d MMM yyyy').format(DateTime.parse(_deadline!))}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (_deadline != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 14),
                    tooltip: 'Quitar fecha',
                    onPressed:
                        _saving ? null : () => setState(() => _deadline = null),
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
// Objetivos de la fase
// ---------------------------------------------------------------------------

class _ObjectivesSection extends StatelessWidget {
  final Laboratory lab;
  final Phase phase;

  const _ObjectivesSection({required this.lab, required this.phase});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Text('Objetivos',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Objetivo'),
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => _ObjectiveFormDialog(lab: lab, phase: phase),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (phase.objectives.isEmpty)
            const Text('Sin objetivos todavía.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted))
          else
            for (final o in phase.objectives)
              _ObjectiveRow(lab: lab, phase: phase, objective: o),
        ],
      ),
    );
  }
}

class _ObjectiveRow extends StatelessWidget {
  final Laboratory lab;
  final Phase phase;
  final Objective objective;

  const _ObjectiveRow({
    required this.lab,
    required this.phase,
    required this.objective,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.read<DataProvider>();
    final trabado = objective.neverCompletable;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                trabado
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                size: 16,
                color:
                    trabado ? AppColors.statusCritical : AppColors.gold,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(objective.text,
                    style: const TextStyle(fontSize: 13.5)),
              ),
              StatusChip(
                label: ObjectiveCategory.label(objective.category),
                color: AppColors.textSecondary,
                icon: Icons.category_outlined,
              ),
              IconButton(
                icon: const Icon(Icons.link, size: 16),
                color: AppColors.gold,
                tooltip: 'Cursos que lo cumplen',
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) =>
                      _ObjectiveCoursesDialog(lab: lab, objective: objective),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                color: AppColors.textSecondary,
                tooltip: 'Editar',
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => _ObjectiveFormDialog(
                      lab: lab, phase: phase, original: objective),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                color: AppColors.statusCritical,
                tooltip: 'Quitar',
                onPressed: () async {
                  final ok = await confirmDialog(context, 'Quitar objetivo',
                      '¿Quitar "${objective.text}" de la fase?');
                  if (!ok || !context.mounted) return;
                  await data.deleteObjective(objective.id, labId: lab.id);
                },
              ),
            ],
          ),
          if (trabado)
            const Padding(
              padding: EdgeInsets.only(left: 24, top: 2),
              child: Text(
                'Sin cursos vinculados no se puede completar nunca, y eso '
                'traba la fase entera para todo el laboratorio.',
                style:
                    TextStyle(fontSize: 11.5, color: AppColors.statusCritical),
              ),
            ),
        ],
      ),
    );
  }
}

class _ObjectiveFormDialog extends StatefulWidget {
  final Laboratory lab;
  final Phase phase;
  final Objective? original;

  const _ObjectiveFormDialog({
    required this.lab,
    required this.phase,
    this.original,
  });

  @override
  State<_ObjectiveFormDialog> createState() => _ObjectiveFormDialogState();
}

class _ObjectiveFormDialogState extends State<_ObjectiveFormDialog> {
  late final TextEditingController _text;
  late String _category;
  bool _saving = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.original?.text ?? '');
    _category =
        widget.original?.category ?? ObjectiveCategory.entrepreneurship;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty) {
      setState(() =>
          _error = const ValidationError('El objetivo necesita su texto.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = context.read<DataProvider>();
      if (widget.original == null) {
        await data.createObjective(
          widget.phase.id,
          category: _category,
          text: _text.text.trim(),
          labId: widget.lab.id,
        );
      } else {
        await data.updateObjective(
          widget.original!.id,
          {'category': _category, 'text': _text.text.trim()},
          labId: widget.lab.id,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
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
    return AdaptiveFormShell(
      title: widget.original == null ? 'Nuevo objetivo' : 'Editar objetivo',
      maxWidth: 480,
      saving: _saving,
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _text,
            enabled: !_saving,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Objetivo'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: [
              for (final c in ObjectiveCategory.all)
                DropdownMenuItem(
                    value: c, child: Text(ObjectiveCategory.label(c))),
            ],
            onChanged: _saving ? null : (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 10),
          const Text(
            'Después hay que vincularle los cursos que lo cumplen: sin ellos '
            'no se completa nunca.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ObjectiveCoursesDialog extends StatefulWidget {
  final Laboratory lab;
  final Objective objective;

  const _ObjectiveCoursesDialog({required this.lab, required this.objective});

  @override
  State<_ObjectiveCoursesDialog> createState() =>
      _ObjectiveCoursesDialogState();
}

class _ObjectiveCoursesDialogState extends State<_ObjectiveCoursesDialog> {
  late Set<String> _seleccion;
  bool _saving = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _seleccion = {...widget.objective.courseIds};
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<DataProvider>().setObjectiveCourses(
            widget.objective.id,
            _seleccion.toList(),
            labId: widget.lab.id,
          );
      if (!mounted) return;
      Navigator.pop(context);
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

    return AdaptiveFormShell(
      title: 'Cursos que cumplen el objetivo',
      maxWidth: 520,
      saving: _saving,
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      child: data.courses.when(
        loading: () => const CardListSkeleton(count: 4, height: 48),
        error: (e) => ErrorBanner(e),
        data: (courses) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              ErrorBanner(_error!),
              const SizedBox(height: 12),
            ],
            Text(
              '"${widget.objective.text}" se da por cumplido cuando el '
              'estudiante termina el 100% de TODOS los cursos marcados.',
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textMuted),
            ),
            if (_seleccion.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Sin ninguno marcado, este objetivo no se completa nunca.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.statusCritical),
                ),
              ),
            const SizedBox(height: 12),
            for (final c in courses.where((c) => !c.isRutaExpo))
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.gold,
                title: Text(c.name,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(c.laboratoryName ?? 'Open Learning',
                    style: const TextStyle(fontSize: 11.5)),
                value: _seleccion.contains(c.id),
                onChanged: _saving
                    ? null
                    : (v) => setState(() => v == true
                        ? _seleccion.add(c.id)
                        : _seleccion.remove(c.id)),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Módulos de la fase
// ---------------------------------------------------------------------------

class _ModulesSection extends StatelessWidget {
  final Laboratory lab;
  final Phase phase;
  final DataProvider data;

  const _ModulesSection({
    required this.lab,
    required this.phase,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Text('Módulos',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Módulo'),
                onPressed: () async {
                  final titulo = await promptText(
                      context, 'Nuevo módulo', 'Título del módulo');
                  if (titulo == null || titulo.isEmpty || !context.mounted) {
                    return;
                  }
                  try {
                    await data.createRutaModule(phase.id, titulo,
                        labId: lab.id);
                  } on ApiException catch (e) {
                    if (context.mounted) {
                      showAppSnack(context, e.message, error: true);
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'El último módulo de la fase es siempre el de mentoría. Se '
            'recalcula solo al agregar, quitar o reordenar.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          if (phase.modules.isEmpty)
            const Text('Sin módulos todavía.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted))
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: phase.modules.length,
              onReorderItem: (fromIndex, toIndex) {
                final ids = phase.modules.map((m) => m.id).toList();
                ids.insert(toIndex, ids.removeAt(fromIndex));
                data.reorderRutaModules(phase.id, ids, labId: lab.id);
              },
              itemBuilder: (context, i) => _ModuleRow(
                key: ValueKey(phase.modules[i].id),
                lab: lab,
                module: phase.modules[i],
                index: i,
              ),
            ),
        ],
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  final Laboratory lab;
  final RutaModule module;
  final int index;

  const _ModuleRow({
    super.key,
    required this.lab,
    required this.module,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.read<DataProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_indicator,
                        color: AppColors.textMuted, size: 16),
                  ),
                ),
              ),
              Icon(
                module.isMentorshipModule
                    ? Icons.groups_outlined
                    : Icons.folder_outlined,
                size: 16,
                color: AppColors.gold,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${index + 1}. ${module.title}',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (module.isMentorshipModule)
                const StatusChip(
                    label: 'Mentoría',
                    color: AppColors.gold,
                    icon: Icons.psychology_outlined),
              IconButton(
                icon: const Icon(Icons.link, size: 16),
                color: AppColors.gold,
                tooltip: 'Cursos del módulo',
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) =>
                      _ModuleCoursesDialog(lab: lab, module: module),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                color: AppColors.textSecondary,
                tooltip: 'Renombrar',
                onPressed: () async {
                  final titulo = await promptText(
                      context, 'Renombrar módulo', 'Título', module.title);
                  if (titulo == null || titulo.isEmpty || !context.mounted) {
                    return;
                  }
                  await data.renameRutaModule(module.id, titulo,
                      labId: lab.id);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16),
                color: AppColors.statusCritical,
                tooltip: 'Eliminar módulo',
                onPressed: () async {
                  final ok = await confirmDoubleDialog(
                    context,
                    'Eliminar módulo',
                    'Vas a eliminar "${module.title}" con sus '
                        '${module.ownLessons.length} lecciones propias.',
                  );
                  if (!ok || !context.mounted) return;
                  await data.deleteRutaModule(module.id, labId: lab.id);
                },
              ),
            ],
          ),
          if (module.courseIds.isNotEmpty || module.ownLessons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 8, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (module.courseIds.isNotEmpty)
                    StatusChip(
                        label: '${module.courseIds.length} cursos',
                        color: AppColors.textSecondary,
                        icon: Icons.video_library_outlined),
                  for (final l in module.ownLessons)
                    StatusChip(
                        label: l.title,
                        color: AppColors.textSecondary,
                        icon: Icons.article_outlined),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ModuleCoursesDialog extends StatefulWidget {
  final Laboratory lab;
  final RutaModule module;

  const _ModuleCoursesDialog({required this.lab, required this.module});

  @override
  State<_ModuleCoursesDialog> createState() => _ModuleCoursesDialogState();
}

class _ModuleCoursesDialogState extends State<_ModuleCoursesDialog> {
  late Set<String> _seleccion;
  bool _saving = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _seleccion = {...widget.module.courseIds};
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final importados =
          await context.read<DataProvider>().setRutaModuleCourses(
                widget.module.id,
                _seleccion.toList(),
                labId: widget.lab.id,
              );
      if (!mounted) return;
      Navigator.pop(context);
      // Los objetivos aparecen solos al vincular un curso: decirlo evita que
      // parezcan salidos de la nada.
      if (importados > 0) {
        showAppSnack(
          context,
          'Se agregaron $importados objetivos del curso a la fase.',
        );
      }
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

    return AdaptiveFormShell(
      title: 'Cursos de ${widget.module.title}',
      maxWidth: 520,
      saving: _saving,
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      child: data.courses.when(
        loading: () => const CardListSkeleton(count: 4, height: 48),
        error: (e) => ErrorBanner(e),
        data: (courses) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              ErrorBanner(_error!),
              const SizedBox(height: 12),
            ],
            const Text(
              'Un curso vive en un solo módulo de esta Ruta: en dos, su avance '
              'se contaría dos veces. Al vincularlo, sus objetivos '
              'categorizados se agregan a la fase.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            for (final c in courses.where((c) => !c.isRutaExpo))
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.gold,
                title: Text(c.name,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(c.laboratoryName ?? 'Open Learning',
                    style: const TextStyle(fontSize: 11.5)),
                value: _seleccion.contains(c.id),
                onChanged: _saving
                    ? null
                    : (v) => setState(() => v == true
                        ? _seleccion.add(c.id)
                        : _seleccion.remove(c.id)),
              ),
          ],
        ),
      ),
    );
  }
}
