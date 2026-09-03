import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_theme.dart';

/// Botón de red social fuera de la web: círculo con ícono, `url_launcher`
/// abre el navegador del sistema. Ahí no existe el bloqueo de ventanas
/// emergentes que motiva la versión web (ver `social_button_web.dart`).
Widget construirBotonSocial({
  required String url,
  required String label,
  required Widget Function(Color) icono,
}) {
  return _BotonSocialIo(url: url, label: label, icono: icono);
}

class _BotonSocialIo extends StatefulWidget {
  final String url;
  final String label;
  final Widget Function(Color) icono;
  const _BotonSocialIo({
    required this.url,
    required this.label,
    required this.icono,
  });

  @override
  State<_BotonSocialIo> createState() => _BotonSocialIoState();
}

class _BotonSocialIoState extends State<_BotonSocialIo> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          onTap: () => launchUrl(
            Uri.parse(widget.url),
            mode: LaunchMode.externalApplication,
          ),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: AnimatedScale(
                scale: _hover ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _hover ? AppColors.gold : AppColors.slateLight,
                    shape: BoxShape.circle,
                    boxShadow: _hover
                        ? [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.45),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ]
                        : const [],
                  ),
                  child: widget.icono(_hover ? AppColors.ink : Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
