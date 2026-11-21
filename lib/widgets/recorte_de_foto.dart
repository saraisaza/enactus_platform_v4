import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n/textos.dart';
import '../utils/app_theme.dart';

/// La foto de perfil recortada al cuadrado del centro y reducida a [lado]
/// píxeles, en PNG.
///
/// El círculo del avatar es un cuadrado con las esquinas redondeadas: una
/// foto vertical u horizontal subida tal cual se veía deformada o cortada
/// donde no era. Recortada acá, entra justa en el círculo, y de paso pesa
/// mucho menos que la foto de la cámara.
Future<Uint8List> recortarAlCuadrado(Uint8List original, {int lado = 512}) async {
  final codec = await ui.instantiateImageCodec(original);
  final imagen = (await codec.getNextFrame()).image;
  final menor = math.min(imagen.width, imagen.height).toDouble();
  final origen = Rect.fromLTWH(
    (imagen.width - menor) / 2,
    (imagen.height - menor) / 2,
    menor,
    menor,
  );
  final destino = math.min(lado.toDouble(), menor);
  final grabadora = ui.PictureRecorder();
  Canvas(grabadora).drawImageRect(
    imagen,
    origen,
    Rect.fromLTWH(0, 0, destino, destino),
    Paint()..filterQuality = FilterQuality.high,
  );
  final recortada = await grabadora
      .endRecording()
      .toImage(destino.round(), destino.round());
  final datos = await recortada.toByteData(format: ui.ImageByteFormat.png);
  imagen.dispose();
  recortada.dispose();
  return datos!.buffer.asUint8List();
}

/// Muestra la foto ya recortada dentro del círculo, como se va a ver, y
/// pregunta si se usa. Devuelve `true` para subirla.
Future<bool> confirmarFotoDePerfil(BuildContext context, Uint8List recortada) async {
  final usar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr.perfilFotoVistaPrevia),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const ValueKey('vista-previa-foto'),
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 3),
              image: DecorationImage(
                image: MemoryImage(recortada),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(tr.perfilFotoVistaPreviaTexto,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(tr.perfilFotoOtra),
        ),
        ElevatedButton.icon(
          key: const ValueKey('usar-foto'),
          icon: const Icon(Icons.check, size: 18),
          label: Text(tr.perfilFotoUsar),
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  return usar ?? false;
}
