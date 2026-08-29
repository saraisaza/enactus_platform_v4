import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/data_provider.dart';
import '../services/api_errors.dart';
import '../utils/app_theme.dart';

/// Un archivo ya subido a S3, listo para adjuntarse a lo que corresponda.
///
/// Se guarda la KEY, no el archivo: el binario ya está en S3 y lo que viaja a
/// la API es la referencia. Antes acá había una ruta local del sistema de
/// archivos, que no significaba nada del otro lado.
class UploadedFile {
  final String s3Key;
  final String fileName;
  final String contentType;
  final int sizeBytes;

  const UploadedFile({
    required this.s3Key,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
  });

  Map<String, dynamic> toJson() => {
        's3Key': s3Key,
        'fileName': fileName,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
      };
}

/// Campo de adjuntos con el flujo de subida de tres pasos.
///
/// El archivo va **directo del navegador a S3**, nunca a través de la API: API
/// Gateway corta el payload en 10 MB. La API solo firma el permiso y después
/// recibe la key.
///
/// Muestra el progreso real de la subida —no un giro indefinido— porque un
/// archivo de varios megabytes tarda lo suficiente como para que dé la
/// sensación de que se colgó.
class FileUploadField extends StatefulWidget {
  /// `submission`, `evidence`, `communication_resource` o `avatar`. El
  /// servidor valida que el rol pueda subir para ese propósito.
  final String purpose;

  final int maxFiles;

  /// Lista que este campo va llenando. Quien lo usa la lee al enviar.
  final List<UploadedFile> files;

  final bool enabled;
  final VoidCallback onChanged;

  const FileUploadField({
    super.key,
    required this.purpose,
    required this.files,
    required this.onChanged,
    this.maxFiles = 1,
    this.enabled = true,
  });

  @override
  State<FileUploadField> createState() => _FileUploadFieldState();
}

class _FileUploadFieldState extends State<FileUploadField> {
  bool _uploading = false;
  double _progress = 0;
  ApiException? _error;

  /// Los tipos que acepta el servidor, mapeados desde la extensión. Se manda
  /// el correcto porque la URL firmada se emite PARA un content-type y S3
  /// rechaza la subida si no coincide.
  String _contentTypeOf(String fileName) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    return switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'svg' => 'image/svg+xml',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'zip' => 'application/zip',
      _ => '',
    };
  }

  Future<void> _pick() async {
    final result = await FilePicker.pickFiles(withData: true);
    final file = result?.files.singleOrNull;
    final bytes = file?.bytes;
    if (bytes == null || !mounted) return;

    final contentType = _contentTypeOf(file!.name);
    if (contentType.isEmpty) {
      setState(() => _error = const ValidationError(
          'Tipo de archivo no permitido. Se aceptan PDF, imágenes, '
          'documentos de Word y ZIP.'));
      return;
    }

    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });
    try {
      final uploaded = await context.read<DataProvider>().uploadFile(
            purpose: widget.purpose,
            fileName: file.name,
            contentType: contentType,
            bytes: bytes,
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      if (!mounted) return;
      widget.files.add(UploadedFile(
        s3Key: uploaded['s3Key'] as String,
        fileName: uploaded['fileName'] as String,
        contentType: uploaded['contentType'] as String,
        sizeBytes: uploaded['sizeBytes'] as int,
      ));
      widget.onChanged();
    } on ApiException catch (e) {
      // El motivo real: "el archivo pesa más de 25 MB" y "no hay conexión"
      // piden cosas distintas de quien lo lee.
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.files.length >= widget.maxFiles;
    final busy = _uploading || !widget.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file, size: 16),
              label: const Text('Adjuntar archivo'),
              onPressed: full || busy ? null : _pick,
            ),
            const SizedBox(width: 10),
            Text('${widget.files.length}/${widget.maxFiles}',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
        if (_uploading) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _progress == 0 ? null : _progress,
            backgroundColor: AppColors.surfaceAlt,
            color: AppColors.gold,
          ),
          const SizedBox(height: 4),
          Text(
              _progress == 0
                  ? 'Preparando la subida…'
                  : 'Subiendo… ${(_progress * 100).round()}%',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11.5)),
        ],
        for (final file in widget.files)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined,
                    size: 14, color: AppColors.gold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(file.fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                ),
                Text(_humanSize(file.sizeBytes),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  tooltip: 'Quitar',
                  // Quitarlo de la entrega no borra el objeto de S3: eso lo
                  // limpia el administrador, no una pantalla de estudiante.
                  onPressed: busy
                      ? null
                      : () {
                          widget.files.remove(file);
                          widget.onChanged();
                        },
                ),
              ],
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!.message,
                style: const TextStyle(
                    color: AppColors.statusCritical, fontSize: 12.5)),
          ),
      ],
    );
  }

  String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
