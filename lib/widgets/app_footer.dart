import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import 'animated_logo.dart';
import 'common.dart';

/// Footer institucional presente en todas las pantallas.
/// Borde tricolor superior (bandera de Colombia), logo animado, tagline y
/// redes sociales.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final socialButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _SocialButton(
            icon: Icons.facebook,
            label: 'Facebook',
            url: SocialLinks.facebook),
        SizedBox(width: 10),
        _SocialButton(
            icon: Icons.camera_alt_outlined,
            label: 'Instagram',
            url: SocialLinks.instagram),
        SizedBox(width: 10),
        _SocialButton(
            icon: Icons.business_center_outlined,
            label: 'LinkedIn',
            url: SocialLinks.linkedin),
      ],
    );
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.slate, Color(0xFF243342)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Borde tricolor de la bandera de Colombia, izquierda a derecha
          const ColombiaFlagBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 18, 4, 18),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 14,
              children: [
                // El logo (95px alto) + divisor + texto en una sola fila
                // sin envoltura ya desborda por sí solo en compact (el
                // texto no tiene ancho acotado); en vez de forzarlos a
                // compartir una fila que no cabe, en compact se apilan
                // verticalmente — un `Column` sí ajusta el texto al ancho
                // disponible (lo hace pasar a más líneas) en vez de exigir
                // su ancho intrínseco completo como un `Row` sin `Expanded`.
                context.isCompact
                    ? const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedLogo(height: 64),
                          SizedBox(height: 12),
                          Text(
                            InstitutionalInfo.footerText,
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Formamos líderes que transforman comunidades 💛',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AnimatedLogo(height: 95),
                          const SizedBox(width: 18),
                          Container(
                            width: 1,
                            height: 75,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          const SizedBox(width: 18),
                          const Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                InstitutionalInfo.footerText,
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Formamos líderes que transforman comunidades 💛',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                // El corrimiento de 100px es un ajuste visual deliberado en
                // escritorio; dentro de este mismo Wrap, en compact las dos
                // filas se apilan y ese corrimiento saca los íconos del
                // viewport — se aplica solo fuera de compact.
                context.isCompact
                    ? socialButtons
                    : Transform.translate(
                        offset: const Offset(100, 0), child: socialButtons),
              ],
            ),
          ),
          // Fila inferior de copyright
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  '© ${DateTime.now().year} Enactus Colombia — Todos los derechos reservados',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
                const Text(
                  'Hecho con 💛 en Bogotá',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón de red social: al pasar el cursor se vuelve dorado, escala y brilla.
class _SocialButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String url;
  const _SocialButton(
      {required this.icon, required this.label, required this.url});

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
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
          onTap: () => launchUrl(Uri.parse(widget.url)),
          // El círculo visible mide 36×36 (9px de padding + ícono de 18) —
          // por debajo del mínimo de 48×48dp. En vez de agrandar el círculo
          // (cambiaría el diseño), se centra dentro de un área táctil
          // invisible de 48×48.
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
                  child: Icon(widget.icon,
                      size: 18,
                      color: _hover ? const Color(0xFF1A1400) : Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
