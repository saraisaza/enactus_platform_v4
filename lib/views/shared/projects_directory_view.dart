import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';

/// Directorio de todos los proyectos Enactus de la plataforma, sin
/// importar laboratorio, universidad o equipo — para que estudiantes y
/// asesores vean qué está haciendo el resto de la comunidad (solo
/// lectura: crear/editar proyectos sigue siendo tarea de Admin/Asesor en
/// sus propias pestañas de gestión).
class ProjectsDirectoryView extends StatefulWidget {
  const ProjectsDirectoryView({super.key});

  @override
  State<ProjectsDirectoryView> createState() => _ProjectsDirectoryViewState();
}

class _ProjectsDirectoryViewState extends State<ProjectsDirectoryView> {
  String _stageFilter = 'todas';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    var projects = data.projects;
    if (_stageFilter != 'todas') {
      projects = projects.where((p) => p.stage == _stageFilter).toList();
    }

    return TabBody(
      title: 'Directorio de Proyectos',
      subtitle:
          'Todos los proyectos activos en la comunidad Enactus Colombia',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todas las etapas'),
              selected: _stageFilter == 'todas',
              selectedColor: AppColors.gold.withValues(alpha: 0.25),
              onSelected: (_) => setState(() => _stageFilter = 'todas'),
            ),
            for (final s in projectStages)
              ChoiceChip(
                label: Text(s),
                selected: _stageFilter == s,
                selectedColor: AppColors.gold.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => _stageFilter = s),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (projects.isEmpty)
          const EmptyState(
              icon: Icons.lightbulb_outline,
              message: 'No hay proyectos para esta etapa todavía.')
        else
          ...projects.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProjectCard(project: p),
              )),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final groups =
        data.groups.where((g) => g.projectId == project.id).toList();

    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(project.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              StatusChip(
                  label: project.stage,
                  color: AppColors.gold,
                  icon: Icons.flag_outlined),
            ],
          ),
          if (project.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(project.description,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ),
          if (project.community.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Comunidad beneficiada: ${project.community}',
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ),
          if (project.ods.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in project.ods)
                  Chip(label: Text(o, style: const TextStyle(fontSize: 11))),
              ],
            ),
          ],
          const SizedBox(height: 10),
          if (groups.isEmpty)
            const Text('Sin equipo asignado todavía.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12))
          else
            for (final g in groups)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.groups_outlined,
                        size: 15, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          '${g.name} · ${g.university.isEmpty ? 'Universidad sin definir' : g.university} · '
                          '${g.studentIds.length} estudiante(s)',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
