import 'dart:typed_data';

/// El molde del certificado de un cliente (etapa 6, parte 2).
///
/// Un diseño hecho afuera —PDF de una página o imagen— y dónde va cada dato.
/// Las posiciones van en fracciones de la página (0 a 1): el mismo molde se
/// dibuja igual en el editor, a cualquier tamaño de pantalla, y en el PDF.
class MoldeDeCertificado {
  /// `null` = el molde de eduXaction.
  final String? clientId;

  /// `pdf`, `png` o `jpeg`: lo decide el servidor mirando el archivo.
  final String backgroundKind;

  /// Tamaño de la página en puntos (1/72 de pulgada).
  final double pageWidth;
  final double pageHeight;
  final Map<String, CampoDelMolde> campos;
  final String backgroundS3Key;
  final String? signatureS3Key;

  /// Enlaces firmados para bajar el fondo y la firma (vencen).
  final String? backgroundUrl;
  final String? signatureUrl;

  const MoldeDeCertificado({
    this.clientId,
    required this.backgroundKind,
    required this.pageWidth,
    required this.pageHeight,
    required this.campos,
    required this.backgroundS3Key,
    this.signatureS3Key,
    this.backgroundUrl,
    this.signatureUrl,
  });

  /// Los datos que se escriben, en el orden en que se ofrecen en el editor.
  static const camposDeTexto = ['nombre', 'curso', 'fecha', 'horas', 'codigo'];

  /// Los que se dibujan: el QR de verificación y la firma.
  static const camposDeImagen = ['qr', 'firma'];

  /// Sin estos dos no hay certificado: los exige también el servidor.
  static const obligatorios = ['nombre', 'curso'];

  /// Dónde va cada dato en un molde recién subido: un punto de partida
  /// razonable para una página horizontal, que el admin acomoda arrastrando.
  static Map<String, CampoDelMolde> camposPorOmision() => {
        'nombre': const CampoDelMolde(
            x: 0.1, y: 0.40, w: 0.8, size: 0.065, font: 'display', bold: true),
        'curso': const CampoDelMolde(x: 0.1, y: 0.54, w: 0.8, size: 0.04),
        'horas': const CampoDelMolde(x: 0.1, y: 0.61, w: 0.8, size: 0.025),
        'fecha': const CampoDelMolde(
            x: 0.08, y: 0.84, w: 0.3, size: 0.025, align: 'left'),
        'codigo': const CampoDelMolde(
            x: 0.62, y: 0.92, w: 0.3, size: 0.018, align: 'right'),
        'firma': const CampoDelMolde(x: 0.4, y: 0.74, w: 0.2),
        'qr': const CampoDelMolde(x: 0.84, y: 0.74, w: 0.1),
      };

  factory MoldeDeCertificado.fromJson(Map<String, dynamic> j) {
    final crudos = Map<String, dynamic>.from((j['fields'] as Map?) ?? const {});
    return MoldeDeCertificado(
      clientId: j['clientId'] as String?,
      backgroundKind: (j['backgroundKind'] as String?) ?? 'png',
      pageWidth: (j['pageWidth'] as num?)?.toDouble() ?? 842,
      pageHeight: (j['pageHeight'] as num?)?.toDouble() ?? 595,
      campos: {
        for (final e in crudos.entries)
          e.key: CampoDelMolde.fromJson(Map<String, dynamic>.from(e.value as Map)),
      },
      backgroundS3Key: (j['backgroundS3Key'] as String?) ?? '',
      signatureS3Key: j['signatureS3Key'] as String?,
      backgroundUrl: j['backgroundUrl'] as String?,
      signatureUrl: j['signatureUrl'] as String?,
    );
  }

  /// El cuerpo de `PUT /clients/:owner/certificate-template`.
  Map<String, dynamic> toJson() => {
        'backgroundS3Key': backgroundS3Key,
        'pageWidth': pageWidth,
        'pageHeight': pageHeight,
        'fields': {
          for (final e in campos.entries)
            e.key: e.value.toJson(imagen: camposDeImagen.contains(e.key)),
        },
        'signatureS3Key': signatureS3Key,
      };

