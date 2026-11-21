import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show GlobalKey;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../l10n/textos.dart';
import '../models/models.dart';
import '../utils/formatos.dart';

/// Una gráfica del tablero, para ponerla en el reporte o bajarla sola.
class GraficaDelReporte {
  final String titulo;
  final GlobalKey llave;
  const GraficaDelReporte(this.titulo, this.llave);
}

/// El reporte del tablero del administrador (recomendaciones del 20 de
/// noviembre): las cifras, las gráficas tal como se ven y las tablas de
/// impacto, en un PDF que se descarga.
///
/// Las gráficas se toman de la pantalla ([RepaintBoundary] con su
/// [GlobalKey]) en vez de redibujarse: así el reporte muestra exactamente lo
/// que la persona estaba mirando.
class ReporteAdmin {
  ReporteAdmin._();

  /// Una foto PNG de lo que dibuja el [RepaintBoundary] de [llave], al doble
  /// de resolución para que se lea impresa. `null` si no está en pantalla.
  static Future<Uint8List?> capturar(GlobalKey llave) async {
    final frontera = llave.currentContext?.findRenderObject();
    if (frontera is! RenderRepaintBoundary) return null;
    final imagen = await frontera.toImage(pixelRatio: 2);
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    imagen.dispose();
    return datos?.buffer.asUint8List();
  }

  /// Arma el PDF.
  static Future<Uint8List> armar({
    required ImpactMetrics metricas,
    required Map<String, Uint8List> graficas,
    required List<(String, int)> proyectosPorFase,
  }) async {
    Future<pw.Font> ttf(String ruta) async =>
        pw.Font.ttf(await rootBundle.load(ruta));
    final sans = await ttf('assets/media/DM_Sans/static/DMSans-Regular.ttf');
    final sansBold =
        await ttf('assets/media/DM_Sans/static/DMSans-SemiBold.ttf');
    final titulo = await ttf('assets/media/oswald/Oswald-Bold.ttf');

    final c = metricas.counts;
    const tinta = PdfColor.fromInt(0xFF1B1A1E);
    const tenue = PdfColor.fromInt(0xFF6B676E);
    const linea = PdfColor.fromInt(0xFFD8D4CE);
    const ambar = PdfColor.fromInt(0xFFFFC107);

    pw.Widget seccion(String texto) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
          child: pw.Text(texto.toUpperCase(),
              style: pw.TextStyle(font: titulo, fontSize: 15, color: tinta)),
        );

    pw.Widget tabla(List<String> encabezados, List<List<String>> filas) =>
        pw.TableHelper.fromTextArray(
          headers: encabezados,
          data: filas,
          border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: linea, width: 0.5),
              bottom: pw.BorderSide(color: linea, width: 0.5)),
          headerStyle: pw.TextStyle(font: sansBold, fontSize: 10, color: tinta),
          headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF4F2EF)),
          cellStyle: pw.TextStyle(font: sans, fontSize: 10, color: tinta),
          cellAlignments: {
            for (var i = 1; i < encabezados.length; i++)
              i: pw.Alignment.centerRight,
          },
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        );

    final cifras = <(String, int)>[
      (tr.tabEstudiantesCorto, c.allStudents),
      (tr.tabProyectosCorto, c.projects),
      (tr.tabEquipos, c.groups),
      (tr.tabCursosCorto, c.courses),
      (tr.certificacionesEmitidos, c.certificates),
      (tr.proyectosUniversidades, c.universities),
      (tr.labMentores, c.mentors),
      (tr.tabLaboratorios, c.laboratories),
    ];
    final porRol = <(String, int)>[
      (tr.adminEstudAbrev, c.allStudents),
      ('LXD', c.lxds),
      (tr.labMentores, c.mentors),
      (tr.adminAsesores, c.advisors),
      (tr.adminEmpresas, c.companies),
      (tr.adminDonantes, c.donors),
    ];

    final doc = pw.Document(
      title: tr.reporteTitulo,
      author: 'eduXaction',
    );
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: ambar, width: 2))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('eduXaction',
                style: pw.TextStyle(font: sansBold, fontSize: 11, color: tinta)),
            pw.Text(fechaHora(DateTime.now()),
                style: pw.TextStyle(font: sans, fontSize: 9, color: tenue)),
          ],
        ),
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(font: sans, fontSize: 9, color: tenue)),
      ),
      build: (ctx) => [
        pw.Text(tr.reporteTitulo.toUpperCase(),
            style: pw.TextStyle(font: titulo, fontSize: 24, color: tinta)),
        pw.SizedBox(height: 4),
        pw.Text(tr.adminDashboardSubtitulo,
            style: pw.TextStyle(font: sans, fontSize: 10, color: tenue)),
        seccion(tr.reporteCifras),
        tabla([tr.reporteIndicador, tr.reporteCantidad],
            [for (final (n, v) in cifras) [n, '$v']]),
        for (final g in graficas.entries) ...[
          seccion(g.key),
          pw.Center(
            child: pw.Image(pw.MemoryImage(g.value),
                height: 200, fit: pw.BoxFit.contain),
          ),
        ],
        seccion(tr.adminUsuariosPorRol),
        tabla([tr.usuariosRol, tr.reporteCantidad],
            [for (final (n, v) in porRol) [n, '$v']]),
        if (proyectosPorFase.isNotEmpty) ...[
          seccion(tr.adminProyectosPorEtapa),
          tabla([tr.comunEtapa, tr.reporteCantidad],
              [for (final (n, v) in proyectosPorFase) [n, '$v']]),
        ],
        if (metricas.hoursByCompetency.isNotEmpty) ...[
          seccion(tr.reporteHorasPorCompetencia),
          tabla([tr.constructorCompetencias, tr.reporteHoras], [
            for (final h in metricas.hoursByCompetency)
              [h.name, decimal(h.hours)]
          ]),
        ],
        if (metricas.odsCompletionRate.isNotEmpty) ...[
          seccion(tr.reporteCoberturaOds),
          tabla([tr.categoriaPasoOds, tr.reporteAvance], [
            for (final o in metricas.odsCompletionRate)
              [o.label, '${(o.rate * 100).round()} %']
          ]),
        ],
        if (metricas.sponsoredHoursByCompany.isNotEmpty) ...[
          seccion(tr.reporteHorasPatrocinadas),
          tabla([tr.adminEmpresas, tr.reporteHoras], [
            for (final s in metricas.sponsoredHoursByCompany)
              [s.companyName, decimal(s.hours)]
          ]),
        ],
      ],
    ));
    return doc.save();
  }

  /// Descarga el PDF (en la web) o lo comparte (en el teléfono).
  static Future<void> descargar(Uint8List pdf) => Printing.sharePdf(
        bytes: pdf,
        filename: tr.reporteArchivo(
            DateTime.now().toIso8601String().substring(0, 10)),
      );
}
