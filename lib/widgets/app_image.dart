import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/data_provider.dart';
import '../services/api_errors.dart';

/// Muestra una imagen guardada en S3 a partir de su key.
///
/// Antes este widget recibía un string que podía ser base64 embebido o una
/// URL, y adivinaba cuál era. Ya no hay nada que adivinar: la imagen vive en
/// S3 y para verla hace falta una URL firmada que **emite el servidor** tras
/// comprobar que esta persona puede leer esa key.
///
/// Eso cambia el widget de forma: pedir la URL es una llamada de red, así que
/// tiene los mismos tres estados que el resto de la app —cargando, error,
/// dato— resueltos con [AsyncValue] igual que en cualquier otra pantalla.
///
/// Con [s3Key] en `null` o vacío no pide nada y dibuja [placeholderBuilder]:
/// "esta persona no tiene foto" no es un error ni una carga.
class AppImage extends StatelessWidget {
  final String? s3Key;
  final BoxFit fit;

  /// Qué dibujar cuando no hay imagen. También se usa mientras carga, salvo
  /// que se dé [loadingBuilder].
  final Widget Function(BuildContext context)? placeholderBuilder;

  final Widget Function(BuildContext context)? loadingBuilder;

  /// Qué dibujar si la imagen no se pudo traer. Recibe el error para poder
  /// distinguir "no tenés permiso" de "no hay conexión".
  final Widget Function(BuildContext context, ApiException error)?
      errorWidgetBuilder;

  const AppImage({
    super.key,
    required this.s3Key,
    this.fit = BoxFit.cover,
    this.placeholderBuilder,
    this.loadingBuilder,
    this.errorWidgetBuilder,
  });

  Widget _empty(BuildContext context) =>
      placeholderBuilder?.call(context) ?? const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    final key = s3Key;
    if (key == null || key.isEmpty) return _empty(context);

    return context.watch<DataProvider>().fileUrl(key).when(
          loading: () => loadingBuilder?.call(context) ?? _empty(context),
          error: (error) =>
              errorWidgetBuilder?.call(context, error) ?? _empty(context),
          data: (url) => Image.network(
            url,
            fit: fit,
            // La URL puede vencer con la pestaña abierta. Se muestra el
            // marcador de posición en vez de el ícono de imagen rota del
            // navegador; el siguiente rebuild pide una URL nueva.
            errorBuilder: (_, _, _) => _empty(context),
          ),
        );
  }
}

/// Igual que [AppImage] pero como [ImageProvider], para las APIs que lo piden
/// así (`CircleAvatar.backgroundImage`, `DecorationImage`).
///
/// Devuelve `null` mientras la URL no esté resuelta — quien lo use tiene que
/// tener un `child` de reserva, que es justo lo que `CircleAvatar` espera.
ImageProvider? appImageProvider(BuildContext context, String? s3Key) {
  if (s3Key == null || s3Key.isEmpty) return null;
  final url = context.watch<DataProvider>().fileUrl(s3Key).valueOrNull;
  return url == null ? null : NetworkImage(url);
}
