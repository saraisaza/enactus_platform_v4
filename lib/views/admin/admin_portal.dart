import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/async_value.dart';
import '../../widgets/async_states.dart';
import '../../widgets/calendar_view.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../shared/forum_view.dart';
import 'admin_backup.dart';
import 'admin_management.dart';
import 'admin_site_content.dart';
import 'admin_users.dart';

/// Portal de administración. [isSuperAdmin] habilita lo exclusivo del Super
/// Admin: crear cuentas de administrador y restaurar respaldos.
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
            label: 'Calendario',
            icon: Icons.calendar_month_outlined,
            builder: (_) => const AdminCalendar()),
        PortalTab(
            label: 'Usuarios',
            icon: Icons.manage_accounts_outlined,
            builder: (_) => AdminUsers(isSuperAdmin: isSuperAdmin)),
        PortalTab(
            label: 'Proyectos',
            icon: Icons.lightbulb_outline,
            builder: (_) => const AdminProjects()),
        PortalTab(
            label: 'Equipos',
            icon: Icons.groups_outlined,
            builder: (_) => const AdminGroups()),
        PortalTab(
            label: 'Laboratorios',
            icon: Icons.science_outlined,
            builder: (_) => const AdminLabs()),
        PortalTab(
            label: 'Cursos',
            icon: Icons.video_library_outlined,
            builder: (_) => const AdminCourses()),
        PortalTab(
            label: 'Evidencias donantes',
            icon: Icons.volunteer_activism_outlined,
            builder: (_) => const AdminEvidences()),
        PortalTab(
            label: 'Foro',
            icon: Icons.forum_outlined,
            builder: (_) => const ForumView()),
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

/// Estado global de la plataforma.
///
/// **Todas las cifras vienen del servidor**, incluidas las de las tarjetas.
/// Antes se contaban las listas cargadas en el navegador, lo que funcionaba
/// porque el navegador tenía la base entera; contra una API paginada de a 100
/// ese conteo dejaría de crecer al llegar a cien y mostraría un número que
/// parece bien y está mal.
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Dashboard General',
      subtitle: 'Estado global de la plataforma',
      children: [
        combine2(data.impactMetrics, data.projects).when(
          loading: () => const CardListSkeleton(count: 3, height: 110),
          error: (e) => ErrorState(e, onRetry: () async {
            await data.reloadImpactMetrics();
            await data.reloadProjects();
          }),
          data: (values) {
            final (metrics, projects) = values;
            return Column(
              children: [
                _Kpis(counts: metrics.counts),
                const SizedBox(height: 16),
                _Charts(counts: metrics.counts, projects: projects),
                const SectionTitle('Impacto formativo eduXaction'),
                _ImpactMetricsPanel(metrics: metrics),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Kpis extends StatelessWidget {
  final PlatformCounts counts;
  const _Kpis({required this.counts});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StatRow(tiles: [
          StatTile(
              value: '${counts.allStudents}',
              label: 'Estudiantes',
              icon: Icons.school_outlined),
          StatTile(
              value: '${counts.projects}',
              label: 'Proyectos',
              icon: Icons.lightbulb_outline),
          StatTile(
              value: '${counts.groups}',
              label: 'Equipos',
              icon: Icons.groups_outlined),
          StatTile(
              value: '${counts.courses}',
              label: 'Cursos',
              icon: Icons.video_library_outlined),
        ]),
        const SizedBox(height: 12),
        StatRow(tiles: [
          StatTile(
              value: '${counts.certificates}',
              label: 'Certificados emitidos',
              icon: Icons.workspace_premium_outlined),
          StatTile(
              value: '${counts.universities}',
              label: 'Universidades',
              icon: Icons.account_balance_outlined),
          StatTile(
              value: '${counts.mentors}',
              label: 'Mentores',
              icon: Icons.psychology_outlined),
          StatTile(
              value: '${counts.laboratories}',
              label: 'Laboratorios',
              icon: Icons.science_outlined),
        ]),
      ],
    );
  }
}

class _Charts extends StatelessWidget {
  final PlatformCounts counts;
  final List<Project> projects;

  const _Charts({required this.counts, required this.projects});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 900;
        final byRole = ChartCard(
          title: 'Usuarios por rol',
          child: SimpleBarChart(
            maxY: [
              counts.allStudents,
              counts.mentors,
              counts.advisors,
              counts.companies,
              counts.donors,
              counts.lxds,
            ].reduce((a, b) => a > b ? a : b).toDouble().clamp(5, 99999) * 1.2,
            data: [
              (label: 'Estud.', value: counts.allStudents.toDouble()),
              (label: 'LXD', value: counts.lxds.toDouble()),
              (label: 'Mentores', value: counts.mentors.toDouble()),
              (label: 'Asesores', value: counts.advisors.toDouble()),
              (label: 'Empresas', value: counts.companies.toDouble()),
              (label: 'Donantes', value: counts.donors.toDouble()),
            ],
          ),
        );

        // La etapa se guarda como identificador y se muestra traducida: mandar
        // la etiqueta al filtro no encontraría nada, y el gráfico saldría
        // vacío sin que nada falle.
        final byStage = ChartCard(
          title: 'Proyectos por etapa',
          child: DonutChart(
            data: [
              for (final stage in ProjectStage.all)
                if (projects.any((p) => p.stage == stage))
                  (
                    label: ProjectStage.label(stage),
                    value:
                        projects.where((p) => p.stage == stage).length.toDouble()
                  ),
            ],
          ),
        );

        if (!wide) {
          return Column(children: [
            Entrance(delayMs: 250, child: byRole),
            const SizedBox(height: 12),
            Entrance(delayMs: 350, child: byStage),
          ]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Entrance(delayMs: 250, child: byRole)),
            const SizedBox(width: 12),
            Expanded(child: Entrance(delayMs: 350, child: byStage)),
          ],
        );
      },
    );
  }
}

