import 'package:flutter/widgets.dart';

/// `false`: fuera del navegador no hay pdf.js, y el PDF se abre con la
/// aplicación del sistema.
const bool visorPdfDisponible = false;

/// No se usa fuera del navegador: [visorPdfDisponible] es `false`.
class PdfView extends StatelessWidget {
  final String url;
  final Widget Function(String message) errorBuilder;

  const PdfView({super.key, required this.url, required this.errorBuilder});

  @override
  Widget build(BuildContext context) =>
      errorBuilder('Este archivo se abre con la aplicación del sistema.');
}
