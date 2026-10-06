import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BuildContext, MaterialPageRoute, Navigator;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../l10n/textos.dart';
import '../models/models.dart';
import '../utils/formatos.dart';
import '../widgets/visor_pdf.dart';

/// Genera certificados en PDF con el logo institucional.
class PdfService {
  // Los tres valores de `AppColors` repetidos a mano: `PdfColor` no acepta
  // un `Color` de Flutter, así que no hay forma de referenciar el token
  // desde acá. Es una de las dos excepciones documentadas en
  // `app_theme.dart` — y por serlo, hay que acordarse de moverlos cuando la
  // paleta cambia: en el rebranding se quedaron con el naranja y el negro
  // viejos, imprimiendo certificados con la identidad anterior.
  static const _gold = PdfColor.fromInt(0xFFFFC107); // AppColors.gold
  static const _dark = PdfColor.fromInt(0xFF17171A); // AppColors.surface
  static const _slate = PdfColor.fromInt(0xFF26262A); // AppColors.slate

  /// Construye el documento del certificado.
  static Future<pw.Document> buildCertificate(Certificate cert) async {
    final doc = pw.Document();
    final dateStr = fechaLarga(cert.issuedAt);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (ctx) => pw.Container(
          decoration: pw.BoxDecoration(
            color: _dark,
            border: pw.Border.all(color: _gold, width: 3),
          ),
          padding: const pw.EdgeInsets.all(40),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              // Wordmark tipográfico "eduXaction" (antes: logo en imagen).
              pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(
                      text: 'edu',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 30,
                          fontWeight: pw.FontWeight.normal)),
                  pw.TextSpan(
                      text: 'X',
                      style: pw.TextStyle(
                          color: _gold,
                          fontSize: 30,
                          fontWeight: pw.FontWeight.bold)),
                  pw.TextSpan(
                      text: 'action',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 30,
                          fontWeight: pw.FontWeight.normal)),
                ]),
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                tr.certificadoTitulo,
                style: pw.TextStyle(
                  color: _gold,
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(tr.certificadoSeCertifica,
                  style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.Text(
                cert.studentName,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(tr.certificadoCompleto,
                  style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 14)),
              pw.SizedBox(height: 8),
              pw.Text(
                cert.laboratoryName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  color: _gold,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (cert.hours > 0) ...[
                pw.SizedBox(height: 6),
                pw.Text(
                  tr.certificadoIntensidad(cert.hours),
                  style: const pw.TextStyle(
                      color: PdfColors.grey300, fontSize: 12),
                ),
              ],
              pw.SizedBox(height: 28),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  pw.Column(children: [
                    pw.Container(width: 160, height: 1, color: PdfColors.grey500),
                    pw.SizedBox(height: 6),
                    pw.Text(cert.issuerName,
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 12)),
                    pw.Text(tr.certificadoEmitidoPor,
                        style: const pw.TextStyle(
                            color: PdfColors.grey400, fontSize: 10)),
                  ]),
                  pw.Column(children: [
                    pw.Text(dateStr,
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 12)),
                    pw.Text(tr.certificadoFechaEmision,
                        style: const pw.TextStyle(
                            color: PdfColors.grey400, fontSize: 10)),
                  ]),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: _slate,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  tr.certificadoCodigo(cert.code),
                  style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                tr.certificadoPie,
                style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
    return doc;
  }

  /// Muestra el certificado.
  ///
  /// En la app, en el visor propio, con "Compartir" e "Imprimir": antes abría
  /// directo el diálogo de impresión del sistema, que no es un visor. En el
  /// navegador sigue siendo el diálogo de impresión de siempre ([preview]).
  static Future<void> ver(BuildContext context, Certificate cert) async {
    if (kIsWeb) return preview(cert);
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => VisorPdf(
          titulo: tr.certificadoTituloVisor(cert.laboratoryName),
          nombreArchivo: tr.certificadoArchivo(cert.code),
          cargar: () async => (await buildCertificate(cert)).save(),
        ),
      ),
    );
  }

  /// Abre la vista previa de impresión del certificado
  /// (en web abre el diálogo de impresión del navegador).
  static Future<void> preview(Certificate cert) async {
    await Printing.layoutPdf(
      name: tr.certificadoArchivo(cert.code),
      onLayout: (_) async => (await buildCertificate(cert)).save(),
    );
  }

  /// Descarga/comparte el certificado como archivo PDF.
  static Future<void> download(Certificate cert) async {
    final doc = await buildCertificate(cert);
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: tr.certificadoArchivo(cert.code),
    );
  }
}
