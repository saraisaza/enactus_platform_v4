import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import 'admin_backup.dart';
import 'admin_management.dart';

/// Portal de administración. [isSuperAdmin] habilita las funciones
/// exclusivas del Super Admin (gestión de laboratorios y de admins).
class AdminPortal extends StatelessWidget {
  final bool isSuperAdmin;
  const AdminPortal({super.key, this.isSuperAdmin = false});

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      portalTitle: isSuperAdmin ? 'Portal Super Admin' : 'Portal Admin',
      tabs: [
        PortalTab(
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            builder: (_) => const AdminDashboard()),
        PortalTab(
            label: 'Usuarios',
            icon: Icons.manage_accounts_outlined,
            builder: (_) => AdminUsers(isSuperAdmin: isSuperAdmin)),
        PortalTab(
            label: 'Proyectos',
            icon: Icons.lightbulb_outline,
            builder: (_) => const AdminProjects()),
        PortalTab(
            label: 'Grupos',
            icon: Icons.groups_outlined,
            builder: (_) => const AdminGroups()),
        PortalTab(
            label: 'Asignaciones',
            icon: Icons.assignment_ind_outlined,
            builder: (_) => const AdminAssignments()),
        if (isSuperAdmin)
          PortalTab(
              label: 'Laboratorios',
              icon: Icons.science_outlined,
              builder: (_) => const AdminLabs()),
        PortalTab(
            label: 'Evidencias donantes',
            icon: Icons.volunteer_activism_outlined,
            builder: (_) => const AdminEvidences()),
        PortalTab(
            label: 'Contenido página',
            icon: Icons.web_outlined,
            builder: (_) => const AdminSiteContent()),
        PortalTab(
            label: 'Datos y respaldos',
            icon: Icons.storage_outlined,
            builder: (_) => const AdminBackup()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final students = data.usersByRole(Roles.student);
    final universities = students.map((s) => s.university).toSet()
      ..remove('');

    return TabBody(
      title: 'Dashboard General',
      subtitle: 'Estado global de la plataforma',
      children: [
        StatRow(tiles: [
          StatTile(
              value: '${students.length}',
              label: 'Estudiantes',
              icon: Icons.school_outlined),
          StatTile(
              value: '${data.projects.length}',
              label: 'Proyectos',
              icon: Icons.lightbulb_outline),
          StatTile(
              value: '${data.groups.length}',
              label: 'Equipos',
              icon: Icons.groups_outlined),
          StatTile(
              value: '${data.courses.length}',
              label: 'Cursos',
              icon: Icons.video_library_outlined),
          StatTile(
              value: '${data.certificates.length}',
              label: 'Certificados emitidos',
              icon: Icons.workspace_premium_outlined),
          StatTile(
              value: '${universities.length}',
              label: 'Universidades',
              icon: Icons.account_balance_outlined),
          StatTile(
              value: '${data.usersByRole(Roles.mentor).length}',
              label: 'Mentores',
              icon: Icons.psychology_outlined),
          StatTile(
              value: '${data.labs.length}',
              label: 'Laboratorios',
              icon: Icons.science_outlined),
        ]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 900;
          final byRole = ChartCard(
            title: 'Usuarios por rol',
            child: SimpleBarChart(
              maxY: (data.users.length.toDouble() * 0.8).clamp(5, 999),
              data: [
                (
                  label: 'Estud.',
                  value: students.length.toDouble(),
                ),
                (
                  label: 'Mentores',
                  value: data.usersByRole(Roles.mentor).length.toDouble()
                ),
                (
                  label: 'Asesores',
                  value: data.usersByRole(Roles.advisor).length.toDouble()
                ),
                (
                  label: 'Empresas',
                  value: data.usersByRole(Roles.company).length.toDouble()
                ),
                (
                  label: 'Donantes',
                  value: data.usersByRole(Roles.donor).length.toDouble()
                ),
              ],
            ),
          );
          final byStage = ChartCard(
            title: 'Proyectos por etapa',
            child: DonutChart(
              data: [
                for (final stage in projectStages)
                  if (data.projects.any((p) => p.stage == stage))
                    (
                      label: stage,
                      value: data.projects
                          .where((p) => p.stage == stage)
                          .length
                          .toDouble()
                    ),
              ],
            ),
          );
          return wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: Entrance(delayMs: 250, child: byRole)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Entrance(delayMs: 350, child: byStage)),
                  ],
                )
              : Column(children: [
                  Entrance(delayMs: 250, child: byRole),
                  const SizedBox(height: 12),
                  Entrance(delayMs: 350, child: byStage),
                ]);
        }),
        const SectionTitle('Impacto formativo Enactus'),
        const _ImpactMetrics(),
      ],
    );
  }
}

