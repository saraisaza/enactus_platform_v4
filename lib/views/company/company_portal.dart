import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/async_value.dart';
import '../../utils/constants.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../shared/lab_detail_view.dart';
import '../shared/projects_directory_view.dart' show ProjectsDirectoryView;
import '../shared/students_map_view.dart';
import '../shared/talent_search_view.dart';
import '../shared/user_detail_view.dart';

/// Portal de la Empresa aliada: su equipo formador, los laboratorios que
/// patrocina y el impacto de su aporte.
///
/// Una empresa **da de alta a su propio equipo** (LXD y mentores) y las
/// cuentas quedan atadas a ella. Es una capacidad real, acotada por el
/// servidor: no puede crear estudiantes, ni administradores, ni otra empresa.
class CompanyPortal extends StatelessWidget {
  const CompanyPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      portalTitle: 'Portal Empresa',
      tabs: [
        PortalTab(
            label: 'Impacto',
            icon: Icons.insights_outlined,
            builder: (_) => const _CompanyDashboard()),
        PortalTab(
            label: 'Mapa de Estudiantes',
            icon: Icons.public,
            builder: (_) => const StudentsMapView()),
        PortalTab(
            label: 'Proyectos',
            icon: Icons.lightbulb_outline,
            builder: (_) => const ProjectsDirectoryView()),
        PortalTab(
            label: 'Mis Laboratorios',
            icon: Icons.science_outlined,
            builder: (_) => const _CompanyLabs()),
        PortalTab(
            label: 'Estudiantes Patrocinados',
            icon: Icons.school_outlined,
            builder: (_) => const _CompanyStudents()),
        PortalTab(
            label: 'Mi Equipo',
            icon: Icons.badge_outlined,
            builder: (_) => const _CompanyTeam()),
        PortalTab(
            label: 'BuscaTalento',
            icon: Icons.search,
            builder: (_) => const TalentSearchView()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Impacto
// ---------------------------------------------------------------------------

class _CompanyDashboard extends StatelessWidget {
  const _CompanyDashboard();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final empresa = context.watch<AuthProvider>().currentUser;

    return TabBody(
      title: 'Impacto de tu aporte',
      subtitle: 'Qué hizo posible tu organización',
      children: [
        combine3(
          data.users(include: 'progress'),
          data.laboratories,
          data.courses,
        ).when(
          loading: () => const CardListSkeleton(count: 2, height: 110),
          error: (e) => ErrorState(e, onRetry: data.reloadLaboratories),
          data: (values) {
            final (personas, labs, cursos) = values;
            final estudiantes = personas
                .where((p) => Roles.isStudentLike(p.role))
                .toList();
            final equipo = personas
                .where((p) => p.role == Roles.lxd || p.role == Roles.mentor)
                .toList();

            // Horas patrocinadas: se suman las de los cursos ponderadas por
            // el avance real de cada estudiante. Es la misma definición que
            // usa el panel de Admin, y por eso los dos números coinciden.
            final horas = estudiantes.fold<double>(
              0,
              (suma, e) =>
                  suma + (e.overallProgress?.ratio ?? 0) * _horasDe(cursos),
            );

            return Column(
              children: [
                StatRow(tiles: [
                  StatTile(
                      value: '${estudiantes.length}',
                      label: 'Estudiantes alcanzados',
                      icon: Icons.school_outlined),
                  StatTile(
                      value: '${labs.length}',
                      label: 'Laboratorios',
                      icon: Icons.science_outlined),
                  StatTile(
                      value: '${equipo.length}',
                      label: 'Tu equipo formador',
                      icon: Icons.badge_outlined),
                  StatTile(
                      value: horas.round().toString(),
                      label: 'Horas de formación',
                      icon: Icons.schedule),
                ]),
                if ((empresa?.companyName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 14),
                  HoverCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.business_outlined,
                            color: AppColors.gold),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${empresa!.companyName} acompaña a '
                            '${estudiantes.length} estudiantes en '
                            '${labs.length} laboratorios.',
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  /// Horas promedio de los cursos visibles. Es una aproximación honesta para
  /// la tarjeta: la cifra exacta por empresa la calcula el servidor en el
  /// panel de Admin, sobre las mismas vistas de avance.
  double _horasDe(List<Course> cursos) {
    if (cursos.isEmpty) return 0;
    final total = cursos.fold<int>(0, (s, c) => s + c.hours);
    return total / cursos.length;
  }
}

// ---------------------------------------------------------------------------
// Laboratorios patrocinados
// ---------------------------------------------------------------------------

class _CompanyLabs extends StatelessWidget {
  const _CompanyLabs();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Mis Laboratorios',
      subtitle: 'Los que patrocinás y aquellos donde trabaja tu equipo',
      children: [
        data.laboratories.when(
          loading: () => const CardListSkeleton(count: 3, height: 100),
          error: (e) => ErrorState(e, onRetry: data.reloadLaboratories),
          data: (labs) => labs.isEmpty
              ? const EmptyState(
                  icon: Icons.science_outlined,
                  message: 'Todavía no hay laboratorios asociados a tu '
                      'organización.')
              : Column(
                  children: [
                    for (final lab in labs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: HoverCard(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: RouteSettings(
                                  name: '${AppRoutes.labs}/${lab.id}'),
                              builder: (_) => LabDetailView(labId: lab.id),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.science_outlined,
                                  color: AppColors.gold),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(lab.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis),
                                    if (lab.description.isNotEmpty)
                                      Text(lab.description,
                                          style: const TextStyle(
                                              fontSize: 12.5,
                                              color: AppColors.textMuted),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              StatusChip(
                                  label: '${lab.studentsAssigned}',
                                  color: AppColors.textSecondary,
                                  icon: Icons.people_outline),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Estudiantes patrocinados
// ---------------------------------------------------------------------------

class _CompanyStudents extends StatelessWidget {
  const _CompanyStudents();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Estudiantes Patrocinados',
      subtitle: 'A quiénes alcanza tu aporte y cómo van',
      children: [
        data
            .users(
                role: '${Roles.student},${Roles.alumni}',
                include: 'team,progress')
            .when(
              loading: () => const CardListSkeleton(count: 4, height: 72),
              error: (e) => ErrorState(e),
              data: (estudiantes) => estudiantes.isEmpty
                  ? const EmptyState(
                      icon: Icons.people_outline,
                      message: 'Todavía no hay estudiantes vinculados a tu '
                          'organización.')
                  : Column(
                      children: [
                        for (final e in estudiantes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PersonCard(user: e, mostrarAvance: true),
                          ),
                      ],
                    ),
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Equipo formador
// ---------------------------------------------------------------------------

class _CompanyTeam extends StatelessWidget {
  const _CompanyTeam();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Mi Equipo',
      subtitle: 'Los LXD y mentores de tu organización',
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('Nueva cuenta'),
          onPressed: () => _crear(context),
        ),
      ],
      children: [
        const _TeamNotice(),
        const SizedBox(height: 12),
        data
            .users(role: '${Roles.lxd},${Roles.mentor}', include: 'reviews')
            .when(
              loading: () => const CardListSkeleton(count: 3, height: 72),
              error: (e) => ErrorState(e),
              data: (equipo) => equipo.isEmpty
                  ? const EmptyState(
                      icon: Icons.badge_outlined,
                      message: 'Todavía no diste de alta a nadie.')
                  : Column(
                      children: [
                        for (final p in equipo)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PersonCard(user: p, mostrarAvance: false),
                          ),
                      ],
                    ),
            ),
      ],
    );
  }

  Future<void> _crear(BuildContext context) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _TeamMemberDialog(),
      );
}

class _TeamNotice extends StatelessWidget {
  const _TeamNotice();

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: const [
          Icon(Icons.info_outline, color: AppColors.gold, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Las cuentas que crees quedan atadas a tu organización. Solo '
              'podés dar de alta LXD y mentores: los estudiantes los asigna '
              'el equipo de administración.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final AppUser user;
  final bool mostrarAvance;

  const _PersonCard({required this.user, required this.mostrarAvance});

  @override
  Widget build(BuildContext context) {
    final avance = user.overallProgress;

    return HoverCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserDetailView(userId: user.id)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final identidad = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InitialsAvatar(user.name, radius: 16),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(user.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    Text(
                      [
                        Roles.label(user.role),
                        if (user.university.isNotEmpty) user.university,
                        if (user.team != null) user.team!.projectName,
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );

          final derecha = mostrarAvance
              ? SizedBox(
                  width: 90, child: ThinProgressBar(value: avance?.ratio ?? 0))
              : (user.reviewsCount != null
                  ? Text('${user.reviewsCount} entregas revisadas',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted))
                  : const SizedBox.shrink());

          // Apilado cuando no cabe: con un nombre largo y la cifra a la
          // derecha, una fila desborda en un teléfono.
          if (c.maxWidth < 480) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [identidad, const SizedBox(height: 8), derecha],
            );
          }
          return Row(
            children: [Expanded(child: identidad), derecha],
          );
        },
      ),
    );
  }
}

/// Alta de un LXD o un mentor del equipo de la empresa.
class _TeamMemberDialog extends StatefulWidget {
  const _TeamMemberDialog();

  @override
  State<_TeamMemberDialog> createState() => _TeamMemberDialogState();
}

class _TeamMemberDialogState extends State<_TeamMemberDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _position = TextEditingController();

  String _role = Roles.lxd;
  bool _saving = false;
  ApiException? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _position.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
      setState(() => _error = const ValidationError(
          'El nombre y el correo son obligatorios.'));
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = const ValidationError(
          'La contraseña necesita al menos 6 caracteres.'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // `companyId` no se manda: el servidor ata la cuenta a la empresa que
      // la crea, lo diga o no el formulario.
      await context.read<DataProvider>().createUser({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
        'role': _role,
        'profile': {'position': _position.text.trim()},
      });
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessCheck(context, 'Cuenta creada ✓');
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
      title: 'Nueva cuenta de tu equipo',
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
          Wrap(
            spacing: 8,
            children: [
              for (final (valor, etiqueta) in const [
                (Roles.lxd, 'LXD'),
                (Roles.mentor, 'Mentor'),
              ])
                ChoiceChip(
                  label: Text(etiqueta),
                  selected: _role == valor,
                  selectedColor: AppColors.gold.withValues(alpha: 0.25),
                  onSelected:
                      _saving ? null : (_) => setState(() => _role = valor),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Nombre completo'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            enabled: !_saving,
            decoration:
                const InputDecoration(labelText: 'Correo electrónico'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            enabled: !_saving,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña',
              helperText: 'Mínimo 6 caracteres. Se la compartís vos.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _position,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Cargo (opcional)'),
          ),
        ],
      ),
    );
  }
}
