import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../../widgets/video_player_dialog.dart';
import '../lxd/lesson_editor.dart' show lessonTypeIcon, lessonTypeLabel;
import 'course_detail_view.dart';

/// Flujo completo de la Ruta de Impacto del estudiante:
/// Laboratorios → Laboratorio (fases) → Fase (objetivos + módulos) →
/// Módulo (cursos, entregas/lecturas y, en el módulo de mentoría, el
/// botón para unirse a la reunión).

// ---------------------------------------------------------------------------
// Tab "Laboratorios": tarjetas de los laboratorios asignados
// ---------------------------------------------------------------------------

class LabsView extends StatelessWidget {
  const LabsView({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final labs = data.labsForStudent(student);

    return TabBody(
      title: 'Laboratorios',
      subtitle:
          'Laboratorios asignados — entra a uno para ver su Ruta de Impacto',
      children: [
        if (labs.isEmpty)
          const EmptyState(
              icon: Icons.science_outlined,
              message:
                  'Tu administrador aún no te asignó a ningún laboratorio.')
        else
          _LabsGrid(labs: labs),
      ],
    );
  }
}

class _LabsGrid extends StatelessWidget {
  final List<Laboratory> labs;
  const _LabsGrid({required this.labs});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth > 900 ? 3 : (c.maxWidth > 600 ? 2 : 1);
      final width = (c.maxWidth - (perRow - 1) * 12) / perRow;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final lab in labs)
            SizedBox(width: width, child: _LabCard(lab: lab)),
        ],
      );
    });
  }
}

class _LabCard extends StatelessWidget {
  final Laboratory lab;
  const _LabCard({required this.lab});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final completedPhases = lab.phases
        .where((p) => data.isPhaseComplete(student.id, lab.id, p))
        .length;

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => GestureDetector(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => LabPhasesScreen(labId: lab.id))),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: hover ? AppColors.surfaceAlt : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: hover ? AppColors.gold : AppColors.border,
                width: hover ? 1.2 : 1),
            boxShadow: hover
                ? const [
                    BoxShadow(
                        color: Colors.black45,
                        blurRadius: 16,
                        offset: Offset(0, 6)),
                  ]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.science_outlined,
                  color: AppColors.gold, size: 28),
              const SizedBox(height: 10),
              Text(lab.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 6),
              Text(lab.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12.5)),
              const SizedBox(height: 12),
              ThinProgressBar(
                  value: lab.phases.isEmpty
                      ? 0
                      : completedPhases / lab.phases.length,
                  tooltip:
                      '$completedPhases de ${lab.phases.length} fases completadas'),
              const SizedBox(height: 6),
              Text('$completedPhases/${lab.phases.length} fases · Ruta de Impacto',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab "Ruta de Impacto": atajo directo del panel lateral
// ---------------------------------------------------------------------------

class RutaImpactoShortcut extends StatelessWidget {
  const RutaImpactoShortcut({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final labs = data.labsForStudent(student);

    if (labs.isEmpty) {
      return const TabBody(
        title: 'Ruta de Impacto',
        children: [
          EmptyState(
              icon: Icons.emoji_events_outlined,
              message:
                  'Tu administrador aún no te asignó a ningún laboratorio.'),
        ],
      );
    }
    if (labs.length == 1) {
      final lab = labs.first;
      return TabBody(
        title: 'Ruta de Impacto',
        subtitle: lab.name,
        children: [_PhasesGrid(lab: lab)],
      );
    }
    return TabBody(
      title: 'Ruta de Impacto',
      subtitle: 'Tienes varios laboratorios: elige uno para ver su Ruta de Impacto',
      children: [_LabsGrid(labs: labs)],
    );
  }
}

// ---------------------------------------------------------------------------
// Laboratorio: 3 tarjetas de fase, con candado en lo bloqueado
// ---------------------------------------------------------------------------

class LabPhasesScreen extends StatelessWidget {
  final String labId;
  const LabPhasesScreen({super.key, required this.labId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final lab = data.labById(labId);
    if (lab == null) {
      return const Scaffold(
          body: Center(child: Text('Laboratorio no encontrado')));
    }

    return Scaffold(
      body: Column(
        children: [
          AppHeader(portalTitle: lab.name),
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
                              child: Text(lab.name.toUpperCase(),
                                  style: knockoutHeading(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.gold)),
                            ),
                          ],
                        ),
                        if (lab.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 56, top: 4),
                            child: Text(lab.description,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14)),
                          ),
                        const SizedBox(height: 24),
                        const SectionTitle('Ruta de Impacto'),
                        _PhasesGrid(lab: lab),
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

class _PhasesGrid extends StatelessWidget {
  final Laboratory lab;
  const _PhasesGrid({required this.lab});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth > 800 ? 3 : (c.maxWidth > 520 ? 2 : 1);
      final width = (c.maxWidth - (perRow - 1) * 14) / perRow;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (var i = 0; i < lab.phases.length; i++)
            SizedBox(width: width, child: _PhaseCard(lab: lab, index: i)),
        ],
      );
    });
  }
}

