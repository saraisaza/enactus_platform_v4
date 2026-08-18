import 'dart:convert';

import 'package:flutter/material.dart';

/// Renderiza una imagen sin que el resto de la app sepa si su origen es un
/// blob base64 embebido (hoy, sin backend — ver [DataStore]) o una URL real
/// de S3 (cuando exista el backend, sin tocar ningún sitio que use este
/// widget). [source] puede ser `null`/vacío (sin imagen), una URL http(s)
/// o un string base64 puro.
class AppImage extends StatelessWidget {
  final String? source;
  final BoxFit fit;
  final Widget Function(BuildContext context)? placeholderBuilder;
  final Widget Function(BuildContext context)? errorWidgetBuilder;

  const AppImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.placeholderBuilder,
    this.errorWidgetBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final src = source;
    if (src == null || src.isEmpty) {
      return placeholderBuilder?.call(context) ?? const SizedBox.shrink();
    }
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        fit: fit,
        errorBuilder: (_, _, _) =>
            errorWidgetBuilder?.call(context) ?? const SizedBox.shrink(),
      );
    }
    try {
      return Image.memory(
        base64Decode(src),
        fit: fit,
        errorBuilder: (_, _, _) =>
            errorWidgetBuilder?.call(context) ?? const SizedBox.shrink(),
      );
    } catch (_) {
      return errorWidgetBuilder?.call(context) ?? const SizedBox.shrink();
    }
  }
}

/// Misma detección de origen que [AppImage] (base64 hoy / URL de S3
/// mañana), pero como [ImageProvider] — para APIs que lo piden así en vez
/// de un [Widget] (ej. `CircleAvatar.backgroundImage`). `null` si [source]
/// está vacío o no se pudo decodificar.
ImageProvider? appImageProvider(String? source) {
  if (source == null || source.isEmpty) return null;
  if (source.startsWith('http://') || source.startsWith('https://')) {
    return NetworkImage(source);
  }
  try {
    return MemoryImage(base64Decode(source));
  } catch (_) {
    return null;
  }
}
