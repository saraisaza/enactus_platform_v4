import 'package:flutter/material.dart';

import '../l10n/textos.dart';
import '../utils/app_theme.dart';

enum AvisoDeLecturaTipo { pdf, archivo }

/// La franja de abajo del material de una lección: qué falta para
/// completarla, y que ya se completó. Sin esto, quien lee no sabe que tiene
/// que llegar a la última página.
class AvisoDeLectura extends StatelessWidget {
  final bool leido;
  final AvisoDeLecturaTipo tipo;

  const AvisoDeLectura({super.key, required this.leido, required this.tipo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Row(
          key: ValueKey(leido),
          children: [
            Icon(leido ? Icons.check_circle : Icons.south,
                size: 16,
                color: leido ? AppColors.statusGood : AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                leido
                    ? tr.lecturaCompletada
                    : (tipo == AvisoDeLecturaTipo.pdf
                        ? tr.lecturaLlegueAlFinal
                        : tr.lecturaDescargueParaCompletar),
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: leido ? FontWeight.w700 : FontWeight.w500,
                    color: leido ? AppColors.statusGood : AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