/// Métricas que diferencian la plataforma de un LMS convencional:
/// horas de formación por competencia, cobertura de ODS y patrocinio.
class _ImpactMetrics extends StatelessWidget {
  const _ImpactMetrics();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final byCompetency = data.hoursByCompetency().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final odsRates = data.odsCompletionRate().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sponsored = data.sponsoredHoursByCompany();

    if (byCompetency.isEmpty && odsRates.isEmpty && sponsored.isEmpty) {
      return const EmptyState(
          icon: Icons.insights_outlined,
          message:
              'Configura competencias, ODS y horas en los cursos (constructor '
              'del mentor) para ver métricas de impacto formativo.');
    }

    return Column(
      children: [
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 900;
          final hoursChart = ChartCard(
            title: 'Horas de formación por competencia',
            height: 220,
            child: byCompetency.isEmpty
                ? const EmptyState(
                    icon: Icons.school_outlined, message: 'Sin datos aún')
                : SimpleBarChart(
                    maxY: (byCompetency.first.value.toDouble() * 1.3)
                        .clamp(5, 99999),
                    data: [
                      for (final e in byCompetency.take(6))
                        (label: _shorten(e.key), value: e.value.toDouble()),
                    ],
                  ),
          );
          final odsCard = Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cobertura de ODS (estudiantes que completaron)',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                if (odsRates.isEmpty)
                  const Text('Sin cursos asociados a ODS aún',
                      style: TextStyle(color: AppColors.textMuted))
                else
                  for (final e in odsRates.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: Text(e.key.split(':').first,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ),
                          Expanded(
                              child: ThinProgressBar(
                                  value: e.value, tooltip: e.key)),
                        ],
                      ),
                    ),
              ],
            ),
          );
          return wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: hoursChart),
                    const SizedBox(width: 12),
                    Expanded(child: odsCard),
                  ],
                )
              : Column(children: [
                  hoursChart,
                  const SizedBox(height: 12),
                  odsCard,
                ]);
        }),
        if (sponsored.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final e in sponsored.entries)
                  HoverCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.business_outlined,
                            color: AppColors.gold, size: 20),
                        const SizedBox(width: 10),
                        Text(
                            '${e.key} ha patrocinado ${e.value} horas de formación',
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _shorten(String s) =>
      s.length <= 12 ? s : '${s.substring(0, 11)}…';
}

// ---------------------------------------------------------------------------
// Gestión de usuarios
// ---------------------------------------------------------------------------

class AdminUsers extends StatefulWidget {
  final bool isSuperAdmin;
  const AdminUsers({super.key, required this.isSuperAdmin});

  @override
  State<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> {
  String _roleFilter = 'todos';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    var users = data.users;
    if (_roleFilter != 'todos') {
      users = users.where((u) => u.role == _roleFilter).toList();
    }

    // Roles que este portal puede crear
    final creatableRoles = [
      if (widget.isSuperAdmin) Roles.admin,
      Roles.student,
      Roles.mentor,
      Roles.advisor,
      Roles.company,
      Roles.donor,
    ];

    return TabBody(
      title: 'Usuarios',
      subtitle: widget.isSuperAdmin
          ? 'Crea y elimina cualquier tipo de cuenta (incluidos admins)'
          : 'Crea cuentas de estudiantes, mentores, asesores, empresas y donantes',
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('Nuevo usuario'),
          onPressed: () =>
              showUserDialog(context, null, creatableRoles),
        ),
      ],
      children: [
        // Filtro por rol
        Wrap(
          spacing: 8,
          children: [
            for (final r in ['todos', ...Roles.all])
              ChoiceChip(
                label: Text(r == 'todos' ? 'Todos' : Roles.label(r)),
                selected: _roleFilter == r,
                selectedColor: AppColors.gold.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => _roleFilter = r),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Nombre')),
                DataColumn(label: Text('Correo')),
                DataColumn(label: Text('Rol')),
                DataColumn(label: Text('Detalle')),
                DataColumn(label: Text('Acciones')),
              ],
              rows: [
                for (final u in users)
                  DataRow(
                    // La fila se ilumina al pasar el mouse
                    color: WidgetStateProperty.resolveWith((states) =>
                        states.contains(WidgetState.hovered)
                            ? AppColors.gold.withValues(alpha: 0.06)
                            : null),
                    cells: [
                      DataCell(Text(u.name)),
                      DataCell(Text(u.email)),
                      DataCell(Text(Roles.label(u.role))),
                      DataCell(Text(_detail(data, u))),
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon:
                                const Icon(Icons.edit_outlined, size: 18),
                            color: AppColors.gold,
                            tooltip: 'Editar',
                            onPressed: u.role == Roles.superAdmin
                                ? null
                                : () => showUserDialog(
                                    context, u, creatableRoles),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18),
                            color: AppColors.statusCritical,
                            tooltip: 'Eliminar',
                            onPressed: !_canDelete(u)
                                ? null
                                : () async {
                                    // Doble verificación: hay que escribir
                                    // ELIMINAR para confirmar.
                                    if (await confirmDoubleDialog(
                                        context,
                                        'Eliminar usuario',
                                        'Vas a eliminar a ${u.name} '
                                        '(${Roles.label(u.role)}).')) {
                                      await data.deleteUser(u.id);
                                    }
                                  },
                          ),
                        ],
                      )),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Nadie elimina Super Admins; solo el Super Admin elimina admins.
  bool _canDelete(AppUser u) {
    if (u.role == Roles.superAdmin) return false;
    if (u.role == Roles.admin) return widget.isSuperAdmin;
    return true;
  }