/// Tarjeta de fase: candado animado si está bloqueada, check si está
/// completa. Transición suave de color/borde/tamaño en hover.
class _PhaseCard extends StatefulWidget {
  final Laboratory lab;
  final int index;
  const _PhaseCard({required this.lab, required this.index});

  @override
  State<_PhaseCard> createState() => _PhaseCardState();
}

class _PhaseCardState extends State<_PhaseCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final phase = widget.lab.phases[widget.index];
    final unlocked = data.isPhaseUnlocked(
        student.id, widget.lab.id, widget.lab, widget.index);
    final complete = data.isPhaseComplete(student.id, widget.lab.id, phase);
    final total = phase.modules.length;
    final done = phase.modules
        .where((m) => data.isModuleComplete(student.id, widget.lab.id, m))
        .length;
    final title = phase.title.isEmpty ? 'Fase ${widget.index + 1}' : phase.title;
    final deadlineStatus =
        data.phaseDeadlineStatus(student.id, widget.lab.id, phase);

    return MouseRegion(
      cursor:
          unlocked ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {
          if (!unlocked) {
            showAppSnack(
                context, 'Completa la fase anterior para desbloquear "$title".');
            return;
          }
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PhaseDetailScreen(
                      labId: widget.lab.id, phaseIndex: widget.index)));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: !unlocked
                ? AppColors.surface.withValues(alpha: 0.55)
                : (_hover ? AppColors.surfaceAlt : AppColors.surface),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: complete
                  ? AppColors.statusGood
                  : (!unlocked
                      ? AppColors.border
                      : (_hover ? AppColors.gold : AppColors.border)),
              width: complete || (_hover && unlocked) ? 1.4 : 1,
            ),
            boxShadow: _hover && unlocked
                ? const [
                    BoxShadow(
                        color: Colors.black45,
                        blurRadius: 16,
                        offset: Offset(0, 6)),
                  ]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedScale(
                    scale: !unlocked && _hover ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      complete
                          ? Icons.check_circle
                          : (!unlocked
                              ? Icons.lock_outline
                              : Icons.lock_open_outlined),
                      color: complete
                          ? AppColors.statusGood
                          : (!unlocked ? AppColors.textMuted : AppColors.gold),
                      size: 26,
                    ),
                  ),
                  const Spacer(),
                  if (complete)
                    const StatusChip(
                        label: 'Completa',
                        color: AppColors.statusGood,
                        icon: Icons.check)
                  else if (unlocked && deadlineStatus == DeadlineStatus.overdue)
                    const StatusChip(
                        label: 'Vencida',
                        color: AppColors.statusCritical,
                        icon: Icons.error_outline)
                  else if (unlocked &&
                      deadlineStatus == DeadlineStatus.approaching)
                    const StatusChip(
                        label: 'Vence pronto',
                        color: AppColors.statusWarning,
                        icon: Icons.schedule),
                ],
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color:
                          !unlocked ? AppColors.textMuted : AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(!unlocked ? 'Bloqueada' : '$done/$total módulos',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12.5)),
              if (unlocked && phase.deadline.isNotEmpty && !complete)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      'Vence: ${DateFormat('d MMM yyyy').format(DateTime.parse(phase.deadline))}',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: deadlineStatus == DeadlineStatus.overdue
                              ? AppColors.statusCritical
                              : deadlineStatus == DeadlineStatus.approaching
                                  ? AppColors.statusWarning
                                  : AppColors.textMuted)),
                ),
              if (unlocked) ...[
                const SizedBox(height: 8),
                ThinProgressBar(value: total == 0 ? 0 : done / total),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fase: descripción, objetivos por categoría y módulos
// ---------------------------------------------------------------------------

class PhaseDetailScreen extends StatelessWidget {
  final String labId;
  final int phaseIndex;
  const PhaseDetailScreen(
      {super.key, required this.labId, required this.phaseIndex});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final lab = data.labById(labId);
    if (lab == null || phaseIndex >= lab.phases.length) {
      return const Scaffold(body: Center(child: Text('Fase no encontrada')));
    }
    final phase = lab.phases[phaseIndex];
    final title = phase.title.isEmpty ? 'Fase ${phaseIndex + 1}' : phase.title;
    final deadlineStatus =
        data.phaseDeadlineStatus(student.id, labId, phase);
    final entrepreneurshipObjs = phase.objectives
        .where((o) => o.category == ObjectiveCategory.entrepreneurship)
        .toList();
    final businessObjs = phase.objectives
        .where((o) => o.category == ObjectiveCategory.business)
        .toList();

    return Scaffold(
      body: Column(
        children: [
          AppHeader(portalTitle: '${lab.name} · $title'),
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
                                  style: knockoutHeading(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.gold)),
                            ),
                          ],
                        ),
                        if (phase.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 56, top: 4),
                            child: Text(phase.description,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    height: 1.5)),
                          ),
                        if (phase.deadline.isNotEmpty &&
                            deadlineStatus != DeadlineStatus.none) ...[
                          const SizedBox(height: 14),
                          HoverCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                    deadlineStatus == DeadlineStatus.overdue
                                        ? Icons.error_outline
                                        : Icons.schedule,
                                    color: deadlineStatus ==
                                            DeadlineStatus.overdue
                                        ? AppColors.statusCritical
                                        : AppColors.statusWarning,
                                    size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                      deadlineStatus == DeadlineStatus.overdue
                                          ? 'Esta fase venció el ${DateFormat('d MMM yyyy').format(DateTime.parse(phase.deadline))}. Complétala lo antes posible.'
                                          : 'Esta fase vence el ${DateFormat('d MMM yyyy').format(DateTime.parse(phase.deadline))}.',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: deadlineStatus ==
                                                  DeadlineStatus.overdue
                                              ? AppColors.statusCritical
                                              : AppColors.statusWarning)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        const SectionTitle('Objetivos de Emprendimiento'),
                        if (entrepreneurshipObjs.isEmpty)
                          const Text('Sin objetivos en esta categoría todavía.',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 13))
                        else
                          for (final o in entrepreneurshipObjs)
                            _ObjectiveRow(studentId: student.id, objective: o),
                        const SizedBox(height: 8),
                        const SectionTitle('Objetivos Empresariales'),
                        if (businessObjs.isEmpty)
                          const Text('Sin objetivos en esta categoría todavía.',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 13))
                        else
                          for (final o in businessObjs)
                            _ObjectiveRow(studentId: student.id, objective: o),
                        const SectionTitle('Módulos'),
                        if (phase.modules.isEmpty)
                          const EmptyState(
                              icon: Icons.view_module_outlined,
                              message:
                                  'Tu administrador aún no configuró los módulos de esta fase.')
                        else
                          for (var i = 0; i < phase.modules.length; i++)
                            _ModuleRow(
                                labId: labId,
                                phaseIndex: phaseIndex,
                                moduleIndex: i),
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

