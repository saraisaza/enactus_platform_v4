import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';

/// Directorio de todos los proyectos Enactus de la plataforma, sin
/// importar laboratorio, universidad o equipo — para que estudiantes y
/// asesores vean qué está haciendo el resto de la comunidad (solo
/// lectura: crear/editar proyectos sigue siendo tarea de Admin/Asesor en
/// sus propias pestañas de gestión).
///
/// Rediseño de alta fidelidad según
/// `design_handoff_portal_estudiante/README.md` (pantalla 5): el color de
/// cada tarjeta viene del ODS principal del proyecto, no de un acento fijo.
/// Usa el [ContentScreenShell] compartido con el resto del portal
/// estudiante para el tema claro/oscuro propio de esta pantalla (el header
/// y el sidebar del portal siguen oscuros siempre).
class ProjectsDirectoryView extends StatefulWidget {
  const ProjectsDirectoryView({super.key});

  @override
  State<ProjectsDirectoryView> createState() => _ProjectsDirectoryViewState();
}

class _ProjectsDirectoryViewState extends State<ProjectsDirectoryView> {
  String _stageFilter = 'todas';
  String _query = '';

  /// Etapa primero, luego búsqueda — encadenado, como pide el handoff.
  ///
  /// Las universidades del equipo vienen con el proyecto (`?include=teams`):
  /// antes se cruzaban contra la lista completa de equipos de la plataforma,
  /// que el cliente ya no tiene —ni debería tener— cargada.
  List<Project> _filter(List<Project> all) {
    var projects = _stageFilter == 'todas'
        ? all
        : all.where((p) => p.stage == _stageFilter).toList();
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return projects;
    return projects.where((p) {
      final haystack = [
        p.name,
        p.description,
        p.community,
        p.stageLabel,
        ...p.ods,
        ...p.universities,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return ContentScreenShell(
      eyebrow: 'Comunidad eduXaction Colombia',
      title: 'Directorio de Proyectos',
      subtitle:
          'Todos los proyectos activos de la red. Filtra por etapa, explora '
          'los ODS que atienden y descubre qué está construyendo el resto '
          'de los equipos.',
      searchHint: 'Buscar proyecto, comunidad u ODS',
      onSearchChanged: (v) => setState(() => _query = v),
      trailingBuilder: (context, colors, isDark) => data.projects.when(
        loading: () => const _StatsSkeleton(),
        // Las cifras no tienen dónde poner un botón de reintentar: el cuerpo
        // de la pantalla ya muestra el error con el suyo.
        error: (_) => const SizedBox.shrink(),
        data: (all) => _StatsRow(projects: all, colors: colors),
      ),
      bodyBuilder: (context, colors, isDark) => data.projects.when(
        loading: () => const CardListSkeleton(count: 4),
        error: (e) => ErrorState(e, onRetry: data.reloadProjects),
        data: (all) {
          final projects = _filter(all);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStageChips(colors, all),
              const SizedBox(height: 26),
              if (projects.isEmpty)
                _buildEmptyState(colors, all.isEmpty)
              else
                _buildGrid(colors, projects),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStageChips(ContentColors colors, List<Project> allProjects) {
    int countFor(String stage) => stage == 'todas'
        ? allProjects.length
        : allProjects.where((p) => p.stage == stage).length;

    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        _StageChip(
          label: 'Todas las etapas',
          count: countFor('todas'),
          active: _stageFilter == 'todas',
          colors: colors,
          onTap: () => setState(() => _stageFilter = 'todas'),
        ),
        // El filtro compara identificadores de la API; lo que se muestra es
        // la etiqueta en español.
        for (final stage in projectStages)
          _StageChip(
            label: ProjectStage.label(stage),
            count: countFor(stage),
            active: _stageFilter == stage,
            colors: colors,
            onTap: () => setState(() => _stageFilter = stage),
          ),
      ],
    );
  }

  Widget _buildGrid(ContentColors colors, List<Project> projects) {
    return LayoutBuilder(builder: (context, constraints) {
      const minCard = 348.0;
      const gap = 20.0;
      final columns =
          math.max(1, ((constraints.maxWidth + gap) / (minCard + gap)).floor());
      final cardWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < projects.length; i++)
            SizedBox(
              width: cardWidth,
              child: Entrance(
                delayMs: 55 * i,
                child: _ProjectCard(
                  project: projects[i],
                  colors: colors,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings:
                          RouteSettings(name: '${AppRoutes.projects}/${projects[i].id}'),
                      builder: (_) => ProjectDetailView(projectId: projects[i].id),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildEmptyState(ContentColors colors, bool noProjectsAtAll) {
    return EmptyState(
      icon: Icons.lightbulb_outline,
      title: 'Aún no hay proyectos aquí',
      message: noProjectsAtAll
          ? 'Todavía no se ha publicado ningún proyecto en la comunidad. '
              'Cuando tu equipo registre el suyo, aparecerá aquí para toda la red.'
          : 'Ningún proyecto coincide con este filtro. Prueba con otra '
              'etapa o limpia la búsqueda.',
      primaryLabel: 'Ver todas las etapas',
      onPrimary: () => setState(() {
        _stageFilter = 'todas';
        _query = '';
      }),
      secondaryLabel: 'Proponer un proyecto',
      secondaryIcon: Icons.add,
      colors: colors,
    );
  }
}

class _StatCard extends StatelessWidget {
  final int value;
  final String label;
  final ContentColors colors;
  final bool isPrimary;
  const _StatCard(
      {required this.value,
      required this.label,
      required this.colors,
      this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              v.round().toString(),
              style: knockoutHeading(
                  fontSize: 40,
                  fontWeight: AppWeights.display,
                  color: isPrimary ? colors.goldInk : colors.text,
                  height: 1.0),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12.5, color: colors.text3)),
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final ContentColors colors;
  final VoidCallback onTap;
  const _StageChip(
      {required this.label,
      required this.count,
      required this.active,
      required this.colors,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.ease,
          transform: Matrix4.translationValues(0, hover ? -1 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: active ? colors.goldSoft : colors.surface,
            border: Border.all(color: active ? colors.goldInk : colors.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: active ? colors.goldInk : colors.text2)),
              const SizedBox(width: 7),
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? colors.goldInk : colors.surface2,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text('$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: active ? colors.bg : colors.text3)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Portada de 104px (tarjeta) reutilizada también en el diálogo de
/// detalle: color plano del ODS principal + rayas diagonales + velo +
/// número en marca de agua + píldora de etapa. Sin fotos de proyecto a
/// propósito (ver README): los equipos aún no suben imágenes.
Widget _buildProjectCover(Project project, ContentColors colors,
    {required double height}) {
  final primaryOds = project.ods.isNotEmpty ? project.ods.first : '';
  final odsNum = primaryOds.isEmpty ? 1 : odsNumberFrom(primaryOds);
  final odsColor = AppColors.odsColors[odsNum] ?? AppColors.gold;
  return SizedBox(
    height: height,
    width: double.infinity,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: odsColor),
        const CustomPaint(painter: StripePainter()),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.4, 1.0],
              colors: [Colors.transparent, colors.veil],
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: -16,
          child: Text('$odsNum',
              style: knockoutHeading(
                  fontSize: 82,
                  fontWeight: AppWeights.display,
                  color: Colors.white.withValues(alpha: 0.32),
                  height: 1.0)),
        ),
        Positioned(
          left: 16,
          top: 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                padding: const EdgeInsets.fromLTRB(9, 6, 12, 6),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flag_rounded, size: 15, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(project.stage,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final ContentColors colors;
  final VoidCallback onTap;
  const _ProjectCard(
      {required this.project, required this.colors, required this.onTap});

  String get _teamLine {
    if (project.teamSize == 0) return 'Sin equipo asignado todavía.';
    final people =
        '${project.teamSize} estudiante${project.teamSize == 1 ? '' : 's'}';
    if (project.universities.isEmpty) return people;
    return '${project.universities.join(' · ')} · $people';
  }

  @override
  Widget build(BuildContext context) {
    final odsColor =
        project.ods.isNotEmpty ? odsColorFor(project.ods.first) : AppColors.gold;
    final stageIndex = projectStages.indexOf(project.stage);
    final currentIndex = stageIndex < 0 ? 0 : stageIndex;

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.ease,
          transform: Matrix4.translationValues(0, hover ? -5 : 0, 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: hover ? odsColor : colors.border),
            borderRadius: BorderRadius.circular(18),
            boxShadow: hover ? colors.shadow : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProjectCover(project, colors, height: 104),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.name.toUpperCase(),
                        style: knockoutHeading(
                            fontSize: 29,
                            fontWeight: AppWeights.display,
                            color: colors.text,
                            height: 1.0)),
                    if (project.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 9),
                        child: Text(project.description,
                            style: TextStyle(
                                fontSize: 14, height: 1.5, color: colors.text2)),
                      ),
                    const SizedBox(height: 13),
                    StageRail(
                        accentColor: odsColor,
                        colors: colors,
                        currentIndex: currentIndex),
                    if (project.community.isNotEmpty) ...[
                      const SizedBox(height: 13),
                      Row(children: [
                        Icon(Icons.location_on_outlined, size: 17, color: colors.text3),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(project.community,
                                style: TextStyle(fontSize: 13, color: colors.text2))),
                      ]),
                    ],
                    if (project.ods.isNotEmpty) ...[
                      const SizedBox(height: 13),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final o in project.ods) _OdsTag(label: o, colors: colors)
                        ],
                      ),
                    ],
                    const SizedBox(height: 13),
                    Divider(height: 1, color: colors.border),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Expanded(
                          child: Row(children: [
                            Icon(Icons.groups_outlined, size: 17, color: colors.text3),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_teamLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12.5, color: colors.text3)),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              color: colors.goldSoft, borderRadius: BorderRadius.circular(9)),
                          child: Icon(Icons.arrow_forward, size: 18, color: colors.goldInk),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OdsTag extends StatelessWidget {
  final String label;
  final ContentColors colors;
  const _OdsTag({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
      decoration: BoxDecoration(
        color: colors.surface2,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration:
                BoxDecoration(color: odsColorFor(label), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontSize: 11.5, color: colors.text2)),
        ],
      ),
    );
  }
}

List<Widget> _detailSection(String title, String body, ContentColors colors) => [
      const SizedBox(height: 16),
      Text(title.toUpperCase(),
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.text3,
              letterSpacing: 1)),
      const SizedBox(height: 6),
      Text(body, style: TextStyle(fontSize: 14, color: colors.text2, height: 1.5)),
    ];

/// Tarjeta de solo lectura para portales que solo necesitan enlazar a un
/// proyecto sin poder editarlo (Mentor, LXD, Empresa) — mismo destino real
/// (`ProjectDetailView`, con URL) que ya usan las tarjetas editables de
/// Admin/Asesor, sin duplicar esa navegación en cada portal.
class ProjectSummaryCard extends StatelessWidget {
  final Project project;

  /// Cuántos de "mis" estudiantes (del rol que mira esta tarjeta) están en
  /// este proyecto — opcional, se omite si no aplica.
  final int? relevantStudentCount;
  const ProjectSummaryCard({super.key, required this.project, this.relevantStudentCount});

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              settings: RouteSettings(name: '${AppRoutes.projects}/${project.id}'),
              builder: (_) => ProjectDetailView(projectId: project.id))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.lightbulb_outline, color: AppColors.gold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(project.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    StatusChip(
                        label: project.stage, color: AppColors.gold, icon: Icons.flag_outlined),
                  ],
                ),
                if (project.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(project.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                ],
                if (relevantStudentCount != null) ...[
                  const SizedBox(height: 6),
                  Text(
                      '$relevantStudentCount estudiante${relevantStudentCount == 1 ? '' : 's'} en tu alcance',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                ],
              ],
            ),
          ),
          const Icon(Icons.arrow_forward, size: 18, color: AppColors.gold),
        ],
      ),
    );
  }
}