  String _detail(DataProvider data, AppUser u) => switch (u.role) {
        Roles.student => u.university,
        Roles.mentor => data.labById(u.labId)?.name ?? '',
        Roles.advisor => u.university,
        Roles.company => data.labById(u.sponsoredLabId)?.name ?? '',
        Roles.donor => u.impactCode,
        _ => '',
      };
}

/// Diálogo de creación/edición de usuario con campos según el rol.
Future<void> showUserDialog(
    BuildContext context, AppUser? user, List<String> creatableRoles) async {
  final data = context.read<DataProvider>();
  final auth = context.read<AuthProvider>();
  final nameCtrl = TextEditingController(text: user?.name ?? '');
  final emailCtrl = TextEditingController(text: user?.email ?? '');
  final passCtrl = TextEditingController(text: user?.password ?? '');
  final phoneCtrl = TextEditingController(text: user?.phone ?? '');
  final cedulaCtrl = TextEditingController(text: user?.cedula ?? '');
  final universityCtrl =
      TextEditingController(text: user?.university ?? '');
  final careerCtrl = TextEditingController(text: user?.career ?? '');
  final companyCtrl = TextEditingController(
      text: user?.role == Roles.mentor
          ? (user?.extra['company'] as String? ?? '')
          : (user?.companyName ?? ''));
  final positionCtrl =
      TextEditingController(text: user?.extra['position'] as String? ?? '');
  final specialtyCtrl =
      TextEditingController(text: user?.extra['specialty'] as String? ?? '');
  final languagesCtrl =
      TextEditingController(text: user?.extra['languages'] as String? ?? '');
  final availabilityCtrl = TextEditingController(
      text: user?.extra['availability'] as String? ?? '');
  final experienceCtrl = TextEditingController(
      text: user?.extra['experience'] as String? ?? '');
  final interestsCtrl =
      TextEditingController(text: user?.extra['interests'] as String? ?? '');
  final impactCodeCtrl = TextEditingController(
      text: user?.impactCode ??
          'ENACTUS-${DateTime.now().year}-${1000 + DateTime.now().millisecond * 9}');
  var role = user?.role ?? creatableRoles.first;
  String? labId = user?.labId ?? user?.sponsoredLabId;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(user == null ? 'Nuevo usuario' : 'Editar usuario',
            style: const TextStyle(fontSize: 18)),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user == null)
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items: [
                      for (final r in creatableRoles)
                        DropdownMenuItem(
                            value: r, child: Text(Roles.label(r))),
                    ],
                    onChanged: (v) => setState(() => role = v!),
                  ),
                const SizedBox(height: 12),
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nombre completo')),
                const SizedBox(height: 12),
                TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Correo electrónico')),
                const SizedBox(height: 12),
                TextField(
                    controller: passCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Contraseña')),
                const SizedBox(height: 12),
                TextField(
                    controller: phoneCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Teléfono')),
                // Campos según el rol
                if (role == Roles.student) ...[
                  const SizedBox(height: 12),
                  TextField(
                      controller: cedulaCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Cédula')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: universityCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Universidad')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: careerCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Carrera')),
                ],
                if (role == Roles.mentor) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: labId,
                    decoration:
                        const InputDecoration(labelText: 'Laboratorio'),
                    items: [
                      for (final l in data.labs)
                        DropdownMenuItem(value: l.id, child: Text(l.name)),
                    ],
                    onChanged: (v) => setState(() => labId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                      controller: companyCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Empresa')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: positionCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Cargo')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: specialtyCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Especialidad')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: languagesCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Idiomas')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: availabilityCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Disponibilidad')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: experienceCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Experiencia')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: interestsCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Intereses')),
                ],
                if (role == Roles.advisor) ...[
                  const SizedBox(height: 12),
                  TextField(
                      controller: universityCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Universidad')),
                ],
                if (role == Roles.company) ...[
                  const SizedBox(height: 12),
                  TextField(
                      controller: companyCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Nombre de la empresa')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: labId,
                    decoration: const InputDecoration(
                        labelText: 'Laboratorio patrocinado (opcional)'),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('Ninguno')),
                      for (final l in data.labs)
                        DropdownMenuItem(value: l.id, child: Text(l.name)),
                    ],
                    onChanged: (v) => setState(() => labId = v),
                  ),
                ],
                if (role == Roles.donor) ...[
                  const SizedBox(height: 12),
                  TextField(
                      controller: impactCodeCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Código de impacto único')),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty ||
                  emailCtrl.text.trim().isEmpty ||
                  passCtrl.text.isEmpty) {
                return;
              }
              final extra =
                  Map<String, dynamic>.from(user?.extra ?? {});
              switch (role) {
                case Roles.student:
                  extra['university'] = universityCtrl.text.trim();
                  extra['career'] = careerCtrl.text.trim();
                case Roles.mentor:
                  extra['labId'] = labId;
                  extra['company'] = companyCtrl.text.trim();
                  extra['position'] = positionCtrl.text.trim();
                  extra['specialty'] = specialtyCtrl.text.trim();
                  extra['languages'] = languagesCtrl.text.trim();
                  extra['availability'] = availabilityCtrl.text.trim();
                  extra['experience'] = experienceCtrl.text.trim();
                  extra['interests'] = interestsCtrl.text.trim();
                case Roles.advisor:
                  extra['university'] = universityCtrl.text.trim();
                case Roles.company:
                  extra['companyName'] = companyCtrl.text.trim();
                  extra['sponsoredLabId'] =
                      (labId ?? '').isEmpty ? null : labId;
                case Roles.donor:
                  extra['impactCode'] = impactCodeCtrl.text.trim();
              }
              final saved = AppUser(
                id: user?.id ?? data.newId('usr'),
                name: nameCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                password: passCtrl.text,
                role: role,
                phone: phoneCtrl.text.trim(),
                cedula: cedulaCtrl.text.trim(),
                extra: extra,
              );
              await data.saveUser(saved);
              auth.refresh();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Contenido de la página principal
// ---------------------------------------------------------------------------

class AdminSiteContent extends StatefulWidget {
  const AdminSiteContent({super.key});

  @override
  State<AdminSiteContent> createState() => _AdminSiteContentState();
}

class _AdminSiteContentState extends State<AdminSiteContent> {
  late TextEditingController _title;
  late TextEditingController _subtitle;
  late TextEditingController _banner;
  late TextEditingController _about;

  @override
  void initState() {
    super.initState();
    final content = context.read<DataProvider>().siteContent;
    _title = TextEditingController(text: content.heroTitle);
    _subtitle = TextEditingController(text: content.heroSubtitle);
    _banner = TextEditingController(text: content.bannerText);
    _about = TextEditingController(text: content.aboutText);
  }

  @override
  Widget build(BuildContext context) {
    return TabBody(
      title: 'Contenido de la Página Principal',
      subtitle: 'Hero, banner y textos visibles para el público',
      children: [
        HoverCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextField(
                  controller: _title,
                  decoration:
                      const InputDecoration(labelText: 'Título del hero')),
              const SizedBox(height: 14),
              TextField(
                  controller: _subtitle,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Subtítulo del hero')),
              const SizedBox(height: 14),
              TextField(
                  controller: _banner,
                  decoration: const InputDecoration(
                      labelText: 'Banner de anuncio (vacío = oculto)')),
              const SizedBox(height: 14),
              TextField(
                  controller: _about,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Texto "Sobre nosotros"')),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Guardar cambios'),
                  onPressed: () async {
                    await context.read<DataProvider>().saveSiteContent(
                          SiteContent(
                            heroTitle: _title.text.trim(),
                            heroSubtitle: _subtitle.text.trim(),
                            bannerText: _banner.text.trim(),
                            aboutText: _about.text.trim(),
                          ),
                        );
                    if (context.mounted) {
                      showAppSnack(context,
                          'Contenido de la página principal actualizado.');
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
