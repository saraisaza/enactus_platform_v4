import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/data_provider.dart';
import '../utils/app_theme.dart';
import 'common.dart';

/// Dónde (laboratorio · fase · módulo) está vinculado este curso hoy, si
/// es que ya lo está. La usan tanto el LXD (sus propios cursos) como el
/// Admin (todos los cursos de la plataforma).
String? linkedModuleLabel(DataProvider data, Course course) {
  if (course.labId.isEmpty) return null;
  final lab = data.labById(course.labId);
  if (lab == null) return null;
  for (var pi = 0; pi < lab.phases.length; pi++) {
    final phase = lab.phases[pi];
    for (var mi = 0; mi < phase.modules.length; mi++) {
      if (phase.modules[mi].courseIds.contains(course.id)) {
        final phaseTitle =
            phase.title.isEmpty ? 'Fase ${pi + 1}' : phase.title;
        final moduleTitle = phase.modules[mi].title.isEmpty
            ? 'Módulo ${mi + 1}'
            : phase.modules[mi].title;
        return '${lab.name} · $phaseTitle · $moduleTitle';
      }
    }
  }
  return null;
}

/// Se elige laboratorio → fase → módulo para vincular un curso. Al
/// confirmar, el curso queda asignado a ese módulo y sus objetivos se
/// suman automáticamente a los de la fase. Lo usa tanto el LXD (para sus
/// propios cursos) como el Admin (para cualquier curso de la plataforma).
Future<void> showLinkToRutaDialog(BuildContext context, Course course) async {
  final data = context.read<DataProvider>();
  String? labId = course.labId.isEmpty ? null : course.labId;
  int? phaseIndex;
  int? moduleIndex;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final lab = labId == null ? null : data.labById(labId!);
        final phase = (lab != null && phaseIndex != null)
            ? lab.phases[phaseIndex!]
            : null;
        return AlertDialog(
          title: const Text('Vincular a Ruta de Impacto',
              style: TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Curso: ${course.name}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: labId,
                  decoration: const InputDecoration(labelText: 'Laboratorio'),
                  items: [
                    for (final l in data.labs)
                      DropdownMenuItem(value: l.id, child: Text(l.name)),
                  ],
                  onChanged: (v) => setState(() {
                    labId = v;
                    phaseIndex = null;
                    moduleIndex = null;
                  }),
                ),
                if (lab != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: phaseIndex,
                    decoration: const InputDecoration(labelText: 'Fase'),
                    items: [
                      for (var i = 0; i < lab.phases.length; i++)
                        DropdownMenuItem(
                            value: i,
                            child: Text(lab.phases[i].title.isEmpty
                                ? 'Fase ${i + 1}'
                                : lab.phases[i].title)),
                    ],
                    onChanged: (v) => setState(() {
                      phaseIndex = v;
                      moduleIndex = null;
                    }),
                  ),
                ],
                if (phase != null) ...[
                  const SizedBox(height: 12),
                  phase.modules.isEmpty
                      ? const Text(
                          'Esta fase no tiene módulos todavía (créalos desde la pestaña Laboratorios).',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted))
                      : DropdownButtonFormField<int>(
                          initialValue: moduleIndex,
                          decoration:
                              const InputDecoration(labelText: 'Módulo'),
                          items: [
                            for (var i = 0; i < phase.modules.length; i++)
                              DropdownMenuItem(
                                  value: i,
                                  child: Text(phase.modules[i].title.isEmpty
                                      ? 'Módulo ${i + 1}'
                                      : phase.modules[i].title)),
                          ],
                          onChanged: (v) => setState(() => moduleIndex = v),
                        ),
                  const SizedBox(height: 8),
                  const Text(
                      'Los objetivos de este curso se sumarán a los de la fase.',
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed:
                  (labId == null || phaseIndex == null || moduleIndex == null)
                      ? null
                      : () async {
                          await data.linkCourseToModule(
                              labId: labId!,
                              phaseIndex: phaseIndex!,
                              moduleIndex: moduleIndex!,
                              courseId: course.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            showSuccessCheck(context, 'Curso vinculado ✓');
                          }
                        },
              child: const Text('Vincular'),
            ),
          ],
        );
      },
    ),
  );
}
