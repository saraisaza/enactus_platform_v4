import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/async_value.dart';
import '../../utils/constants.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../widgets/file_upload_field.dart';
import '../../widgets/portal_shell.dart';
import '../lxd/course_editor_view.dart';
import '../shared/projects_directory_view.dart' show ProjectDetailView;
import 'lab_ruta_editor.dart';

/// Las pestañas de gestión del Admin: proyectos, equipos, laboratorios,
/// cursos y evidencias.
///
/// Todas comparten la misma forma: leen un `AsyncValue`, cubren sus tres
/// ramas y escriben por el endpoint que corresponde. Nada se calcula acá que
/// el servidor ya sepa.

// ---------------------------------------------------------------------------
// Proyectos
// ---------------------------------------------------------------------------

class AdminProjects extends StatelessWidget {
  const AdminProjects({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Proyectos',
      subtitle: 'Cada proyecto define problema, solución, comunidad, ODS, '
          'etapa e indicadores',
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nuevo proyecto'),
          onPressed: () => showProjectDialog(context, null),
        ),
      ],
      children: [
        data.projects.when(
          loading: () => const CardListSkeleton(count: 4, height: 120),
          error: (e) => ErrorState(e, onRetry: data.reloadProjects),
          data: (projects) => projects.isEmpty
              ? const EmptyState(
                  icon: Icons.lightbulb_outline, message: 'No hay proyectos.')
              : Column(
                  children: [
                    for (final p in projects)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ProjectCard(project: p),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final data = context.read<DataProvider>();

    return HoverCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          settings: RouteSettings(name: '${AppRoutes.projects}/${project.id}'),
          builder: (_) => ProjectDetailView(projectId: project.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(project.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis),
              ),
              StatusChip(
                label: project.stageLabel,
                color: AppColors.gold,
                icon: Icons.timeline_outlined,
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.gold,
                tooltip: 'Editar',
                onPressed: () => showProjectDialog(context, project),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.statusCritical,
                tooltip: 'Eliminar',
                onPressed: () async {
                  final ok = await confirmDoubleDialog(
                    context,
                    'Eliminar proyecto',
                    'Vas a eliminar "${project.name}".',
                  );
                  if (!ok || !context.mounted) return;
                  try {
                    await data.deleteProject(project.id);
                  } on ApiException catch (e) {
                    if (context.mounted) {
                      showAppSnack(context, e.message, error: true);
                    }
                  }
                },
              ),
            ],
          ),
          if (project.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(project.description,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (project.expoEnabled)
                const StatusChip(
                    label: 'National Expo',
                    color: AppColors.statusGood,
                    icon: Icons.emoji_events_outlined),
              if (project.teamSize > 0)
                StatusChip(
                    label: '${project.teamSize} integrantes',
                    color: AppColors.textSecondary,
                    icon: Icons.groups_outlined),
              for (final u in project.universities)
                StatusChip(
                    label: u,
                    color: AppColors.textSecondary,
                    icon: Icons.account_balance_outlined),
            ],
          ),
        ],
      ),
    );
  }
}

/// Crea o edita un proyecto. Devuelve `true` si se guardó.
Future<bool> showProjectDialog(BuildContext context, Project? project) async {
  final guardado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ProjectFormDialog(original: project),
  );
  return guardado ?? false;
}

class _ProjectFormDialog extends StatefulWidget {
  final Project? original;
  const _ProjectFormDialog({this.original});

  @override
  State<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<_ProjectFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _problem;
  late final TextEditingController _solution;
  late final TextEditingController _community;
  late final TextEditingController _indicators;

  late String _stage;
  late bool _expoEnabled;
  late Set<String> _ods;

  bool _saving = false;
  ApiException? _error;

  bool get _isNew => widget.original == null;

