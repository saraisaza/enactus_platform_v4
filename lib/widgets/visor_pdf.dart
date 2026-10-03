import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_theme.dart';
import 'async_states.dart';

/// Visor de PDF dentro de la app, con "Compartir" e "Imprimir".
///
/// Antes cada PDF —el material de una lección, un adjunto, un certificado—
/// sacaba a la persona de la app: Safari en iOS y, en Android, a veces Chrome
/// descargaba el archivo en vez de mostrarlo. El certificado abría el diálogo
/// de impresión del sistema, que no es un visor.
///
/// Usa `PdfPreview` de `printing`, que ya era dependencia. En la web NO se usa:
/// `PdfPreview` pide pdf.js a un CDN, que la CSP de eduxaction.com bloquea a
/// propósito. Ahí el PDF lo muestra `FileViewer`, con la copia local de pdf.js
/// que sirve el sitio (`web/pdfjs/`).
class VisorPdf extends StatefulWidget {
  final String titulo;
  final String nombreArchivo;
  final Future<Uint8List> Function() cargar;

  const VisorPdf({
    super.key,
    required this.titulo,
    required this.nombreArchivo,
    required this.cargar,
  });

  @override
  State<VisorPdf> createState() => _VisorPdfState();
}

class _VisorPdfState extends State<VisorPdf> {
  // Una sola descarga: `PdfPreview` vuelve a pedir el documento cada vez que
  // se redibuja.
  late final Future<Uint8List> _bytes = widget.cargar();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(widget.titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16)),
      ),
      body: PdfPreview(
        build: (_) => _bytes,
        pdfFileName: widget.nombreArchivo,
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        loadingWidget: const BrandLoader(message: 'Abriendo el documento…'),
        onError: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No pudimos abrir este documento. Revise su conexión e '
              'intente de nuevo.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Abre el material de una lección, un adjunto o cualquier enlace.
///
/// - **En el navegador:** pestaña nueva, como siempre.
/// - **En la app:** los PDF en [VisorPdf]; lo demás, en el navegador
///   integrado (Safari o Chrome dentro de la app), que tiene su botón para
///   volver. Así la lección queda donde estaba.
///
/// Devuelve `false` si no se pudo abrir, para que quien llama lo diga.
Future<bool> abrirRecurso(
  BuildContext context,
  String url, {
  String titulo = 'Documento',
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;
  if (kIsWeb) return launchUrl(uri, mode: LaunchMode.externalApplication);

  if (uri.path.toLowerCase().endsWith('.pdf')) {
    await abrirPdf(context, url, titulo: titulo);
    return true;
  }
  return launchUrl(uri, mode: LaunchMode.inAppBrowserView);
}

/// Abre un PDF en [VisorPdf], a pantalla completa. Solo fuera del navegador:
/// en la web lo muestra `FileViewer` con pdf.js.
Future<void> abrirPdf(
  BuildContext context,
  String url, {
  String titulo = 'Documento',
}) async {
  final uri = Uri.parse(url);
  final nombre = uri.pathSegments.isEmpty ? 'documento.pdf' : uri.pathSegments.last;
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => VisorPdf(
        titulo: titulo,
        nombreArchivo: nombre,
        cargar: () => _descargar(uri),
      ),
    ),
  );
}

/// Un enlace de reunión (Meet, Zoom, Teams) se abre en SU aplicación si está
/// instalada; un navegador dentro de eduXaction no sirve para una
/// videollamada.
Future<bool> abrirReunion(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

Future<Uint8List> _descargar(Uri uri) async {
  final respuesta = await http.get(uri);
  if (respuesta.statusCode != 200) {
    throw Exception('Descarga fallida (${respuesta.statusCode}).');
  }
  return respuesta.bodyBytes;
}
