import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'animated_logo.dart';
import 'common.dart';
import 'social_button.dart';
import 'social_icons.dart';

/// Footer institucional presente en todas las pantallas.
/// Borde tricolor superior (bandera de Colombia), logo animado, tagline y
/// redes sociales.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final socialButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        construirBotonSocial(
          icono: _iconoFacebook,
          label: 'Facebook',
          url: SocialLinks.facebook,
        ),
        const SizedBox(width: 10),
        construirBotonSocial(
          icono: _iconoInstagram,
          label: 'Instagram',
          url: SocialLinks.instagram,
        ),
        const SizedBox(width: 10),
        construirBotonSocial(
          icono: _iconoLinkedIn,
          label: 'LinkedIn',
          url: SocialLinks.linkedin,
        ),
      ],
    );
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.slate, AppColors.slateDark],
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
                // La decisión se toma sobre el ancho DISPONIBLE, no sobre el
                // de la ventana: el pie vive dentro de portales con barra
                // lateral, así que "hay 800px de ventana" no significa "hay
                // 800px acá". Con `context.isCompact` la fila desbordaba en
                // toda ventana de escritorio angosta —en los ocho portales, y
                // por 559px— porque los dos textos exigen su ancho natural y
                // dentro de un `Wrap` nadie los obliga a encoger.
                _apilar(context)
                    ? const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedLogo(height: 64, compact: true),
                          SizedBox(height: 12),
                          Text(
                            InstitutionalInfo.footerText,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Formamos líderes que transforman comunidades 💛',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
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
                          // Acotado: sin techo, estos dos textos piden su
                          // ancho intrínseco y arrastran la fila entera.
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  InstitutionalInfo.footerText,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Formamos líderes que transforman comunidades 💛',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                // El corrimiento de 100px es un ajuste visual deliberado en
                // escritorio; dentro de este mismo Wrap, en compact las dos
                // filas se apilan y ese corrimiento saca los íconos del
                // viewport — se aplica solo fuera de compact.
                _apilar(context)
                    ? socialButtons
                    : Transform.translate(
                        offset: const Offset(100, 0),
                        child: socialButtons,
                      ),
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
                  '© ${DateTime.now().year} eduXaction Colombia — Todos los derechos reservados',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
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
Widget _iconoFacebook(Color c) => Icon(Icons.facebook, size: 18, color: c);
Widget _iconoInstagram(Color c) => InstagramIcon(color: c);
Widget _iconoLinkedIn(Color c) => LinkedInIcon(color: c);

/// ¿Hay que apilar el pie en vez de ponerlo en una fila?
///
/// Se decide sobre el ancho de la VENTANA porque el pie ocupa el ancho
/// completo de su contenedor; el umbral es más alto que el de compact porque
/// el bloque de la izquierda (logotipo + dos líneas de texto) mide bastante
/// más que un teléfono.
bool _apilar(BuildContext context) => MediaQuery.sizeOf(context).width < 900;
