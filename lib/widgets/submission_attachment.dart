import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/data_provider.dart';
import '../services/api_errors.dart';
import '../utils/app_theme.dart';
import 'common.dart';
import 'file_viewer.dart';

/// Un adjunto de una entrega, que se abre pidiendo su URL firmada al servidor.
///
/// Lo usan la tarjeta del estudiante y las de quien revisa (LXD y Mentor):
/// calificar sin poder abrir el archivo entregado era calificar a ciegas.
class SubmissionAttachmentRow extends StatelessWidget {
  final SubmissionFile file;
  const SubmissionAttachmentRow({super.key, required this.file});

  Future<void> _open(BuildContext context) async {
    final data = context.read<DataProvider>();
    try {
      final url = await data.resolveFileUrl(file.s3Key);
      if (!context.mounted) return;
      await FileViewer.show(context,
          url: url, fileName: file.fileName, s3Key: file.s3Key);
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: () => _open(context),
        // 48 dp de alto tocable: el texto de 12 px solo medía ~18 dp y había
        // que acertarle al subrayado.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file_outlined,
                  size: 14, color: AppColors.gold),
              const SizedBox(width: 6),
              Flexible(
                child: Text(file.fileName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
