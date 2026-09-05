import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../models/progress.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/async_value.dart';
import '../../utils/constants.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';
import '../../widgets/async_states.dart';
import '../../widgets/charts.dart' show ProgressRing;
import '../../widgets/common.dart';
import '../../widgets/file_upload_field.dart';
import '../../widgets/portal_shell.dart';
import '../../widgets/video_player_dialog.dart';
import '../../widgets/lesson_visuals.dart';
import '../shared/lab_detail_view.dart';
import 'course_detail_view.dart';

/// Flujo completo de la Ruta de Impacto del estudiante:
/// Laboratorios → Laboratorio (fases) → Fase (objetivos + módulos) →
/// Módulo (cursos, entregas/lecturas y, en el módulo de mentoría, el
/// botón para unirse a la reunión).

// ---------------------------------------------------------------------------
// Tab "Laboratorios": rediseño de alta fidelidad según
// `design_handoff_portal_estudiante/README.md` (pantalla 8) — cada
// laboratorio con identidad de color, avance legible (una sola fuente de
// verdad: [DataProvider.labModuleProgress], sumando los módulos de sus
// fases) y una entrada clara al detalle ([LabDetailBody], pantalla 9).
// ---------------------------------------------------------------------------

class LabsView extends StatelessWidget {
  const LabsView({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;

    // Dos fuentes distintas y a propósito: `laboratories` son LOS SUYOS, con
    // su estructura completa; `allLaboratories` es la red entera en versión
    // reducida. El avance sale de la Ruta, que lo calcula el servidor.
    return combine3(
      data.laboratories,
      data.allLaboratories,
      data.rutaProgress,
    ).when(
      loading: () => const _LabsShell(child: CardListSkeleton(count: 2)),
      error: (e) => _LabsShell(
        child: ErrorState(e, onRetry: data.reloadLaboratories),
      ),
      data: (values) {
        final (myLabs, allLabs, ruta) = values;
        final otherLabs = allLabs
            .where((l) => !myLabs.any((m) => m.id == l.id))
            .toList();

        return ContentScreenShell(
          eyebrow: myLabs.isEmpty
              ? '${allLabs.length} en la red'
              : '${myLabs.length} ${myLabs.length == 1 ? 'laboratorio asignado' : 'laboratorios asignados'} '
                  '· ${allLabs.length} en la red',
          title: 'Laboratorios',
          subtitle:
              'Un laboratorio es un área de trabajo de eduXaction Colombia: '
              'reúne una Ruta de Impacto por fases, cursos y un LXD que la '
              'acompaña. Entre al suyo para ver qué sigue.',
          bodyBuilder: (context, colors, isDark) {
            if (myLabs.isEmpty) {
              return EmptyState(
                icon: Icons.science_outlined,
                title: 'Sin laboratorios asignados',
                message: 'Su administrador todavía no le ha asignado un '
                    'laboratorio. Sin uno no tiene Ruta de Impacto ni cursos '
                    'de área.',
                primaryLabel: 'Actualizar',
                onPrimary: data.reloadLaboratories,
                colors: colors,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabsGrid(
                    labs: myLabs,
                    ruta: ruta,
                    student: student,
                    colors: colors),
                if (otherLabs.isNotEmpty) ...[
                  const SizedBox(height: 36),
                  Text('OTROS LABORATORIOS DE LA RED',
                      style: displayHeading(
                          fontSize: 30,
                          fontWeight: AppWeights.display,
                          color: colors.text)),
                  const SizedBox(height: 6),
                  Text(
                      'Solicite a su administrador que le asigne uno si su proyecto lo necesita.',
                      style: TextStyle(fontSize: 13.5, color: colors.text3)),
                  const SizedBox(height: 16),
                  _OtherLabsGrid(labs: otherLabs, colors: colors),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

/// El marco de la pantalla mientras carga o falla, para que el encabezado no
/// aparezca y desaparezca entre estados.
class _LabsShell extends StatelessWidget {
  final Widget child;
  const _LabsShell({required this.child});

  @override
  Widget build(BuildContext context) => ContentScreenShell(
        eyebrow: 'Laboratorios',
        title: 'Laboratorios',
        bodyBuilder: (context, colors, isDark) => child,
      );
}

class _LabsGrid extends StatelessWidget {
  final List<Laboratory> labs;
  final RutaProgress ruta;
  final AppUser student;
  final ContentColors colors;
  const _LabsGrid(
      {required this.labs,
      required this.ruta,
      required this.student,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const minCard = 420.0;
      const gap = 20.0;
      final columns =
          math.max(1, ((c.maxWidth + gap) / (minCard + gap)).floor());
      final width = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < labs.length; i++)
            SizedBox(
              width: width,
              child: Entrance(
                  delayMs: 70 * i,
                  child: _LabCard(
                      lab: labs[i],
                      progress: ruta.labById(labs[i].id),
                      student: student,
                      colors: colors)),
            ),
        ],
      );
    });
  }
}

/// Tarjeta de un laboratorio asignado. Toda la tarjeta es clicable y navega
/// al detalle con una ruta con nombre real (`/student/lab/<id>`) para que la
/// URL cambie y el botón atrás del navegador funcione.
///
/// El avance —fase en curso, módulos hechos, si hay algo vencido— sale
/// entero de [LabProgress], que calcula el servidor. Antes cada dato se
/// recalculaba acá con una llamada distinta y podían no coincidir entre sí.
class _LabCard extends StatelessWidget {
  final Laboratory lab;
  final LabProgress? progress;
  final AppUser student;
  final ContentColors colors;
  const _LabCard(
      {required this.lab,
      required this.progress,
      required this.student,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final accent = labColorFor(lab.id);
    // El encabezado se pinta con el color del laboratorio, que puede ser
    // claro u oscuro: la tinta se elige por contraste, no fija en blanco.
    final tinta = inkSobre(accent);
    final odsNum = labOdsNumberFor(lab.id);
    final compacto = context.isCompact;

    final phases = progress?.phases ?? const <PhaseProgress>[];
    final modules = progress?.moduleProgress ?? (done: 0, total: 0);
    final currentPhaseIdx = phases.indexWhere((p) => !p.isComplete);
    final allComplete = phases.isNotEmpty && currentPhaseIdx == -1;
    final phaseCount = phases.isEmpty ? lab.phases.length : phases.length;
    final currentPhaseDisplay =
        allComplete ? phaseCount : currentPhaseIdx + 1;
    final overdue = phases.any((p) =>
        p.isUnlocked && p.deadlineStatus == DeadlineStatus.overdue);

    final courses = (data.courses.valueOrNull ?? const <Course>[])
        .where((c) => c.laboratoryId == lab.id)
        .toList();
    final hours = courses.fold<int>(0, (sum, c) => sum + c.estimatedHours);
    final lxd = lab.lxds.firstOrNull;

    void open() => Navigator.pushNamed(
        context, '${AppRoutes.forRole(student.role)}/lab/${lab.id}');

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => GestureDetector(
        onTap: open,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          clipBehavior: Clip.antiAlias,
          transform: Matrix4.translationValues(0, hover ? -5 : 0, 0),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: hover ? accent : colors.border),
            borderRadius: BorderRadius.circular(20),
            boxShadow: hover ? colors.shadow : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                // 120 y no 108: un nombre de dos líneas —"Laboratorio IA
                // y Tecnología"— dejaba el título pegado a la píldora de
                // estado.
                height: compacto ? 120 : 136,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: accent),
                    const Positioned.fill(child: CustomPaint(painter: StripePainter())),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.35, 1.0],
                          colors: [Colors.transparent, colors.veil],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: compacto ? -18 : -24,
                      child: Text('$odsNum',
                          style: displayHeading(
                              fontSize: compacto ? 76 : 104,
                              fontWeight: AppWeights.display,
                              color: tinta.withValues(alpha: 0.28),
                              height: 1.0)),
                    ),
                    Positioned(
                      left: 20,
                      top: 18,
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: tinta.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(11)),
                            child: Icon(Icons.science_outlined,
                                size: 21, color: tinta),
                          ),
                          const SizedBox(width: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color: tinta.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999)),
                                child: Text(overdue ? 'ENTREGA VENCIDA' : 'EN CURSO',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 11.5 * 0.1,
                                        color: tinta)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 20,
                      // En teléfono la marca de agua es más chica, así que el
                      // título necesita menos reserva a la derecha; a 32 px
                      // ocupaba las dos líneas y llenaba la banda entera.
                      right: compacto ? 72 : 100,
                      bottom: 16,
                      child: Text(lab.name.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: displayHeading(
                              fontSize: compacto ? 22 : 32,
                              fontWeight: AppWeights.display,
                              color: tinta,
                              height: 1.0)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (lab.description.isNotEmpty)
                      Text(lab.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, height: 1.5, color: colors.text2)),
                    const SizedBox(height: 16),
                    StageRail(
                      accentColor: accent,
                      colors: colors,
                      currentIndex: allComplete
                          ? phaseCount - 1
                          : math.max(0, currentPhaseIdx),
                      totalOverride: phaseCount,
                      caption: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              allComplete
                                  ? 'Fase $phaseCount de $phaseCount completa'
                                  : 'Fase $currentPhaseDisplay de $phaseCount en curso',
                              style: TextStyle(fontSize: 12, color: colors.text3)),
                          const SizedBox(height: 2),
                          Text(
                              modules.total == 0
                                  ? 'Sin módulos aún'
                                  : '${modules.done}/${modules.total} módulos',
                              style: TextStyle(fontSize: 12, color: colors.text3)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(icon: Icons.route, label: '$phaseCount fases', colors: colors),
                        _MetaChip(icon: Icons.school, label: '${courses.length} cursos', colors: colors),
                        _MetaChip(icon: Icons.schedule, label: '$hours h estimadas', colors: colors),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Divider(height: 1, color: colors.border),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                          child: Text(
                              lxd == null || lxd.name.isEmpty ? '?' : lxd.name[0].toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(lxd == null ? 'Sin LXD asignado' : 'LXD: ${lxd.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: colors.text3)),
                        ),
                        const SizedBox(width: 10),
                        TextButton.icon(
                          onPressed: open,
                          style: TextButton.styleFrom(
                            backgroundColor: colors.goldSoft,
                            foregroundColor: colors.goldInk,
                            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                          ),
                          icon: const Icon(Icons.arrow_forward, size: 17),
                          label: const Text('Entrar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ContentColors colors;
  const _MetaChip({required this.icon, required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surface2,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.text3),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11.5, color: colors.text2)),
        ],
      ),
    );
  }
}

/// Sección "Otros laboratorios de la red" — adición del diseño confirmada
/// por el usuario, con el conteo de equipos calculado de datos reales
/// ([DataProvider.teamsInLabArea]: grupos con al menos un estudiante
/// asignado a esa área), no la cifra inventada del prototipo.
class _OtherLabsGrid extends StatelessWidget {
  final List<Laboratory> labs;
  final ContentColors colors;
  const _OtherLabsGrid({required this.labs, required this.colors});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const minCard = 268.0;
      const gap = 14.0;
      final columns =
          math.max(1, ((c.maxWidth + gap) / (minCard + gap)).floor());
      final width = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final lab in labs)
            SizedBox(width: width, child: _OtherLabCard(lab: lab, colors: colors)),
        ],
      );
    });
  }
}

