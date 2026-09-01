import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../widgets/async_states.dart';
import '../../utils/app_theme.dart';
import '../../utils/colombia_cities.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/colombia_map.dart';
import '../../widgets/common.dart';

/// Mapa de Estudiantes (`design_handoff_mapa_estudiantes/README.md`):
/// dónde están los estudiantes registrados en la red, compartido por los
/// portales de Empresa y Donante. La ciudad de cada estudiante es un campo
/// cerrado de su perfil (ver [colombiaCities] y el selector en el diálogo
/// de usuario del Admin) — un estudiante sin ciudad asignada simplemente
/// no aparece en el mapa, no se inventa un dato.
class StudentsMapView extends StatefulWidget {
  const StudentsMapView({super.key});

  @override
  State<StudentsMapView> createState() => _StudentsMapViewState();
}

class _StudentsMapViewState extends State<StudentsMapView> {
  bool _isDark = true;
  // "Los que patrocino" por defecto: en el portal de un aliado es su
  // información más relevante (dónde están SUS estudiantes), no la red
  // completa — ver README, "Alcance del aliado".
  String _scope = 'mine';
  String? _hoveredCity;

  ContentColors get _colors => _isDark ? ContentColors.dark : ContentColors.light;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final colors = _colors;

    // Dos orígenes distintos, y a propósito:
    //
    // - "Los que patrocino" salen de `users()`, cuyo alcance ya lo decide el
    //   servidor para cada rol (una empresa ve su gente; un donante, los que
    //   apoya). Acá no se vuelve a filtrar por dueño.
    // - "La red completa" sale de `/talent`, el único listado con alcance más
    //   ancho, que es exactamente lo que esta vista quiere mostrar.
    //
    // Antes las dos salían de tener toda la tabla de usuarios en el navegador.
    final propios = data.users();
    final red = _scope == 'all' ? data.talent : null;

    final estado = red == null
        ? propios.map<List<_Persona>>(
            (users) => [for (final u in users) _Persona(u.city, u.university)])
        : red.map<List<_Persona>>(
            (perfiles) => [for (final t in perfiles) _Persona(t.city, t.university)]);