class _ObjectiveRow extends StatelessWidget {
  final String studentId;
  final Objective objective;
  const _ObjectiveRow({required this.studentId, required this.objective});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final done = data.isObjectiveComplete(studentId, objective);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: HoverCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? AppColors.statusGood : AppColors.textMuted,
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(objective.text,
                  style: TextStyle(
                      color:
                          done ? AppColors.textMuted : AppColors.textPrimary,
                      decoration:
                          done ? TextDecoration.lineThrough : null)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  final String labId;
  final int phaseIndex;
  final int moduleIndex;
  const _ModuleRow(
      {required this.labId,
      required this.phaseIndex,
      required this.moduleIndex});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final lab = data.labById(labId)!;
    final phase = lab.phases[phaseIndex];
    final module = phase.modules[moduleIndex];
    final unlocked =
        data.isModuleUnlocked(student.id, labId, phase, moduleIndex);
    final complete = data.isModuleComplete(student.id, labId, module);
    final totalItems = module.ownLessons.length + module.courseIds.length;
    final title =
        module.title.isEmpty ? 'Módulo ${moduleIndex + 1}' : module.title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HoverCard(
        onTap: !unlocked
            ? () => showAppSnack(context,
                'Completa el módulo anterior para desbloquear "$title".')
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ModuleDetailScreen(
                        labId: labId,
                        phaseIndex: phaseIndex,
                        moduleIndex: moduleIndex))),
        child: Row(
          children: [
            Icon(
              complete
                  ? Icons.check_circle
                  : (!unlocked
                      ? Icons.lock_outline
                      : (module.isMentorshipModule
                          ? Icons.groups_outlined
                          : Icons.view_module_outlined)),
              color: complete
                  ? AppColors.statusGood
                  : (!unlocked ? AppColors.textMuted : AppColors.gold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: !unlocked
                              ? AppColors.textMuted
                              : AppColors.textPrimary)),
                  Text(
                    !unlocked
                        ? 'Bloqueado'
                        : (module.isMentorshipModule
                            ? 'Módulo de mentoría'
                            : '$totalItems elemento(s)'),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: !unlocked ? AppColors.border : AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Módulo: cursos asignados, entregas/lecturas propias y, si es el módulo
// de mentoría, el botón para unirse a la reunión.
// ---------------------------------------------------------------------------

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
    final student = context.watch<AuthProvider>().currentUser!;
    final lab = data.labById(labId);
    if (lab == null || phaseIndex >= lab.phases.length) {
      return const Scaffold(body: Center(child: Text('Módulo no encontrado')));
    }
    final phase = lab.phases[phaseIndex];
    if (moduleIndex >= phase.modules.length) {
      return const Scaffold(body: Center(child: Text('Módulo no encontrado')));
    }
    final module = phase.modules[moduleIndex];
    final title =
        module.title.isEmpty ? 'Módulo ${moduleIndex + 1}' : module.title;
    final progress = data.rutaProgressFor(student.id, labId);
    final noContent = module.courseIds.isEmpty &&
        module.ownLessons.isEmpty &&
        !module.isMentorshipModule;

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
                                  style: knockoutHeading(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.gold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (module.isMentorshipModule)
                          _MeetingCard(phase: phase),
                        if (module.courseIds.isNotEmpty) ...[
                          const SectionTitle('Cursos asignados'),
                          for (final cid in module.courseIds)
                            _ModuleCourseRow(
                                courseId: cid, studentId: student.id),
                        ],
                        if (module.ownLessons.isNotEmpty) ...[
                          const SectionTitle('Entregas y lecturas'),
                          for (final lesson in module.ownLessons)
                            _OwnLessonRow(
                                labId: labId,
                                moduleId: module.id,
                                lesson: lesson,
                                done: progress.completedOwnLessonIds
                                    .contains(lesson.id)),
                        ],
                        if (noContent)
                          const EmptyState(
                              icon: Icons.inbox_outlined,
                              message:
                                  'Tu administrador aún no agregó contenido a este módulo.'),
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
  final Phase phase;
  const _MeetingCard({required this.phase});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final phaseTitle = phase.title.isEmpty ? 'esta fase' : phase.title;
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
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Reúnete con tu Mentor para cerrar $phaseTitle.',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.video_call, size: 18),
              label: const Text('Unirse a la reunión'),
              onPressed: () => launchUrl(
                  Uri.parse(data.siteContent.meetingLink),
                  mode: LaunchMode.externalApplication),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCourseRow extends StatelessWidget {
  final String courseId;
  final String studentId;
  const _ModuleCourseRow({required this.courseId, required this.studentId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final course = data.courseById(courseId);
    if (course == null) return const SizedBox.shrink();
    final progress = data.courseProgress(studentId, course);
    final complete = progress >= 1.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HoverCard(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CourseDetailView(courseId: course.id))),
        child: Row(
          children: [
            Icon(complete ? Icons.check_circle : Icons.play_circle_outline,
                color: complete ? AppColors.statusGood : AppColors.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  ThinProgressBar(value: progress),
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

class _OwnLessonRow extends StatelessWidget {
  final String labId;
  final String moduleId;
  final Lesson lesson;
  final bool done;
  const _OwnLessonRow(
      {required this.labId,
      required this.moduleId,
      required this.lesson,
      required this.done});

  @override
  Widget build(BuildContext context) {
    final data = context.read<DataProvider>();
    final student = context.read<AuthProvider>().currentUser!;
    final isActivity = lesson.type == LessonType.activity;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HoverCard(
        onTap: () => isActivity
            ? _openSubmissionDialog(context, data, student)
            : _openReadingContent(context, data, student),
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
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          color: done
                              ? AppColors.textMuted
                              : AppColors.textPrimary)),
                  Text(isActivity ? 'Entrega' : lessonTypeLabel(lesson.type),
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

  void _openReadingContent(
      BuildContext context, DataProvider data, AppUser student) {
    if (lesson.type == LessonType.video) {
      VideoPlayerDialog.show(context, lesson.title, lesson.resourcePath);
    } else {
      showAppSnack(
          context, 'Material en course_resources/${lesson.resourcePath}');
    }
    data.toggleOwnLesson(student.id, labId, lesson.id);
  }

  Future<void> _openSubmissionDialog(
      BuildContext context, DataProvider data, AppUser student) async {
    final commentCtrl = TextEditingController();
    String filePath = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(lesson.title, style: const TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lesson.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(lesson.description,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ),
                TextField(
                    controller: commentCtrl,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Comentario')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: const Text('Adjuntar archivo'),
                      onPressed: () async {
                        final result = await FilePicker.pickFiles();
                        if (result != null) {
                          setState(() => filePath =
                              result.files.single.path ??
                                  result.files.single.name);
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        filePath.isEmpty
                            ? 'Sin archivo'
                            : filePath.split('/').last,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                await data.saveSubmission(Submission(
                  id: data.newId('sub'),
                  rutaModuleId: moduleId,
                  studentId: student.id,
                  lessonId: lesson.id,
                  taskName: lesson.title,
                  comment: commentCtrl.text.trim(),
                  filePath: filePath,
                ));
                await data.toggleOwnLesson(student.id, labId, lesson.id);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  showSuccessCheck(context, 'Entrega enviada ✓');
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }
}
