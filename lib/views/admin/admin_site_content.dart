import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../widgets/file_upload_field.dart';
import '../../widgets/portal_shell.dart';

/// Contenido de la página principal: hero, banner, cifras y galería.
class AdminSiteContent extends StatelessWidget {
  const AdminSiteContent({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'Contenido de la Página Principal',
      subtitle: 'Hero, banner y textos visibles para el público',
      children: [
        data.siteContent.when(
          loading: () => const CardListSkeleton(count: 1, height: 400),
          error: (e) => ErrorState(e, onRetry: data.reloadSiteContent),
          // La `key` fuerza a rehacer los controladores cuando el contenido se
          // recarga: si no, tras guardar seguirían mostrando lo que se escribió
          // aunque el servidor hubiera normalizado algo.
          data: (content) =>
              _Form(key: ValueKey(content.heroTitle), content: content),
        ),
      ],
    );
  }
}

class _Form extends StatefulWidget {
  final SiteContent content;
  const _Form({super.key, required this.content});

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _banner;
  late final TextEditingController _about;
  late final TextEditingController _meetingLink;
  late final TextEditingController _statStudents;
  late final TextEditingController _statProjects;
  late final TextEditingController _statLabs;
  late final TextEditingController _statUniversities;

  /// Lo que acaba de subirse y todavía no está en la galería.
  final List<UploadedFile> _nuevas = [];

