import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../l10n/textos.dart';
import 'formatos.dart';
import 'marca.dart';

/// Lo que se sabe de un logo apenas se elige, antes de subirlo.
///
/// El servidor vuelve a revisar el archivo al guardar —es la regla que cuenta—
/// pero esperar a la subida para decir «no es un PNG» o «pesa demasiado» es
/// hacer esperar a quien administra para nada. Las reglas son las mismas:
/// `backend/src/routes/clients.ts`.
class AnalisisDeLogo {
  /// El motivo por el que no sirve, ya en el idioma de la interfaz, o `null`.
  final String? error;
  final int ancho;
  final int alto;

  /// Algún píxel es transparente: el logo se apoya sobre el encabezado.
  final bool tieneTransparencia;

  /// Sobre el gris del encabezado se vería poco: conviene la placa clara.
  final bool necesitaPlaca;

  const AnalisisDeLogo._({
    this.error,
    this.ancho = 0,
    this.alto = 0,
    this.tieneTransparencia = false,
    this.necesitaPlaca = false,
  });

  bool get sirve => error == null;
}

/// Las mismas cotas que el servidor.
const maxBytesLogo = 1024 * 1024;
const minLadoMayorLogo = 200;
const maxLadoLogo = 4000;

/// El gris del encabezado, sobre el que va el logo.
const _fondoEncabezado = PaletaMarca.fondoOscuroMasClaro;

/// Ancho y alto de un PNG leídos de su encabezado, o `null` si no es PNG.
///
/// Igual que el servidor: la firma de 8 bytes y el bloque `IHDR`. No alcanza
/// con la extensión del archivo: un JPG renombrado a `.png` se elige igual.
({int ancho, int alto})? medidasDePng(Uint8List bytes) {
  const firma = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length < 24) return null;
  for (var i = 0; i < firma.length; i++) {
    if (bytes[i] != firma[i]) return null;
  }
  if (String.fromCharCodes(bytes.sublist(12, 16)) != 'IHDR') return null;
  final datos = ByteData.sublistView(bytes);
  final ancho = datos.getUint32(16);
  final alto = datos.getUint32(20);
  if (ancho == 0 || alto == 0) return null;
  return (ancho: ancho, alto: alto);
}

/// Revisa [bytes] y, si sirve, mira cómo se verá sobre el encabezado.
Future<AnalisisDeLogo> analizarLogo(Uint8List bytes) async {
  if (bytes.length > maxBytesLogo) {
    return AnalisisDeLogo._(
        error: tr.clientesLogoPesado(decimal(bytes.length / 1024 / 1024)));
  }
  final medidas = medidasDePng(bytes);
  if (medidas == null) return AnalisisDeLogo._(error: tr.clientesLogoNoPng);
  final (:ancho, :alto) = medidas;
  if ((ancho > alto ? ancho : alto) < minLadoMayorLogo) {
    return AnalisisDeLogo._(
        error: tr.clientesLogoChico(ancho, alto, minLadoMayorLogo));
  }
  if (ancho > maxLadoLogo || alto > maxLadoLogo) {
    return AnalisisDeLogo._(
        error: tr.clientesLogoGrande(ancho, alto, maxLadoLogo));
  }

  // Para decidir la placa basta una versión chica: el promedio de color no
  // cambia, y decodificar un logo de 4000 px en un teléfono es lento.
  final codec = await ui.instantiateImageCodec(bytes,
      targetWidth: ancho > 160 ? 160 : null);
  final imagen = (await codec.getNextFrame()).image;
  final datos = await imagen.toByteData(format: ui.ImageByteFormat.rawRgba);
  imagen.dispose();
  codec.dispose();
  if (datos == null) {
    return AnalisisDeLogo._(ancho: ancho, alto: alto);
  }

  var transparentes = 0;
  var pesoTotal = 0.0;
  var luzPonderada = 0.0;
  for (var i = 0; i < datos.lengthInBytes; i += 4) {
    final alfa = datos.getUint8(i + 3);
    if (alfa < 250) transparentes++;
    if (alfa < 32) continue;
    final peso = alfa / 255;
    final pixel = Color.fromARGB(
        255, datos.getUint8(i), datos.getUint8(i + 1), datos.getUint8(i + 2));
    luzPonderada += pixel.computeLuminance() * peso;
    pesoTotal += peso;
  }
  final tieneTransparencia = transparentes > 0;
  // Un logo sin transparencia trae su propio fondo: la placa no aporta nada.
  // Con transparencia, se mira cuánto se separa del gris del encabezado. El
  // umbral es 3:1, el de WCAG para elementos gráficos.
  var necesitaPlaca = false;
  if (tieneTransparencia && pesoTotal > 0) {
    final luz = luzPonderada / pesoTotal;
    final fondo = _fondoEncabezado.computeLuminance();
    final claro = luz > fondo ? luz : fondo;
    final oscuro = luz > fondo ? fondo : luz;
    necesitaPlaca = (claro + 0.05) / (oscuro + 0.05) < 3;
  }
  return AnalisisDeLogo._(
    ancho: ancho,
    alto: alto,
    tieneTransparencia: tieneTransparencia,
    necesitaPlaca: necesitaPlaca,
  );
}
