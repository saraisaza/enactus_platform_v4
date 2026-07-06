import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/video_source_io.dart'
    if (dart.library.js_interop) '../services/video_source_web.dart';
import '../utils/app_theme.dart';

/// Reproductor de video para lecciones locales (carpeta `course_resources/`).
///
/// En escritorio lee el archivo directamente; en web lo pide al servidor de
/// desarrollo (que sirve `web/course_resources/`). Si el recurso no existe o
/// es un dummy del seed, muestra un placeholder elegante en lugar de fallar.
/// Al migrar a AWS S3 este widget pasará a recibir URLs firmadas.
class VideoPlayerDialog extends StatefulWidget {
  final String title;
  final String resourcePath; // relativo a course_resources/
  const VideoPlayerDialog(
      {super.key, required this.title, required this.resourcePath});

  static Future<void> show(
      BuildContext context, String title, String resourcePath) {
    return showDialog(
      context: context,
      builder: (_) =>
          VideoPlayerDialog(title: title, resourcePath: resourcePath),
    );
  }

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = await createCourseVideoController(widget.resourcePath);
      if (c == null) {
        if (mounted) setState(() => _failed = true);
        return;
      }
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
      await c.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
                  const Icon(Icons.play_circle_outline,
                      color: AppColors.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.title,
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
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _failed
                    ? _placeholder()
                    : _controller == null
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.gold))
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: VideoPlayer(_controller!),
                          ),
              ),
              if (_controller != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(_controller!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow),
                      color: AppColors.gold,
                      onPressed: () => setState(() {
                        _controller!.value.isPlaying
                            ? _controller!.pause()
                            : _controller!.play();
                      }),
                    ),
                    Expanded(
                      child: VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: AppColors.gold,
                          bufferedColor: AppColors.slateLight,
                          backgroundColor: AppColors.surfaceAlt,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off_outlined,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text('Video de demostración',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'El archivo course_resources/${widget.resourcePath} es un '
              'recurso de ejemplo. Reemplázalo por un .mp4 real para verlo aquí.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
