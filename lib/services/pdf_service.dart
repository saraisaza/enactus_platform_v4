import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';

/// Genera certificados en PDF con el logo institucional.
class PdfService {
  static const _gold = PdfColor.fromInt(0xFFF4C430);
  static const _dark = PdfColor.fromInt(0xFF111315);
  static const _slate = PdfColor.fromInt(0xFF2D3E50);

  /// Construye el documento del certificado.
  static Future<pw.Document> buildCertificate(Certificate cert) async {
    final doc = pw.Document();
    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/media/mainlogo.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      // Sin logo el certificado sigue siendo válido.
    }
    final dateStr = DateFormat('d MMMM yyyy', 'es').format(cert.date);

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
              if (logo != null) pw.Image(logo, height: 70),
              pw.SizedBox(height: 24),
              pw.Text(
                'CERTIFICADO DE FINALIZACIÓN',
                style: pw.TextStyle(
                  color: _gold,
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Se certifica que',
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
              pw.Text('completó la Ruta de Impacto del laboratorio',
                  style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 14)),
              pw.SizedBox(height: 8),
              pw.Text(
                cert.labName,
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
                  'Intensidad: ${cert.hours} horas certificadas',
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
                    pw.Text('Emitido por',
                        style: const pw.TextStyle(
                            color: PdfColors.grey400, fontSize: 10)),
                  ]),
                  pw.Column(children: [
                    pw.Text(dateStr,
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 12)),
                    pw.Text('Fecha de emisión',
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
                  'Código de verificación: ${cert.code}',
                  style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'Enactus Colombia · Entidad sin ánimo de lucro · Bogotá D. C.',
                style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
    return doc;
  }

  /// Abre la vista previa de impresión del certificado
  /// (en web abre el diálogo de impresión del navegador).
  static Future<void> preview(Certificate cert) async {
    await Printing.layoutPdf(
      name: 'certificado_${cert.code}.pdf',
      onLayout: (_) async => (await buildCertificate(cert)).save(),
    );
  }

  /// Descarga/comparte el certificado como archivo PDF.
  static Future<void> download(Certificate cert) async {
    final doc = await buildCertificate(cert);
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'certificado_${cert.code}.pdf',
    );
  }
}