class _OtherLabCard extends StatelessWidget {
  final Laboratory lab;
  final ContentColors colors;
  const _OtherLabCard({required this.lab, required this.colors});

  @override
  Widget build(BuildContext context) {
    final accent = labColorFor(lab.id);
    final teams = lab.teamCount;

    return KeyboardHoverBuilder(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              settings: RouteSettings(name: '${AppRoutes.labs}/${lab.id}'),
              builder: (_) => LabDetailView(labId: lab.id))),
      builder: (context, hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: hover ? colors.surface2 : colors.surface,
          border: Border.all(color: hover ? accent : colors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.science_outlined, size: 19, color: accent),
                      ),
                      const SizedBox(height: 10),
                      Text(lab.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text)),
                      if (lab.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(lab.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: colors.text3)),
                      ],
                      const SizedBox(height: 8),
                      Text(teams == 1 ? '1 equipo en la red' : '$teams equipos en la red',
                          style: TextStyle(fontSize: 11.5, color: colors.text3)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detalle de laboratorio (pantalla 9): identidad, avance, Ruta de Impacto
// con las 4 fases del estado (Completa/Vencida/Disponible/Bloqueada — nunca
// "Bloqueada" a secas, siempre con la razón), cursos del laboratorio y la
// tarjeta del LXD. Vive "dentro" de la pestaña Laboratorios vía
// `PortalShell.contentOverride` (ver [StudentPortal.openLabId]), así que no
// repite el header ni la barra lateral del portal.
// ---------------------------------------------------------------------------

class LabDetailBody extends StatefulWidget {
  final String labId;
  const LabDetailBody({super.key, required this.labId});

  @override
  State<LabDetailBody> createState() => _LabDetailBodyState();
}

class _LabDetailBodyState extends State<LabDetailBody> {
  bool _isDark = true;
  ContentColors get _colors => _isDark ? ContentColors.dark : ContentColors.light;

  // Siempre navega explícitamente en vez de intentar Navigator.pop(): en
  // Flutter web, `canPop()` puede devolver true incluso cuando se llegó por
  // URL directa (sin nada real que hacer pop), lo que rompía este botón —
  // ver la nota en `main.dart` junto a la ruta `/laboratorios`.
  void _goBack(AppUser student) {
    Navigator.pushReplacementNamed(context, '${AppRoutes.forRole(student.role)}/laboratorios');
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final colors = _colors;

    // La estructura del laboratorio y el avance de esta persona son dos
    // fuentes distintas: la primera describe el laboratorio, la segunda dice
    // cómo va quien lo mira. Se piden juntas para no dibujar media pantalla.
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.bg),
      child: combine2(data.labById(widget.labId), data.rutaProgress).when(
        loading: () => const Center(child: BrandLoader()),
        error: (e) => Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: e is NotFoundError
                ? EmptyState(
                    icon: Icons.science_outlined,
                    title: 'Laboratorio no encontrado',
                    message:
                        'Puede que ya no exista o que el enlace esté mal escrito.',
                    primaryLabel: 'Todos los laboratorios',
                    onPrimary: () => _goBack(student),
                    colors: colors,
                  )
                : ErrorState(e, onRetry: data.reloadRutaProgress),
          ),
        ),
        data: (values) {
          final (lab, ruta) = values;
          return _content(context, lab, ruta.labById(lab.id), student, colors);
        },
      ),
    );
  }

  Widget _content(BuildContext context, Laboratory lab, LabProgress? progress,
      AppUser student, ContentColors colors) {
    final data = context.watch<DataProvider>();

    final phases = progress?.phases ?? const <PhaseProgress>[];
    final modules = progress?.moduleProgress ?? (done: 0, total: 0);
    final currentPhaseIdx = phases.indexWhere((p) => !p.isComplete);
    final phaseCount = phases.isEmpty ? lab.phases.length : phases.length;
    final currentPhaseDisplay =
        currentPhaseIdx == -1 ? phaseCount : currentPhaseIdx + 1;

    final courses = (data.courses.valueOrNull ?? const <Course>[])
        .where((c) => c.laboratoryId == lab.id)
        .toList();
    final hours = courses.fold<int>(0, (sum, c) => sum + c.estimatedHours);
    final lxd = lab.lxds.firstOrNull;
    final accent = labColorFor(lab.id);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 34, 40, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _BackButton(colors: colors, onTap: () => _goBack(student)),
                    const Spacer(),
                    _ContentThemeToggle(
                        isDark: _isDark,
                        colors: colors,
                        onTap: () => setState(() => _isDark = !_isDark)),
                  ],
                ),
                const SizedBox(height: 20),
                _LabIdentityBand(
                    lab: lab,
                    modules: modules,
                    currentPhaseDisplay: currentPhaseDisplay,
                    totalPhases: phaseCount,
                    colors: colors),
                const SizedBox(height: 20),
                _LabStatsRow(
                    phaseCount: phaseCount,
                    modules: modules,
                    courseCount: courses.length,
                    hours: hours,
                    colors: colors),
                const SizedBox(height: 32),
                Text('RUTA DE IMPACTO',
                    style: displayHeading(
                        fontSize: 34,
                        fontWeight: AppWeights.display,
                        color: colors.text)),
                const SizedBox(height: 4),
                Text(
                    'Las fases se abren en orden. Su LXD publica el contenido de cada una.',
                    style: TextStyle(fontSize: 13.5, color: colors.text3)),
                const SizedBox(height: 18),
                _PhaseCardsGrid(
                    lab: lab, phases: phases, student: student, colors: colors),
                const SizedBox(height: 32),
                LayoutBuilder(builder: (context, c) {
                  final coursesCard = _LabCoursesCard(
                      courses: courses, accent: accent, colors: colors);
                  final lxdCard = _LabLxdCard(
                      lab: lab, lxd: lxd, accent: accent, colors: colors);
                  if (c.maxWidth > 760) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 150, child: coursesCard),
                        const SizedBox(width: 20),
                        Expanded(flex: 100, child: lxdCard),
                      ],
                    );
                  }
                  return Column(
                      children: [coursesCard, const SizedBox(height: 20), lxdCard]);
                }),
              ],
            ),
          ),
        ),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Align(alignment: Alignment.bottomCenter, child: AppFooter()),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  final ContentColors colors;
  final VoidCallback onTap;
  const _BackButton({required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(11, 9, 15, 9),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: hover ? colors.goldInk : colors.border),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back, size: 18, color: hover ? colors.goldInk : colors.text2),
              const SizedBox(width: 8),
              Text('Todos los laboratorios',
                  style: TextStyle(fontSize: 13, color: hover ? colors.goldInk : colors.text2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentThemeToggle extends StatelessWidget {
  final bool isDark;
  final ContentColors colors;
  final VoidCallback onTap;
  const _ContentThemeToggle({required this.isDark, required this.colors, required this.onTap});

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
          child: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 21, color: hover ? AppColors.gold : colors.text2),
        ),
      ),
    );
  }
}