  bool _saving = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.content;
    _title = TextEditingController(text: c.heroTitle);
    _subtitle = TextEditingController(text: c.heroSubtitle);
    _banner = TextEditingController(text: c.bannerText);
    _about = TextEditingController(text: c.aboutText);
    _meetingLink = TextEditingController(text: c.meetingLink);
    _statStudents = TextEditingController(text: '${c.statStudents}');
    _statProjects = TextEditingController(text: '${c.statProjects}');
    _statLabs = TextEditingController(text: '${c.statLabs}');
    _statUniversities = TextEditingController(text: '${c.statUniversities}');
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _subtitle,
      _banner,
      _about,
      _meetingLink,
      _statStudents,
      _statProjects,
      _statLabs,
      _statUniversities,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error =
          const ValidationError('El título del hero no puede quedar vacío.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = context.read<DataProvider>();
      await data.saveSiteContent({
        'heroTitle': _title.text.trim(),
        'heroSubtitle': _subtitle.text.trim(),
        'bannerText': _banner.text.trim(),
        'aboutText': _about.text.trim(),
        'meetingLink': _meetingLink.text.trim(),
        'statStudents': int.tryParse(_statStudents.text.trim()) ?? 0,
        'statProjects': int.tryParse(_statProjects.text.trim()) ?? 0,
        'statLabs': int.tryParse(_statLabs.text.trim()) ?? 0,
        'statUniversities': int.tryParse(_statUniversities.text.trim()) ?? 0,
      });
      if (!mounted) return;
      setState(() => _saving = false);
      showSuccessCheck(context, 'Página principal actualizada ✓');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e;
        });
      }
    }
  }

  /// Publica en la galería lo que se acaba de subir.
  ///
  /// Va en dos pasos porque la subida y la publicación son cosas distintas: el
  /// archivo llega a S3 primero y solo después se anuncia en la portada, que
  /// se ve sin sesión.
  Future<void> _publicarNuevas() async {
    if (_nuevas.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final data = context.read<DataProvider>();
    try {
      for (final archivo in [..._nuevas]) {
        await data.addGalleryImage(archivo.s3Key);
      }
      if (!mounted) return;
      setState(() {
        _nuevas.clear();
        _saving = false;
      });
      showSuccessCheck(context, 'Imágenes publicadas ✓');
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
    return HoverCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 14),
          ],
          _campo(_title, 'Título del hero'),
          const SizedBox(height: 14),
          _campo(_subtitle, 'Subtítulo del hero', maxLines: 2),
          const SizedBox(height: 14),
          _campo(_banner, 'Banner de anuncio (vacío = oculto)'),
          const SizedBox(height: 14),
          _campo(_about, 'Texto "Sobre nosotros"', maxLines: 3),
          const SizedBox(height: 14),
          TextField(
            controller: _meetingLink,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Link de videollamada (módulos de mentoría)',
              helperText: 'Un solo enlace genérico: todavía no hay integración '
                  'con un proveedor de reuniones.',
            ),
          ),
          const SizedBox(height: 20),
          const Text('Cifras del hero',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          const Text(
            'Los cuatro números bajo el título. Se escriben a mano a propósito: '
            'son la cifra que el equipo quiere comunicar, no el conteo de la '
            'base — ese vive en el panel.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          // Dos por fila cuando caben; apiladas cuando no.
          LayoutBuilder(
            builder: (context, c) {
              final campos = [
                _numero(_statStudents, 'Estudiantes activos'),
                _numero(_statProjects, 'Proyectos de impacto'),
                _numero(_statLabs, 'Laboratorios'),
                _numero(_statUniversities, 'Universidades aliadas'),
              ];
              if (c.maxWidth < 460) {
                return Column(
                  children: [
                    for (final campo in campos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: campo,
                      ),
                  ],
                );
              }
              return Column(
                children: [
                  Row(children: [
                    Expanded(child: campos[0]),
                    const SizedBox(width: 14),
                    Expanded(child: campos[1]),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: campos[2]),
                    const SizedBox(width: 14),
                    Expanded(child: campos[3]),
                  ]),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _Galeria(
            imagenes: widget.content.gallery,
            nuevas: _nuevas,
            enabled: !_saving,
            onChanged: () => setState(() {}),
            onPublicar: _publicarNuevas,
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
              onPressed: _saving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo(TextEditingController c, String label, {int maxLines = 1}) =>
      TextField(
        controller: c,
        enabled: !_saving,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      );

  Widget _numero(TextEditingController c, String label) => TextField(
        controller: c,
        enabled: !_saving,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label),
      );
}

class _Galeria extends StatelessWidget {
  final List<GalleryImage> imagenes;
  final List<UploadedFile> nuevas;
  final bool enabled;
  final VoidCallback onChanged;
  final Future<void> Function() onPublicar;

  const _Galeria({
    required this.imagenes,
    required this.nuevas,
    required this.enabled,
    required this.onChanged,
    required this.onPublicar,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.read<DataProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Galería de imágenes',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 4),
        const Text(
          'Se muestran en la página principal, entre los laboratorios y el '
          'cierre. Quitar una la saca de la portada de inmediato.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        if (imagenes.isEmpty)
          const Text('Todavía no hay imágenes en la galería.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5))
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final img in imagenes)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        // Ya viene firmada: la portada se ve sin sesión, así
                        // que el servidor la firma al construir la respuesta.
                        child: Image.network(img.url, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                                  color: AppColors.surfaceAlt,
                                  child: const Icon(Icons.broken_image_outlined,
                                      color: AppColors.textMuted),
                                )),
                      ),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      // El círculo visible mide 24; el área táctil, 48. Crece
                      // hacia adentro de la miniatura, no hacia la vecina.
                      child: GestureDetector(
                        onTap: !enabled
                            ? null
                            : () async {
                                final ok = await confirmDialog(
                                  context,
                                  'Quitar imagen',
                                  '¿Sacarla de la página principal?',
                                );
                                if (!ok) return;
                                await data.removeGalleryImage(img.id);
                              },
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Align(
                            alignment: Alignment.topRight,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.statusCritical,
                              child: Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        const SizedBox(height: 14),
        FileUploadField(
          purpose: 'site_gallery',
          files: nuevas,
          maxFiles: 6,
          enabled: enabled,
          onChanged: onChanged,
        ),
        if (nuevas.isNotEmpty) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text('Publicar ${nuevas.length} en la portada'),
              onPressed: enabled ? onPublicar : null,
            ),
          ),
        ],
      ],
    );
  }
}
