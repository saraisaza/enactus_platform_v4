import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';

/// Extensiones de archivo aceptadas para un recurso de comunicaciones.
const List<String> _allowedResourceExtensions = [
  'pdf',
  'jpeg',
  'jpg',
  'png',
  'svg',
];

const List<String> _imageExtensions = ['jpg', 'jpeg', 'png'];

/// Vista de solo lectura: Asesor, Mentor y LXD consultan y descargan las
/// plantillas que Admin publica desde "Recursos Comunicaciones". Sin
/// controles de edición — misma fuente de datos que [AdminCommunicationResources],
/// así que un recurso nuevo aparece aquí de inmediato.
class CommunicationResourcesView extends StatelessWidget {
  const CommunicationResourcesView({super.key});

  @override
  Widget build(BuildContext context) {
    final resources = context.watch<DataProvider>().communicationResources;
    return TabBody(
      title: 'Recursos Comunicaciones',
      subtitle:
          'Plantillas y material de comunicaciones y diseño publicados por el equipo Admin',
      children: [
        if (resources.isEmpty)
          const EmptyState(
              icon: Icons.perm_media_outlined,
              message: 'Aún no hay recursos publicados.')
        else
          _ResourceGrid(resources: resources),
      ],
    );
  }
}

/// Gestión desde Admin: sube archivos (PDF, JPEG, JPG, PNG, SVG) o enlaces
/// y los elimina. Quedan visibles de inmediato en Asesor, Mentor y LXD
/// (mismo [DataProvider] — solo cambia el acceso de escritura).
class AdminCommunicationResources extends StatelessWidget {
  const AdminCommunicationResources({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final resources = data.communicationResources;
    return TabBody(
      title: 'Recursos Comunicaciones',
      subtitle:
          'Plantillas para Asesor, Mentor y LXD — sube archivos o enlaces',
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nuevo recurso'),
          onPressed: () => _editResource(context),
        ),
      ],
      children: [
        if (resources.isEmpty)
          const EmptyState(
              icon: Icons.perm_media_outlined,
              message: 'Aún no has subido ningún recurso.')
        else
          _ResourceGrid(
            resources: resources,
            onDelete: (r) async {
              if (await confirmDialog(
                  context, 'Eliminar recurso', '¿Eliminar "${r.title}"?')) {
                await data.deleteCommunicationResource(r.id);
              }
            },
          ),
      ],
    );
  }

  Future<void> _editResource(BuildContext context) async {
    final data = context.read<DataProvider>();
    final auth = context.read<AuthProvider>();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    var type = CommunicationResourceType.file;
    PlatformFile? picked;
    var picking = false;

    await showAdaptiveFormDialog<void>(
      context: context,
      title: 'Nuevo recurso',
      maxWidth: 480,
      contentBuilder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Archivo'),
                  selected: type == CommunicationResourceType.file,
                  onSelected: (_) =>
                      setState(() => type = CommunicationResourceType.file),
                ),
                ChoiceChip(
                  label: const Text('Enlace'),
                  selected: type == CommunicationResourceType.link,
                  onSelected: (_) =>
                      setState(() => type = CommunicationResourceType.link),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Título')),
            const SizedBox(height: 12),
            TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)')),
            const SizedBox(height: 12),
            if (type == CommunicationResourceType.file) ...[
              OutlinedButton.icon(
                icon: picking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file_outlined, size: 18),
                label: Text(
                    picked == null ? 'Seleccionar archivo' : 'Cambiar archivo'),
                onPressed: picking
                    ? null
                    : () async {
                        setState(() => picking = true);
                        try {
                          final result = await FilePicker.pickFiles(
                            dialogTitle: 'Selecciona una plantilla',
                            type: FileType.custom,
                            allowedExtensions: _allowedResourceExtensions,
                            withData: true,
                          );
                          final file = result?.files.single;
                          if (file == null) return;
                          final ext = (file.extension ?? '').toLowerCase();
                          if (file.bytes == null ||
                              !_allowedResourceExtensions.contains(ext)) {
                            if (ctx.mounted) {
                              showAppSnack(
                                  ctx,
                                  'Formato no permitido. Usa PDF, JPEG, JPG, PNG o SVG.',
                                  error: true);
                            }
                            return;
                          }
                          setState(() => picked = file);
                        } finally {
                          if (ctx.mounted) setState(() => picking = false);
                        }
                      },
              ),
              if (picked != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(picked!.name,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12.5)),
                ),
            ] else
              TextField(
                controller: urlCtrl,
                decoration:
                    const InputDecoration(labelText: 'Enlace (https://...)'),
              ),
          ],
        ),
      ),
      actionsBuilder: (ctx) => [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () async {
            final title = titleCtrl.text.trim();
            if (title.isEmpty) {
              showAppSnack(ctx, 'Escribe un título', error: true);
              return;
            }
            if (type == CommunicationResourceType.file && picked == null) {
              showAppSnack(ctx, 'Selecciona un archivo', error: true);
              return;
            }
            final url = urlCtrl.text.trim();
            if (type == CommunicationResourceType.link &&
                !(url.startsWith('http://') || url.startsWith('https://'))) {
              showAppSnack(
                  ctx, 'El enlace debe empezar con http:// o https://',
                  error: true);
              return;
            }
            await data.saveCommunicationResource(CommunicationResource(
              id: data.newId('res'),
              title: title,
              description: descCtrl.text.trim(),
              type: type,
              fileName: picked?.name ?? '',
              fileBase64: picked == null ? '' : base64Encode(picked!.bytes!),
              url: url,
              uploadedBy: auth.currentUser!.id,
            ));
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Grilla responsiva de tarjetas: 1 columna en compact, más en medium/
/// expanded según el ancho disponible — mismo patrón `LayoutBuilder` +
/// `responsiveColumns` + `Wrap` usado en 10+ pantallas de la app.
class _ResourceGrid extends StatelessWidget {
  final List<CommunicationResource> resources;
  final void Function(CommunicationResource)? onDelete;
  const _ResourceGrid({required this.resources, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final columns =
            responsiveColumns(constraints.maxWidth, minCardWidth: 190, gap: gap);
        final cardWidth = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final r in resources)
              SizedBox(
                width: cardWidth,
                child: _ResourceCard(
                  resource: r,
                  onDelete: onDelete == null ? null : () => onDelete!(r),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final CommunicationResource resource;
  final VoidCallback? onDelete;
  const _ResourceCard({required this.resource, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isImage = resource.type == CommunicationResourceType.file &&
        _imageExtensions.contains(resource.fileExt);
    return HoverCard(
      padding: EdgeInsets.zero,
      onTap: () => _showResourceDetail(context, resource),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: isImage
                        ? Image.memory(base64Decode(resource.fileBase64),
                            fit: BoxFit.cover)
                        : Container(
                            color: AppColors.surfaceAlt,
                            alignment: Alignment.center,
                            child: Icon(_resourceIcon(resource),
                                size: 36, color: AppColors.gold),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(resource.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  '${_resourceCaption(resource)} · ${DateFormat('d MMM yyyy', 'es').format(resource.date)}',
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          // Botón de eliminar: círculo visible pequeño (24×24) centrado en
          // un área táctil invisible de 48×48 — mismo patrón que el botón
          // "quitar" de la galería en admin_portal.dart.
          if (onDelete != null)
            Positioned(
              top: 0,
              right: 0,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: GestureDetector(
                      onTap: onDelete,
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.statusCritical,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

IconData _resourceIcon(CommunicationResource r) {
  if (r.type == CommunicationResourceType.link) return Icons.link_outlined;
  if (r.fileExt == 'pdf') return Icons.picture_as_pdf_outlined;
  return Icons.image_outlined;
}

String _resourceCaption(CommunicationResource r) {
  if (r.type == CommunicationResourceType.link) return 'Enlace';
  return r.fileExt.isEmpty ? 'Archivo' : r.fileExt.toUpperCase();
}

Future<void> _openOrDownload(BuildContext context, CommunicationResource r) async {
  if (r.type == CommunicationResourceType.link) {
    final uri = Uri.tryParse(r.url);
    final ok =
        uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showAppSnack(context, 'No se pudo abrir el enlace', error: true);
    }
    return;
  }
  final path = await FilePicker.saveFile(
    dialogTitle: 'Guardar ${r.fileName}',
    fileName: r.fileName,
    type: FileType.custom,
    allowedExtensions: [if (r.fileExt.isNotEmpty) r.fileExt],
    bytes: base64Decode(r.fileBase64),
  );
  if (context.mounted && path != null) {
    showSuccessCheck(context, 'Descargado ✓');
  }
}

Future<void> _showResourceDetail(BuildContext context, CommunicationResource r) {
  final isImage = r.type == CommunicationResourceType.file &&
      _imageExtensions.contains(r.fileExt);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(children: [
        Icon(_resourceIcon(r), color: AppColors.gold, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(r.title)),
      ]),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tipo: ${_resourceCaption(r)}',
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            Text('Publicado: ${DateFormat('d MMM yyyy', 'es').format(r.date)}',
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            if (r.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(r.description,
                  style: const TextStyle(fontSize: 14, height: 1.5)),
            ],
            if (isImage) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    Image.memory(base64Decode(r.fileBase64), fit: BoxFit.contain),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ElevatedButton.icon(
          icon: Icon(
              r.type == CommunicationResourceType.link
                  ? Icons.open_in_new
                  : Icons.download_outlined,
              size: 18),
          label: Text(
              r.type == CommunicationResourceType.link ? 'Abrir enlace' : 'Descargar'),
          onPressed: () => _openOrDownload(context, r),
        ),
      ],
    ),
  );
}
