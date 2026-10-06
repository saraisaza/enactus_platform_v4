import 'package:flutter/material.dart';

import '../l10n/textos.dart';
import '../models/models.dart';
import '../services/api_errors.dart';
import '../services/video_upload/mp4_inspector.dart';
import '../services/video_upload/upload_types.dart';
import '../services/video_upload/video_platform.dart' as platform;
import '../services/video_upload/video_upload_controller.dart';
import '../utils/app_theme.dart';
import '../utils/formatos.dart';
import 'common.dart';
import 'lesson_video_shell.dart';
import 'uploaded_lesson_player.dart';

/// «Subir video» en el editor de lección: elegir o soltar el archivo, ver si
/// sirve, mirarlo antes de guardar, elegir la portada y seguir la subida.
///
/// La subida en sí la dispara el editor al guardar (necesita el id de la
/// lección); este panel muestra el estado de [controller].
class VideoUploadPanel extends StatefulWidget {
  const VideoUploadPanel({
    super.key,
    required this.controller,
    required this.title,
    this.original,
    this.enabled = true,
  });

  final VideoUploadController controller;
  final String title;

  /// La lección como está guardada, para mostrar su video actual.
  final Lesson? original;
  final bool enabled;

  @override
  State<VideoUploadPanel> createState() => _VideoUploadPanelState();
}

class _VideoUploadPanelState extends State<VideoUploadPanel> {
  VideoDropListener? _drops;
  bool _arrastrando = false;

  VideoUploadController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _drops = platform.listenForVideoDrops(
      onDragging: (si) {
        if (mounted && si != _arrastrando) setState(() => _arrastrando = si);
      },
      onDrop: (video) {
        if (mounted && widget.enabled && !_c.uploading) _c.accept(video);
      },
    );
  }

  @override
  void dispose() {
    _drops?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final file = _c.file;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (file == null) ...[
              if (_c.pending != null) ...[
                _Aviso(
                  icon: Icons.restore,
                  text: tr.subidaSinTerminar(_c.pending!.fileName, formatMegabytes(_c.pending!.sizeBytes)),
                ),
                const SizedBox(height: 10),
              ],
              if (widget.original?.isUploadedVideo == true) ...[
                _VideoActual(lesson: widget.original!, controller: _c),
                const SizedBox(height: 12),
              ],
              _ZonaDeSoltar(
                arrastrando: _arrastrando,
                enabled: widget.enabled,
                reemplaza: widget.original?.isUploadedVideo == true,
                onPick: _c.pick,
              ),
            ] else if (_c.checking)
              const _Revisando()
            else if (_c.problem != null)
              _Problema(
                message: _c.problem!,
                onPickOther: widget.enabled ? _c.pick : null,
              )
            else
              _Elegido(
                controller: _c,
                title: widget.title,
                enabled: widget.enabled,
              ),
            if (_c.uploading || _c.uploadError != null) ...[
              const SizedBox(height: 12),
              _Subida(controller: _c),
            ],
          ],
        );
      },
    );
  }
}

class _ZonaDeSoltar extends StatelessWidget {
  final bool arrastrando;
  final bool enabled;
  final bool reemplaza;
  final VoidCallback onPick;

  const _ZonaDeSoltar({
    required this.arrastrando,
    required this.enabled,
    required this.reemplaza,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final color = arrastrando ? AppColors.gold : AppColors.border;
    return Semantics(
      container: true,
      label: tr.subidaZonaSoltar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: arrastrando
              ? AppColors.gold.withValues(alpha: 0.08)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: DashedRRectBorder(
          color: color,
          radius: 12,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            child: Column(
              children: [
                Icon(Icons.cloud_upload_outlined,
                    size: 38,
                    color: arrastrando ? AppColors.gold : AppColors.textMuted),
                const SizedBox(height: 8),
                Text(
                  arrastrando
                      ? tr.subidaSuelte
                      : reemplaza
                          ? tr.subidaReemplazar
                          : tr.subidaArrastre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: Text(tr.subidaElegirVideo),
                  onPressed: enabled ? onPick : null,
                ),
                const SizedBox(height: 10),
                Text(
                  tr.subidaFormato,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Revisando extends StatelessWidget {
  const _Revisando();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(tr.subidaRevisando,
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _Problema extends StatelessWidget {
  final String message;
  final VoidCallback? onPickOther;
  const _Problema({required this.message, required this.onPickOther});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusCritical.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.statusCritical.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: AppColors.statusCritical),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message,
                    style: const TextStyle(
                        color: AppColors.textPrimary, height: 1.4)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.folder_open, size: 18),
              label: Text(tr.subidaElegirOtro),
              onPressed: onPickOther,
            ),
          ),
        ],
      ),
    );
  }
}

/// El archivo elegido y aceptado: vista previa, datos y portada.
class _Elegido extends StatelessWidget {
  final VideoUploadController controller;
  final String title;
  final bool enabled;

  const _Elegido({
    required this.controller,
    required this.title,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final file = c.file!;
    final probe = c.probe;
    final datos = [
      formatMegabytes(file.sizeBytes),
      if (probe != null && probe.duration > Duration.zero)
        formatVideoTime(probe.duration),
      if (probe != null) '${probe.width}×${probe.height}',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr.subidaVistaPreviaAsi,
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
        const SizedBox(height: 6),
        if (file.previewUrl != null)
          UploadedLessonPlayer(
            key: ValueKey('vista-previa-${file.fingerprint}'),
            localUrl: file.previewUrl,
            localThumbnail: c.cover,
            durationHint: probe?.duration,
            title: title.isEmpty ? tr.subidaVistaPrevia : title,
          )
        else
          VideoBox16x9(
            child: LessonVideoFailure(
              title: tr.subidaVistaPreviaNavegador,
              detail: tr.subidaVistaPreviaDetalle,
            ),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.movie_outlined, size: 18, color: AppColors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: file.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(
                      text: '  $datos',
                      style: const TextStyle(color: AppColors.textMuted)),
                ]),
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            TextButton(
              onPressed: enabled && !c.uploading ? c.clearFile : null,
              child: Text(tr.comunQuitar),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _Portada(controller: c, enabled: enabled && !c.uploading),
      ],
    );
  }
}

class _Portada extends StatelessWidget {
  final VideoUploadController controller;
  final bool enabled;
  const _Portada({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final cover = c.cover;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 96,
                height: 54,
                child: cover == null
                    ? const VideoCoverFallback()
                    : Image.memory(cover, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                c.customCover != null
                    ? tr.subidaPortadaPropia
                    : cover != null
                        ? tr.subidaPortadaDelVideo
                        : tr.subidaSinPortada,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(tr.subidaUsarOtraImagen),
              onPressed: enabled ? c.pickCover : null,
            ),
            if (c.customCover != null)
              TextButton(
                onPressed: enabled ? c.removeCustomCover : null,
                child: Text(c.probe?.frameJpeg != null
                    ? tr.subidaVolverPortadaVideo
                    : tr.subidaQuitarPortada),
              ),
          ],
        ),
        if (c.coverProblem != null)
          Text(c.coverProblem!,
              style: const TextStyle(color: AppColors.statusCritical, fontSize: 12)),
      ],
    );
  }
}