/// Detalle completo de un proyecto, con URL real (`/proyectos/:id`) y
/// botón atrás, reemplaza al antiguo diálogo (que se quedaba corto:
/// nombre/descripción/equipo, sin mentor ni progreso). Reutiliza la
/// portada/etiquetas ODS/secciones de texto ya construidas para la tarjeta
/// y el `StageRail` de la etapa del proyecto.
///
/// "Mentor asignado", "fase" y "módulos" del pedido original en realidad
/// viven en el Laboratorio de cada integrante, no en el Proyecto — los
/// integrantes de un mismo equipo pueden estar en laboratorios distintos
/// (confirmado en los datos: en Equipo AquaVida, Est1/Alum1 están en IA e
/// Impacto pero Est2 está en Emprendimiento). Por eso el equipo muestra lo
/// real a nivel de proyecto (nombre, universidad, integrantes, etapa,
/// fecha de creación) y, junto a cada integrante, un enlace a SU
/// laboratorio real con mentor/fases/módulos (decidido con el usuario).
class ProjectDetailView extends StatefulWidget {
  final String projectId;
  const ProjectDetailView({super.key, required this.projectId});

  @override
  State<ProjectDetailView> createState() => _ProjectDetailViewState();
}

class _ProjectDetailViewState extends State<ProjectDetailView> {
  bool _isDark = true;
  ContentColors get _colors => _isDark ? ContentColors.dark : ContentColors.light;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final colors = _colors;

