import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';

/// Copia de seguridad local: exporta/importa toda la base de datos como
/// archivo JSON. Mientras la plataforma corre en local, los datos viven en
/// el almacenamiento del navegador (IndexedDB) — este respaldo permite
/// guardarlos como archivo real en el disco.
class AdminBackup extends StatelessWidget {
  const AdminBackup({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Datos y Copias de Seguridad',
      subtitle: 'Dónde viven tus datos y cómo respaldarlos',
      children: [
        // Explicación del almacenamiento
        HoverCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.storage_outlined, color: AppColors.gold),
                  SizedBox(width: 10),
                  Text('¿Dónde se guardan los datos?',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Todos los datos (usuarios, cursos, proyectos, entregas, progreso) '
                'se guardan en el almacenamiento local del navegador (IndexedDB) '
                'asociado a la dirección http://localhost:8080.\n\n'
                'Para no perderlos:\n'
                '  •  Usa siempre la misma dirección: http://localhost:8080 '
                '(no 127.0.0.1) y el mismo navegador.\n'
                '  •  No uses modo incógnito ni borres los "datos de sitio".\n'
                '  •  Descarga una copia de seguridad después de hacer cambios importantes.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13.5, height: 1.6),
              ),
            ],
          ),
        ),
        const SectionTitle('Estado actual'),
        StatRow(tiles: [
          StatTile(
              value: '${data.users.length}',
              label: 'Usuarios',
              icon: Icons.people_outline),
          StatTile(
              value: '${data.courses.length}',
              label: 'Cursos',
              icon: Icons.video_library_outlined),
          StatTile(
              value: '${data.projects.length}',
              label: 'Proyectos',
              icon: Icons.lightbulb_outline),
          StatTile(
              value: '${data.submissions.length}',
              label: 'Entregas',
              icon: Icons.upload_file_outlined),
        ]),
        const SectionTitle('Respaldo'),
        HoverCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Descargar copia de seguridad'),
                    onPressed: () => _export(context),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload, size: 18),
                    label: const Text('Restaurar desde archivo'),
                    onPressed: () => _import(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'La copia incluye absolutamente todo. Al restaurar, los datos '
                'actuales se reemplazan por los del archivo.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context) async {
    final data = context.read<DataProvider>();
    final json = data.exportBackupJson();
    final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    final path = await FilePicker.saveFile(
      dialogTitle: 'Guardar copia de seguridad',
      fileName: 'enactus_respaldo_$stamp.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: utf8.encode(json),
    );
    if (context.mounted && path != null) {
      showSuccessCheck(context, 'Copia de seguridad descargada ✓');
    }
  }

  Future<void> _import(BuildContext context) async {
    final data = context.read<DataProvider>();
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Selecciona el archivo de respaldo',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null || !context.mounted) return;

    final ok = await confirmDoubleDialog(
      context,
      'Restaurar copia de seguridad',
      'Los datos actuales se reemplazarán por completo con los del archivo '
      '"${result!.files.single.name}".',
    );
    if (!ok || !context.mounted) return;

    try {
      await data.importBackupJson(utf8.decode(bytes));
      if (context.mounted) {
        showSuccessCheck(context, 'Datos restaurados ✓');
        // La sesión actual podría no existir en el respaldo: volver al login.
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      }
    } on FormatException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }
}
