import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';

/// Datos y copias de seguridad.
///
/// **Esta pantalla decía otra cosa antes, y era verdad entonces**: explicaba
/// que todo vivía en el almacenamiento del navegador y advertía sobre el modo
/// incógnito y los "datos de sitio". Con la base en PostgreSQL nada de eso
/// aplica, y dejarlo habría sido peor que no tener la pantalla: una
/// instrucción que ya no corresponde se sigue siguiendo.
class AdminBackup extends StatelessWidget {
  const AdminBackup({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final esSuperAdmin =
        context.watch<AuthProvider>().currentUser?.role == Roles.superAdmin;

    return TabBody(
      title: 'Datos y Copias de Seguridad',
      subtitle: 'Dónde viven los datos y cómo respaldarlos',
      children: [
        const _WhereItLives(),
        const SectionTitle('Estado actual'),
        data.impactMetrics.when(
          loading: () => const CardListSkeleton(count: 1, height: 96),
          error: (e) => ErrorState(e, onRetry: data.reloadImpactMetrics),
          data: (metrics) => _Counts(counts: metrics.counts),
        ),
        const SectionTitle('Respaldo'),
        _BackupCard(esSuperAdmin: esSuperAdmin),
      ],
    );
  }
}

class _WhereItLives extends StatelessWidget {
  const _WhereItLives();

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.storage_outlined, color: AppColors.gold),
              SizedBox(width: 10),
              Expanded(
                child: Text('¿Dónde se guardan los datos?',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Los datos viven en la base de datos del servidor, no en este '
            'navegador. Cerrar sesión, cambiar de computador o entrar desde '
            'otro dispositivo no cambia nada: cada quien ve lo mismo.\n\n'
            'Los archivos (fotos, PDF, videos) se guardan aparte, en el '
            'almacenamiento de objetos, y el respaldo NO los incluye: guarda '
            'las referencias, no los archivos.\n\n'
            'Una copia de seguridad tampoco lleva credenciales. Las '
            'contraseñas y las sesiones abiertas quedan fuera a propósito: un '
            'respaldo es para restaurar datos, no para llevárselas.',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13.5, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _Counts extends StatelessWidget {
  final PlatformCounts counts;
  const _Counts({required this.counts});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StatRow(tiles: [
          StatTile(
              value: '${counts.allStudents}',
              label: 'Estudiantes',
              icon: Icons.people_outline),
          StatTile(
              value: '${counts.courses}',
              label: 'Cursos',
              icon: Icons.video_library_outlined),
          StatTile(
              value: '${counts.projects}',
              label: 'Proyectos',
              icon: Icons.lightbulb_outline),
          StatTile(
              value: '${counts.laboratories}',
              label: 'Laboratorios',
              icon: Icons.science_outlined),
        ]),
        const SizedBox(height: 12),
        StatRow(tiles: [
          StatTile(
              value: '${counts.groups}',
              label: 'Equipos',
              icon: Icons.groups_outlined),
          StatTile(
              value: '${counts.certificates}',
              label: 'Certificados',
              icon: Icons.workspace_premium_outlined),
          StatTile(
              value: '${counts.universities}',
              label: 'Universidades',
              icon: Icons.account_balance_outlined),
          StatTile(
              value: '${counts.submissionsPending}',
              label: 'Entregas sin revisar',
              icon: Icons.pending_actions_outlined),
        ]),
      ],
    );
  }
}

class _BackupCard extends StatefulWidget {
  final bool esSuperAdmin;
  const _BackupCard({required this.esSuperAdmin});

  @override
  State<_BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<_BackupCard> {
  bool _working = false;
  ApiException? _error;

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `Wrap` y no `Row`: los dos rótulos juntos miden más que el ancho
          // útil de un teléfono, y en `Row` eso desborda siempre.
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.download, size: 18),
                label: Text(_working
                    ? 'Preparando…'
                    : 'Descargar copia de seguridad'),
                onPressed: _working ? null : _export,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload, size: 18),
                label: const Text('Restaurar desde archivo'),
                onPressed:
                    _working || !widget.esSuperAdmin ? null : _import,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.esSuperAdmin
                ? 'Restaurar reemplaza la base entera por la del archivo. No '
                    'se puede deshacer.'
                : 'Restaurar reemplaza la base entera, así que solo lo puede '
                    'hacer un Super Admin.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            ErrorBanner(_error!),
          ],
        ],
      ),
    );
  }

  Future<void> _export() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final backup = await context.read<DataProvider>().exportBackup();
      final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final path = await FilePicker.saveFile(
        dialogTitle: 'Guardar copia de seguridad',
        fileName: 'enactus_respaldo_$stamp.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: utf8.encode(jsonEncode(backup)),
      );
      if (!mounted) return;
      setState(() => _working = false);
      // `path` nulo = la persona canceló el diálogo de guardado. No es un
      // error y no merece un aviso de éxito.
      if (path != null) showSuccessCheck(context, 'Copia descargada ✓');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _working = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Seleccione el archivo de respaldo',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null || !mounted) return;

    final ok = await confirmDoubleDialog(
      context,
      'Restaurar copia de seguridad',
      'La base entera se reemplaza por la del archivo '
          '"${result!.files.single.name}". No se puede deshacer.',
    );
    if (!ok || !mounted) return;

    setState(() {
      _working = true;
      _error = null;
    });

    Map<String, dynamic> payload;
    try {
      payload = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(bytes)) as Map);
    } on FormatException {
      if (mounted) {
        setState(() {
          _working = false;
          _error = const ValidationError(
              'Ese archivo no es un respaldo válido: no se pudo leer como JSON.');
        });
      }
      return;
    }

    try {
      await context.read<DataProvider>().restoreBackup(payload);
      if (!mounted) return;
      showSuccessCheck(context, 'Datos restaurados ✓');
      // La sesión actual puede no existir en el respaldo restaurado: se vuelve
      // al ingreso en vez de dejar la pantalla con un token que ya no vale.
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _working = false;
          _error = e;
        });
      }
    }
  }
}