    return data.projectById(widget.projectId).when(
          loading: () => Scaffold(
            backgroundColor: colors.bg,
            body: const Column(
              children: [
                AppHeader(portalTitle: 'Proyecto'),
                Expanded(child: Center(child: BrandLoader())),
              ],
            ),
          ),
          error: (e) => Scaffold(
            backgroundColor: colors.bg,
            body: Column(
              children: [
                const AppHeader(portalTitle: 'Proyecto'),
                Expanded(
                  child: ErrorState(e,
                      onRetry: () => data.reloadProject(widget.projectId)),
                ),
              ],
            ),
          ),
          data: (project) => _buildDetail(context, project, colors),
        );
  }

  Widget _buildDetail(
      BuildContext context, Project project, ContentColors colors) {
    // El equipo llega DENTRO del proyecto, con el rol de cada integrante —
    // esa es la brecha de modelo que cerró el esquema: antes un equipo era una
    // lista de ids sin rol, y había que cruzarla contra todos los usuarios.
    final stageIndex = projectStages.indexOf(project.stage);
    final currentIndex = stageIndex < 0 ? 0 : stageIndex;
    final odsColor = project.ods.isNotEmpty ? odsColorFor(project.ods.first) : AppColors.gold;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          const AppHeader(portalTitle: 'Proyecto'),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  color: colors.goldInk,
                                  onPressed: () => Navigator.pop(context),
                                ),
                                const Spacer(),
                                _ThemeToggleButton(
                                  isDark: _isDark,
                                  colors: colors,
                                  onTap: () => setState(() => _isDark = !_isDark),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: _buildProjectCover(project, colors, height: 160),
                            ),
                            const SizedBox(height: 20),
                            Text(project.name.toUpperCase(),
                                style: knockoutHeading(
                                    fontSize: 36, fontWeight: AppWeights.display, color: colors.text)),
                            if (project.description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(project.description,
                                  style: TextStyle(fontSize: 15, height: 1.5, color: colors.text2)),
                            ],
                            const SizedBox(height: 18),
                            StageRail(
                                accentColor: odsColor, colors: colors, currentIndex: currentIndex),
                            const SizedBox(height: 10),
                            Text(
                              project.createdAt == null
                                  ? 'Fecha no registrada'
                                  : 'Creado el ${DateFormat('d MMM yyyy', 'es').format(project.createdAt!)}',
                              style: TextStyle(fontSize: 12.5, color: colors.text3),
                            ),
                            if (project.problem.isNotEmpty)
                              ..._detailSection('Problema', project.problem, colors),
                            if (project.solution.isNotEmpty)
                              ..._detailSection('Solución', project.solution, colors),
                            if (project.impactIndicators.isNotEmpty)
                              ..._detailSection(
                                  'Indicadores de impacto', project.impactIndicators, colors),
                            if (project.community.isNotEmpty)
                              ..._detailSection('Comunidad', project.community, colors),
                            if (project.ods.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text('ODS',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: colors.text3,
                                      letterSpacing: 1)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  for (final o in project.ods) _OdsTag(label: o, colors: colors)
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text('EQUIPO',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: colors.text3,
                                    letterSpacing: 1)),
                            const SizedBox(height: 10),
                            if (project.teams.isEmpty)
                              Text('Sin equipo asignado todavía.',
                                  style: TextStyle(
                                      fontSize: 13, color: colors.text3))
                            else
                              for (final team in project.teams)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 18),
                                  child: _GroupBlock(
                                    team: team,
                                    members: project.team
                                        .where((m) => m.groupId == team.groupId)
                                        .toList(),
                                    colors: colors,
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Align(alignment: Alignment.bottomCenter, child: AppFooter()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final ContentColors colors;
  final VoidCallback onTap;
  const _ThemeToggleButton({required this.isDark, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: hover ? colors.surface2 : colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 16, color: colors.text2),
              const SizedBox(width: 6),
              Text(isDark ? 'Claro' : 'Oscuro',
                  style: TextStyle(fontSize: 12.5, color: colors.text2)),
            ],
          ),
        ),
      ),
    );
  }
}