class _LabIdentityBand extends StatelessWidget {
  final Laboratory lab;

  /// Módulos hechos/totales de toda la Ruta. Única fuente para el anillo y
  /// para el texto: no hay dos cifras que puedan desincronizarse.
  final ({int done, int total}) modules;
  final int currentPhaseDisplay;
  final int totalPhases;
  final ContentColors colors;
  const _LabIdentityBand(
      {required this.lab,
      required this.modules,
      required this.currentPhaseDisplay,
      required this.totalPhases,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    final accent = labColorFor(lab.id);
    final odsNum = labOdsNumberFor(lab.id);
    final pct = modules.total == 0 ? 0.0 : modules.done / modules.total;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(32, 30, 32, 28),
        color: accent,
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: StripePainter())),
            Positioned(
              right: 24,
              bottom: -30,
              child: Text('$odsNum',
                  style: displayHeading(
                      fontSize: 132, fontWeight: AppWeights.display, color: Colors.white.withValues(alpha: 0.24), height: 1.0)),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('LABORATORIO',
                          style: TextStyle(
                              fontSize: 11.5,
                              letterSpacing: 11.5 * 0.16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.85))),
                      const SizedBox(height: 8),
                      Text(lab.name.toUpperCase(),
                          style: displayHeading(
                              fontSize: 52, fontWeight: AppWeights.display, color: Colors.white, height: 0.96)),
                      if (lab.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Text(lab.description,
                              style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.9), height: 1.4)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ProgressRing(value: pct, size: 76, strokeWidth: 8, percentFontSize: 20),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Su avance',
                                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75))),
                              const SizedBox(height: 4),
                              Text('Fase $currentPhaseDisplay de $totalPhases',
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.white)),
                              const SizedBox(height: 2),
                              Text('${modules.done} de ${modules.total} módulos',
                                  style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LabStatsRow extends StatelessWidget {
  final int phaseCount;
  final ({int done, int total}) modules;
  final int courseCount;
  final int hours;
  final ContentColors colors;
  const _LabStatsRow(
      {required this.phaseCount,
      required this.modules,
      required this.courseCount,
      required this.hours,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (value: '$phaseCount', label: 'Fases en la ruta', primary: true),
      (value: '${modules.total}', label: 'Módulos publicados', primary: false),
      (value: '$courseCount', label: 'Cursos del laboratorio', primary: false),
      (value: '$hours h', label: 'Horas estimadas', primary: false),
    ];
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth > 700 ? 4 : 2;
      final width = (c.maxWidth - (perRow - 1) * 12) / perRow;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final t in tiles)
            SizedBox(
              width: width,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                    color: colors.surface, border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.value,
                        style: displayHeading(
                            fontSize: 40,
                            fontWeight: AppWeights.display,
                            color: t.primary ? colors.goldInk : colors.text,
                            height: 1.0)),
                    const SizedBox(height: 6),
                    Text(t.label, style: TextStyle(fontSize: 12.5, color: colors.text3)),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _PhaseCardsGrid extends StatelessWidget {
  final Laboratory lab;

  /// Avance por fase de quien mira. Viene vacío para un rol sin Ruta propia.
  final List<PhaseProgress> phases;
  final AppUser student;
  final ContentColors colors;
  const _PhaseCardsGrid(
      {required this.lab,
      required this.phases,
      required this.student,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    if (phases.isEmpty) {
      return Text(
          'Este laboratorio todavía no tiene fases publicadas.',
          style: TextStyle(fontSize: 13.5, color: colors.text3));
    }
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth > 940 ? 3 : (c.maxWidth > 620 ? 2 : 1);
      final width = (c.maxWidth - (perRow - 1) * 16) / perRow;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (var i = 0; i < phases.length; i++)
            SizedBox(
              width: width,
              child: Entrance(
                  delayMs: 70 * i,
                  child: _PhaseDetailCard(
                      labId: lab.id,
                      phase: phases[i],
                      index: i,
                      colors: colors)),
            ),
        ],
      );
    });
  }
}

