import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../widgets/file_upload_field.dart';
import '../../widgets/portal_shell.dart';

/// Recursos de comunicaciones: plantillas, guías de marca y material que el
/// equipo de Admin publica para Asesores, Mentores y LXD.
///
/// Quién puede publicar lo decide el servidor —solo Admin—, y esta pantalla se
/// limita a no mostrar los botones a quien no puede. Es una comodidad, no una
/// defensa: la API rechaza igual la escritura de cualquier otro rol.
class CommunicationResourcesView extends StatelessWidget {
  const CommunicationResourcesView({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final rol = context.watch<AuthProvider>().currentUser?.role;
    final puedePublicar = rol == Roles.admin || rol == Roles.superAdmin;

    return TabBody(
      title: 'Recursos de Comunicaciones',
      subtitle: 'Plantillas, guías de marca y material para el equipo',
      actions: [
        if (puedePublicar)
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuevo recurso'),
            onPressed: () => _publicar(context),
          ),
      ],
      children: [
        data.communicationResources.when(
          loading: () => const CardListSkeleton(count: 4, height: 80),
          error: (e) =>
              ErrorState(e, onRetry: data.reloadCommunicationResources),
          data: (recursos) => recursos.isEmpty
              ? const EmptyState(
                  icon: Icons.perm_media_outlined,
                  message: 'Todavía no hay recursos publicados.')
              : Column(
                  children: [
                    for (final r in recursos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ResourceCard(
                            resource: r, puedeBorrar: puedePublicar),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _publicar(BuildContext context) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ResourceFormDialog(),
      );
}

class _ResourceCard extends StatelessWidget {
  final CommunicationResource resource;
  final bool puedeBorrar;

  const _ResourceCard({required this.resource, required this.puedeBorrar});

  @override
  Widget build(BuildContext context) {
    final data = context.read<DataProvider>();

    return HoverCard(
      onTap: () => _abrir(context, data),
      child: Row(
        children: [
          Icon(
            resource.isLink ? Icons.link : Icons.description_outlined,
            color: AppColors.gold,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(resource.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                if (resource.description.isNotEmpty)
                  Text(resource.description,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                Text(
                  '${resource.isLink ? 'Enlace' : resource.fileExt.toUpperCase()}'
                  ' · ${DateFormat('d MMM yyyy').format(resource.createdAt)}',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (puedeBorrar)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.statusCritical,
              tooltip: 'Eliminar',
              onPressed: () async {
                final ok = await confirmDialog(context, 'Eliminar recurso',
                    '¿Eliminar "${resource.title}"?');
                if (!ok || !context.mounted) return;
                try {
                  await data.deleteCommunicationResource(resource.id);
                } on ApiException catch (e) {
                  if (context.mounted) {
                    showAppSnack(context, e.message, error: true);
                  }
                }
              },
            ),
        ],
      ),
    );
  }

  /// Un enlace se abre directo; un archivo necesita que el servidor lo firme
  /// primero. La URL firmada vence en una hora, así que se pide al tocar y no
  /// al dibujar la lista.
  Future<void> _abrir(BuildContext context, DataProvider data) async {
    final clave = resource.s3Key;
    if (!resource.isLink && clave == null) return;
    try {
      final destino =
          resource.isLink ? resource.url : await data.resolveFileUrl(clave!);
      if (destino == null || !context.mounted) return;
      await launchUrl(Uri.parse(destino), mode: LaunchMode.externalApplication);
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }
}

class _ResourceFormDialog extends StatefulWidget {
  const _ResourceFormDialog();

  @override
  State<_ResourceFormDialog> createState() => _ResourceFormDialogState();
}

class _ResourceFormDialogState extends State<_ResourceFormDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _url = TextEditingController();
  final List<UploadedFile> _archivo = [];

  String _type = 'file';
  bool _saving = false;
  ApiException? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final esArchivo = _type == 'file';
    if (_title.text.trim().isEmpty) {
      setState(() =>
          _error = const ValidationError('El recurso necesita un título.'));
      return;
    }
    if (esArchivo && _archivo.isEmpty) {
      setState(() =>
          _error = const ValidationError('Falta subir el archivo.'));
      return;
    }
    if (!esArchivo && _url.text.trim().isEmpty) {
      setState(() => _error = const ValidationError('Falta la URL.'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await context.read<DataProvider>().createCommunicationResource({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'type': _type,
        if (esArchivo) ...{
          's3Key': _archivo.first.s3Key,
          'fileName': _archivo.first.fileName,
          'contentType': _archivo.first.contentType,
          'sizeBytes': _archivo.first.sizeBytes,
        } else
          'url': _url.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessCheck(context, 'Recurso publicado ✓');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveFormShell(
      title: 'Nuevo recurso',
      maxWidth: 480,
      saving: _saving,
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _title,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            enabled: !_saving,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final (valor, etiqueta) in const [
                ('file', 'Archivo'),
                ('link', 'Enlace'),
              ])
                ChoiceChip(
                  label: Text(etiqueta),
                  selected: _type == valor,
                  selectedColor: AppColors.gold.withValues(alpha: 0.25),
                  onSelected:
                      _saving ? null : (_) => setState(() => _type = valor),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_type == 'file')
            FileUploadField(
              purpose: 'communication_resource',
              files: _archivo,
              enabled: !_saving,
              onChanged: () => setState(() {}),
            )
          else
            TextField(
              controller: _url,
              enabled: !_saving,
              decoration: const InputDecoration(
                  labelText: 'URL', hintText: 'https://…'),
            ),
        ],
      ),
    );
  }
}