/// Un equipo del proyecto: nombre, universidad, asesor académico e
/// integrantes con su rol.
///
/// **Ya no muestra el avance de cada integrante en su laboratorio.** No es un
/// recorte de diseño: leer la Ruta de Impacto de otra persona exige ser su
/// mentor, asesor o administrador, y el servidor responde 403 a un estudiante
/// que lo intente. La versión anterior lo mostraba solo porque Hive tenía
/// todos los datos de todo el mundo en el navegador.
class _GroupBlock extends StatelessWidget {
  final ProjectTeam team;
  final List<ProjectMember> members;
  final ContentColors colors;
  const _GroupBlock(
      {required this.team, required this.members, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.groups_outlined, size: 17, color: colors.text3),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  '${team.groupName} · '
                  '${team.university.isEmpty ? "Universidad sin definir" : team.university}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.text)),
            ),
          ]),
          if (team.advisorName != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 25),
              child: Text('Asesor académico: ${team.advisorName}',
                  style: TextStyle(fontSize: 12.5, color: colors.text3)),
            ),
          ],
          const SizedBox(height: 14),
          if (members.isEmpty)
            Text('Sin integrantes asignados.',
                style: TextStyle(fontSize: 13, color: colors.text3))
          else
            for (final member in members)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MemberRow(member: member, colors: colors),
              ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final ProjectMember member;
  final ContentColors colors;
  const _MemberRow({required this.member, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: colors.surface2, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        InitialsAvatar(member.name),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(member.name,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: colors.text)),
              Text(
                  [
                    member.university.isEmpty
                        ? 'Universidad sin definir'
                        : member.university,
                    if (member.career.isNotEmpty) member.career,
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: colors.text3)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // El rol dentro del proyecto: la brecha de modelo que cerró el
        // esquema. Antes un equipo era una lista de ids sin rol.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: colors.goldSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(member.roleLabel,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: colors.goldInk)),
        ),
      ]),
    );
  }
}