enum _PhaseUiState { complete, overdue, available, locked }

/// Tarjeta de fase del detalle (pantalla 9): 4 estados con color e ícono
/// propios (tabla del README) y, si está bloqueada, **siempre** una razón
/// concreta — nunca la palabra "Bloqueada" a secas. Una fase bloqueada
/// nunca muestra su fecha en rojo: eso está reservado para lo que el
/// estudiante puede abrir de verdad.
class _PhaseDetailCard extends StatelessWidget {
  final String labId;
  final PhaseProgress phase;
  final int index;
  final ContentColors colors;
  const _PhaseDetailCard(
      {required this.labId,
      required this.phase,
      required this.index,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    final accent = labColorFor(labId);
    final title = phase.title.isEmpty ? 'Fase ${index + 1}' : phase.title;

    // Los cuatro estados salen del servidor: el desbloqueo, la completitud y
    // el estado de la fecha. Antes se recalculaban acá, cada uno con su
    // llamada, y la tarjeta podía contradecir al riel de fases de al lado.
    final published = phase.hasPublishedContent;
    final state = phase.isComplete
        ? _PhaseUiState.complete
        : (!phase.isUnlocked || !published)
            ? _PhaseUiState.locked
            : (phase.deadlineStatus == DeadlineStatus.overdue
                ? _PhaseUiState.overdue
                : _PhaseUiState.available);

    final (chipBg, chipColor, chipIcon, chipLabel) = switch (state) {
      _PhaseUiState.complete => (
          AppColors.statusGood.withValues(alpha: 0.16),
          AppColors.statusGood,
          Icons.check_circle,
          'Completa'
        ),
      _PhaseUiState.overdue => (
          colors.alertInk.withValues(alpha: 0.16),
          colors.alertInk,
          Icons.warning_amber_rounded,
          'Vencida'
        ),
      _PhaseUiState.available => (colors.goldSoft, colors.goldInk, Icons.lock_open, 'Disponible'),
      _PhaseUiState.locked => (colors.surface2, colors.text3, Icons.lock_outline, 'Bloqueada'),
    };

    final (circleBg, circleBorder, circleTextColor) = switch (state) {
      _PhaseUiState.complete => (
          AppColors.statusGood.withValues(alpha: 0.16),
          AppColors.statusGood,
          AppColors.statusGood
        ),
      _PhaseUiState.overdue || _PhaseUiState.available => (accent, accent, Colors.white),
      _PhaseUiState.locked => (colors.surface2, colors.border, colors.text3),
    };

    final done = phase.modulesDone;
    final total = phase.modulesTotal;
    final showModules = state != _PhaseUiState.locked;

    String lockedReason() => !phase.isUnlocked
        ? 'Se abre cuando completes la Fase $index'
        : 'Su LXD publicará el contenido de esta fase.';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: state == _PhaseUiState.locked ? colors.border : accent),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: circleBg,
                  border: Border.all(color: circleBorder, width: 2),
                ),
                child: Text('${index + 1}',
                    style: displayHeading(fontSize: 22, fontWeight: AppWeights.display, color: circleTextColor)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chipIcon, size: 14, color: chipColor),
                    const SizedBox(width: 5),
                    Text(chipLabel, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: chipColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title.toUpperCase(),
              style: displayHeading(fontSize: 27, fontWeight: AppWeights.display, color: colors.text)),
          if (phase.description.isNotEmpty || !published) ...[
            const SizedBox(height: 8),
            Text(
                phase.description.isNotEmpty
                    ? phase.description
                    : 'Su LXD aún no ha publicado el contenido de esta fase.',
                style: TextStyle(fontSize: 13.5, height: 1.5, color: colors.text2)),
          ],
          const SizedBox(height: 14),
          if (!showModules)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 17, color: colors.text3),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(lockedReason(), style: TextStyle(fontSize: 12.5, color: colors.text3))),
                ],
              ),
            )
          else ...[
            for (var j = 0; j < phase.modules.length; j++)
              _ModuleSummaryRow(
                  labId: labId,
                  module: phase.modules[j],
                  phaseIndex: index,
                  moduleIndex: j,
                  colors: colors),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(total == 0 ? 'Sin módulos publicados' : '$done de $total módulos',
                    style: TextStyle(fontSize: 11.5, color: colors.text3)),
                if (total > 0)
                  Text('${(done / total * 100).round()}%', style: TextStyle(fontSize: 11.5, color: colors.text3)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  minHeight: 6,
                  value: total == 0 ? 0 : done / total,
                  backgroundColor: colors.surface2,
                  valueColor: AlwaysStoppedAnimation(accent)),
            ),
          ],
          if (phase.deadlineDate != null) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: colors.border),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.event, size: 17, color: colors.text3),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      state == _PhaseUiState.locked
                          ? 'Fecha prevista por el laboratorio: '
                              '${DateFormat('d MMM yyyy', 'es').format(phase.deadlineDate!)}'
                          : (state == _PhaseUiState.overdue
                              ? 'Entrega vencida: ${DateFormat('d MMM yyyy', 'es').format(phase.deadlineDate!)}'
                              : 'Entrega: ${DateFormat('d MMM yyyy', 'es').format(phase.deadlineDate!)}'),
                      style: TextStyle(
                          fontSize: 12.5,
                          color: state == _PhaseUiState.overdue ? colors.alertInk : colors.text3)),
                ),
              ],
            ),
          ],
          if ((state == _PhaseUiState.available || state == _PhaseUiState.overdue) &&
              phase.modules.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final nextIndex =
                      phase.modules.indexWhere((m) => !m.isComplete);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ModuleDetailScreen(
                              labId: labId,
                              phaseIndex: index,
                              moduleIndex: nextIndex == -1 ? 0 : nextIndex)));
                },
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(done == 0 ? 'Empezar la fase' : 'Continuar la fase'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final ContentColors colors;
  final Widget child;
  const _DetailCard({required this.icon, required this.title, required this.colors, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colors.goldSoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 19, color: colors.goldInk),
              ),
              const SizedBox(width: 11),
              Text(title.toUpperCase(),
                  style: displayHeading(fontSize: 24, fontWeight: AppWeights.display, color: colors.text)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LabCoursesCard extends StatelessWidget {
  final List<Course> courses;
  final Color accent;
  final ContentColors colors;
  const _LabCoursesCard(
      {required this.courses, required this.accent, required this.colors});

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      icon: Icons.school_outlined,
      title: 'Cursos del laboratorio',
      colors: colors,
      child: courses.isEmpty
          ? DashedRRectBorder(
              color: colors.border,
              radius: 14,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                child: Column(
                  children: [
                    Icon(Icons.library_books_outlined, size: 30, color: colors.text3),
                    const SizedBox(height: 12),
                    Text(
                        'Este laboratorio todavía no tiene cursos publicados. '
                        'Su LXD los abrirá junto con la Fase 1.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: colors.text2)),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                for (final c in courses)
                  _LabCourseRow(course: c, accent: accent, colors: colors),
              ],
            ),
    );
  }
}

class _LabCourseRow extends StatelessWidget {
  final Course course;
  final Color accent;
  final ContentColors colors;
  const _LabCourseRow(
      {required this.course, required this.accent, required this.colors});

  @override
  Widget build(BuildContext context) {
    // El avance vino con la lista de cursos (`include=progress`): leerlo acá
    // no dispara una petición por fila.
    final progress =
        context.watch<DataProvider>().courseProgress(course.id).valueOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HoverBuilder(
        cursor: SystemMouseCursors.click,
        builder: (context, hover) => GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  settings: RouteSettings(name: '${AppRoutes.courses}/${course.id}'),
                  builder: (_) => CourseDetailView(courseId: course.id))),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: hover ? colors.goldSoft : colors.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.menu_book_outlined, size: 19, color: Colors.white),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(course.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: colors.text)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                            minHeight: 5,
                            value: progress?.ratio ?? 0,
                            backgroundColor: colors.border,
                            valueColor: AlwaysStoppedAnimation(accent)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                    '${progress?.completedLessons ?? 0}/${progress?.totalLessons ?? 0}',
                    style: TextStyle(fontSize: 12.5, color: colors.text3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta "Su LXD" — datos reales del laboratorio (`DataProvider.lxdForLab`,
/// `AppUser.email`, `extra['availability']`). El botón "Agendar mentoría"
/// no fabrica una integración de calendario que el estudiante no tiene
/// permiso de usar (crear eventos es exclusivo de Admin/LXD/Mentor): si el
/// LXD publicó su disponibilidad, abre un diálogo con el horario y un
/// enlace `mailto:` para coordinar; si no, el botón queda deshabilitado con
/// el porqué.
class _LabLxdCard extends StatelessWidget {
  final Laboratory lab;
  final LabStaff? lxd;
  final Color accent;
  final ContentColors colors;
  const _LabLxdCard({required this.lab, required this.lxd, required this.accent, required this.colors});

  @override
  Widget build(BuildContext context) {
    final lxd = this.lxd;
    return _DetailCard(
      icon: Icons.diversity_3,
      title: 'Su LXD',
      colors: colors,
      child: lxd == null
          ? Text('Este laboratorio todavía no tiene un LXD asignado.',
              style: TextStyle(fontSize: 13.5, color: colors.text3))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sin enlace a un perfil: no existe —ni debería— un endpoint
                // que le permita a un estudiante leer la cuenta de otra
                // persona. Nombre, correo y disponibilidad es lo que hace
                // falta para coordinar una mentoría.
                Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                        child: Text(lxd.name.isEmpty ? '?' : lxd.name[0].toUpperCase(),
                            style: displayHeading(fontSize: 22, fontWeight: AppWeights.display, color: Colors.white)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(lxd.name,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colors.text)),
                            Text('Learning Experience Designer',
                                style: TextStyle(fontSize: 12.5, color: colors.text3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Divider(height: 1, color: colors.border),
                const SizedBox(height: 14),
                _LxdInfoRow(
                    icon: Icons.schedule,
                    text: lxd.availability.isEmpty
                        ? 'Sin horario publicado'
                        : lxd.availability,
                    colors: colors),
                const SizedBox(height: 10),
                _LxdInfoRow(icon: Icons.mail_outline, text: lxd.email, colors: colors),
                const SizedBox(height: 18),
                _ScheduleMentoriaButton(lab: lab, lxd: lxd, colors: colors),
              ],
            ),
    );
  }
}

class _LxdInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final ContentColors colors;
  const _LxdInfoRow({required this.icon, required this.text, required this.colors});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: colors.text3),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: colors.text2))),
        ],
      );
}

