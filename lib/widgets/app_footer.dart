import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/textos.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../utils/tema.dart';
import 'animated_logo.dart';
import 'common.dart';
import 'social_button.dart';
import 'social_icons.dart';

/// Footer institucional presente en todas las pantallas de la web.
/// Borde tricolor superior (bandera de Colombia), logo animado, tagline y
/// redes sociales.
///
/// En la app NO se dibuja: un pie de página de sitio web al final de cada
/// pantalla es de lo primero que hace ver una app como "un sitio web
/// empaquetado" (guía 4.2 de Apple), y ocupaba ~200 dp de cada scroll. Las
/// redes y los créditos están en el menú de la cuenta › Acerca de eduXaction
/// (`widgets/cuenta.dart`). Solo queda
/// el margen de la barra de gestos, para que el último contenido no quede
/// debajo del indicador de inicio.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return SizedBox(height: MediaQuery.paddingOf(context).bottom + 24);
    }
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
        const SizedBox(width: 10),
        construirBotonSocial(
          icono: _iconoWhatsApp,
          label: 'WhatsApp ${SocialLinks.whatsappVisible}',
          url: SocialLinks.whatsapp,
        ),
      ],
    );
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
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
            padding: EdgeInsets.fromLTRB(
                _apilar(context) ? 16 : 28, 18, _apilar(context) ? 16 : 28, 18),
            child: SizedBox(
  // A todo el ancho: un `Wrap` con `spaceBetween` mide lo que su
  // contenido y deja todo amontonado a la izquierda.
  width: double.infinity,
  child: Wrap(
              alignment: _apilar(context)
                  ? WrapAlignment.center
                  : WrapAlignment.spaceBetween,
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
                // En el teléfono, todo centrado y con el logo completo, no
                // solo la «X» (recomendaciones del 20 de noviembre).
                _apilar(context)
                    ? SizedBox(
                        width: double.infinity,
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedLogo(
                              height: 44, compact: false, onLight: !Tema.oscuro),
                          SizedBox(height: 12),
                          Text(
                            InstitutionalInfo.footerText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            tr.pieLema,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedLogo(height: 95, onLight: !Tema.oscuro),
                          const SizedBox(width: 18),
                          Container(
                            width: 1,
                            height: 75,
                            color: AppColors.velo(0.12),
                          ),
                          const SizedBox(width: 18),
                          // Acotado: sin techo, estos dos textos piden su
                          // ancho intrínseco y arrastran la fila entera.
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
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
                                  tr.pieLema,
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
                // Las redes, al borde derecho: el `Wrap` va a todo el ancho.
                // (Antes no lo iba y se las corría 100 px a mano.)
                socialButtons,
              ],
            )),
          ),
          // Fila inferior de copyright
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.velo(0.08)),
              ),
            ),
            child: SizedBox(
  // A todo el ancho: un `Wrap` con `spaceBetween` mide lo que su
  // contenido y deja todo amontonado a la izquierda.
  width: double.infinity,
  child: Wrap(
              alignment: _apilar(context)
                  ? WrapAlignment.center
                  : WrapAlignment.spaceBetween,
              runSpacing: 4,
              children: [
                Text(
                  tr.pieDerechos(DateTime.now().year),
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                Text(
                  tr.pieHechoEn,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

/// Botón de red social: al pasar el cursor se vuelve dorado, escala y brilla.
Widget _iconoFacebook(Color c) => Icon(Icons.facebook, size: 18, color: c);
Widget _iconoInstagram(Color c) => InstagramIcon(color: c);
Widget _iconoWhatsApp(Color c) => WhatsAppIcon(color: c);
Widget _iconoLinkedIn(Color c) => LinkedInIcon(color: c);

/// ¿Hay que apilar el pie en vez de ponerlo en una fila?
///
/// Se decide sobre el ancho de la VENTANA porque el pie ocupa el ancho
/// completo de su contenedor; el umbral es más alto que el de compact porque
/// el bloque de la izquierda (logotipo + dos líneas de texto) mide bastante
/// más que un teléfono.
bool _apilar(BuildContext context) => MediaQuery.sizeOf(context).width < 900;
