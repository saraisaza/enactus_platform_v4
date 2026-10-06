import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/textos.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/animated_logo.dart';
import '../../widgets/async_states.dart';
import '../../widgets/selector_idioma.dart';

/// Hay una sesión guardada pero no se pudo comprobar con el servidor.
///
/// Antes este caso mostraba la portada, como si la persona hubiera cerrado
/// sesión, sin ningún aviso y sin forma de reintentar. En el teléfono es lo
/// más común del mundo: abrir la app en el metro o en un salón sin señal.
///
/// Los tokens siguen guardados: "Reintentar" vuelve a comprobarlos y, si la
/// red ya volvió, entra directo al portal. La app también reintenta sola al
/// volver a primer plano (ver `EnactusApp`).
class SinConexionView extends StatelessWidget {
  const SinConexionView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const BarraIdioma(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AnimatedLogo(height: 64),
                        const SizedBox(height: 32),
                        const Icon(Icons.wifi_off_rounded,
                            size: 44, color: AppColors.gold),
                        const SizedBox(height: 16),
                        Text(
                          tr.sinConexionTitulo,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tr.sinConexionTexto,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.45),
                        ),
                        const SizedBox(height: 28),
                        if (auth.isRestoring)
                          BrandLoader(message: tr.sinConexionComprobando)
                        else
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(tr.comunReintentar),
                            onPressed: () => auth.restoreSession(),
                          ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: auth.isRestoring ? null : () => auth.logout(),
                          child: Text(tr.sinConexionOtraCuenta),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
