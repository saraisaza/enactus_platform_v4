import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../l10n/textos.dart';
import '../utils/app_theme.dart';
import '../utils/formatos.dart';

/// La primera página de un PDF como imagen, para la vista previa. `null` si
/// no se pudo (el PDF está dañado o la plataforma no sabe dibujarlo): la
/// vista previa muestra entonces el ícono, no un error.
@visibleForTesting
Future<Uint8List?> Function(Uint8List pdf) primeraPaginaDePdf = (pdf) async {
  try {
    await for (final pagina
        in Printing.raster(pdf, pages: const [0], dpi: 60)) {
      return await pagina.toPng();
    }
  } catch (_) {}
  return null;
};

/// Muestra lo que se va a subir y pregunta si se sube (recomendaciones del 20
/// de noviembre: «siempre una vista previa antes de subir»).
///
/// Una imagen se ve entera; de un PDF, su primera página; de lo demás, el
/// ícono de su tipo. Siempre con el nombre y el peso: así se nota antes de
/// subir que se eligió el archivo equivocado. Devuelve `true` para subir.
Future<bool> confirmarAntesDeSubir(
  BuildContext context, {
  required String nombre,
  required Uint8List bytes,
  required String contentType,
}) async {
  final subir = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr.subirVistaPreviaTitulo),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: const ValueKey('vista-previa-archivo'),
              height: 260,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: _Contenido(bytes: bytes, contentType: contentType),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(_icono(contentType), size: 20, color: AppColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Text('${decimal(bytes.length / 1024 / 1024, 2)} MB',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(tr.comunCancelar),
        ),
        ElevatedButton.icon(
          key: const ValueKey('confirmar-subida'),
          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
          label: Text(tr.subirVistaPreviaSubir),
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  return subir ?? false;
}

IconData _icono(String contentType) {
  if (contentType.startsWith('image/')) return Icons.image_outlined;
  if (contentType == 'application/pdf') return Icons.picture_as_pdf_outlined;
  if (contentType.contains('zip')) return Icons.folder_zip_outlined;
  if (contentType.startsWith('video/')) return Icons.movie_outlined;
  return Icons.description_outlined;
}

class _Contenido extends StatelessWidget {
  final Uint8List bytes;
  final String contentType;
  const _Contenido({required this.bytes, required this.contentType});

  Widget _sinVista() => Center(
        child: Icon(_icono(contentType), size: 72, color: AppColors.textMuted),
      );

  @override
  Widget build(BuildContext context) {
    // SVG no: Flutter no lo dibuja sin un paquete aparte.
    if (contentType.startsWith('image/') && contentType != 'image/svg+xml') {
      return Image.memory(bytes,
          fit: BoxFit.contain, errorBuilder: (_, _, _) => _sinVista());
    }
    if (contentType == 'application/pdf') {
      return FutureBuilder<Uint8List?>(
        future: primeraPaginaDePdf(bytes)
            .timeout(const Duration(seconds: 6), onTimeout: () => null),
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final png = s.data;
          return png == null
              ? _sinVista()
              : Image.memory(png, fit: BoxFit.contain);
        },
      );
    }
    return _sinVista();
  }
}