/// Las cuatro cifras del encabezado, sobre TODOS los proyectos — no sobre el
/// resultado filtrado: son el tamaño de la comunidad, no del filtro.
class _StatsRow extends StatelessWidget {
  final List<Project> projects;
  final ContentColors colors;
  const _StatsRow({required this.projects, required this.colors});

  @override
  Widget build(BuildContext context) {
    final universities = <String>{
      for (final p in projects) ...p.universities,
    }.length;
    final odsCovered = <String>{for (final p in projects) ...p.ods}.length;
    final expoCount =
        projects.where((p) => p.stage == 'national_expo').length;

    final cards = [
      (projects.length, 'Proyectos activos', true),
      (universities, 'Universidades', false),
      (odsCovered, 'ODS cubiertos', false),
      (expoCount, 'En National Expo', false),
    ];

    return LayoutBuilder(builder: (context, c) {
      // Sin ancho mínimo: el bloque tiene que poder encogerse. Con un
      // `minWidth` de 440 los cuatro `Expanded` internos no podían achicarlo
      // por debajo de ese piso y desbordaba en cualquier teléfono.
      final perRow = c.maxWidth > 420 ? 4 : 2;
      final width = (c.maxWidth - (perRow - 1) * 12) / perRow;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (value, label, primary) in cards)
            SizedBox(
              width: width,
              child: _StatCard(
                  value: value,
                  label: label,
                  colors: colors,
                  isPrimary: primary),
            ),
        ],
      );
    });
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth > 420 ? 4 : 2;
      final width = (c.maxWidth - (perRow - 1) * 12) / perRow;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var i = 0; i < 4; i++)
            Skeleton(
                width: width, height: 86, radius: BorderRadius.circular(14)),
        ],
      );
    });
  }
}