class _ScheduleMentoriaButton extends StatelessWidget {
  final Laboratory lab;
  final LabStaff lxd;
  final ContentColors colors;
  const _ScheduleMentoriaButton({required this.lab, required this.lxd, required this.colors});

  @override
  Widget build(BuildContext context) {
    final availability = lxd.availability;
    final enabled = availability.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: enabled ? () => _showDialog(context, availability) : null,
            icon: const Icon(Icons.event_available, size: 18),
            label: const Text('Agendar mentoría'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.goldInk,
              side: BorderSide(color: enabled ? colors.goldInk : colors.border),
            ),
          ),
        ),
        if (!enabled)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Su LXD todavía no publicó su disponibilidad.',
                style: TextStyle(fontSize: 12, color: colors.text3)),
          ),
      ],
    );
  }

  Future<void> _showDialog(BuildContext context, String availability) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agendar mentoría', style: TextStyle(fontSize: 18)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Disponibilidad de ${lxd.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 6),
              Text(availability, style: const TextStyle(fontSize: 13.5, height: 1.5)),
              const SizedBox(height: 16),
              Text('Escríbele para coordinar el horario exacto de ${lab.name}.',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          ElevatedButton.icon(
            icon: const Icon(Icons.mail_outline, size: 16),
            label: const Text('Escribir correo'),
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(Uri(
                  scheme: 'mailto',
                  path: lxd.email,
                  query: 'subject=${Uri.encodeComponent('Mentoría - ${lab.name}')}'));
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab "Ruta de Impacto": rediseño de alta fidelidad según
// `design_handoff_portal_estudiante/README.md` (pantalla 4) — selector de
// laboratorio, camino de fases con objetivos y módulos siempre expandidos
// (reemplaza la navegación a PhaseDetailScreen) y la tarjeta National
// Expo. Los módulos, al tocarlos, siguen empujando a [ModuleDetailScreen]
// (sin cambios) para abrir/entregar contenido.
// ---------------------------------------------------------------------------

class RutaImpactoShortcut extends StatefulWidget {
  const RutaImpactoShortcut({super.key});

  @override
  State<RutaImpactoShortcut> createState() => _RutaImpactoShortcutState();
}

class _RutaImpactoShortcutState extends State<RutaImpactoShortcut> {
  String? _selectedLabId;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final team = student.team;
    final group =
        team == null ? null : data.groupById(team.groupId).valueOrNull;

    return ContentScreenShell(
      eyebrow: team == null
          ? 'Ruta de Impacto'
          : '${team.groupName}'
              '${student.university.isEmpty ? '' : ' · ${student.university}'}',
      title: 'Ruta de Impacto',
      subtitle: 'Las fases de su laboratorio, sus objetivos y lo que falta '
          'para llegar a National Expo.',
      searchHint: 'Buscar en el portal',
      bodyBuilder: (context, colors, isDark) => data.rutaProgress.when(
        loading: () => const CardListSkeleton(count: 3),
        // Un Open Learning recibe 403 acá y eso es lo que se muestra: la
        // pestaña ni siquiera existe en su portal, así que llegar es señal de
        // que algo está mal, no de que "todavía no hay datos".
        error: (e) => ErrorState(e, onRetry: data.reloadRutaProgress),
        data: (ruta) {
          final labs = ruta.laboratories;
          if (labs.isEmpty) {
            return EmptyState(
              icon: Icons.route_outlined,
              title: 'Sin laboratorio asignado',
              message:
                  'Su administrador aún no le ha asignado ningún laboratorio.',
              colors: colors,
            );
          }

          final selected = labs.firstWhere(
              (l) => l.laboratoryId == _selectedLabId,
              orElse: () => labs.first);
          final hasContent =
              selected.phases.any((p) => p.hasPublishedContent);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final lab in labs)
                    _LabChip(
                      lab: lab,
                      active: lab.laboratoryId == selected.laboratoryId,
                      colors: colors,
                      onTap: () =>
                          setState(() => _selectedLabId = lab.laboratoryId),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              if (!hasContent)
                EmptyState(
                  icon: Icons.route_outlined,
                  title: 'Laboratorio sin fases',
                  message:
                      'El ${selected.laboratoryName} todavía no ha publicado '
                      'sus fases. Su LXD las abrirá cuando el contenido esté '
                      'listo.',
                  primaryLabel: labs.length > 1 ? 'Ver otro laboratorio' : null,
                  onPrimary: labs.length > 1
                      ? () => setState(() {
                            final idx = labs.indexOf(selected);
                            _selectedLabId =
                                labs[(idx + 1) % labs.length].laboratoryId;
                          })
                      : null,
                  colors: colors,
                )
              else
                LayoutBuilder(builder: (context, c) {
                  final left = _PhasePath(lab: selected, colors: colors);
                  final right = _ExpoCard(group: group, colors: colors);
                  if (c.maxWidth > 800) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 160, child: left),
                        const SizedBox(width: 22),
                        Expanded(flex: 100, child: right),
                      ],
                    );
                  }
                  return Column(
                      children: [left, const SizedBox(height: 22), right]);
                }),
            ],
          );
        },
      ),
    );
  }
}

