import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/textos.dart';
import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/async_value.dart';
import '../../utils/constants.dart';
import '../../utils/formatos.dart';
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
          AppHeader(portalTitle: tr.rutaDeImpacto),
          Expanded(
            child: data.labById(labId).when(
                  loading: () => const Center(child: BrandLoader()),
                  error: (e) =>
                      ErrorState(e, onRetry: () => data.reloadLab(labId)),
                  data: (lab) => AvisoEscritorio(
                    herramienta: tr.rutaEditorHerramienta,
                    child: _Body(lab: lab),
                  ),
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
                tooltip: tr.comunVolver,
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
                    Text(tr.rutaEditorVersion(lab.contentVersion),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tr.rutaEditorVersionTexto,
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
          Text(tr.rutaEditorAcompanan,
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
                Text(tr.rutaEditorSinMentores,
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
                label: Text(tr.labMentores),
                onPressed: () => _asignar(
                  context,
                  titulo: tr.rutaEditorMentoresDe(lab.name),
                  role: Roles.mentor,
                  actuales: (_) =>
                      AsyncValue.data(lab.mentors.map((m) => m.id).toSet()),
                  ayuda: tr.rutaEditorMentoresAyuda,
                  onGuardar: (ids) => context
                      .read<DataProvider>()
                      .setLabMentors(lab.id, ids),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.school_outlined, size: 16),
                label: Text(tr.rutaEditorEstudiantesCantidad(lab.studentsAssigned)),
                onPressed: () => _asignarEstudiantes(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _asignarEstudiantes(BuildContext context) {
    final data = context.read<DataProvider>();
    return _asignar(
      context,
      titulo: tr.rutaEditorEstudiantesDe(lab.name),
      role: '${Roles.student},${Roles.alumni}',
      // El detalle no trae la lista de estudiantes, solo cuántos son: se
      // piden filtrados por laboratorio, que es una consulta del servidor. El
      // diálogo espera esa respuesta antes de dejar marcar o guardar.
      actuales: (d) => d
          .users(laboratoryId: lab.id)
          .map((us) => us.map((u) => u.id).toSet()),
      ayuda: tr.rutaEditorEstudiantesAyuda,
      onGuardar: (ids) => data.setLabStudents(lab.id, ids),
    );
  }
}

/// [actuales] es una consulta y no un conjunto ya resuelto a propósito.
///
/// Antes se leía una sola vez, al abrir: si la lista del laboratorio todavía
/// no había llegado del servidor, el diálogo empezaba con todo desmarcado. Y
/// como guardar REEMPLAZA la lista completa, marcar a una persona y guardar
/// dejaba el laboratorio solo con ella: quitaba a todos los demás.
Future<void> _asignar(
  BuildContext context, {
  required String titulo,
  required String role,
  required AsyncValue<Set<String>> Function(DataProvider data) actuales,
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
  final AsyncValue<Set<String>> Function(DataProvider data) actuales;
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
  /// `null` hasta que llegan las personas Y quiénes están asignadas hoy. Ver
  /// [_asignar] para lo que pasaba cuando se llenaba antes de tiempo.
  Set<String>? _seleccion;
  bool _saving = false;
  ApiException? _error;

  Future<void> _save() async {
    final seleccion = _seleccion;
    if (seleccion == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onGuardar(seleccion.toList());
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
    final estado =
        combine2(data.users(role: widget.role), widget.actuales(data));
    // Se fija una sola vez, recién con los dos datos: lo que la persona marque
    // después no se pisa con cada notificación del provider.
    if (_seleccion == null) {
      if (estado.valueOrNull case (_, final asignados)) {
        _seleccion = {...asignados};
      }
    }
    final seleccion = _seleccion;

    return AdaptiveFormShell(
      title: widget.titulo,
      maxWidth: 480,
      saving: _saving,
      onCancel: () => Navigator.pop(context),
      onSave: seleccion == null ? null : _save,
      child: estado.when(
            loading: () => const CardListSkeleton(count: 4, height: 48),
            error: (e) => ErrorBanner(e),
            data: (valores) => Column(
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
                if (valores.$1.isEmpty)
                  Text(tr.rutaEditorSinCuentas,
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted))
                else
                  for (final p in valores.$1)
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
                      value: seleccion?.contains(p.id) ?? false,
                      onChanged: _saving || seleccion == null
                          ? null
                          : (v) => setState(() => v == true
                              ? seleccion.add(p.id)
                              : seleccion.remove(p.id)),
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
                            ? tr.rutaFaseNumero(phase.orderIndex)
                            : phase.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      if (phase.deadline != null)
                        Text(
                          tr.labFechaLimite(fechaCorta(phase.deadlineDate!)),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.gold,
                  tooltip: tr.rutaEditorEditarFase,
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
      title: tr.rutaFaseNumero(widget.phase.orderIndex),
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
          Text(
            tr.rutaEditorFasesTres,
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            enabled: !_saving,
            decoration: InputDecoration(labelText: tr.comunTitulo),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            enabled: !_saving,
            maxLines: 3,
            decoration: InputDecoration(labelText: tr.comunDescripcion),
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
                        ? tr.leccionFechaSinDefinir
                        : tr.labFechaLimite(fechaCorta(DateTime.parse(_deadline!))),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (_deadline != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 14),
                    tooltip: tr.constructorQuitarFecha,
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
              Text(tr.cursoObjetivos,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(tr.rutaEditorObjetivo),
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
            Text(tr.rutaEditorSinObjetivos,
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
                tooltip: tr.rutaEditorCursosCumplen,
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
                tooltip: tr.comunEditar,
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
                tooltip: tr.comunQuitar,
                onPressed: () async {
                  final ok = await confirmDialog(context, tr.rutaEditorQuitarObjetivo,
                      tr.rutaEditorQuitarObjetivoTexto(objective.text));
                  if (!ok || !context.mounted) return;
                  await data.deleteObjective(objective.id, labId: lab.id);
                },
              ),
            ],
          ),
          if (trabado)
            Padding(
              padding: EdgeInsets.only(left: 24, top: 2),
              child: Text(
                tr.rutaEditorSinCursosTraba,
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
          _error = ValidationError(tr.rutaEditorObjetivoTexto));
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
      title: widget.original == null ? tr.rutaEditorNuevoObjetivo : tr.rutaEditorEditarObjetivo,
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
            decoration: InputDecoration(labelText: tr.rutaEditorObjetivo),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _category,
            decoration: InputDecoration(labelText: tr.rutaEditorCategoria),
            items: [
              for (final c in ObjectiveCategory.all)
                DropdownMenuItem(
                    value: c, child: Text(ObjectiveCategory.label(c))),
            ],
            onChanged: _saving ? null : (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 10),
          Text(
            tr.rutaEditorVincular,
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
      title: tr.rutaEditorCursosCumplenTitulo,
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
              tr.rutaEditorCumplido(widget.objective.text),
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textMuted),
            ),
            if (_seleccion.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  tr.rutaEditorSinMarcados,
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
              Text(tr.rutaEditorModulos,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(tr.rutaModulo),
                onPressed: () async {
                  final titulo = await promptText(
                      context, tr.constructorNuevoModulo, tr.constructorTituloModulo);
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
          Text(
            tr.rutaEditorUltimoMentoria,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          if (phase.modules.isEmpty)
            Text(tr.rutaEditorSinModulos,
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
                StatusChip(
                    label: tr.eventoMentoria,
                    color: AppColors.gold,
                    icon: Icons.psychology_outlined),
              IconButton(
                icon: const Icon(Icons.link, size: 16),
                color: AppColors.gold,
                tooltip: tr.rutaEditorCursosModulo,
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
                tooltip: tr.rutaEditorRenombrar,
                onPressed: () async {
                  final titulo = await promptText(
                      context, tr.constructorRenombrarModulo, tr.comunTitulo, module.title);
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
                tooltip: tr.constructorEliminarModulo,
                onPressed: () async {
                  final ok = await confirmDoubleDialog(
                    context,
                    tr.constructorEliminarModulo,
                    tr.rutaEditorEliminarModuloTexto(module.title, module.ownLessons.length),
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
                        label: tr.rutaEditorCursosCantidad(module.courseIds.length),
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
          tr.rutaEditorImportados(importados),
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
      title: tr.rutaEditorCursosDe(widget.module.title),
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
              tr.rutaEditorCursoUnModulo,
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
