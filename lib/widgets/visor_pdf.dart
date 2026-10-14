import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/textos.dart';
import '../utils/app_theme.dart';
import 'async_states.dart';
import 'aviso_de_lectura.dart';

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

  /// El material de una lección: se llama una vez, al llegar al final del
  /// documento (es lo que completa una lectura). Abajo se ve qué falta.
  final VoidCallback? onReachedEnd;

  const VisorPdf({
    super.key,
    required this.titulo,
    required this.nombreArchivo,
    required this.cargar,
    this.onReachedEnd,
  });

  @override
  State<VisorPdf> createState() => _VisorPdfState();
}

class _VisorPdfState extends State<VisorPdf> {
  // Una sola descarga: `PdfPreview` vuelve a pedir el documento cada vez que
  // se redibuja.
  late final Future<Uint8List> _bytes = widget.cargar();

  final _scroll = ScrollController();
  bool _leido = false;

  /// Cuántas páginas tiene el documento. `PdfPreview` las va dibujando de a
  /// una, así que sin este número la primera página —que entra entera en la
  /// pantalla— parecería el final de un documento de diez.
  int? _paginas;
  int _dibujadas = 0;

  @override
  void initState() {
    super.initState();
    if (widget.onReachedEnd != null) {
      _scroll.addListener(_mirar);
      unawaited(_contarPaginas());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _contarPaginas() async {
    try {
      // A 2 ppp cada página son unos pocos píxeles: contarlas es barato.
      final cuantas = await Printing.raster(await _bytes, dpi: 2).length;
      if (mounted) setState(() => _paginas = cuantas);
      _mirarDespues();
    } catch (_) {
      // Sin la cuenta no hay cómo saber cuál es la última: el aviso no se da.
    }
  }

  void _mirarDespues() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _mirar());

  /// Al final: todas las páginas dibujadas y lo que queda por debajo es menos
  /// que un dedo. Un documento que entra entero llega al final enseguida.
  void _mirar() {
    final aviso = widget.onReachedEnd;
    final paginas = _paginas;
    if (aviso == null || _leido || !mounted || paginas == null) return;
    if (_dibujadas < paginas || !_scroll.hasClients) return;
    final posicion = _scroll.position;
    if (!posicion.hasContentDimensions || posicion.extentAfter > 48) return;
    setState(() => _leido = true);
    aviso();
  }

  Widget _paginasDibujadas(BuildContext context, List<PdfPreviewPageData> pages) {
    if (pages.length != _dibujadas) {
      _dibujadas = pages.length;
      _mirarDespues();
    }
    return ListView.builder(
      controller: _scroll,
      itemCount: pages.length,
      itemBuilder: (context, i) => Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(offset: Offset(0, 3), blurRadius: 5)],
        ),
        child: AspectRatio(
          aspectRatio: pages[i].aspectRatio,
          child: Image(image: pages[i].image, fit: BoxFit.cover),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget error(BuildContext context, Object error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              tr.visorNoAbre,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        );
    final cargando = BrandLoader(message: tr.visorAbriendo);

    final preview = widget.onReachedEnd == null
        ? PdfPreview(
            build: (_) => _bytes,
            pdfFileName: widget.nombreArchivo,
            allowSharing: true,
            allowPrinting: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            loadingWidget: cargando,
            onError: error,
          )
        : PdfPreview.builder(
            build: (_) => _bytes,
            pdfFileName: widget.nombreArchivo,
            allowSharing: true,
            allowPrinting: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            loadingWidget: cargando,
            onError: error,
            pagesBuilder: _paginasDibujadas,
          );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(widget.titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16)),
      ),
      body: preview,
      bottomNavigationBar: widget.onReachedEnd == null
          ? null
          : SafeArea(
              child: AvisoDeLectura(
                  leido: _leido, tipo: AvisoDeLecturaTipo.pdf)),
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
  String? titulo,
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
  String? titulo,
  VoidCallback? onReachedEnd,
}) async {
  final tituloVisible = titulo ?? tr.visorDocumento;
  final uri = Uri.parse(url);
  final nombre = uri.pathSegments.isEmpty ? tr.visorNombreArchivo : uri.pathSegments.last;
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => VisorPdf(
        titulo: tituloVisible,
        nombreArchivo: nombre,
        cargar: () => _descargar(uri),
        onReachedEnd: onReachedEnd,
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