class _LabChip extends StatelessWidget {
  final LabProgress lab;
  final bool active;
  final ContentColors colors;
  final VoidCallback onTap;
  const _LabChip(
      {required this.lab, required this.active, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = labColorFor(lab.laboratoryId);
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.translationValues(0, hover ? -1 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: active ? colors.goldSoft : colors.surface,
            border: Border.all(color: active ? colors.goldInk : colors.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 10),
              Text(lab.laboratoryName,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: active ? colors.goldInk : colors.text2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// El camino de fases: una columna vertical, no una fila de pasos.
class _PhasePath extends StatelessWidget {
  final LabProgress lab;
  final ContentColors colors;
  const _PhasePath({required this.lab, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lab.phases.length; i++)
          _PhaseRow(
              labId: lab.laboratoryId,
              phase: lab.phases[i],
              index: i,
              colors: colors,
              isLast: i == lab.phases.length - 1),
      ],
    );
  }
}

class _PhaseRow extends StatelessWidget {
  final String labId;
  final PhaseProgress phase;
  final int index;
  final ContentColors colors;
  final bool isLast;
  const _PhaseRow(
      {required this.labId,
      required this.phase,
      required this.index,
      required this.colors,
      required this.isLast});

  @override
  Widget build(BuildContext context) {
    final accent = labColorFor(labId);
    final unlocked = phase.isUnlocked;
    final complete = phase.isComplete;
    final deadlineStatus = phase.deadlineStatus;
    final title = phase.title.isEmpty ? 'Fase ${index + 1}' : phase.title;
    // Token de alerta (README `design_handoff_portal_estudiante`, sección
    // "Tokens de diseño"): nunca un literal hex suelto por tema.
    final alertColor = colors.alertInk;

    final (chipBg, chipColor, chipIcon, chipLabel) = complete
        ? (AppColors.statusGood.withValues(alpha: 0.15), AppColors.statusGood, Icons.check_circle,
            'Completa')
        : !unlocked
            ? (colors.surface2, colors.text3, Icons.lock_outline, 'Sin abrir')
            : deadlineStatus == DeadlineStatus.overdue
                ? (alertColor.withValues(alpha: 0.16), alertColor, Icons.warning_amber_rounded,
                    'Vencida')
                : (colors.goldSoft, colors.goldInk, Icons.play_circle_outline, 'En curso');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 46,
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked ? accent : colors.surface,
                  border: Border.all(color: unlocked ? accent : colors.border, width: 2),
                ),
                child: Text('${index + 1}',
                    style: displayHeading(
                        fontSize: 22,
                        fontWeight: AppWeights.display,
                        color: unlocked ? Colors.white : colors.text3)),
              ),
              if (!isLast)
                Container(width: 2, height: 64, color: colors.border),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: complete || unlocked ? accent : colors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title.toUpperCase(),
                            style: displayHeading(
                                fontSize: 27, fontWeight: AppWeights.display, color: colors.text)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration:
                            BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(chipIcon, size: 14, color: chipColor),
                            const SizedBox(width: 5),
                            Text(chipLabel,
                                style: TextStyle(
                                    fontSize: 11.5, fontWeight: FontWeight.w600, color: chipColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (phase.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(phase.description,
                        style: TextStyle(fontSize: 13.5, height: 1.5, color: colors.text2)),
                  ],
                  if (phase.objectives.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('OBJETIVOS',
                        style: TextStyle(
                            fontSize: 11.5,
                            letterSpacing: 11.5 * 0.14,
                            fontWeight: FontWeight.w600,
                            color: colors.text3)),
                    const SizedBox(height: 10),
                    for (final o in phase.objectives)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Si el objetivo está cumplido lo decide el
                            // servidor: es "todos sus cursos vinculados al
                            // 100%", una regla que vive en una vista de
                            // PostgreSQL, no en esta pantalla.
                            Icon(
                                o.isComplete
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 17,
                                color: o.isComplete
                                    ? AppColors.statusGood
                                    : colors.text3),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(o.text, style: TextStyle(fontSize: 13.5, color: colors.text2)),
                                  Text(o.categoryLabel,
                                      style: TextStyle(fontSize: 11.5, color: colors.text3)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (phase.modules.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    for (var j = 0; j < phase.modules.length; j++)
                      _ModuleSummaryRow(
                          labId: labId,
                          module: phase.modules[j],
                          phaseIndex: index,
                          moduleIndex: j,
                          colors: colors),
                  ],
                  if (phase.deadlineDate != null) ...[
                    const SizedBox(height: 14),
                    Divider(height: 1, color: colors.border),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.event, size: 17, color: colors.text3),
                        const SizedBox(width: 8),
                        Text(
                            deadlineStatus == DeadlineStatus.overdue
                                ? 'Entrega vencida: ${DateFormat('d MMM yyyy', 'es').format(phase.deadlineDate!)}'
                                : 'Entrega: ${DateFormat('d MMM yyyy', 'es').format(phase.deadlineDate!)}',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: deadlineStatus == DeadlineStatus.overdue
                                    ? alertColor
                                    : colors.text3)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModuleSummaryRow extends StatelessWidget {
  final String labId;

  /// Estado del módulo para quien mira: desbloqueo y completitud incluidos,
  /// tal como los calculó el servidor.
  final ModuleProgress module;
  final int phaseIndex;
  final int moduleIndex;
  final ContentColors colors;
  const _ModuleSummaryRow(
      {required this.labId,
      required this.module,
      required this.phaseIndex,
      required this.moduleIndex,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    final unlocked = module.isUnlocked;
    final complete = module.isComplete;
    final title =
        module.title.isEmpty ? 'Módulo ${moduleIndex + 1}' : module.title;
    final totalItems = module.totalItems;

    final (iconBg, iconColor) = complete
        ? (AppColors.statusGood.withValues(alpha: 0.15), AppColors.statusGood)
        : !unlocked
            ? (colors.surface2, colors.text3)
            : (colors.goldSoft, colors.goldInk);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => unlocked
            ? Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ModuleDetailScreen(
                        labId: labId,
                        phaseIndex: phaseIndex,
                        moduleIndex: moduleIndex)))
            : showAppSnack(
                context, 'Complete el módulo anterior para desbloquear "$title".'),
        child: MouseRegion(
          cursor: unlocked ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration:
                BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(11)),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
                  child: Icon(
                      complete
                          ? Icons.check_circle
                          : (!unlocked
                              ? Icons.lock_outline
                              : (module.isMentorshipModule
                                  ? Icons.diversity_3
                                  : Icons.menu_book_outlined)),
                      size: 16,
                      color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, color: colors.text)),
                      Text(
                          !unlocked
                              ? 'Bloqueado'
                              : (module.isMentorshipModule
                                  ? 'Módulo de mentoría'
                                  : (module.isEmpty
                                      ? 'Sin contenido aún'
                                      : '$totalItems elemento(s)')),
                          style: TextStyle(fontSize: 11.5, color: colors.text3)),
                    ],
                  ),
                ),
                Text(
                    complete ? 'Completo' : (!unlocked ? 'Bloqueado' : 'Pendiente'),
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: iconColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpoCard extends StatelessWidget {
  final Group? group;
  final ContentColors colors;
  const _ExpoCard({required this.group, required this.colors});

  @override
  Widget build(BuildContext context) {
    // El checklist llega dentro del equipo (`GET /groups/:id`): es suyo, y no
    // tiene un recurso propio porque nadie lo escribe.
    final checklist = group?.checklist ?? const <ChecklistItem>[];
    final done = checklist.where((item) => item.done).length;
    final total = checklist.length;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            // Mismo caso que la tarjeta del Dashboard: sin ancho la banda se
            // encoge al texto y no llega al borde de la tarjeta.
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            color: AppColors.gold,
            child: Stack(
              children: [
                const Positioned.fill(child: CustomPaint(painter: StripePainter())),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('META DEL AÑO',
                        style: TextStyle(
                            fontSize: 11.5,
                            letterSpacing: 11.5 * 0.16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink.withValues(alpha: 0.7))),
                    const SizedBox(height: 8),
                    Text('National Expo',
                        style: displayHeading(
                            fontSize: 32,
                            fontWeight: AppWeights.display,
                            color: AppColors.ink)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: group == null
                ? Text('Aún no perteneces a un equipo.',
                    style: TextStyle(fontSize: 13.5, color: colors.text3))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Checklist del equipo',
                              style: TextStyle(fontSize: 12.5, color: colors.text3)),
                          Text('$done/$total',
                              style: displayHeading(
                                  fontSize: 22, fontWeight: AppWeights.display, color: colors.goldInk)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : done / total,
                          minHeight: 7,
                          backgroundColor: colors.surface2,
                          valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final item in checklist)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Icon(
                                  item.done
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 19,
                                  color: item.done
                                      ? AppColors.statusGood
                                      : colors.text3),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(item.label,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: item.done
                                            ? colors.text2
                                            : colors.text3)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Módulo: cursos asignados, entregas/lecturas propias y, si es el módulo
// de mentoría, el botón para unirse a la reunión.
// ---------------------------------------------------------------------------


/// Un módulo de la Ruta: sus cursos, sus lecturas y entregas propias y, si es
/// el de mentoría, el botón para unirse a la reunión.
///
/// Todo —qué hay dentro, qué está hecho, qué está desbloqueado— sale de
/// `/students/:id/ruta-progress`. La pantalla no calcula nada.
class ModuleDetailScreen extends StatelessWidget {
  final String labId;
  final int phaseIndex;
  final int moduleIndex;
  const ModuleDetailScreen(
      {super.key,
      required this.labId,
      required this.phaseIndex,
      required this.moduleIndex});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return data.rutaProgress.when(
      loading: () => const Scaffold(body: Center(child: BrandLoader())),
      error: (e) => Scaffold(
        body: Column(
          children: [
            const AppHeader(portalTitle: 'Módulo'),
            Expanded(child: ErrorState(e, onRetry: data.reloadRutaProgress)),
          ],
        ),
      ),
      data: (ruta) {
        final lab = ruta.labById(labId);
        final phase = (lab != null && phaseIndex < lab.phases.length)
            ? lab.phases[phaseIndex]
            : null;
        final module = (phase != null && moduleIndex < phase.modules.length)
            ? phase.modules[moduleIndex]
            : null;

        if (module == null || phase == null) {
          return const Scaffold(
            body: Column(
              children: [
                AppHeader(portalTitle: 'Módulo'),
                Expanded(
                  child: EmptyState(
                      icon: Icons.inbox_outlined,
                      message:
                          'Este módulo ya no existe o el enlace está mal escrito.'),
                ),
              ],
            ),
          );
        }
        return _ModuleBody(
            labId: labId, phase: phase, module: module, index: moduleIndex);
      },
    );
  }
}

class _ModuleBody extends StatelessWidget {
  final String labId;
  final PhaseProgress phase;
  final ModuleProgress module;
  final int index;
  const _ModuleBody(
      {required this.labId,
      required this.phase,
      required this.module,
      required this.index});

  @override
  Widget build(BuildContext context) {
    final title = module.title.isEmpty ? 'Módulo ${index + 1}' : module.title;

    return Scaffold(
      body: Column(
        children: [
          AppHeader(portalTitle: title),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              color: AppColors.gold,
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(title.toUpperCase(),
                                  style: displayHeading(
                                      fontSize: 22,
                                      fontWeight: AppWeights.display,
                                      color: AppColors.gold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (module.isMentorshipModule)
                          _MeetingCard(phaseTitle: phase.title),
                        if (module.courses.isNotEmpty) ...[
                          const SectionTitle('Cursos asignados'),
                          for (final course in module.courses)
                            _ModuleCourseRow(course: course),
                        ],
                        if (module.ownLessons.isNotEmpty) ...[
                          const SectionTitle('Entregas y lecturas'),
                          for (final lesson in module.ownLessons)
                            _OwnLessonRow(
                                moduleId: module.moduleId, lesson: lesson),
                        ],
                        // "Sin contenido aún" no es lo mismo que "pendiente":
                        // acá no hay nada que la persona pueda hacer.
                        if (module.isEmpty && !module.isMentorshipModule)
                          const EmptyState(
                              icon: Icons.inbox_outlined,
                              message:
                                  'Su administrador aún no agregó contenido a este módulo.'),
                      ],
                    ),
                  ),
                ),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Align(
                      alignment: Alignment.bottomCenter, child: AppFooter()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final String phaseTitle;
  const _MeetingCard({required this.phaseTitle});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final link = data.siteContent.valueOrNull?.meetingLink ?? '';
    final title = phaseTitle.isEmpty ? 'esta fase' : phaseTitle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: HoverCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.video_camera_front_outlined,
                color: AppColors.gold, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Módulo de mentoría',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Reúnete con su Mentor para cerrar $title.',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  // Sin enlace configurado el botón queda apagado y se dice
                  // por qué, en vez de abrir una pestaña en blanco.
                  if (link.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                          'Su administrador todavía no configuró el enlace de la reunión.',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ),
                ],
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.video_call, size: 18),
              label: const Text('Unirse a la reunión'),
              onPressed: link.isEmpty
                  ? null
                  : () => launchUrl(Uri.parse(link),
                      mode: LaunchMode.externalApplication),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCourseRow extends StatelessWidget {
  final CourseProgress course;
  const _ModuleCourseRow({required this.course});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HoverCard(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                settings:
                    RouteSettings(name: '${AppRoutes.courses}/${course.courseId}'),
                builder: (_) =>
                    CourseDetailView(courseId: course.courseId))),
        child: Row(
          children: [
            Icon(
                course.isComplete
                    ? Icons.check_circle
                    : Icons.play_circle_outline,
                color:
                    course.isComplete ? AppColors.statusGood : AppColors.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.courseName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  ThinProgressBar(
                    value: course.ratio,
                    tooltip: '${course.completedLessons} de '
                        '${course.totalLessons} lecciones',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Una lectura o entrega propia del módulo.
///
/// Una lectura se marca al abrirla; una entrega se marca al entregar. En los
/// dos casos el que decide es el mismo endpoint que usa cualquier lección de
/// curso, así que el avance del módulo, de la fase y de la Ruta se recalcula
/// solo con la respuesta.
class _OwnLessonRow extends StatelessWidget {
  final String moduleId;
  final OwnLesson lesson;
  const _OwnLessonRow({required this.moduleId, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final done = lesson.isComplete;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HoverCard(
        onTap: () => lesson.isActivity
            ? _submit(context)
            : _openReading(context),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle : lessonTypeIcon(lesson.type),
              color: done ? AppColors.statusGood : AppColors.gold,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done
                              ? AppColors.textMuted
                              : AppColors.textPrimary)),
                  Text(
                      lesson.isActivity
                          ? 'Entrega'
                          : lessonTypeLabel(lesson.type),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReading(BuildContext context) async {
    final data = context.read<DataProvider>();

    if (lesson.type == LessonType.video) {
      await VideoPlayerDialog.show(context, lesson.toLesson());
    } else {
      final key = lesson.resourceS3Key;
      final url = lesson.externalUrl;
      if (key != null && key.isNotEmpty) {
        try {
          final signed = await data.resolveFileUrl(key);
          final uri = Uri.tryParse(signed);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } on ApiException catch (e) {
          if (context.mounted) showAppSnack(context, e.message);
          return;
        }
      } else if (url != null && url.isNotEmpty) {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        if (context.mounted) {
          showAppSnack(context, 'Esta lectura todavía no tiene material.');
        }
        return;
      }
    }

    // Abrirla la da por vista. `IfPending` y no un toggle: volver a abrirla
    // no debería desmarcarla.
    try {
      await data.toggleRutaLessonIfPending(lesson.id);
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message);
    }
  }

  Future<void> _submit(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => _OwnLessonSubmitDialog(moduleId: moduleId, lesson: lesson),
    );
  }
}

class _OwnLessonSubmitDialog extends StatefulWidget {
  final String moduleId;
  final OwnLesson lesson;
  const _OwnLessonSubmitDialog({required this.moduleId, required this.lesson});

  @override
  State<_OwnLessonSubmitDialog> createState() =>
      _OwnLessonSubmitDialogState();
}

class _OwnLessonSubmitDialogState extends State<_OwnLessonSubmitDialog> {
  final _comment = TextEditingController();
  final List<UploadedFile> _files = [];
  bool _sending = false;
  ApiException? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final data = context.read<DataProvider>();
      await data.createSubmission(
        rutaModuleId: widget.moduleId,
        lessonId: widget.lesson.id,
        taskName: widget.lesson.title,
        comment: _comment.text.trim(),
        files: _files.map((f) => f.toJson()).toList(),
      );
      await data.toggleRutaLessonIfPending(widget.lesson.id);
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessCheck(context, 'Entrega enviada ✓');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.lesson.title, style: const TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.lesson.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(widget.lesson.description,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ),
              TextField(
                  controller: _comment,
                  enabled: !_sending,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Comentario')),
              const SizedBox(height: 12),
              FileUploadField(
                purpose: 'submission',
                maxFiles: 3,
                files: _files,
                enabled: !_sending,
                onChanged: () => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                ErrorBanner(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _sending ? null : () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _sending ? null : _send,
          child: Text(_sending ? 'Enviando…' : 'Enviar'),
        ),
      ],
    );
  }
}
