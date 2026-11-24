import 'package:flutter/material.dart';

/// Logo de Instagram, dibujado.
///
/// Material no trae un ícono de marca para Instagram. Se dibuja en vez de
/// agregar un paquete de iconos de marca por dos usos.
class InstagramIcon extends StatelessWidget {
  final double size;
  final Color color;
  const InstagramIcon({super.key, this.size = 18, required this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _InstagramPainter(color),
      );
}

class _InstagramPainter extends CustomPainter {
  final Color color;
  _InstagramPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round;
    final d = size.width;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(d * 0.09, d * 0.09, d * 0.82, d * 0.82),
        Radius.circular(d * 0.26),
      ),
      trazo,
    );
    canvas.drawCircle(Offset(d / 2, d / 2), d * 0.21, trazo);
    canvas.drawCircle(
      Offset(d * 0.72, d * 0.28),
      d * 0.055,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_InstagramPainter viejo) => viejo.color != color;
}

/// Logo de LinkedIn: el cuadrado redondeado con "in" en minúscula que usa la
/// marca real.
///
/// La primera versión dibujaba la "i" y la "n" a mano con curvas Bézier, y el
/// resultado se veía torpe: una tipografía ya resuelve las proporciones de
/// una letra mejor que una curva ajustada a ojo. Se reemplaza por texto real
/// con una fuente redondeada y peso alto, que es además lo que hace el logo
/// oficial.
class LinkedInIcon extends StatelessWidget {
  final double size;
  final Color color;
  const LinkedInIcon({super.key, this.size = 18, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Text(
          'in',
          style: TextStyle(
            color: color,
            fontSize: size * 0.82,
            fontWeight: FontWeight.w800,
            height: 1.0,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

/// Logo de WhatsApp: el de la marca, no uno inventado.
///
/// La primera versión era un círculo con una cola y un teléfono encima, y se
/// leía como una lupa. Este es el contorno oficial (de Simple Icons, CC0),
/// dibujado desde su trazo SVG en una caja de 24×24.
class WhatsAppIcon extends StatelessWidget {
  final double size;
  final Color color;
  const WhatsAppIcon({super.key, this.size = 18, required this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _WhatsAppPainter(color),
      );
}

class _WhatsAppPainter extends CustomPainter {
  final Color color;
  _WhatsAppPainter(this.color);

  static const _trazo =
      'M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15'
      '-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463'
      '-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606'
      '.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025'
      '-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008'
      '-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0'
      ' 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262'
      '.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413'
      '.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004'
      'a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86'
      ' 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03'
      ' 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884'
      'm8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0'
      ' 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683'
      ' 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z';

  static final Path _camino = trazoSvg(_trazo)..fillType = PathFillType.evenOdd;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(_camino, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WhatsAppPainter viejo) => viejo.color != color;
}

/// Un trazo SVG (`d="..."`) como [Path]: M, L, H, V, C, S, Q, A y Z, en
/// mayúscula (absoluto) o minúscula (relativo). Alcanza para logos de marca;
/// no es un lector de SVG completo.
Path trazoSvg(String d) {
  final path = Path();
  final fichas = RegExp(r'[MmLlHhVvCcSsQqAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  var i = 0;
  var x = 0.0, y = 0.0, inicioX = 0.0, inicioY = 0.0;
  double? ctrlX, ctrlY;
  var comando = 'M';
  bool esComando(String f) => RegExp(r'^[A-Za-z]$').hasMatch(f);
  double num() => double.parse(fichas[i++]);
  // Las banderas de un arco pueden venir pegadas («01»): se leen de a un
  // dígito.
  final banderas = <String>[];
  bool bandera() {
    if (banderas.isNotEmpty) return banderas.removeAt(0) == '1';
    final f = fichas[i++];
    if (f.length > 1 && !f.contains('.')) {
      banderas.addAll(f.substring(1).split(''));
      return f[0] == '1';
    }
    if (f.length > 1 && f.startsWith('0') || f.startsWith('1')) {
      // «01.5» = bandera 0, bandera 1 y el número .5
      if (f.length > 1 && f[1] != '.') {
        banderas.add(f[1]);
        fichas.insert(i, f.substring(2));
        return f[0] == '1';
      }
    }
    return f == '1';
  }

  while (i < fichas.length) {
    if (esComando(fichas[i])) comando = fichas[i++];
    final rel = comando == comando.toLowerCase();
    final dx = rel ? x : 0.0, dy = rel ? y : 0.0;
    switch (comando.toUpperCase()) {
      case 'M':
        x = dx + num();
        y = dy + num();
        path.moveTo(x, y);
        inicioX = x;
        inicioY = y;
        // Pares que siguen a un M son L.
        comando = rel ? 'l' : 'L';
        ctrlX = null;
      case 'L':
        x = dx + num();
        y = dy + num();
        path.lineTo(x, y);
        ctrlX = null;
      case 'H':
        x = (rel ? x : 0) + num();
        path.lineTo(x, y);
        ctrlX = null;
      case 'V':
        y = (rel ? y : 0) + num();
        path.lineTo(x, y);
        ctrlX = null;
      case 'C':
        final x1 = dx + num(), y1 = dy + num();
        final x2 = dx + num(), y2 = dy + num();
        x = dx + num();
        y = dy + num();
        path.cubicTo(x1, y1, x2, y2, x, y);
        ctrlX = x2;
        ctrlY = y2;
      case 'S':
        final x1 = ctrlX == null ? x : 2 * x - ctrlX;
        final y1 = ctrlY == null || ctrlX == null ? y : 2 * y - ctrlY;
        final x2 = dx + num(), y2 = dy + num();
        x = dx + num();
        y = dy + num();
        path.cubicTo(x1, y1, x2, y2, x, y);
        ctrlX = x2;
        ctrlY = y2;
      case 'Q':
        final x1 = dx + num(), y1 = dy + num();
        x = dx + num();
        y = dy + num();
        path.quadraticBezierTo(x1, y1, x, y);
        ctrlX = null;
      case 'A':
        final rx = num(), ry = num(), rotacion = num();
        final grande = bandera(), horario = bandera();
        x = dx + num();
        y = dy + num();
        path.arcToPoint(Offset(x, y),
            radius: Radius.elliptical(rx, ry),
            rotation: rotacion,
            largeArc: grande,
            clockwise: horario);
        ctrlX = null;
      case 'Z':
        path.close();
        x = inicioX;
        y = inicioY;
        ctrlX = null;
    }
  }
  return path;
}
