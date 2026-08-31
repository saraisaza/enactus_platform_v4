import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/async_value.dart';
import '../../utils/constants.dart';
import '../../widgets/async_states.dart';
import '../../widgets/calendar_view.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../admin/admin_management.dart' show showProjectDialog;
import '../shared/communication_resources_view.dart';
import '../shared/forum_view.dart';
import '../shared/projects_directory_view.dart';
import '../shared/user_detail_view.dart';

/// Portal del Asesor académico: acompaña a los equipos de SU universidad.
///
/// El alcance —"su universidad"— lo aplica el servidor en cada lectura. Acá no
/// se vuelve a filtrar: con la base entera en el navegador ese filtro era una
/// comodidad; contra una API sería una segunda definición de "los míos" que
/// puede discrepar de la del servidor.
class AdvisorPortal extends StatelessWidget {
  const AdvisorPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      portalTitle: 'Portal Asesor Académico',
      tabs: [
        PortalTab(
            label: 'Dashboard Universidad',
            icon: Icons.dashboard_outlined,
            builder: (_) => const _AdvisorDashboard()),
        PortalTab(
            label: 'Calendario',
            icon: Icons.calendar_month_outlined,
            builder: (_) => const _AdvisorCalendar()),
        PortalTab(
            label: 'Seguimiento Estudiantes',
            icon: Icons.school_outlined,
            builder: (_) => const _AdvisorStudents()),
        PortalTab(
            label: 'Proyectos',
            icon: Icons.lightbulb_outline,
            builder: (_) => const _AdvisorProjects()),
        PortalTab(
            label: 'Directorio de Proyectos',
            icon: Icons.explore_outlined,
            builder: (_) => const ProjectsDirectoryView()),
        PortalTab(
            label: 'Foro',
            icon: Icons.forum_outlined,
            builder: (_) => const ForumView()),
        PortalTab(
            label: 'Recursos Comunicaciones',
            icon: Icons.perm_media_outlined,
            builder: (_) => const CommunicationResourcesView()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

class _AdvisorDashboard extends StatelessWidget {
  const _AdvisorDashboard();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final universidad =
        context.watch<AuthProvider>().currentUser?.university ?? '';

    return TabBody(
      title: universidad.isEmpty ? 'Tu universidad' : universidad,
      subtitle: 'Los equipos y estudiantes que acompañás',
      children: [
        combine2(
          data.users(role: '${Roles.student},${Roles.alumni}',
              include: 'team,progress'),
          data.groups,
        ).when(
          loading: () => const CardListSkeleton(count: 2, height: 110),
          error: (e) => ErrorState(e, onRetry: data.reloadGroups),
          data: (values) {
            final (estudiantes, equipos) = values;
            final conAvance = estudiantes
                .where((e) => (e.overallProgress?.coursesTotal ?? 0) > 0)
                .toList();
            final promedio = conAvance.isEmpty
                ? 0.0
                : conAvance
                        .map((e) => e.overallProgress!.ratio)
                        .reduce((a, b) => a + b) /
                    conAvance.length;

            return Column(
              children: [
                StatRow(tiles: [
                  StatTile(
                      value: '${estudiantes.length}',
                      label: 'Estudiantes',
                      icon: Icons.school_outlined),
                  StatTile(
                      value: '${equipos.length}',
                      label: 'Equipos',
                      icon: Icons.groups_outlined),
                  StatTile(
                      value: '${(promedio * 100).round()}%',
                      label: 'Avance promedio',
                      icon: Icons.trending_up),
                ]),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Calendario
// ---------------------------------------------------------------------------

class _AdvisorCalendar extends StatelessWidget {
  const _AdvisorCalendar();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Calendario',
      subtitle: 'Eventos de la Ruta de Impacto y de los laboratorios de tus '
          'estudiantes',
      children: [
        data.calendarEvents.when(
          loading: () => const CardListSkeleton(count: 1, height: 320),
          error: (e) => ErrorState(e, onRetry: data.reloadCalendarEvents),
          // Un asesor consulta el calendario; no crea eventos. Quién puede
          // crear cada tipo lo decide el servidor igual.
          data: (events) => CalendarView(events: events, canManage: false),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Seguimiento de estudiantes
// ---------------------------------------------------------------------------

class _AdvisorStudents extends StatefulWidget {
  const _AdvisorStudents();

  @override
  State<_AdvisorStudents> createState() => _AdvisorStudentsState();
}

class _AdvisorStudentsState extends State<_AdvisorStudents> {
  final _search = TextEditingController();
  String _tipo = 'todos';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Seguimiento de Estudiantes',
      subtitle: 'Cómo van los estudiantes de tu universidad',
      children: [
        // `Wrap` y no `Row`: el buscador con ancho fijo más tres fichas
        // desbordaba siempre en pantallas angostas.
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300, minWidth: 180),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Buscar por nombre…',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            for (final (valor, etiqueta) in const [
              ('todos', 'Todos'),
              (StudentType.enactus, 'eduXaction'),
              (StudentType.openLearning, 'Open Learning'),
            ])
              ChoiceChip(
                label: Text(etiqueta),
                selected: _tipo == valor,
                selectedColor: AppColors.gold.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => _tipo = valor),
              ),
          ],
        ),
        const SizedBox(height: 16),
        data
            .users(
                role: '${Roles.student},${Roles.alumni}',
                include: 'team,progress')
            .when(
              loading: () => const CardListSkeleton(count: 5, height: 72),
              error: (e) => ErrorState(e),
              data: (estudiantes) {
                final texto = _search.text.trim().toLowerCase();
                final visibles = estudiantes.where((e) {
                  if (_tipo != 'todos' && e.studentType != _tipo) return false;
                  if (texto.isEmpty) return true;
                  return e.name.toLowerCase().contains(texto);
                }).toList();

                if (visibles.isEmpty) {
                  return const EmptyState(
                      icon: Icons.people_outline,
                      message: 'Ningún estudiante coincide.');
                }
                return Column(
                  children: [
                    for (final e in visibles)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _StudentCard(student: e),
                      ),
                  ],
                );
              },
            ),
      ],
    );
  }
}

class _StudentCard extends StatelessWidget {
  final AppUser student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final avance = student.overallProgress;

    return HoverCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => UserDetailView(userId: student.id)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final identidad = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InitialsAvatar(student.name, radius: 16),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(student.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    Text(
                      [
                        StudentType.label(student.studentType),
                        if (student.team != null) student.team!.projectName,
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

          final progreso = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 110, child: ThinProgressBar(value: avance?.ratio ?? 0)),
              const SizedBox(width: 10),
              Text(
                '${avance?.coursesDone ?? 0}/${avance?.coursesTotal ?? 0} cursos',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          );

          // Apilado en angosto: en una fila, el nombre y el avance juntos no
          // caben en un teléfono.
          if (c.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [identidad, const SizedBox(height: 10), progreso],
            );
          }
          return Row(
            children: [
              Expanded(child: identidad),
              progreso,
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Proyectos de sus equipos
// ---------------------------------------------------------------------------

class _AdvisorProjects extends StatelessWidget {
  const _AdvisorProjects();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Proyectos',
      subtitle: 'Los proyectos de los equipos que asesorás',
      children: [
        data.projects.when(
          loading: () => const CardListSkeleton(count: 3, height: 110),
          error: (e) => ErrorState(e, onRetry: data.reloadProjects),
          data: (projects) => projects.isEmpty
              ? const EmptyState(
                  icon: Icons.lightbulb_outline,
                  message: 'Todavía no hay proyectos.')
              : Column(
                  children: [
                    for (final p in projects)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: HoverCard(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: RouteSettings(
                                  name: '${AppRoutes.projects}/${p.id}'),
                              builder: (_) =>
                                  ProjectDetailView(projectId: p.id),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis),
                                    Text(p.stageLabel,
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                color: AppColors.gold,
                                tooltip: 'Editar',
                                // El servidor decide si un asesor puede
                                // editarlo: si no, responde 403 y el diálogo
                                // lo muestra.
                                onPressed: () => showProjectDialog(context, p),
                              ),
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
