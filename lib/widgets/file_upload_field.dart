import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/textos.dart';
import '../providers/data_provider.dart';
import '../services/api_errors.dart';
import '../utils/app_theme.dart';
import '../utils/formatos.dart';

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

  /// Lo que acepta el servidor (`ALLOWED_DOCUMENT_TYPES`). Se filtra en el
  /// selector: antes se podía elegir cualquier cosa y recién después llegaba
  /// el "no permitido".
  static const _extensiones = [
    'pdf', 'png', 'jpg', 'jpeg', 'svg', 'doc', 'docx', 'zip', //
  ];

  /// El máximo del servidor (`MAX_DOCUMENT_BYTES`).
  static const _maxBytes = 25 * 1024 * 1024;

  /// [foto]: el selector de fotos del teléfono en vez del de archivos. En
  /// iPhone, "Archivo" abre la app Archivos, donde no están las fotos.
  Future<void> _pick({bool foto = false}) async {
    final result = await FilePicker.pickFiles(
      type: foto ? FileType.image : FileType.custom,
      allowedExtensions: foto ? null : _extensiones,
      // En iOS, cualquier valor mayor que 0 hace que el selector de fotos
      // entregue JPEG ("compatible") en vez del HEIC original del iPhone, que
      // el servidor rechaza.
      compressionQuality: foto ? 80 : 0,
      // En la web no hay ruta de archivo: los bytes llegan con la selección.
      // En el teléfono se leen DESPUÉS de comprobar el tamaño: antes se
      // cargaba el archivo entero en memoria para recién ahí rechazarlo, y un
      // video de 1 GB elegido por error podía cerrar la app.
      withData: kIsWeb,
    );
    final file = result?.files.singleOrNull;
    if (file == null || !mounted) return;

    final contentType = _contentTypeOf(file.name);
    if (contentType.isEmpty) {
      setState(() => _error = ValidationError(
          tr.archivoTipoNoPermitido));
      return;
    }
    if (file.size > _maxBytes) {
      setState(() => _error = ValidationError(
          tr.archivoPesado(decimal(file.size / 1024 / 1024))));
      return;
    }
    final bytes = file.bytes ?? await file.xFile.readAsBytes();
    if (!mounted) return;

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
        // `Wrap` y no `Row`: a 360 dp, con el texto del contador, la fila
        // desbordaba.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!kIsWeb)
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: Text(tr.evidenciaFoto),
                onPressed: full || busy ? null : () => _pick(foto: true),
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file, size: 16),
              label: Text(kIsWeb ? tr.archivoAdjuntar : tr.archivoArchivo),
              onPressed: full || busy ? null : _pick,
            ),
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
                  ? tr.archivoPreparando
                  : tr.archivoSubiendo((_progress * 100).round()),
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11.5)),
        ],
        for (final file in widget.files)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.insert_drive_file_outlined,
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
                  tooltip: tr.comunQuitar,
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
    return '${decimal(bytes / 1024 / 1024)} MB';
  }
}
