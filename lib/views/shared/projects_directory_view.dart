import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/common.dart';

/// Extrae el número de un rótulo de ODS ("ODS 6: Agua limpia..." -> 6).
int _odsNumber(String odsLabel) {
  final match = RegExp(r'ODS\s*(\d+)').firstMatch(odsLabel);
  return match != null ? int.parse(match.group(1)!) : 1;
}

Color _odsColor(String odsLabel) =>
    AppColors.odsColors[_odsNumber(odsLabel)] ?? AppColors.gold;

/// Directorio de todos los proyectos Enactus de la plataforma, sin
/// importar laboratorio, universidad o equipo — para que estudiantes y
/// asesores vean qué está haciendo el resto de la comunidad (solo
/// lectura: crear/editar proyectos sigue siendo tarea de Admin/Asesor en
/// sus propias pestañas de gestión).
///
/// Rediseño de alta fidelidad según
/// `assets/design_handoff_directorio_proyectos/README.md`: el color de
/// cada tarjeta viene del ODS principal del proyecto, no de un acento fijo.
/// Es la única pantalla con tema claro/oscuro propio (el header y el
/// sidebar del portal — compartidos con el resto de la app — siguen
/// oscuros siempre).
class ProjectsDirectoryView extends StatefulWidget {
  const ProjectsDirectoryView({super.key});

  @override
  State<ProjectsDirectoryView> createState() => _ProjectsDirectoryViewState();
}

class _ProjectsDirectoryViewState extends State<ProjectsDirectoryView>
    with SingleTickerProviderStateMixin {
  String _stageFilter = 'todas';
  String _query = '';
  bool _isDark = true;
  final _searchCtrl = TextEditingController();
  late final AnimationController _glow = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();

  DirectoryColors get _colors => _isDark ? DirectoryColors.dark : DirectoryColors.light;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final allProjects = data.projects;
    final groups = data.groups;
    final colors = _colors;

    // Etapa primero, luego búsqueda — encadenado, como pide el handoff.
    var projects = _stageFilter == 'todas'
        ? allProjects
        : allProjects.where((p) => p.stage == _stageFilter).toList();
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      projects = projects.where((p) {
        final teamUniversities =
            groups.where((g) => g.projectId == p.id).map((g) => g.university);
        final haystack = [p.name, p.description, p.community, p.stage, ...p.ods, ...teamUniversities]
            .join(' ')
            .toLowerCase();
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
    final expoCount = allProjects.where((p) => p.stage == 'National Expo').length;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.bg),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 34, 40, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildControlsRow(colors),
                  const SizedBox(height: 22),
                  _buildHeader(
                      colors, allProjects.length, universities, odsCovered, expoCount),
                  const SizedBox(height: 26),
                  _buildStageChips(colors, allProjects),
                  const SizedBox(height: 26),
                  if (projects.isEmpty)
                    _buildEmptyState(colors, allProjects.isEmpty)
                  else
                    _buildGrid(colors, projects, groups),
                ],
              ),
            ),
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AppFooter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsRow(DirectoryColors colors) {
    return Row(
      children: [
        const Spacer(),
        Container(
          width: 320,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: colors.text3),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(fontSize: 14, color: colors.text),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Buscar proyecto, comunidad u ODS',
                    hintStyle: TextStyle(fontSize: 14, color: colors.text3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _ThemeToggleButton(
          isDark: _isDark,
          colors: colors,
          onTap: () => setState(() => _isDark = !_isDark),
        ),
      ],
    );
  }

  Widget _buildHeader(
      DirectoryColors colors, int total, int universities, int ods, int expo) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 32,
      runSpacing: 20,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 320, maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _glow,
                    builder: (_, __) {
                      final t = _glow.value;
                      return Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4C9F38),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4C9F38)
                                  .withValues(alpha: 0.55 * (1 - t)),
                              spreadRadius: 5 * t,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 9),
                  Text('COMUNIDAD ENACTUS COLOMBIA',
                      style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 12 * 0.16,
                          fontWeight: FontWeight.w600,
                          color: colors.text3)),
                ],
              ),
              const SizedBox(height: 10),
              Text('Directorio de Proyectos'.toUpperCase(),
                  style: knockoutHeading(
                      fontSize: 58,
                      fontWeight: FontWeight.w800,
                      color: colors.goldInk,
                      height: 0.94)),
              const SizedBox(height: 12),
              Text(
                'Todos los proyectos activos de la red. Filtra por etapa, explora '
                'los ODS que atienden y descubre qué está construyendo el resto '
                'de los equipos.',
                style: TextStyle(fontSize: 15.5, color: colors.text2, height: 1.4),
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 440),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                    child: _StatCard(
                        value: total,
                        label: 'Proyectos activos',
                        colors: colors,
                        isPrimary: true)),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatCard(
                        value: universities, label: 'Universidades', colors: colors)),
                const SizedBox(width: 12),
                Expanded(
                    child:
                        _StatCard(value: ods, label: 'ODS cubiertos', colors: colors)),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatCard(
                        value: expo, label: 'En National Expo', colors: colors)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStageChips(DirectoryColors colors, List<Project> allProjects) {
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
      DirectoryColors colors, List<Project> projects, List<Group> groups) {
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
                  onTap: () => showProjectDetailDialog(
                    context,
                    projects[i],
                    groups.where((g) => g.projectId == projects[i].id).toList(),
                    colors,
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildEmptyState(DirectoryColors colors, bool noProjectsAtAll) {
    return _DashedRRectBorder(
      color: colors.border,
      radius: 20,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration:
                  BoxDecoration(color: colors.goldSoft, borderRadius: BorderRadius.circular(22)),
              child: Icon(Icons.lightbulb_outline, size: 36, color: colors.goldInk),
            ),
            const SizedBox(height: 16),
            Text('Aún no hay proyectos aquí'.toUpperCase(),
                style: knockoutHeading(
                    fontSize: 38, fontWeight: FontWeight.w800, color: colors.text)),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Text(
                noProjectsAtAll
                    ? 'Todavía no se ha publicado ningún proyecto en la comunidad. '
                        'Cuando tu equipo registre el suyo, aparecerá aquí para toda la red.'
                    : 'Ningún proyecto coincide con este filtro. Prueba con otra '
                        'etapa o limpia la búsqueda.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.55, color: colors.text2),
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => setState(() {
                    _stageFilter = 'todas';
                    _query = '';
                    _searchCtrl.clear();
                  }),
                  icon: const Icon(Icons.restart_alt, size: 19),
                  label: const Text('Ver todas las etapas'),
                ),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.add, size: 19),
                  label: const Text('Proponer un proyecto'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final DirectoryColors colors;
  final VoidCallback onTap;
  const _ThemeToggleButton(
      {required this.isDark, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: hover ? AppColors.gold : colors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 21,
            color: hover ? AppColors.gold : colors.text2,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final int value;
  final String label;
  final DirectoryColors colors;
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
  final DirectoryColors colors;
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
Widget _buildProjectCover(Project project, DirectoryColors colors,
    {required double height}) {
  final primaryOds = project.ods.isNotEmpty ? project.ods.first : '';
  final odsNum = primaryOds.isEmpty ? 1 : _odsNumber(primaryOds);
  final odsColor = AppColors.odsColors[odsNum] ?? AppColors.gold;
  return SizedBox(
    height: height,
    width: double.infinity,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: odsColor),
        const CustomPaint(painter: _StripePainter()),
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

/// Rayas diagonales de la portada: `repeating-linear-gradient(115deg,
/// rgba(255,255,255,.14) 0 2px, transparent 2px 13px)` del handoff.
class _StripePainter extends CustomPainter {
  const _StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 2;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-25 * math.pi / 180);
    canvas.translate(-size.width / 2, -size.height / 2);
    final diag = size.width + size.height;
    for (double x = -diag; x < diag; x += 13) {
      canvas.drawLine(Offset(x, -diag), Offset(x, diag * 2), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final List<Group> groups;
  final DirectoryColors colors;
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
        project.ods.isNotEmpty ? _odsColor(project.ods.first) : AppColors.gold;
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
                    _StageRail(
                        odsColor: odsColor, colors: colors, currentIndex: currentIndex),
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

class _StageRail extends StatelessWidget {
  final Color odsColor;
  final DirectoryColors colors;
  final int currentIndex;
  const _StageRail(
      {required this.odsColor, required this.colors, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final total = projectStages.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < currentIndex
                        ? colors.goldSoft
                        : (i == currentIndex ? odsColor : colors.border),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Etapa ${currentIndex + 1} de $total',
                style: TextStyle(fontSize: 11.5, color: colors.text3)),
            Text(
                currentIndex >= total - 1
                    ? 'Etapa final'
                    : 'Sigue: ${projectStages[currentIndex + 1]}',
                style: TextStyle(fontSize: 11.5, color: colors.text3)),
          ],
        ),
      ],
    );
  }
}

class _OdsTag extends StatelessWidget {
  final String label;
  final DirectoryColors colors;
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
                BoxDecoration(color: _odsColor(label), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontSize: 11.5, color: colors.text2)),
        ],
      ),
    );
  }
}