  MoldeDeCertificado copyWith({
    Map<String, CampoDelMolde>? campos,
    String? backgroundS3Key,
    String? backgroundKind,
    double? pageWidth,
    double? pageHeight,
    String? Function()? signatureS3Key,
  }) =>
      MoldeDeCertificado(
        clientId: clientId,
        backgroundKind: backgroundKind ?? this.backgroundKind,
        pageWidth: pageWidth ?? this.pageWidth,
        pageHeight: pageHeight ?? this.pageHeight,
        campos: campos ?? this.campos,
        backgroundS3Key: backgroundS3Key ?? this.backgroundS3Key,
        signatureS3Key:
            signatureS3Key != null ? signatureS3Key() : this.signatureS3Key,
        backgroundUrl: backgroundUrl,
        signatureUrl: signatureUrl,
      );
}

/// Dónde y cómo va un dato. En el QR y la firma solo cuentan x, y y w.
class CampoDelMolde {
  /// Esquina superior izquierda de la caja, en fracciones de la página.
  final double x;
  final double y;

  /// Ancho de la caja (el texto se alinea dentro de ella; el QR y la firma
  /// miden eso de ancho).
  final double w;

  /// Tamaño de la letra, como fracción del alto de la página.
  final double size;

  /// `left`, `center` o `right`.
  final String align;

  /// `#RRGGBB`.
  final String color;

  /// `sans` (DM Sans) o `display` (Oswald).
  final String font;
  final bool bold;

  const CampoDelMolde({
    required this.x,
    required this.y,
    required this.w,
    this.size = 0.03,
    this.align = 'center',
    this.color = '#1F1F1F',
    this.font = 'sans',
    this.bold = false,
  });

  factory CampoDelMolde.fromJson(Map<String, dynamic> j) => CampoDelMolde(
        x: (j['x'] as num?)?.toDouble() ?? 0,
        y: (j['y'] as num?)?.toDouble() ?? 0,
        w: (j['w'] as num?)?.toDouble() ?? 0.2,
        size: (j['size'] as num?)?.toDouble() ?? 0.03,
        align: (j['align'] as String?) ?? 'center',
        color: (j['color'] as String?) ?? '#1F1F1F',
        font: (j['font'] as String?) ?? 'sans',
        bold: (j['bold'] as bool?) ?? false,
      );

  /// El QR y la firma no llevan letra: el servidor rechaza campos de más.
  Map<String, dynamic> toJson({bool imagen = false}) => imagen
      ? {'x': _r(x), 'y': _r(y), 'w': _r(w)}
      : {
          'x': _r(x),
          'y': _r(y),
          'w': _r(w),
          'size': _r(size),
          'align': align,
          'color': color,
          'font': font,
          'bold': bold,
        };

  /// Cuatro decimales: una diezmilésima de página es menos que un píxel.
  static double _r(double v) => (v * 10000).round() / 10000;

  CampoDelMolde copyWith({
    double? x,
    double? y,
    double? w,
    double? size,
    String? align,
    String? color,
    String? font,
    bool? bold,
  }) =>
      CampoDelMolde(
        x: x ?? this.x,
        y: y ?? this.y,
        w: w ?? this.w,
        size: size ?? this.size,
        align: align ?? this.align,
        color: color ?? this.color,
        font: font ?? this.font,
        bold: bold ?? this.bold,
      );
}

/// Un molde listo para imprimir: con los bytes de su fondo (si era un PDF, ya
/// convertido en imagen) y de su firma.
class MoldeImpreso {
  final MoldeDeCertificado molde;
  final Uint8List fondo;
  final Uint8List? firma;

  const MoldeImpreso({required this.molde, required this.fondo, this.firma});
}