/// El video que ya tiene la lección, con la opción de cambiarle la portada.
class _VideoActual extends StatelessWidget {
  final Lesson lesson;
  final VideoUploadController controller;
  const _VideoActual({required this.lesson, required this.controller});

  @override
  Widget build(BuildContext context) {
    final fecha = lesson.videoUploadedAt;
    final segundos = lesson.videoDurationSec;
    final datos = [
      if (lesson.videoSizeBytes != null) formatMegabytes(lesson.videoSizeBytes!),
      if (segundos != null && segundos > 0)
        formatVideoTime(Duration(seconds: segundos)),
      if (fecha != null)
        tr.subidaSubidoEl(fechaCorta(fecha.toLocal())),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr.subidaVideoActual(
                  lesson.videoOriginalName ?? tr.subidaArchivoSubido) +
              (datos.isEmpty ? '' : ' · $datos'),
          style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 6),
        UploadedLessonPlayer(
          key: ValueKey('actual-${lesson.id}'),
          lessonId: lesson.id,
          title: lesson.title,
          durationHint: segundos == null ? null : Duration(seconds: segundos),
        ),
        const SizedBox(height: 6),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(lesson.hasVideoThumbnail
                    ? tr.subidaCambiarPortada
                    : tr.subidaPonerPortada),
                onPressed: controller.uploading ? null : controller.pickCover,
              ),
              if (controller.customCover != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.memory(controller.customCover!,
                          width: 64, height: 36, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 6),
                    Text(tr.subidaNuevaPortada,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              if (controller.coverProblem != null)
                Text(controller.coverProblem!,
                    style: const TextStyle(
                        color: AppColors.statusCritical, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

/// La barra de la subida, con porcentaje, cuánto falta y cancelar.
class _Subida extends StatelessWidget {
  final VideoUploadController controller;
  const _Subida({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.progress;
    if (!c.uploading) {
      final e = c.uploadError;
      if (e == null || e is UploadCancelled) return const SizedBox.shrink();
      final mensaje = e is ApiException ? e.message : '$e';
      return _Aviso(
        icon: Icons.wifi_off_outlined,
        color: AppColors.statusCritical,
        text: tr.subidaNoTermino(mensaje),
      );
    }
    final pct = ((p?.ratio ?? 0) * 100).floor();
    final falta = p?.remaining;
    final detalle = [
      if (p != null)
        tr.subidaDe(formatMegabytes(p.sentBytes), formatMegabytes(p.totalBytes)),
      if (falta != null) tr.subidaQuedan(_restante(falta)),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p?.resumed == true
                      ? tr.subidaSiguiendo(pct)
                      : tr.subidaSubiendo(pct),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.close, size: 18),
                label: Text(tr.subidaCancelar),
                onPressed: c.cancelUpload,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: tr.subidaAvance,
            value: '$pct %',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p?.ratio,
                minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.gold),
              ),
            ),
          ),
          if (detalle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(detalle,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
          const SizedBox(height: 4),
          Text(
            tr.subidaNoCierre,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  static String _restante(Duration d) {
    if (d.inMinutes >= 1) return '~${d.inMinutes + (d.inSeconds % 60 >= 30 ? 1 : 0)} min';
    return '~${d.inSeconds.clamp(1, 59)} s';
  }
}

class _Aviso extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Aviso({required this.icon, required this.text, this.color = AppColors.gold});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textPrimary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
