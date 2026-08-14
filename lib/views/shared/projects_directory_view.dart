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
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import 'lab_progress_view.dart';

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

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final allProjects = data.projects;
    final groups = data.groups;

    // Etapa primero, luego búsqueda — encadenado, como pide el handoff.
    var projects = _stageFilter == 'todas'
        ? allProjects
        : allProjects.where((p) => p.stage == _stageFilter).toList();
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      projects = projects.where((p) {
        final teamUniversities =
            groups.where((g) => g.projectId == p.id).map((g) => g.university);
        final haystack = [
          p.name,
          p.description,
          p.community,
          p.stage,
          ...p.ods,
          ...teamUniversities
        ].join(' ').toLowerCase();
        return haystack.contains(q);
      }).toList();
    }

    // Las 4 estadísticas se calculan de los datos reales, siempre sobre
    // TODOS los proyectos (no sobre el resultado filtrado).
    final universities = <String>{
      for (final p in allProjects)
        for (final g in groups.where((g) => g.projectId == p.id))
          if (g.university.isNotEmpty) g.university,
    }.length;
    final odsCovered = <String>{for (final p in allProjects) ...p.ods}.length;
    final expoCount =
        allProjects.where((p) => p.stage == 'National Expo').length;

    return ContentScreenShell(
      eyebrow: 'Comunidad Enactus Colombia',
      title: 'Directorio de Proyectos',
      subtitle:
          'Todos los proyectos activos de la red. Filtra por etapa, explora '
          'los ODS que atienden y descubre qué está construyendo el resto '
          'de los equipos.',
      searchHint: 'Buscar proyecto, comunidad u ODS',
      onSearchChanged: (v) => setState(() => _query = v),
      trailingBuilder: (context, colors, isDark) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 440),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                  child: _StatCard(
                      value: allProjects.length,
                      label: 'Proyectos activos',
                      colors: colors,
                      isPrimary: true)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      value: universities,
                      label: 'Universidades',
                      colors: colors)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      value: odsCovered, label: 'ODS cubiertos', colors: colors)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      value: expoCount,
                      label: 'En National Expo',
                      colors: colors)),
            ],
          ),
        ),
      ),
      bodyBuilder: (context, colors, isDark) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStageChips(colors, allProjects),
          const SizedBox(height: 26),
          if (projects.isEmpty)
            _buildEmptyState(colors, allProjects.isEmpty)
          else
            _buildGrid(colors, projects, groups),
        ],
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
        for (final s in projectStages)
          _StageChip(
            label: s,
            count: countFor(s),
            active: _stageFilter == s,
            colors: colors,
            onTap: () => setState(() => _stageFilter = s),
          ),
      ],
    );
  }

  Widget _buildGrid(
      ContentColors colors, List<Project> projects, List<Group> groups) {
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
                  groups: groups.where((g) => g.projectId == projects[i].id).toList(),
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
            builder: (_, v, __) => Text(
              v.round().toString(),
              style: knockoutHeading(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
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
                  fontWeight: FontWeight.w800,
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
                  color: const Color(0x8C0A0C0E),
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
  final List<Group> groups;
  final ContentColors colors;
  final VoidCallback onTap;
  const _ProjectCard(
      {required this.project,
      required this.groups,
      required this.colors,
      required this.onTap});

  String get _teamLine {
    if (groups.isEmpty) return 'Sin equipo asignado todavía.';
    return groups
        .map((g) =>
            '${g.name} · ${g.university.isEmpty ? "Universidad sin definir" : g.university} · '
            '${g.studentIds.length} estudiante${g.studentIds.length == 1 ? '' : 's'}')
        .join(' · ');
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
                            fontWeight: FontWeight.w800,
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
    final project = data.projectById(widget.projectId);
    final colors = _colors;

    if (project == null) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: Column(
          children: [
            const AppHeader(portalTitle: 'Proyecto'),
            Expanded(
              child: EmptyState(
                  icon: Icons.lightbulb_outline,
                  message: 'Este proyecto ya no existe o fue eliminado.',
                  colors: colors),
            ),
          ],
        ),
      );
    }

    final groups = data.groups.where((g) => g.projectId == project.id).toList();
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
                                    fontSize: 36, fontWeight: FontWeight.w800, color: colors.text)),
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
                            if (groups.isEmpty)
                              Text('Sin equipo asignado todavía.',
                                  style: TextStyle(fontSize: 13, color: colors.text3))
                            else
                              for (final g in groups)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 18),
                                  child: _GroupBlock(group: g, colors: colors),
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

/// Un equipo del proyecto: nombre, universidad y sus integrantes con
/// enlace a su propio laboratorio real (mentor/fases/módulos) — decidido
/// con el usuario en vez de un "mentor del proyecto" que no existe en el
/// modelo (ver comentario de [ProjectDetailView]).
class _GroupBlock extends StatelessWidget {
  final Group group;
  final ContentColors colors;
  const _GroupBlock({required this.group, required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final advisor = group.advisorId.isEmpty ? null : data.userById(group.advisorId);
    final members =
        group.studentIds.map(data.userById).whereType<AppUser>().toList();

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
                  '${group.name} · ${group.university.isEmpty ? "Universidad sin definir" : group.university}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text)),
            ),
          ]),
          if (advisor != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 25),
              child: Text('Asesor académico: ${advisor.name}',
                  style: TextStyle(fontSize: 12.5, color: colors.text3)),
            ),
          ],
          const SizedBox(height: 14),
          if (members.isEmpty)
            Text('Sin integrantes asignados.', style: TextStyle(fontSize: 13, color: colors.text3))
          else
            for (final m in members)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MemberRow(student: m, colors: colors),
              ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final AppUser student;
  final ContentColors colors;
  const _MemberRow({required this.student, required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final labs = data.labsForStudent(student);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            InitialsAvatar(student.name),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(student.name,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: colors.text)),
                  Text(student.university.isEmpty ? 'Universidad sin definir' : student.university,
                      style: TextStyle(fontSize: 12, color: colors.text3)),
                ],
              ),
            ),
          ]),
          if (labs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final lab in labs)
                  _LabChip(
                    student: student,
                    lab: lab,
                    colors: colors,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              LabProgressView(studentId: student.id, labId: lab.id)),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LabChip extends StatelessWidget {
  final AppUser student;
  final Laboratory lab;
  final ContentColors colors;
  final VoidCallback onTap;
  const _LabChip(
      {required this.student, required this.lab, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final done = lab.phases.where((p) => data.isPhaseComplete(student.id, lab.id, p)).length;
    final accent = labColorFor(lab.id);
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: hover ? accent.withValues(alpha: 0.16) : colors.surface,
            border: Border.all(color: accent),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text('${lab.name} · Fase $done/${lab.phases.length}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.text2)),
            ],
          ),
        ),
      ),
    );
  }
}
