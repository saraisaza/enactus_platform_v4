import 'package:flutter/painting.dart';

import '../utils/marca.dart';

/// Un cliente de la plataforma —una empresa, o Enactus— con su marca.
///
/// Sin colores, el cliente se ve con la marca de eduXaction; sin logo, solo
/// con el de eduXaction. Ver `docs/clientes/README.md`.
class Client {
  final String id;
  final String name;

  /// La key en S3 del logo (PNG), o `null` si no tiene.
  final String? logoS3Key;

  /// La URL del logo ya firmada por el servidor. Vence en minutos: se usa al
  /// dibujar, no se guarda.
  final String? logoUrl;
  final int? logoWidth;
  final int? logoHeight;

  /// Placa clara detrás del logo, para uno oscuro sobre el encabezado gris.
  final bool logoLightPlate;

  /// `#RRGGBB`, o `null` para usar los de eduXaction.
  final String? primaryColor;
  final String? secondaryColor;

  /// Laboratorios y Ruta de Impacto: solo Enactus.
  final bool hasLaboratories;

  /// `false` = desactivado: sus cuentas no pueden iniciar sesión.
  final bool active;

  const Client({
    required this.id,
    required this.name,
    this.logoS3Key,
    this.logoUrl,
    this.logoWidth,
    this.logoHeight,
    this.logoLightPlate = false,
    this.primaryColor,
    this.secondaryColor,
    this.hasLaboratories = false,
    this.active = true,
  });

  factory Client.fromJson(Map<String, dynamic> j) => Client(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        logoS3Key: j['logoS3Key'] as String?,
        logoUrl: j['logoUrl'] as String?,
        logoWidth: (j['logoWidth'] as num?)?.toInt(),
        logoHeight: (j['logoHeight'] as num?)?.toInt(),
        logoLightPlate: (j['logoLightPlate'] as bool?) ?? false,
        primaryColor: j['primaryColor'] as String?,
        secondaryColor: j['secondaryColor'] as String?,
        hasLaboratories: (j['hasLaboratories'] as bool?) ?? false,
        active: (j['active'] as bool?) ?? true,
      );

  /// La paleta con la que se ve este cliente.
  PaletaMarca get paleta => paletaDeColores(primaryColor, secondaryColor);
}

/// La paleta de dos colores guardados como texto.
///
/// Sin primario es la de eduXaction entera, aunque haya secundario: el
/// secundario solo acompaña a un primario propio.
PaletaMarca paletaDeColores(String? primario, String? secundario) {
  final p = colorDesdeHex(primario);
  if (p == null) return PaletaMarca.eduXaction;
  return PaletaMarca.desde(primario: p, secundario: colorDesdeHex(secundario));
}

/// `#1A73E8`, `1a73e8` → el color; cualquier otra cosa → `null`.
Color? colorDesdeHex(String? texto) {
  if (texto == null) return null;
  final limpio = texto.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(limpio)) return null;
  return Color(0xFF000000 | int.parse(limpio, radix: 16));
}

/// El color como lo guarda el servidor: `#RRGGBB` en mayúsculas.
String hexDe(Color c) {
  String canal(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${canal(c.r)}${canal(c.g)}${canal(c.b)}'.toUpperCase();
}
