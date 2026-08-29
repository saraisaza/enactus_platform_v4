import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../utils/app_theme.dart';

/// Reproductor de video de una lección.
///
/// El video tiene dos orígenes posibles y **no se tratan igual**:
///
/// - **`external`** — un enlace de YouTube o Vimeo. Se abre en una pestaña
///   nueva. No se embebe en un iframe porque ambos servicios exigen sus
///   propios reproductores y políticas de cookies; abrirlo aparte es lo que
///   funciona hoy en todos los navegadores sin pelearse con el CSP.
///
/// - **`uploaded`** — un archivo propio en S3. **Todavía no se puede
///   reproducir**: servirlo necesita la distribución de CloudFront con URLs
///   firmadas (Fase 6). No se sirve por URL firmada de S3 a propósito — es una
///   decisión de costo, y la API rechaza esas keys en `/files/download-url`.
///   Hasta entonces se dice exactamente eso, en vez de mostrar un reproductor
///   que se queda cargando para siempre.
class VideoPlayerDialog extends StatelessWidget {
  final Lesson lesson;
  const VideoPlayerDialog({super.key, required this.lesson});

  static Future<void> show(BuildContext context, Lesson lesson) {
    return showDialog(
      context: context,
      builder: (_) => VideoPlayerDialog(lesson: lesson),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.play_circle_outline, color: AppColors.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(lesson.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AspectRatio(aspectRatio: 16 / 9, child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (lesson.isExternalVideo && lesson.videoUrl != null) {
      return _Panel(
        icon: Icons.open_in_new,
        title: 'Ver el video',
        message: 'Se abre en una pestaña nueva.',
        action: ('Abrir video', () => _open(context, lesson.videoUrl!)),
      );
    }
    if (lesson.isUploadedVideo) {
      return const _Panel(
        icon: Icons.cloud_off_outlined,
        title: 'Reproducción no disponible todavía',
        message: 'Este video está guardado en la plataforma, pero servirlo '
            'necesita la distribución de CloudFront, que se configura en la '
            'siguiente fase de despliegue.',
      );
    }
    return const _Panel(
      icon: Icons.videocam_off_outlined,
      title: 'Esta lección todavía no tiene video',
      message: 'Quien la creó aún no le cargó ninguno.',
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    final ok = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace del video.')),
      );
    }
  }
}

class _Panel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final (String, VoidCallback)? action;

  const _Panel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(action!.$1),
              onPressed: action!.$2,
            ),
          ],
        ],
      ),
    );
  }
}
