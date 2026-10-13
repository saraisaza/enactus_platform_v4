import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BuildContext, MaterialPageRoute, Navigator;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../l10n/textos.dart';
import '../models/molde_certificado.dart';
import '../models/models.dart';
import '../providers/data_provider.dart';
import '../utils/constants.dart';
import '../utils/formatos.dart';
import '../widgets/visor_pdf.dart';

/// Genera certificados en PDF con el logo institucional.
class PdfService {
  // Los dos valores de `AppColors` repetidos a mano: `PdfColor` no acepta
  // un `Color` de Flutter, así que no hay forma de referenciar el token
  // desde acá. Es una de las dos excepciones documentadas en
  // `app_theme.dart` — y por serlo, hay que acordarse de moverlos cuando la
  // paleta cambia: en el rebranding se quedaron con el naranja y el negro
  // viejos, imprimiendo certificados con la identidad anterior.
  static const _gold = PdfColor.fromInt(0xFFFFC107); // AppColors.gold
  static const _dark = PdfColor.fromInt(0xFF17171A); // AppColors.surface

  /// Construye el documento del certificado: sobre el [molde] de su cliente
  /// si lo tiene; si no, con el diseño de eduXaction.
  static Future<pw.Document> buildCertificate(Certificate cert,
      {MoldeImpreso? molde}) async {
    if (molde != null) return _sobreElMolde(cert, molde);
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
              pw.SizedBox(height: 16),
              pw.Text(
                tr.certificadoTitulo,
                style: pw.TextStyle(
                  color: _gold,
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 14),
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
              pw.Text(
                  cert.esDeCurso
                      ? tr.certificadoCompletoCurso
                      : tr.certificadoCompleto,
                  style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 14)),
              pw.SizedBox(height: 8),
              pw.Text(
                cert.titulo,
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
              pw.SizedBox(height: 18),
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
                  // El QR abre la verificación pública; va sobre blanco
                  // porque, invertido sobre el fondo oscuro, muchos lectores
                  // no lo reconocen. Debajo, el código para quien lo escriba.
                  pw.Column(children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(3),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: EnlacesWeb.verificarCertificado(cert.id),
                        width: 58,
                        height: 58,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(tr.certificadoCodigo(cert.code),
                        style: const pw.TextStyle(
                            color: PdfColors.grey300, fontSize: 8)),
                    pw.Text(tr.certificadoEscanee,
                        style: const pw.TextStyle(
                            color: PdfColors.grey400, fontSize: 8)),
                  ]),
                ],
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
    final data = context.read<DataProvider>();
    if (kIsWeb) return preview(data, cert);
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => VisorPdf(
          titulo: tr.certificadoTituloVisor(cert.titulo),
          nombreArchivo: tr.certificadoArchivo(cert.code),
          cargar: () async => (await _conSuMolde(data, cert)).save(),
        ),
      ),
    );
  }

  /// Abre la vista previa de impresión del certificado
  /// (en web abre el diálogo de impresión del navegador).
  static Future<void> preview(DataProvider data, Certificate cert) async {
    await Printing.layoutPdf(
      name: tr.certificadoArchivo(cert.code),
      onLayout: (_) async => (await _conSuMolde(data, cert)).save(),
    );
  }

  /// Descarga/comparte el certificado como archivo PDF.
  static Future<void> download(BuildContext context, Certificate cert) async {
    final doc = await _conSuMolde(context.read<DataProvider>(), cert);
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: tr.certificadoArchivo(cert.code),
    );
  }

  // -------------------------------------------------------------------------
  // Sobre el molde del cliente (etapa 6, parte 2)
  // -------------------------------------------------------------------------

  /// El certificado con el molde que le corresponde (lo decide el servidor:
  /// el de su cliente emisor, o el de eduXaction, o ninguno).
  static Future<pw.Document> _conSuMolde(
      DataProvider data, Certificate cert) async {
    final molde = await data.moldeDeCertificado(cert.id);
    return buildCertificate(cert,
        molde: molde == null ? null : await imprimible(data, molde));
  }

  /// Baja el fondo y la firma de [molde]; si el fondo es un PDF, lo convierte
  /// en imagen. `null` si el molde no trae enlaces (un entorno sin
  /// almacenamiento): se imprime con el diseño de siempre.
  static Future<MoldeImpreso?> imprimible(
    DataProvider data,
    MoldeDeCertificado molde, {
    Uint8List? fondo,
    Uint8List? firma,
  }) async {
    final urlFondo = molde.backgroundUrl;
    if (fondo == null && urlFondo == null) return null;
    final crudo = fondo ?? await data.bajarArchivo(urlFondo!);
    final urlFirma = molde.signatureUrl;
    return MoldeImpreso(
      molde: molde,
      fondo: molde.backgroundKind == 'pdf'
          ? (await rasterizar(crudo)).imagen
          : crudo,
      firma: firma ??
          (urlFirma == null ? null : await data.bajarArchivo(urlFirma)),
    );
  }

  /// La primera página de un PDF como PNG, y su tamaño en puntos. A 200 ppp:
  /// suficiente para imprimir, sin pesar como un póster.
  ///
  /// Es una variable para que las pruebas —que no tienen el visor de PDF del
  /// sistema— puedan reemplazarla.
  static Future<({Uint8List imagen, double ancho, double alto})> Function(
      Uint8List pdf) rasterizar = _rasterizarConPrinting;

  static Future<({Uint8List imagen, double ancho, double alto})>
      _rasterizarConPrinting(Uint8List pdf) async {
    const ppp = 200.0;
    await for (final pagina in Printing.raster(pdf, pages: const [0], dpi: ppp)) {
      return (
        imagen: await pagina.toPng(),
        ancho: pagina.width * 72 / ppp,
        alto: pagina.height * 72 / ppp,
      );
    }
    throw StateError('El PDF no tiene páginas.');
  }

  /// Lo que se escribe en cada lugar del molde.
  static Map<String, String> textosDe(Certificate cert) => {
        'nombre': cert.studentName,
        'curso': cert.titulo,
        'fecha': fechaLarga(cert.issuedAt),
        if (cert.hours > 0) 'horas': tr.certificadoIntensidad(cert.hours),
        'codigo': tr.certificadoCodigo(cert.code),
      };

  static Map<String, pw.Font>? _fuentes;

  /// Las letras de la plataforma: Oswald para títulos, DM Sans para el resto.
  static Future<Map<String, pw.Font>> _cargarFuentes() async {
    if (_fuentes != null) return _fuentes!;
    Future<pw.Font> ttf(String ruta) async =>
        pw.Font.ttf(await rootBundle.load(ruta));
    return _fuentes = {
      'sans': await ttf('assets/media/DM_Sans/static/DMSans-Regular.ttf'),
      'sansBold': await ttf('assets/media/DM_Sans/static/DMSans-SemiBold.ttf'),
      'display': await ttf('assets/media/oswald/Oswald-Regular.ttf'),
      'displayBold': await ttf('assets/media/oswald/Oswald-Bold.ttf'),
    };
  }

  static Future<pw.Document> _sobreElMolde(
      Certificate cert, MoldeImpreso impreso) async {
    final m = impreso.molde;
    final ancho = m.pageWidth;
    final alto = m.pageHeight;
    final fuentes = await _cargarFuentes();
    final fondo = pw.MemoryImage(impreso.fondo);
    final firma =
        impreso.firma == null ? null : pw.MemoryImage(impreso.firma!);
    final textos = textosDe(cert);

    pw.Widget texto(CampoDelMolde c, String valor) => pw.Positioned(
          left: c.x * ancho,
          top: c.y * alto,
          child: pw.SizedBox(
            width: c.w * ancho,
            child: pw.Text(
              valor,
              textAlign: switch (c.align) {
                'left' => pw.TextAlign.left,
                'right' => pw.TextAlign.right,
                _ => pw.TextAlign.center,
              },
              style: pw.TextStyle(
                font: fuentes['${c.font}${c.bold ? 'Bold' : ''}'],
                fontSize: c.size * alto,
                color: PdfColor.fromHex(c.color),
              ),
            ),
          ),
        );

    final qr = m.campos['qr'];
    final lugarFirma = m.campos['firma'];
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(ancho, alto, marginAll: 0),
        build: (ctx) => pw.Stack(
          children: [
            pw.Positioned(
              left: 0,
              top: 0,
              right: 0,
              bottom: 0,
              child: pw.Image(fondo, fit: pw.BoxFit.fill),
            ),
            for (final campo in MoldeDeCertificado.camposDeTexto)
              if (m.campos[campo] != null && textos[campo] != null)
                texto(m.campos[campo]!, textos[campo]!),
            if (lugarFirma != null && firma != null)
              pw.Positioned(
                left: lugarFirma.x * ancho,
                top: lugarFirma.y * alto,
                child: pw.Image(firma, width: lugarFirma.w * ancho),
              ),
            // El QR, sobre blanco: sobre un fondo oscuro o con dibujo, muchos
            // lectores no lo reconocen.
            if (qr != null)
              pw.Positioned(
                left: qr.x * ancho,
                top: qr.y * alto,
                child: pw.Container(
                  color: PdfColors.white,
                  padding: pw.EdgeInsets.all(qr.w * ancho * 0.06),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: EnlacesWeb.verificarCertificado(cert.id),
                    width: qr.w * ancho * 0.88,
                    height: qr.w * ancho * 0.88,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return doc;
  }
}
