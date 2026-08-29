import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';

/// Pantalla para los portales que todavía no se migraron a la API.
///
/// Es deliberadamente honesta: dice que la función no está disponible todavía,
/// en vez de mostrar un portal a medias. Un portal que muestra datos
/// incompletos —o que revienta ante un 403— es peor que uno que aún no está,
/// porque la persona no puede saber si lo que ve es cierto.
///
/// Los archivos de estos portales viven en `migration_pending/`, fuera de
/// `lib/`, y vuelven cuando les toca su ciclo de migración.
class PendingPortalView extends StatelessWidget {
  final String portalName;

  const PendingPortalView({super.key, required this.portalName});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 64),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.construction_outlined,
                          size: 40, color: AppColors.gold),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      portalName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 30,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Disponible próximamente',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Estamos conectando este portal con el nuevo sistema. '
                      'Preferimos tenerlo bien hecho antes que a medias: '
                      'mientras tanto, no vas a ver información que pueda '
                      'estar desactualizada.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14.5,
                        height: 1.6,
                      ),
                    ),
                    if (user != null) ...[
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline,
                                size: 18, color: AppColors.textMuted),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Tu sesión sigue activa como '
                                '${user.name} · ${Roles.label(user.role)}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.home_outlined, size: 18),
                          label: const Text('Ir al inicio'),
                          onPressed: () => Navigator.of(context)
                              .pushNamedAndRemoveUntil(
                                  AppRoutes.landing, (_) => false),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Cerrar sesión'),
                          onPressed: () async {
                            await context.read<AuthProvider>().logout();
                            if (context.mounted) {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                  AppRoutes.landing, (_) => false);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const AppFooter(),
          ],
        ),
      ),
    );
  }
}
