import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../l10n/textos.dart';

/// `true`: en el navegador el PDF se dibuja dentro de la página.
const bool visorPdfDisponible = true;

/// Un PDF dibujado por pdf.js dentro de un `<div>` de la página.
///
/// El trabajo lo hace `web/visor_pdf.js`; acá solo se crea el contenedor y se
/// muestra el error si algo falla. Ver ese archivo para el porqué de pdf.js y
/// no un `<iframe>`.
class PdfView extends StatefulWidget {
  final String url;

  /// Qué mostrar si el PDF no se pudo dibujar.
  final Widget Function(String message) errorBuilder;

  const PdfView({super.key, required this.url, required this.errorBuilder});

  @override
  State<PdfView> createState() => _PdfViewState();
}

class _PdfViewState extends State<PdfView> {
  bool _loading = true;
  String? _error;

  Future<void> _render(web.HTMLDivElement contenedor) async {
    String error;
    try {
      final visor = Uri.parse(web.document.baseURI).resolve('visor_pdf.js');
      final modulo = await importModule(visor.toString().toJS).toDart;
      final resultado = await modulo
          .callMethod<JSPromise<JSString>>(
              'mostrarPdf'.toJS, contenedor, widget.url.toJS)
          .toDart;
      error = resultado.toDart;
    } catch (_) {
      error = tr.visorNoCarga;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error.isEmpty ? null : error;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return widget.errorBuilder(_error!);
    return Stack(
      children: [
        Positioned.fill(
          child: HtmlElementView.fromTagName(
            tagName: 'div',
            onElementCreated: (Object elemento) {
              final contenedor = elemento as web.HTMLDivElement;
              contenedor.style
                ..width = '100%'
                ..height = '100%'
                ..overflow = 'auto'
                ..backgroundColor = '#525659';
              _render(contenedor);
            },
          ),
        ),
        if (_loading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
