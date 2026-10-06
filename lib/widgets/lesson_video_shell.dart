import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../l10n/textos.dart';
import '../utils/app_theme.dart';
import 'common.dart';

/// Lo que comparten los dos reproductores de lección —YouTube y el video
/// subido— para que quien mira no note de dónde viene el video: la caja
/// 16:9, la carátula con la portada y el botón de reproducir, y el panel de
/// «no se pudo» con su salida.

/// 16:9 que responde sus medidas intrínsecas con la proporción, sin
/// preguntarle a lo que tiene adentro.
///
/// Hace falta porque adentro hay `LayoutBuilder` —en la carátula, y en el
/// reproductor del paquete en Android/iOS— y un `LayoutBuilder` no sabe
/// responder medidas intrínsecas: lanza. Un `AlertDialog` las pide siempre
/// (envuelve su contenido en un `IntrinsicWidth`), y la vista previa del
/// editor de lecciones vive en uno. Sin esto, pegar un enlace en el editor
/// rompía el diálogo entero.
///
/// La usan los dos reproductores de lección: YouTube y el video subido.
class VideoBox16x9 extends AspectRatio {
  const VideoBox16x9({super.key, super.child}) : super(aspectRatio: 16 / 9);

  @override
  RenderAspectRatio createRenderObject(BuildContext context) =>
      _RenderVideoBox16x9(aspectRatio: aspectRatio);
}

class _RenderVideoBox16x9 extends RenderAspectRatio {
  _RenderVideoBox16x9({required super.aspectRatio});

  @override
  double computeMinIntrinsicWidth(double height) =>
      height.isFinite ? height * aspectRatio : 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      height.isFinite ? height * aspectRatio : 0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      width.isFinite ? width / aspectRatio : 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      width.isFinite ? width / aspectRatio : 0;
}

/// La carátula: la portada con el botón de reproducir.
///
/// La misma para YouTube y para el video subido: quien mira no tendría por
/// qué notar de dónde viene el video. Cambian solo [image] y la etiqueta
/// ([sourceLabel] / [sourceIcon]).
class LessonVideoCover extends StatelessWidget {
  /// La portada ya armada (`Image.network`, `Image.memory`). `null` muestra
  /// el fondo genérico.
  final Widget? image;
  final String sourceLabel;
  final IconData sourceIcon;
  final String title;
  final Duration? resumeAt;
  final double? watchedRatio;
  final VoidCallback? onPlay;
  final bool loading;

  const LessonVideoCover({
    super.key,
    required this.title,
    required this.sourceLabel,
    required this.sourceIcon,
    this.image,
    this.resumeAt,
    this.watchedRatio,
    this.onPlay,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // En un teléfono el reproductor mide ~360 px de ancho: el botón y las
      // etiquetas se achican para no tapar la miniatura entera.
      final chico = constraints.maxWidth < 480;
      final resume = resumeAt;

      return KeyboardHoverBuilder(
        onTap: loading ? null : onPlay,
        builder: (context, activo) => Semantics(
          label: loading
              ? tr.videoCargandoTitulo(title)
              : resume == null
                  ? tr.videoReproducirTitulo(title)
                  : tr.videoSeguirViendo(title, formatVideoTime(resume)),
          excludeSemantics: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image ?? const VideoCoverFallback(),
              // Degradé para que las etiquetas se lean sobre cualquier imagen.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33000000),
                      Color(0x00000000),
                      Color(0xB3000000),
                    ],
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),
              Center(
                child: loading
                    ? SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(AppColors.gold),
                        ),
                      )
                    : AnimatedScale(
                        scale: activo ? 1.08 : 1,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          width: chico ? 56 : 72,
                          height: chico ? 56 : 72,
                          decoration: BoxDecoration(
                            color: activo
                                ? AppColors.goldBright
                                : AppColors.gold,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x80000000),
                                  blurRadius: 18,
                                  offset: Offset(0, 6)),
                            ],
                          ),
                          // Tinta oscura sobre el ámbar: blanco ahí da 1.6:1.
                          child: Icon(Icons.play_arrow_rounded,
                              color: AppColors.ink, size: chico ? 34 : 44),
                        ),
                      ),
              ),
              Positioned(
                left: chico ? 10 : 14,
                right: chico ? 10 : 14,
                bottom: chico ? 10 : 14,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Etiqueta(icon: sourceIcon, text: sourceLabel),
                    if (loading)
                      _Etiqueta(
                          icon: Icons.hourglass_empty,
                          text: tr.videoCargando)
                    else if (resume != null)
                      _Etiqueta(
                          icon: Icons.history,
                          text: tr.videoSeguirDesde(formatVideoTime(resume))),
                  ],
                ),
              ),
              if ((watchedRatio ?? 0) > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: watchedRatio,
                    minHeight: 4,
                    backgroundColor: const Color(0x55FFFFFF),
                    valueColor: AlwaysStoppedAnimation(AppColors.gold),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

/// Fondo de la carátula cuando no hay portada, o mientras carga.
class VideoCoverFallback extends StatelessWidget {
  const VideoCoverFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.slate, AppColors.slateDark],
        ),
      ),
      child: Center(
        child: Icon(Icons.smart_display_outlined,
            color: AppColors.textMuted, size: 48),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Etiqueta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// No cargó, o no se puede ver acá. Siempre con una salida.
///
/// [onRetry] en `null` esconde «Reintentar» (un video borrado no vuelve por
/// reintentar); [secondary] es la otra salida, si la hay («Ver en YouTube»).
class LessonVideoFailure extends StatelessWidget {
  final String title;
  final String detail;
  final VoidCallback? onRetry;
  final (String label, IconData icon, VoidCallback onPressed)? secondary;

  const LessonVideoFailure({
    super.key,
    required this.title,
    required this.detail,
    this.onRetry,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final otra = secondary;
    return Container(
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined,
                  size: 40, color: AppColors.textMuted),
              const SizedBox(height: 10),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12.5)),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onRetry != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(tr.comunReintentar),
                      onPressed: onRetry,
                    ),
                  if (otra != null)
                    ElevatedButton.icon(
                      icon: Icon(otra.$2, size: 18),
                      label: Text(otra.$1),
                      onPressed: otra.$3,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `m:ss`, o `h:mm:ss` en videos de una hora o más.
String formatVideoTime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}
