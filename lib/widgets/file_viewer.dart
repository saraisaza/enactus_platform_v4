import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_theme.dart';
import 'pdf_view_io.dart' if (dart.library.js_interop) 'pdf_view_web.dart';

/// Visor de archivos DENTRO de la página, como el reproductor de YouTube.
///
/// Antes cada archivo se abría con `launchUrl(... externalApplication)`, que
/// en el navegador es una pestaña nueva: la persona salía de la plataforma
/// para ver un PDF de la lección y tenía que volver a buscarla.
///
/// - **PDF**: lo dibuja pdf.js en la misma página (ver `web/visor_pdf.js`).
/// - **Imagen**: con zoom y arrastre.
/// - **Lo demás** (Word, ZIP, SVG): el navegador no lo puede mostrar, así que
///   se ofrece descargarlo, sin salir de la página.
///
/// Recibe la URL ya firmada: quien llama la pide al servidor y muestra el
/// error de permisos como hasta ahora.
class FileViewer {
  FileViewer._();

  static Future<void> show(
    BuildContext context, {
    required String url,
    String? fileName,
    String? s3Key,
  }) async {
    final nombre = _nombreVisible(fileName, s3Key, url);
    final tipo = _tipoDe(fileName, s3Key);

    // Fuera del navegador (escritorio) no hay pdf.js: el PDF se abre con la
    // aplicación del sistema, que ahí no significa salir de ninguna página.
    if (tipo == _Tipo.pdf && !visorPdfDisponible) {
      await _abrirAfuera(context, url);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => _FileViewerDialog(url: url, nombre: nombre, tipo: tipo),
    );
  }

  static String _nombreVisible(String? fileName, String? s3Key, String url) {
    if (fileName != null && fileName.trim().isNotEmpty) return fileName.trim();
    final fuente = s3Key ?? Uri.tryParse(url)?.path ?? '';
    final ultimo = fuente.split('/').last;
    return ultimo.isEmpty ? 'Archivo' : ultimo;
  }

  /// La extensión de la key manda: el servidor la arma con la del archivo
  /// subido. El nombre visible puede ser un título libre («Informe v1.2»).
  static _Tipo _tipoDe(String? fileName, String? s3Key) {
    for (final nombre in [s3Key, fileName]) {
      if (nombre == null || !nombre.contains('.')) continue;
      final ext = nombre.split('.').last.toLowerCase();
      if (ext == 'pdf') return _Tipo.pdf;
      if (const {'png', 'jpg', 'jpeg', 'gif', 'webp'}.contains(ext)) {
        return _Tipo.imagen;
      }
    }
    return _Tipo.otro;
  }
}

enum _Tipo { pdf, imagen, otro }

Future<void> _abrirAfuera(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final ok = uri != null &&
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el archivo.')));
  }
}

class _FileViewerDialog extends StatelessWidget {
  final String url;
  final String nombre;
  final _Tipo tipo;

  const _FileViewerDialog({
    required this.url,
    required this.nombre,
    required this.tipo,
  });

  @override
  Widget build(BuildContext context) {
    final pantalla = MediaQuery.sizeOf(context);
    final compacta = pantalla.width < 600;

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: compacta ? EdgeInsets.zero : const EdgeInsets.all(24),
      shape: compacta
          ? const RoundedRectangleBorder()
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: tipo == _Tipo.otro ? 480 : 1000,
        height: tipo == _Tipo.otro ? null : pantalla.height,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Encabezado(nombre: nombre, url: url, tipo: tipo),
            const Divider(height: 1, color: AppColors.border),
            if (tipo == _Tipo.otro)
              _Aviso(
                mensaje: 'Este tipo de archivo no se puede ver dentro de la '
                    'página. Descárguelo para abrirlo.',
                url: url,
              )
            else
              Expanded(child: _Contenido(url: url, tipo: tipo)),
          ],
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  final String nombre;
  final String url;
  final _Tipo tipo;

  const _Encabezado({required this.nombre, required this.url, required this.tipo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Icon(
            switch (tipo) {
              _Tipo.pdf => Icons.picture_as_pdf_outlined,
              _Tipo.imagen => Icons.image_outlined,
              _Tipo.otro => Icons.insert_drive_file_outlined,
            },
            color: AppColors.gold,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nombre,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
          ),
          if (tipo != _Tipo.otro)
            IconButton(
              tooltip: 'Descargar',
              icon: const Icon(Icons.download_outlined,
                  color: AppColors.textSecondary),
              onPressed: () => _abrirAfuera(context, url),
            ),
          IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  final String url;
  final _Tipo tipo;

  const _Contenido({required this.url, required this.tipo});

  @override
  Widget build(BuildContext context) {
    Widget fallo(String mensaje) =>
        Center(child: _Aviso(mensaje: mensaje, url: url));

    if (tipo == _Tipo.pdf) {
      return PdfView(url: url, errorBuilder: fallo);
    }
    return InteractiveViewer(
      maxScale: 6,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (_, imagen, progreso) => progreso == null
              ? imagen
              : const CircularProgressIndicator(),
          errorBuilder: (_, _, _) =>
              fallo('No se pudo mostrar la imagen.'),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String mensaje;
  final String url;

  const _Aviso({required this.mensaje, required this.url});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Descargar'),
            onPressed: () => _abrirAfuera(context, url),
          ),
        ],
      ),
    );
  }
}