    return estado.when(
      loading: () => DecoratedBox(
        decoration: BoxDecoration(color: colors.bg),
        child: const Center(child: BrandLoader()),
      ),
      error: (e) => DecoratedBox(
        decoration: BoxDecoration(color: colors.bg),
        child: ErrorState(e),
      ),
      data: (personas) => _buildMap(context, data, colors, personas,
          propiosVacios: propios.valueOrNull?.isEmpty ?? false),
    );
  }

  Widget _buildMap(
    BuildContext context,
    DataProvider data,
    ContentColors colors,
    List<_Persona> activeStudents, {
    required bool propiosVacios,
  }) {
    final byCity = <String, List<_Persona>>{};
    for (final s in activeStudents) {
      if (s.city.isEmpty) continue;
      byCity.putIfAbsent(s.city, () => []).add(s);
    }
    final groups = <_CityGroup>[];
    for (final entry in byCity.entries) {
      final city = colombiaCityByName(entry.key);
      if (city != null) groups.add(_CityGroup(city: city, students: entry.value));
    }
    groups.sort((a, b) => b.students.length.compareTo(a.students.length));

    final maxValue =
        groups.isEmpty ? 1 : groups.map((g) => g.students.length).reduce(math.max);
    final tiers = studentCountTiers(maxValue);
    final points = [
      for (final g in groups)
        CityMapPoint(
          city: g.city,
          value: g.students.length,
          color: tierForValue(g.students.length, tiers).color,
          universities: (g.students.map((s) => s.university).where((u) => u.isNotEmpty).toSet().toList()
            ..sort()),
        ),
    ];
    final legend = [for (final t in tiers) MapLegendEntry(color: t.color, label: t.label)];

    final totalStudents = points.fold<int>(0, (sum, p) => sum + p.value);
    final totalUniversities = <String>{
      for (final g in groups) ...g.students.map((s) => s.university).where((u) => u.isNotEmpty),
    }.length;
    final totalDepartments = <String>{for (final p in points) p.city.department}.length;

    final tiles = [
      (value: totalStudents, label: 'Estudiantes registrados', primary: true),
      (value: points.length, label: 'Ciudades', primary: false),
      (value: totalUniversities, label: 'Universidades', primary: false),
      (value: totalDepartments, label: 'Departamentos', primary: false),
    ];

    final emptyMine = _scope == 'mine' && propiosVacios;

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
                  Wrap(
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
                                const _PulseDot(),
                                const SizedBox(width: 9),
                                Text(
                                    (_scope == 'all'
                                            ? 'Red nacional · actualizado hoy'
                                            : 'Estudiantes que patrocina tu organización')
                                        .toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 12,
                                        letterSpacing: 12 * 0.16,
                                        fontWeight: FontWeight.w600,
                                        color: colors.text3)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text('Estudiantes en el país'.toUpperCase(),
                                style: displayHeading(
                                    fontSize: 58, fontWeight: AppWeights.display, color: colors.goldInk, height: 0.94)),
                            const SizedBox(height: 12),
                            Text(
                                'Dónde están los estudiantes registrados en eduXaction Colombia. '
                                'Cada punto es una ciudad con al menos una universidad activa en la red.',
                                style: TextStyle(fontSize: 15.5, color: colors.text2, height: 1.4)),
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 460, maxWidth: 640),
                        child: LayoutBuilder(builder: (context, c) {
                          final perRow = c.maxWidth > 380 ? 4 : 2;
                          final width = (c.maxWidth - (perRow - 1) * 12) / perRow;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final t in tiles)
                                SizedBox(
                                    width: width,
                                    child: _CountUpStat(
                                        value: t.value, label: t.label, primary: t.primary, colors: colors)),
                            ],
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      _ScopeSegment(
                          scope: _scope, colors: colors, onChanged: (v) => setState(() => _scope = v)),
                      const Spacer(),
                      _ThemeGhostButton(
                          isDark: _isDark, colors: colors, onTap: () => setState(() => _isDark = !_isDark)),
                    ],
                  ),
                  const SizedBox(height: 26),
                  LayoutBuilder(builder: (context, c) {
                    final mapCard = Container(
                      height: c.maxWidth > 1080 ? 620 : 520,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                          color: colors.surface,
                          border: Border.all(color: colors.border),
                          borderRadius: BorderRadius.circular(18)),
                      child: emptyMine
                          ? _MineEmptyState(colors: colors, data: data)
                          : ColombiaStudentsMap(
                              points: points,
                              legend: legend,
                              colors: colors,
                              isDark: _isDark,
                              hoveredCity: _hoveredCity,
                              onHoverCity: (v) => setState(() => _hoveredCity = v),
                              tooltipSuffix: _scope == 'mine' ? 'estudiantes que patrocinas' : 'estudiantes',
                            ),
                    );
                    final listCard = _CityListCard(
                      points: points,
                      maxValue: maxValue,
                      hint: _scope == 'all'
                          ? 'Ordenadas por número de estudiantes'
                          : 'Solo los estudiantes vinculados a tu aporte',
                      hoveredCity: _hoveredCity,
                      onHoverCity: (v) => setState(() => _hoveredCity = v),
                      colors: colors,
                    );
                    if (c.maxWidth > 1080) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 162, child: mapCard),
                          const SizedBox(width: 20),
                          Expanded(flex: 100, child: listCard),
                        ],
                      );
                    }
                    return Column(children: [mapCard, const SizedBox(height: 20), listCard]);
                  }),
                  const SizedBox(height: 22),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.only(top: 22),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.border))),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      runSpacing: 8,
                      spacing: 24,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              height: 22,
                              width: 4,
                              child: ColoredBox(color: AppColors.gold),
                            ),
                            const SizedBox(width: 14),
                            Text('Portal de aliados · eduXaction Colombia',
                                style: TextStyle(fontSize: 12.5, color: colors.text3)),
                          ],
                        ),
                        Text('Geometría: Natural Earth (dominio público)',
                            style: TextStyle(fontSize: 12.5, color: colors.text3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Align(alignment: Alignment.bottomCenter, child: AppFooter()),
          ),
        ],
      ),
    );
  }
}