/// Borde punteado — Flutter no lo trae de fábrica; se dibuja a mano sobre
/// el contorno redondeado del hijo. Usado solo en el estado vacío.
class _DashedRRectBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  const _DashedRRectBorder(
      {required this.child, required this.color, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

List<Widget> _detailSection(String title, String body, DirectoryColors colors) => [
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

/// Diálogo de solo lectura con la info básica de un proyecto: no existía
/// ninguna vista de detalle en la app para reutilizar, así que este
/// diálogo (contenido a esta pantalla) cumple ese propósito sin introducir
/// una ruta/página nueva.
Future<void> showProjectDetailDialog(
    BuildContext context, Project project, List<Group> groups, DirectoryColors colors) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProjectCover(project, colors, height: 140),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.name.toUpperCase(),
                        style: knockoutHeading(
                            fontSize: 32, fontWeight: FontWeight.w800, color: colors.text)),
                    if (project.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(project.description,
                          style:
                              TextStyle(fontSize: 14.5, color: colors.text2, height: 1.5)),
                    ],
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
                    const SizedBox(height: 8),
                    if (groups.isEmpty)
                      Text('Sin equipo asignado todavía.',
                          style: TextStyle(fontSize: 13, color: colors.text3))
                    else
                      for (final g in groups)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            Icon(Icons.groups_outlined, size: 16, color: colors.text3),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  '${g.name} · ${g.university.isEmpty ? "Universidad sin definir" : g.university} · '
                                  '${g.studentIds.length} estudiante${g.studentIds.length == 1 ? '' : 's'}',
                                  style: TextStyle(fontSize: 13, color: colors.text2)),
                            ),
                          ]),
                        ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