/// Lo que diferencia la plataforma de un LMS convencional: horas de formación
/// por competencia, cobertura de ODS y patrocinio.
class _ImpactMetricsPanel extends StatelessWidget {
  final ImpactMetrics metrics;
  const _ImpactMetricsPanel({required this.metrics});

  @override
  Widget build(BuildContext context) {
    if (metrics.hasNoCharts) {
      return const EmptyState(
        icon: Icons.insights_outlined,
        message: 'Configura competencias, ODS y horas en los cursos '
            '(constructor del LXD) para ver métricas de impacto formativo.',
      );
    }

    final horas = metrics.hoursByCompetency;
    final ods = metrics.odsCompletionRate;

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth > 900;
            final hoursChart = ChartCard(
              title: 'Horas de formación por competencia',
              height: 220,
              child: horas.isEmpty
                  ? const EmptyState(
                      icon: Icons.school_outlined, message: 'Sin datos aún')
                  : SimpleBarChart(
                      maxY: (horas.first.hours * 1.3).clamp(5, 99999),
                      data: [
                        for (final h in horas.take(6))
                          (label: _shorten(h.name), value: h.hours),
                      ],
                    ),
            );
            final odsCard = _OdsCard(ods: ods);

            if (!wide) {
              return Column(children: [
                hoursChart,
                const SizedBox(height: 12),
                odsCard,
              ]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: hoursChart),
                const SizedBox(width: 12),
                Expanded(child: odsCard),
              ],
            );
          },
        ),
        if (metrics.sponsoredHoursByCompany.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final s in metrics.sponsoredHoursByCompany)
                  HoverCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.business_outlined,
                            color: AppColors.gold, size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '${s.companyName} ha patrocinado '
                            '${s.hours.toStringAsFixed(s.hours % 1 == 0 ? 0 : 1)} '
                            'horas de formación',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
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

class _OdsCard extends StatelessWidget {
  final List<OdsCoverage> ods;
  const _OdsCard({required this.ods});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          if (ods.isEmpty)
            const Text('Sin cursos asociados a ODS aún',
                style: TextStyle(color: AppColors.textMuted))
          else
            for (final o in ods.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text('ODS ${o.number}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ),
                    Expanded(
                      child: ThinProgressBar(
                        value: o.rate,
                        // Sobre cuántos: un 100% de dos personas y otro de
                        // doscientas no son la misma noticia, y la barra sola
                        // no lo distingue.
                        tooltip:
                            '${o.label} — ${o.completed} de ${o.total}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${o.completed}/${o.total}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendario: control total sobre cualquier tipo de evento
// ---------------------------------------------------------------------------

class AdminCalendar extends StatelessWidget {
  const AdminCalendar({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Calendario',
      subtitle: 'Sesiones sincrónicas de Open Learning, eventos de Ruta de '
          'Impacto y mentorías de toda la plataforma',
      children: [
        combine3(data.calendarEvents, data.courses, data.laboratories).when(
          loading: () => const CardListSkeleton(count: 1, height: 320),
          error: (e) => ErrorState(e, onRetry: data.reloadCalendarEvents),
          data: (values) {
            final (events, courses, labs) = values;
            final openLearning =
                courses.where((c) => c.isOpenLearning).toList();
            final meetLink = data.siteContent.valueOrNull?.meetingLink ?? '';

            Future<void> guardar(
              List<CalendarEvent> nuevos,
              String? idQueSeEdita,
            ) async {
              for (final e in nuevos) {
                await data.saveCalendarEvent(e, id: idQueSeEdita);
              }
            }

            return CalendarView(
              // El alcance ya lo aplicó el servidor: acá no se vuelve a
              // filtrar por quién mira.
              events: events,
              canManage: true,
              onAddEvent: (day) => showCalendarEventDialog(
                context,
                initialDay: day,
                allowedTypes: CalendarEventType.values,
                courses: openLearning,
                labs: labs,
                defaultMeetLink: meetLink,
                onSave: guardar,
              ),
              onEditEvent: (event) => showCalendarEventDialog(
                context,
                existing: event,
                allowedTypes: CalendarEventType.values,
                courses: openLearning,
                labs: labs,
                defaultMeetLink: meetLink,
                onSave: guardar,
              ),
              onDeleteEvent: (event) => data.deleteCalendarEvent(event.id),
            );
          },
        ),
      ],
    );
  }
}