class _CityGroup {
  final ColombiaCity city;
  final List<_Persona> students;
  const _CityGroup({required this.city, required this.students});
}

class StudentCountTier {
  final int min;
  final Color color;
  final String label;
  const StudentCountTier({required this.min, required this.color, required this.label});
}

/// Umbrales de color por tamaño de comunidad, recalculados sobre el
/// máximo REAL del conjunto visible en vez de los 40/12 fijos del
/// prototipo — esos estaban calibrados para su distribución de ejemplo
/// (máximo 96). Aquí se preserva la misma proporción (~42 % y ~12,5 % del
/// máximo, la misma calibración relativa) pero aplicada al máximo real,
/// para no terminar con todos los puntos del mismo color si la escala de
/// datos cambia (ver README, sección "Color").
List<StudentCountTier> studentCountTiers(int maxValue) {
  if (maxValue <= 1) {
    return [
      StudentCountTier(
          min: 2, color: AppColors.chartSeries[2], label: '2 o más estudiantes'),
      const StudentCountTier(min: 1, color: AppColors.gold, label: '1 estudiante'),
      StudentCountTier(
          min: 0, color: AppColors.chartSeries[1], label: 'Sin estudiantes'),
    ];
  }
  final high = (maxValue * 0.417).round().clamp(2, maxValue);
  final mid = (maxValue * 0.125).round().clamp(1, high - 1);
  // Con pocos datos "high" y "mid" pueden quedar pegados (p. ej. 2 y 1):
  // "Entre 1 y 1" lee mal, mejor el número exacto en singular/plural.
  final midLabel = mid == high - 1
      ? '$mid estudiante${mid == 1 ? '' : 's'}'
      : 'Entre $mid y ${high - 1}';
  return [
    StudentCountTier(
        min: high, color: AppColors.chartSeries[2], label: '$high o más estudiantes'),
    StudentCountTier(min: mid, color: AppColors.gold, label: midLabel),
    StudentCountTier(min: 0, color: AppColors.chartSeries[1], label: 'Menos de $mid'),
  ];
}

StudentCountTier tierForValue(int value, List<StudentCountTier> tiers) {
  for (final t in tiers) {
    if (value >= t.min) return t;
  }
  return tiers.last;
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: AppColors.gold,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.55 * (1 - t)), spreadRadius: 5 * t),
            ],
          ),
        );
      },
    );
  }
}

class _CountUpStat extends StatelessWidget {
  final int value;
  final String label;
  final bool primary;
  final ContentColors colors;
  const _CountUpStat(
      {required this.value, required this.label, required this.primary, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
          color: colors.surface, border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text('${v.round()}',
                style: displayHeading(
                    fontSize: 40, fontWeight: AppWeights.display, color: primary ? colors.goldInk : colors.text, height: 1.0)),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12.5, color: colors.text3)),
        ],
      ),
    );
  }
}

class _ScopeSegment extends StatelessWidget {
  final String scope;
  final ContentColors colors;
  final ValueChanged<String> onChanged;
  const _ScopeSegment({required this.scope, required this.colors, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(String value, String label) {
      final active = scope == value;
      return HoverBuilder(
        cursor: SystemMouseCursors.click,
        builder: (context, hover) => GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
            decoration:
                BoxDecoration(color: active ? colors.goldSoft : Colors.transparent, borderRadius: BorderRadius.circular(999)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? colors.goldInk : (hover ? colors.text : colors.text3))),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration:
          BoxDecoration(color: colors.surface, border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('all', 'Toda la red'),
        const SizedBox(width: 4),
        seg('mine', 'Los que patrocino'),
      ]),
    );
  }
}

