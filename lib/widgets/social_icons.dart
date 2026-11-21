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

/// Logo de WhatsApp: el globo de conversación redondo, con la cola abajo a
/// la izquierda, y el auricular adentro. Dibujado, como [InstagramIcon]:
/// Material no trae el ícono de la marca.
class WhatsAppIcon extends StatelessWidget {
  final double size;
  final Color color;
  const WhatsAppIcon({super.key, this.size = 18, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
                size: Size.square(size), painter: _WhatsAppPainter(color)),
            Icon(Icons.phone, size: size * 0.46, color: color),
          ],
        ),
      );
}

class _WhatsAppPainter extends CustomPainter {
  final Color color;
  _WhatsAppPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final d = size.width;
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = d * 0.09
      ..strokeJoin = StrokeJoin.round;
    final centro = Offset(d * 0.53, d * 0.47);
    final radio = d * 0.38;
    // El círculo abierto donde nace la cola.
    final circulo = Rect.fromCircle(center: centro, radius: radio);
    const inicio = 2.35; // ~135°, abajo a la izquierda
    const barrido = 5.9;
    final globo = Path()..addArc(circulo, inicio + 0.38, barrido);
    // La cola, hacia la esquina de abajo a la izquierda.
    globo
      ..lineTo(d * 0.1, d * 0.92)
      ..lineTo(centro.dx + radio * 0.73 * -1, centro.dy + radio * 0.69);
    canvas.drawPath(globo, trazo);
  }

  @override
  bool shouldRepaint(_WhatsAppPainter viejo) => viejo.color != color;
}
