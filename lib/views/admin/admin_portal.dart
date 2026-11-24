import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/textos.dart';
import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/async_value.dart';
import '../../utils/formatos.dart';
import '../../widgets/async_states.dart';
import '../../widgets/calendar_view.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../shared/forum_view.dart';
import 'admin_backup.dart';
import 'admin_clients.dart';
import 'admin_management.dart';
import 'admin_site_content.dart';
import 'admin_users.dart';
import '../../services/reporte_admin.dart';

/// Portal de administración. [isSuperAdmin] habilita lo exclusivo del Super
/// Admin: crear cuentas de administrador y restaurar respaldos.
class AdminPortal extends StatelessWidget {
  final bool isSuperAdmin;
  const AdminPortal({super.key, this.isSuperAdmin = false});

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      portalTitle: isSuperAdmin ? tr.adminPortalSuper : tr.adminPortal,
      tabs: [
        PortalTab(
            label: tr.tabDashboard,
            shortLabel: tr.tabInicioCorto,
            destacada: true,
            icon: Icons.dashboard_outlined,
            builder: (_) => const AdminDashboard()),
        PortalTab(
            id: PortalShell.pestanaCalendario,
            label: tr.tabCalendario,
            destacada: true,
            icon: Icons.calendar_month_outlined,
            builder: (_) => const AdminCalendar()),
        PortalTab(
            label: tr.tabUsuarios,
            grupo: tr.menuGrupoPersonas,
            destacada: true,
            icon: Icons.manage_accounts_outlined,
            builder: (_) => AdminUsers(isSuperAdmin: isSuperAdmin)),
        PortalTab(
            label: tr.tabClientes,
            grupo: tr.menuGrupoPersonas,
            icon: Icons.storefront_outlined,
            builder: (_) => const AdminClients()),
        PortalTab(
            label: tr.tabProyectosCorto,
            grupo: tr.menuGrupoProyectos,
            icon: Icons.lightbulb_outline,
            builder: (_) => const AdminProjects()),
        PortalTab(
            label: tr.tabEquipos,
            grupo: tr.menuGrupoProyectos,
            icon: Icons.groups_outlined,
            builder: (_) => const AdminGroups()),
        PortalTab(
            label: tr.tabLaboratorios,
            grupo: tr.menuGrupoFormacion,
            icon: Icons.science_outlined,
            builder: (_) => const AdminLabs()),
        PortalTab(
            label: tr.tabCursosCorto,
            grupo: tr.menuGrupoFormacion,
            icon: Icons.video_library_outlined,
            builder: (_) => const AdminCourses()),
        PortalTab(
            label: tr.tabEvidenciasDonantes,
            grupo: tr.menuGrupoComunicacion,
            shortLabel: tr.tabEvidenciasCorto,
            icon: Icons.volunteer_activism_outlined,
            builder: (_) => const AdminEvidences()),
        PortalTab(
            label: tr.tabForo,
            grupo: tr.menuGrupoComunicacion,
            destacada: true,
            icon: Icons.forum_outlined,
            builder: (_) => const ForumView()),
        PortalTab(
            label: tr.tabContenidoPagina,
            grupo: tr.menuGrupoComunicacion,
            shortLabel: tr.tabContenidoCorto,
            icon: Icons.web_outlined,
            builder: (_) => const AdminSiteContent()),
        PortalTab(
            label: tr.tabDatosRespaldos,
            grupo: tr.menuGrupoSistema,
            shortLabel: tr.tabRespaldosCorto,
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
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  /// Las gráficas, para tomarlas como imagen en el reporte.
  final _porRol = GlobalKey();
  final _porFase = GlobalKey();
  bool _armando = false;

  List<(String, int)> _proyectosPorFase(List<Project> proyectos) => [
        for (final fase in ProjectStage.all)
          if (proyectos.any((p) => p.stage == fase))
            (
              ProjectStage.label(fase),
              proyectos.where((p) => p.stage == fase).length
            ),
      ];

  /// El reporte en PDF: cifras, las dos gráficas tal como se ven y las
  /// tablas de impacto (recomendaciones del 20 de noviembre).
  Future<void> _descargarReporte(DataProvider data) async {
    final metricas = data.impactMetrics.valueOrNull;
    final proyectos = data.projects.valueOrNull;
    if (metricas == null || proyectos == null) return;
    setState(() => _armando = true);
    try {
      final graficas = <String, Uint8List>{};
      for (final (titulo, llave) in [
        (tr.adminUsuariosPorRol, _porRol),
        (tr.adminProyectosPorEtapa, _porFase),
      ]) {
        final png = await ReporteAdmin.capturar(llave);
        if (png != null) graficas[titulo] = png;
      }
      final pdf = await ReporteAdmin.armar(
        metricas: metricas,
        graficas: graficas,
        proyectosPorFase: _proyectosPorFase(proyectos),
      );
      await ReporteAdmin.descargar(pdf);
    } catch (e) {
      if (mounted) showAppSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _armando = false);
    }
  }

  /// Una gráfica sola, en PNG.
  Future<void> _descargarGrafica(String titulo, GlobalKey llave) async {
    final png = await ReporteAdmin.capturar(llave);
    if (png == null || !mounted) return;
    final ruta = await FilePicker.saveFile(
      dialogTitle: tr.reporteDescargarGrafica,
      fileName: tr.reporteGraficaArchivo(
          titulo.toLowerCase().replaceAll(RegExp(r'[^a-z0-9áéíóúñ]+'), '-')),
      type: FileType.custom,
      allowedExtensions: ['png'],
      bytes: png,
    );
    if (ruta != null && mounted) {
      showSuccessCheck(context, tr.reporteGraficaDescargada);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: tr.adminDashboardGeneral,
      subtitle: tr.adminDashboardSubtitulo,
      actions: [
        ElevatedButton.icon(
          key: const ValueKey('descargar-reporte'),
          icon: _armando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: Text(tr.reporteDescargar),
          onPressed: _armando ||
                  data.impactMetrics.valueOrNull == null ||
                  data.projects.valueOrNull == null
              ? null
              : () => _descargarReporte(data),
        ),
      ],
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
                _Charts(
                  counts: metrics.counts,
                  projects: projects,
                  llavePorRol: _porRol,
                  llavePorFase: _porFase,
                  alDescargar: _descargarGrafica,
                ),
                SectionTitle(tr.adminImpactoFormativo),
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
    // Nueve cifras en una sola rejilla de tres columnas (3 × 3), en
    // cualquier ancho. Antes eran dos filas de cuatro: en una pantalla
    // mediana cada fila pasaba a tres por renglón y la cuarta quedaba sola
    // abajo (3, 1, 3, 1).
    final tarjetas = [
      StatTile(
          value: '${counts.allStudents}',
          label: tr.tabEstudiantesCorto,
          icon: Icons.school_outlined),
      StatTile(
          value: '${counts.projects}',
          label: tr.tabProyectosCorto,
          icon: Icons.lightbulb_outline),
      StatTile(
          value: '${counts.groups}',
          label: tr.tabEquipos,
          icon: Icons.groups_outlined),
      StatTile(
          value: '${counts.courses}',
          label: tr.tabCursosCorto,
          icon: Icons.video_library_outlined),
      StatTile(
          value: '${counts.certificates}',
          label: tr.certificacionesEmitidos,
          icon: Icons.workspace_premium_outlined),
      StatTile(
          value: '${counts.universities}',
          label: tr.proyectosUniversidades,
          icon: Icons.account_balance_outlined),
      StatTile(
          value: '${counts.mentors}',
          label: tr.labMentores,
          icon: Icons.psychology_outlined),
      StatTile(
          value: '${counts.laboratories}',
          label: tr.tabLaboratorios,
          icon: Icons.science_outlined),
      StatTile(
          value: '${counts.companies}',
          label: tr.adminEmpresasAliadas,
          icon: Icons.business_outlined),
    ];
    return RejillaDeTarjetas(
      key: const ValueKey('cifras-del-panel'),
      anchoMinimo: 0,
      maxColumnas: 3,
      separacion: 12,
      mismaAltura: true,
      children: [
        for (var i = 0; i < tarjetas.length; i++)
          Entrance(delayMs: 70 * i, child: tarjetas[i]),
      ],
    );
  }
}

class _Charts extends StatelessWidget {
  final PlatformCounts counts;
  final List<Project> projects;
  final GlobalKey llavePorRol;
  final GlobalKey llavePorFase;
  final void Function(String titulo, GlobalKey llave) alDescargar;

  const _Charts({
    required this.counts,
    required this.projects,
    required this.llavePorRol,
    required this.llavePorFase,
    required this.alDescargar,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 900;
        final byRole = ChartCard(
          title: tr.adminUsuariosPorRol,
          llaveDeCaptura: llavePorRol,
          alDescargar: () => alDescargar(tr.adminUsuariosPorRol, llavePorRol),
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
              (label: tr.adminEstudAbrev, value: counts.allStudents.toDouble()),
              (label: 'LXD', value: counts.lxds.toDouble()),
              (label: tr.labMentores, value: counts.mentors.toDouble()),
              (label: tr.adminAsesores, value: counts.advisors.toDouble()),
              (label: tr.adminEmpresas, value: counts.companies.toDouble()),
              (label: tr.adminDonantes, value: counts.donors.toDouble()),
            ],
          ),
        );

        // La etapa se guarda como identificador y se muestra traducida: mandar
        // la etiqueta al filtro no encontraría nada, y el gráfico saldría
        // vacío sin que nada falle.
        final byStage = ChartCard(
          title: tr.adminProyectosPorEtapa,
          llaveDeCaptura: llavePorFase,
          alDescargar: () =>
              alDescargar(tr.adminProyectosPorEtapa, llavePorFase),
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
      return EmptyState(
        icon: Icons.insights_outlined,
        message: tr.adminConfigureMetricas,
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
              title: tr.adminHorasCompetencia,
              height: 220,
              child: horas.isEmpty
                  ? EmptyState(
                      icon: Icons.school_outlined, message: tr.adminSinDatosAun)
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
                        Icon(Icons.business_outlined,
                            color: AppColors.gold, size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            tr.adminHorasPatrocinadas(
                                s.companyName, numero(s.hours)),
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
          Text(tr.adminCoberturaOds,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          if (ods.isEmpty)
            Text(tr.adminSinCursosOds,
                style: TextStyle(color: AppColors.textMuted))
          else
            for (final o in ods.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(tr.odsNumero(o.number),
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ),
                    Expanded(
                      child: ThinProgressBar(
                        value: o.rate,
                        // Sobre cuántos: un 100% de dos personas y otro de
                        // doscientas no son la misma noticia, y la barra sola
                        // no lo distingue.
                        tooltip:
                            tr.adminOdsTooltip(o.label, o.completed, o.total),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${o.completed}/${o.total}',
                        style: TextStyle(
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
      title: tr.tabCalendario,
      subtitle: tr.adminCalendarioSubtitulo,
      children: [
        combine3(data.calendarEvents, data.courses, data.laboratories).when(
          loading: () => const CardListSkeleton(count: 1, height: 320),
          error: (e) => ErrorState(e, onRetry: data.reloadCalendarEvents),
          data: (values) {
            final (events, courses, labs) = values;

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
              // El admin agenda para cualquier curso, laboratorio u
              // organización, y la Ruta de Impacto.
              onAddEvent: (day) => abrirEventoDelCalendario(
                context,
                data: data,
                dia: day,
                tipos: const [
                  CalendarEventType.openLearningSync,
                  CalendarEventType.laboratorio,
                  CalendarEventType.organizacion,
                  CalendarEventType.rutaImpacto,
                  CalendarEventType.mentoria,
                ],
                cursos: courses,
                labs: [for (final l in labs) (l.id, l.name)],
                alGuardar: guardar,
              ),
              onEditEvent: (event) => abrirEventoDelCalendario(
                context,
                data: data,
                existente: event,
                tipos: CalendarEventType.values,
                cursos: courses,
                labs: [for (final l in labs) (l.id, l.name)],
                alGuardar: guardar,
              ),
              onDeleteEvent: (event) => data.deleteCalendarEvent(event.id),
            );
          },
        ),
      ],
    );
  }
}