class _ThemeGhostButton extends StatelessWidget {
  final bool isDark;
  final ContentColors colors;
  final VoidCallback onTap;
  const _ThemeGhostButton({required this.isDark, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: hover ? colors.goldInk : colors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 18, color: hover ? colors.goldInk : colors.text2),
              const SizedBox(width: 9),
              Text('Tema', style: TextStyle(fontSize: 13, color: hover ? colors.goldInk : colors.text2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MineEmptyState extends StatelessWidget {
  final ContentColors colors;
  final DataProvider data;
  const _MineEmptyState({required this.colors, required this.data});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: EmptyState(
          icon: Icons.public_off,
          title: 'Aún no hay estudiantes vinculados',
          message: 'Todavía no hay estudiantes vinculados a tu aporte. En cuanto tu administrador '
              'asigne alguno, aparecerá aquí en el mapa.',
          secondaryLabel: 'Escribir a mi administrador',
          secondaryIcon: Icons.mail_outline,
          onSecondary: () => _contactAdmin(context),
          colors: colors,
        ),
      ),
    );
  }

  /// Le avisa al equipo, sin enumerar administradores.
  ///
  /// Antes buscaba el correo de un admin en la lista completa de usuarios y
  /// abría el cliente de correo. Ese listado ya no existe para un aliado —y no
  /// debería—: el aviso va por la bandeja de la plataforma, y a quién le llega
  /// lo resuelve el servidor.
  Future<void> _contactAdmin(BuildContext context) async {
    try {
      await data.notifyAdmins(
        title: 'Solicitud de estudiantes patrocinados',
        body: 'Un aliado pidió que le asignen estudiantes a su aporte.',
      );
      if (context.mounted) {
        showAppSnack(context, 'Le avisamos a tu administrador.');
      }
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }
}

class _CityListCard extends StatelessWidget {
  final List<CityMapPoint> points;
  final int maxValue;
  final String hint;
  final String? hoveredCity;
  final ValueChanged<String?> onHoverCity;
  final ContentColors colors;
  const _CityListCard({
    required this.points,
    required this.maxValue,
    required this.hint,
    required this.hoveredCity,
    required this.onHoverCity,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
          color: colors.surface, border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Ciudades'.toUpperCase(),
              style: displayHeading(fontSize: 24, fontWeight: AppWeights.display, color: colors.text)),
          const SizedBox(height: 4),
          Text(hint, style: TextStyle(fontSize: 12.5, color: colors.text3)),
          const SizedBox(height: 16),
          if (points.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('Sin ciudades para este alcance todavía.',
                  style: TextStyle(fontSize: 13, color: colors.text3)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 470),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < points.length; i++)
                      _CityRow(
                        rank: i + 1,
                        point: points[i],
                        maxValue: maxValue,
                        active: hoveredCity == points[i].city.name,
                        onHover: (on) => onHoverCity(on ? points[i].city.name : null),
                        colors: colors,
                      ),
                  ],
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 18),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 17, color: colors.goldInk),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                      'La ciudad es la que el estudiante (o su administrador) eligió en su perfil. '
                      'Los estudiantes sin ciudad asignada todavía no aparecen en el mapa.',
                      style: TextStyle(fontSize: 12.5, height: 1.5, color: colors.text3)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  final int rank;
  final CityMapPoint point;
  final int maxValue;
  final bool active;
  final ValueChanged<bool> onHover;
  final ContentColors colors;
  const _CityRow({
    required this.rank,
    required this.point,
    required this.maxValue,
    required this.active,
    required this.onHover,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    // `onTap` además del hover: en una pantalla táctil no hay `hover`, así
    // que sin esto tocar una ciudad de la lista no hacía nada.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        onTap: () => onHover(!active),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        margin: const EdgeInsets.only(bottom: 3),
        decoration:
            BoxDecoration(color: active ? colors.surface2 : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            SizedBox(
                width: 22,
                child: Text('$rank', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, color: colors.text3))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${point.city.name} · ${point.city.department}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: colors.text)),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                        minHeight: 5,
                        value: maxValue == 0 ? 0 : point.value / maxValue,
                        backgroundColor: active ? colors.border : colors.surface2,
                        valueColor: AlwaysStoppedAnimation(point.color)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 30,
              child: Text('${point.value}',
                  textAlign: TextAlign.right,
                  style: displayHeading(fontSize: 19, fontWeight: AppWeights.display, color: colors.text2)),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

/// Lo único que el mapa necesita de cada persona: dónde está y de qué
/// universidad. Se declara acá para que las dos fuentes —`users()` y
/// `/talent`, que devuelven modelos distintos— entren por el mismo camino.
class _Persona {
  final String city;
  final String university;
  const _Persona(this.city, this.university);
}
