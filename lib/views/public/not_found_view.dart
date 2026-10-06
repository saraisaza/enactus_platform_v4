import 'package:flutter/material.dart';

import '../../l10n/textos.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/animated_logo.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/common.dart';
import '../../widgets/selector_idioma.dart';

/// Página 404: se muestra cuando la ruta no existe.
class NotFoundView extends StatelessWidget {
  const NotFoundView({super.key});

  @override
  Widget build(BuildContext context) {
    // Footer dentro del scroll: solo aparece al llegar al final.
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              children: [
                const SafeArea(bottom: false, child: BarraIdioma()),
                Expanded(
                  child: Center(
              child: Entrance(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AnimatedLogo(height: 130),
                    const SizedBox(height: 32),
                    Text(
                      '404',
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr.noEncontradaTitulo,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr.noEncontradaTexto,
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.home_outlined, size: 18),
                      label: Text(tr.comunVolverAlInicio),
                      onPressed: () => Navigator.of(context)
                          .pushNamedAndRemoveUntil(
                              AppRoutes.landing, (_) => false),
                    ),
                  ],
                ),
              ),
                  ),
                ),
                const AppFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