  @override
  void initState() {
    super.initState();
    final p = widget.original;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _problem = TextEditingController(text: p?.problem ?? '');
    _solution = TextEditingController(text: p?.solution ?? '');
    _community = TextEditingController(text: p?.community ?? '');
    _indicators = TextEditingController(text: p?.impactIndicators ?? '');
    _stage = p?.stage ?? ProjectStage.all.first;
    _expoEnabled = p?.expoEnabled ?? false;
    _ods = {...(p?.ods ?? const <String>[])};
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _problem,
      _solution,
      _community,
      _indicators,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() =>
          _error = const ValidationError('El proyecto necesita un nombre.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final campos = {
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'problem': _problem.text.trim(),
      'solution': _solution.text.trim(),
      'community': _community.text.trim(),
      // La etapa se guarda como identificador. Mandar la etiqueta en español
      // ("Prototipo") la rechaza el enum de PostgreSQL.
      'stage': _stage,
      'impactIndicators': _indicators.text.trim(),
      'expoEnabled': _expoEnabled,
      'ods': _ods.toList(),
    };

    try {
      final data = context.read<DataProvider>();
      if (_isNew) {
        await data.createProject(campos);
      } else {
        await data.updateProject(widget.original!.id, campos);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
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
      title: _isNew ? 'Nuevo proyecto' : 'Editar proyecto',
      maxWidth: 540,
      saving: _saving,
      onCancel: () => Navigator.pop(context, false),
      onSave: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          _campo(_name, 'Nombre'),
          const SizedBox(height: 12),
          _campo(_description, 'Descripción', maxLines: 2),
          const SizedBox(height: 12),
          _campo(_problem, 'Problema que resuelve', maxLines: 2),
          const SizedBox(height: 12),
          _campo(_solution, 'Solución propuesta', maxLines: 2),
          const SizedBox(height: 12),
          _campo(_community, 'Comunidad beneficiada'),
          const SizedBox(height: 12),
          _campo(_indicators, 'Indicadores de impacto'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _stage,
            decoration: const InputDecoration(labelText: 'Etapa actual'),
            items: [
              for (final s in ProjectStage.all)
                DropdownMenuItem(value: s, child: Text(ProjectStage.label(s))),
            ],
            onChanged: _saving ? null : (v) => setState(() => _stage = v!),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Habilitar RUTA NATIONAL EXPO',
                style: TextStyle(fontSize: 14)),
            subtitle: const Text(
                'Abre la checklist de preparación para el equipo.',
                style: TextStyle(fontSize: 12)),
            value: _expoEnabled,
            activeThumbColor: AppColors.gold,
            onChanged:
                _saving ? null : (v) => setState(() => _expoEnabled = v),
          ),
          const SectionTitle('ODS relacionados'),
          _OdsPicker(
            selected: _ods,
            enabled: !_saving,
            onChanged: (nuevos) => setState(() => _ods = nuevos),
          ),
        ],
      ),
    );
  }

  Widget _campo(TextEditingController c, String label, {int maxLines = 1}) =>
      TextField(
        controller: c,
        enabled: !_saving,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      );
}

/// Fichas de ODS desde el catálogo del servidor.
///
/// Lo que se guarda es el código (`ods_6`); lo que se lee, la etiqueta. La
/// lista sale de `/catalogs` y no de una constante copiada acá, porque son
/// claves ajenas: una etiqueta inventada la rechazaría el guardado.
class _OdsPicker extends StatelessWidget {
  final Set<String> selected;
  final bool enabled;
  final void Function(Set<String>) onChanged;

  const _OdsPicker({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return context.watch<DataProvider>().catalogs.when(
          loading: () => const CardListSkeleton(count: 1, height: 60),
          error: (e) => ErrorBanner(e),
          data: (catalogs) => Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final o in catalogs.ods)
                FilterChip(
                  label: Text('ODS ${o.number}',
                      style: const TextStyle(fontSize: 12)),
                  tooltip: o.title,
                  selected: selected.contains(o.code),
                  selectedColor: AppColors.gold.withValues(alpha: 0.25),
                  onSelected: !enabled
                      ? null
                      : (sel) => onChanged({
                            ...selected,
                            if (sel) o.code,
                          }..removeWhere((c) => !sel && c == o.code)),
                ),
            ],
          ),
        );
  }
}

// ---------------------------------------------------------------------------
// Equipos
// ---------------------------------------------------------------------------

class AdminGroups extends StatelessWidget {
  const AdminGroups({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Equipos',
      subtitle: 'Cada equipo trabaja un proyecto desde una universidad, con '
          'su asesor académico',
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nuevo equipo'),
          onPressed: () => showGroupDialog(context, null),
        ),
      ],
      children: [
        combine2(data.groups, data.projects).when(
          loading: () => const CardListSkeleton(count: 4, height: 96),
          error: (e) => ErrorState(e, onRetry: () async {
            await data.reloadGroups();
            await data.reloadProjects();
          }),
          data: (values) {
            final (groups, projects) = values;
            if (groups.isEmpty) {
              return const EmptyState(
                  icon: Icons.groups_outlined, message: 'No hay equipos.');
            }
            final porId = {for (final p in projects) p.id: p};
            return Column(
              children: [
                for (final g in groups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GroupCard(
                      group: g,
                      projectName: porId[g.projectId]?.name ?? '—',
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Group group;
  final String projectName;

  const _GroupCard({required this.group, required this.projectName});

  @override
  Widget build(BuildContext context) {
    final data = context.read<DataProvider>();

    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_outlined, color: AppColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    Text(
                      '$projectName'
                      '${group.university.isEmpty ? '' : ' · ${group.university}'}',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_alt_outlined, size: 18),
                color: AppColors.gold,
                tooltip: 'Integrantes',
                onPressed: () => showGroupMembersDialog(context, group),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.gold,
                tooltip: 'Editar',
                onPressed: () => showGroupDialog(context, group),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.statusCritical,
                tooltip: 'Eliminar',
                onPressed: () async {
                  final ok = await confirmDoubleDialog(context,
                      'Eliminar equipo', 'Vas a eliminar "${group.name}".');
                  if (!ok || !context.mounted) return;
                  try {
                    await data.deleteGroup(group.id);
                  } on ApiException catch (e) {
                    if (context.mounted) {
                      showAppSnack(context, e.message, error: true);
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<bool> showGroupDialog(BuildContext context, Group? group) async {
  final guardado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _GroupFormDialog(original: group),
  );
  return guardado ?? false;
}

class _GroupFormDialog extends StatefulWidget {
  final Group? original;
  const _GroupFormDialog({this.original});

  @override
  State<_GroupFormDialog> createState() => _GroupFormDialogState();
}

class _GroupFormDialogState extends State<_GroupFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _university;
  String? _projectId;
  String? _advisorId;

  bool _saving = false;
  ApiException? _error;

  bool get _isNew => widget.original == null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.original?.name ?? '');
    _university =
        TextEditingController(text: widget.original?.university ?? '');
    _projectId = widget.original?.projectId;
    _advisorId = widget.original?.advisorId;
  }

  @override
  void dispose() {
    _name.dispose();
    _university.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _projectId == null) {
      setState(() => _error = const ValidationError(
          'El equipo necesita un nombre y un proyecto.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final campos = {
      'name': _name.text.trim(),
      'projectId': _projectId,
      'university': _university.text.trim(),
      'advisorId': _advisorId,
    };

    try {
      final data = context.read<DataProvider>();
      if (_isNew) {
        await data.createGroup(campos);
      } else {
        await data.updateGroup(widget.original!.id, campos);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
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
      title: _isNew ? 'Nuevo equipo' : 'Editar equipo',
      maxWidth: 500,
      saving: _saving,
      onCancel: () => Navigator.pop(context, false),
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
            controller: _name,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Nombre del equipo'),
          ),
          const SizedBox(height: 12),
          data.projects.when(
            loading: () => const CardListSkeleton(count: 1, height: 56),
            error: (e) => ErrorBanner(e),
            data: (projects) => DropdownButtonFormField<String>(
              initialValue:
                  projects.any((p) => p.id == _projectId) ? _projectId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Proyecto'),
              items: [
                for (final p in projects)
                  DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged:
                  _saving ? null : (v) => setState(() => _projectId = v),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _university,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Universidad'),
          ),
          const SizedBox(height: 12),
          data.users(role: Roles.advisor).when(
                loading: () => const CardListSkeleton(count: 1, height: 56),
                error: (e) => ErrorBanner(e),
                data: (asesores) => DropdownButtonFormField<String?>(
                  initialValue: asesores.any((a) => a.id == _advisorId)
                      ? _advisorId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Asesor académico (opcional)',
                    helperText: 'El asesor acompaña al equipo, no al proyecto: '
                        'un proyecto puede tener equipos de varias '
                        'universidades.',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Sin asesor')),
                    for (final a in asesores)
                      DropdownMenuItem<String?>(
                          value: a.id,
                          child:
                              Text(a.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged:
                      _saving ? null : (v) => setState(() => _advisorId = v),
                ),
              ),
        ],
      ),
    );
  }
}

/// Integrantes del equipo, cada uno con su rol dentro del proyecto.
Future<void> showGroupMembersDialog(BuildContext context, Group group) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GroupMembersDialog(group: group),
    );

class _GroupMembersDialog extends StatefulWidget {
  final Group group;
  const _GroupMembersDialog({required this.group});

  @override
  State<_GroupMembersDialog> createState() => _GroupMembersDialogState();
}

class _GroupMembersDialogState extends State<_GroupMembersDialog> {
  /// `userId -> rol en el proyecto`.
  late Map<String, String> _members;
  bool _saving = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _members = {};
    // El detalle del equipo trae los integrantes; la tarjeta de la lista, no.
    final detalle = context.read<DataProvider>().groupById(widget.group.id);
    for (final m in detalle.valueOrNull?.members ?? const <ProjectMember>[]) {
      _members[m.userId] = m.roleInProject;
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<DataProvider>().setGroupMembers(
            widget.group.id,
            [
              for (final e in _members.entries)
                {'userId': e.key, 'roleInProject': e.value},
            ],
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
      title: 'Integrantes de ${widget.group.name}',
      maxWidth: 520,
      saving: _saving,
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      child: data.groupById(widget.group.id).when(
            loading: () => const CardListSkeleton(count: 3, height: 56),
            error: (e) => ErrorBanner(e),
            data: (_) => combine2(
              data.users(role: '${Roles.student},${Roles.alumni}'),
              data.groupById(widget.group.id),
            ).when(
              loading: () => const CardListSkeleton(count: 3, height: 56),
              error: (e) => ErrorBanner(e),
              data: (values) {
                final (estudiantes, _) = values;
                if (estudiantes.isEmpty) {
                  return const EmptyState(
                      icon: Icons.people_outline,
                      message: 'No hay estudiantes para asignar.');
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      ErrorBanner(_error!),
                      const SizedBox(height: 12),
                    ],
                    const Text(
                      'El rol dentro del proyecto no es el rol de la '
                      'plataforma: describe qué hace esa persona en el equipo.',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    for (final e in estudiantes)
                      _MemberRow(
                        user: e,
                        role: _members[e.id],
                        enabled: !_saving,
                        onChanged: (rol) => setState(() {
                          if (rol == null) {
                            _members.remove(e.id);
                          } else {
                            _members[e.id] = rol;
                          }
                        }),
                      ),
                  ],
                );
              },
            ),
          ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final AppUser user;
  final String? role;
  final bool enabled;
  final void Function(String?) onChanged;

  const _MemberRow({
    required this.user,
    required this.role,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Checkbox(
            value: role != null,
            activeColor: AppColors.gold,
            onChanged: !enabled
                ? null
                : (v) =>
                    onChanged(v == true ? ProjectMemberRole.all.last : null),
          ),
          Expanded(
            child: Text(user.name,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          if (role != null)
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                initialValue: role,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: [
                  for (final r in ProjectMemberRole.all)
                    DropdownMenuItem(
                        value: r,
                        child: Text(ProjectMemberRole.label(r),
                            style: const TextStyle(fontSize: 12))),
                ],
                onChanged: !enabled ? null : onChanged,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Laboratorios
// ---------------------------------------------------------------------------

class AdminLabs extends StatelessWidget {
  const AdminLabs({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Laboratorios',
      subtitle: 'Cada laboratorio tiene su Ruta de Impacto de tres fases',
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nuevo laboratorio'),
          onPressed: () => showLabDialog(context, null),
        ),
      ],
      children: [
        data.laboratories.when(
          loading: () => const CardListSkeleton(count: 4, height: 110),
          error: (e) => ErrorState(e, onRetry: data.reloadLaboratories),
          data: (labs) => labs.isEmpty
              ? const EmptyState(
                  icon: Icons.science_outlined,
                  message: 'No hay laboratorios.')
              : Column(
                  children: [
                    for (final lab in labs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LabCard(lab: lab),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _LabCard extends StatelessWidget {
  final Laboratory lab;
  const _LabCard({required this.lab});

  @override
  Widget build(BuildContext context) {
    final data = context.read<DataProvider>();

    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined, color: AppColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(lab.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: const Icon(Icons.route_outlined, size: 18),
                color: AppColors.gold,
                tooltip: 'Editar Ruta de Impacto',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => LabRutaEditorView(labId: lab.id)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.gold,
                tooltip: 'Editar',
                onPressed: () => showLabDialog(context, lab),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.statusCritical,
                tooltip: 'Eliminar',
                onPressed: () async {
                  final ok = await confirmDoubleDialog(
                    context,
                    'Eliminar laboratorio',
                    'Vas a eliminar "${lab.name}" con toda su Ruta.',
                  );
                  if (!ok || !context.mounted) return;
                  try {
                    await data.deleteLab(lab.id);
                  } on ApiException catch (e) {
                    // Con gente adentro el servidor lo bloquea y dice cuánta:
                    // borrarlo dejaría su avance apuntando a una Ruta que ya
                    // no existe.
                    if (context.mounted) {
                      showAppSnack(context, e.message, error: true);
                    }
                  }
                },
              ),
            ],
          ),
          if (lab.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(lab.description,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

Future<bool> showLabDialog(BuildContext context, Laboratory? lab) async {
  final guardado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LabFormDialog(original: lab),
  );
  return guardado ?? false;
}

class _LabFormDialog extends StatefulWidget {
  final Laboratory? original;
  const _LabFormDialog({this.original});

  @override
  State<_LabFormDialog> createState() => _LabFormDialogState();
}

class _LabFormDialogState extends State<_LabFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _objectives;
  String? _sponsorId;

  bool _saving = false;
  ApiException? _error;

  bool get _isNew => widget.original == null;

  @override
  void initState() {
    super.initState();
    final l = widget.original;
    _name = TextEditingController(text: l?.name ?? '');
    _description = TextEditingController(text: l?.description ?? '');
    _objectives = TextEditingController(text: l?.objectives ?? '');
    _sponsorId = l?.sponsorCompanyId;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _objectives.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error =
          const ValidationError('El laboratorio necesita un nombre.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final data = context.read<DataProvider>();
      if (_isNew) {
        await data.createLab(
          name: _name.text.trim(),
          description: _description.text.trim(),
          objectives: _objectives.text.trim(),
          sponsorCompanyId: _sponsorId,
        );
      } else {
        await data.updateLab(widget.original!.id, {
          'name': _name.text.trim(),
          'description': _description.text.trim(),
          'objectives': _objectives.text.trim(),
          'sponsorCompanyId': _sponsorId,
        });
      }
      if (!mounted) return;
      Navigator.pop(context, true);
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
      title: _isNew ? 'Nuevo laboratorio' : 'Editar laboratorio',
      maxWidth: 480,
      saving: _saving,
      onCancel: () => Navigator.pop(context, false),
      onSave: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          if (_isNew)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Se crea con sus tres fases. Después se editan desde el editor '
                'de Ruta de Impacto.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
            ),
          TextField(
            controller: _name,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            enabled: !_saving,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _objectives,
            enabled: !_saving,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Objetivos'),
          ),
          const SizedBox(height: 12),
          data.users(role: Roles.company).when(
                loading: () => const CardListSkeleton(count: 1, height: 56),
                error: (e) => ErrorBanner(e),
                data: (empresas) => DropdownButtonFormField<String?>(
                  initialValue: empresas.any((c) => c.id == _sponsorId)
                      ? _sponsorId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Empresa patrocinadora (opcional)'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Ninguna')),
                    for (final c in empresas)
                      DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(
                            c.companyName.isEmpty ? c.name : c.companyName,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged:
                      _saving ? null : (v) => setState(() => _sponsorId = v),
                ),
              ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cursos
// ---------------------------------------------------------------------------

class AdminCourses extends StatefulWidget {
  const AdminCourses({super.key});

  @override
  State<AdminCourses> createState() => _AdminCoursesState();
}

class _AdminCoursesState extends State<AdminCourses> {
  static const _todos = 'todos';
  String _filtro = _todos;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Cursos',
      subtitle: 'Todos los cursos de la plataforma, de cualquier LXD',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in [_todos, ...CourseStatus.all])
              ChoiceChip(
                label: Text(s == _todos ? 'Todos' : CourseStatus.label(s)),
                selected: _filtro == s,
                selectedColor: AppColors.gold.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => _filtro = s),
              ),
          ],
        ),
        const SizedBox(height: 16),
        data.coursesWithStats.when(
          loading: () => const CardListSkeleton(count: 4, height: 130),
          error: (e) => ErrorState(e, onRetry: data.reloadCoursesWithStats),
          data: (courses) {
            final visibles = _filtro == _todos
                ? courses
                : courses.where((c) => c.status == _filtro).toList();
            if (visibles.isEmpty) {
              return const EmptyState(
                  icon: Icons.video_library_outlined,
                  message: 'No hay cursos con ese estado.');
            }
            return Column(
              children: [
                for (final c in visibles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CourseCard(course: c),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final data = context.read<DataProvider>();
    final stats = course.stats;

    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(course.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis),
              ),
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
          const SizedBox(height: 6),
          Text(
            '${course.laboratoryName ?? 'Open Learning'} · '
            '${course.creatorName ?? 'sin autor'}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          if (stats != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                StatusChip(
                    label: '${stats.enrolled} inscritos',
                    color: AppColors.textSecondary,
                    icon: Icons.people_outline),
                StatusChip(
                    label: '${stats.completed} completaron',
                    color: AppColors.statusGood,
                    icon: Icons.verified_outlined),
                if (stats.pending > 0)
                  StatusChip(
                      label: '${stats.pending} sin calificar',
                      color: AppColors.statusSerious,
                      icon: Icons.pending_actions_outlined),
                if (course.linkedModule != null)
                  StatusChip(
                      label: 'Ruta: ${course.linkedModule}',
                      color: AppColors.gold,
                      icon: Icons.route_outlined),
              ],
            ),
          ],
          const SizedBox(height: 10),
          // `Wrap` y no `Row` con `Spacer`: con tres botones de texto largo
          // esta fila desbordaba siempre en pantallas angostas.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CourseEditorView(courseId: course.id)),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Eliminar'),
                onPressed: () async {
                  final ok = await confirmDoubleDialog(context,
                      'Eliminar curso', 'Vas a eliminar "${course.name}".');
                  if (!ok || !context.mounted) return;
                  try {
                    await data.deleteCourse(course.id);
                  } on ApiException catch (e) {
                    // Con estudiantes con avance el servidor lo bloquea y
                    // propone archivarlo: borrarlo dejaría su progreso
                    // huérfano y el objetivo de la fase trabado en silencio.
                    if (context.mounted) {
                      showAppSnack(context, e.message, error: true);
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Evidencias para donantes
// ---------------------------------------------------------------------------

class AdminEvidences extends StatelessWidget {
  const AdminEvidences({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Evidencias para Donantes',
      subtitle: 'Fotos, historias y reportes que ve cada donante en su portal',
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nueva evidencia'),
          onPressed: () => showEvidenceDialog(context, null),
        ),
      ],
      children: [
        data.evidences.when(
          loading: () => const CardListSkeleton(count: 3, height: 96),
          error: (e) => ErrorState(e, onRetry: data.reloadEvidences),
          data: (evidences) => evidences.isEmpty
              ? const EmptyState(
                  icon: Icons.volunteer_activism_outlined,
                  message: 'No hay evidencias todavía.')
              : Column(
                  children: [
                    for (final ev in evidences)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _EvidenceCard(evidence: ev),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  final Evidence evidence;
  const _EvidenceCard({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final data = context.read<DataProvider>();

    return HoverCard(
      child: Row(
        children: [
          const Icon(Icons.volunteer_activism_outlined,
              color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(evidence.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                if (evidence.description.isNotEmpty)
                  Text(evidence.description,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: AppColors.gold,
            tooltip: 'Editar',
            onPressed: () => showEvidenceDialog(context, evidence),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: AppColors.statusCritical,
            tooltip: 'Eliminar',
            onPressed: () async {
              final ok = await confirmDialog(context, 'Eliminar evidencia',
                  '¿Eliminar "${evidence.title}"?');
              if (!ok || !context.mounted) return;
              try {
                await data.deleteEvidence(evidence.id);
              } on ApiException catch (e) {
                if (context.mounted) {
                  showAppSnack(context, e.message, error: true);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

Future<bool> showEvidenceDialog(
  BuildContext context,
  Evidence? evidence,
) async {
  final guardado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _EvidenceFormDialog(original: evidence),
  );
  return guardado ?? false;
}

class _EvidenceFormDialog extends StatefulWidget {
  final Evidence? original;
  const _EvidenceFormDialog({this.original});

  @override
  State<_EvidenceFormDialog> createState() => _EvidenceFormDialogState();
}

class _EvidenceFormDialogState extends State<_EvidenceFormDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String _type;
  String? _donorId;
  final List<UploadedFile> _archivo = [];

  bool _saving = false;
  ApiException? _error;

  bool get _isNew => widget.original == null;

  @override
  void initState() {
    super.initState();
    final e = widget.original;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _type = e?.type ?? 'photo';
    _donorId = e?.donorId;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _donorId == null) {
      setState(() => _error = const ValidationError(
          'La evidencia necesita un título y un donante.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final campos = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'type': _type,
      'donorId': _donorId,
      if (_archivo.isNotEmpty) ...{
        's3Key': _archivo.first.s3Key,
        'fileName': _archivo.first.fileName,
        'contentType': _archivo.first.contentType,
        'sizeBytes': _archivo.first.sizeBytes,
      },
    };

    try {
      final data = context.read<DataProvider>();
      if (_isNew) {
        await data.createEvidence(campos);
      } else {
        await data.updateEvidence(widget.original!.id, campos);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
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
      title: _isNew ? 'Nueva evidencia' : 'Editar evidencia',
      maxWidth: 460,
      saving: _saving,
      onCancel: () => Navigator.pop(context, false),
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
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: [
              for (final t in const [
                'photo',
                'video',
                'testimonial',
                'report',
                'story'
              ])
                DropdownMenuItem(
                    value: t, child: Text(Evidence.typeLabel(t))),
            ],
            onChanged: _saving ? null : (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 12),
          data.users(role: Roles.donor).when(
                loading: () => const CardListSkeleton(count: 1, height: 56),
                error: (e) => ErrorBanner(e),
                data: (donantes) => DropdownButtonFormField<String>(
                  initialValue:
                      donantes.any((d) => d.id == _donorId) ? _donorId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Donante que la recibe',
                    helperText: 'Solo ese donante la ve en su portal.',
                  ),
                  items: [
                    for (final d in donantes)
                      DropdownMenuItem(
                          value: d.id,
                          child:
                              Text(d.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged:
                      _saving ? null : (v) => setState(() => _donorId = v),
                ),
              ),
          const SizedBox(height: 14),
          const Text('Archivo (opcional)',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          if (widget.original?.s3Key != null && _archivo.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Ya tiene un archivo. Subir otro lo reemplaza.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            ),
          FileUploadField(
            purpose: 'evidence',
            files: _archivo,
            enabled: !_saving,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}
