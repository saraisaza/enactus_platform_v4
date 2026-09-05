import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../utils/app_theme.dart';

/// Botón de red social en la **web**: un `<a>` HTML real, no un
/// `GestureDetector` de Flutter.
///
/// Por qué. `GestureDetector.onTap` no llama al callback en el mismo turno
/// del evento nativo de clic: pasa antes por el árbol de gestos de Flutter
/// (`GestureArenaManager`), y esa resolución introduce un salto de
/// microtarea. Cuando el callback finalmente corre y llama a
/// `window.open(...)`, el navegador ya no considera "reciente" la activación
/// del clic y bloquea la pestaña — sin ningún error en consola. Es
/// exactamente lo que se reportó: el primer botón del pie abría su enlace y
/// los otros dos no hacían nada.
///
/// Un `<a target="_blank">` no tiene ese problema: el navegador nunca
/// bloquea un clic genuino sobre un enlace real, porque no pasa por
/// `window.open` en absoluto — es la navegación nativa del propio elemento.
///
/// El hover se resuelve con CSS (`:hover`), no con `MouseRegion` de Flutter:
/// es más simple y no depende de que Flutter procese el evento primero.
Widget construirBotonSocial({
  required String url,
  required String label,
  required Widget Function(Color) icono,
}) {
  _asegurarEstilos();
  final viewType = 'boton-social-${url.hashCode}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
    final a = web.HTMLAnchorElement()
      ..href = url
      ..target = '_blank'
      ..rel = 'noopener noreferrer'
      ..title = label
      ..className = 'enactus-boton-social'
      ..innerHTML = _svgDe(label).toJS;
    return a;
  });
  return SizedBox(
    width: 48,
    height: 48,
    child: HtmlElementView(viewType: viewType),
  );
}

bool _estilosListos = false;

/// Un color de Flutter como lo escribe CSS.
///
/// Existe para que esta hoja de estilos NO tenga hexadecimales propios. Los
/// tenía —el naranja y el marrón de la paleta anterior— y sobrevivieron
/// intactos al rebranding: al ser texto dentro de una cadena, ni el
/// compilador ni una búsqueda de `AppColors` los alcanzaban, así que el pie
/// quedaba con los colores viejos mientras el resto de la app cambiaba.
String _css(Color color, {double? alpha}) {
  final r = (color.r * 255).round();
  final g = (color.g * 255).round();
  final b = (color.b * 255).round();
  return alpha == null
      ? 'rgb($r, $g, $b)'
      : 'rgba($r, $g, $b, $alpha)';
}

/// Una sola hoja de estilos para los tres botones, inyectada una vez.
///
/// Este archivo es DOM puro (sin `BuildContext`), pero sí puede leer las
/// constantes de [AppColors]: los colores se interpolan desde ahí en vez de
/// repetirse a mano.
void _asegurarEstilos() {
  if (_estilosListos) return;
  _estilosListos = true;
  final estilo = web.HTMLStyleElement()
    ..textContent = '''
      .enactus-boton-social {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 36px;
        height: 36px;
        margin: 6px;
        border-radius: 50%;
        background: ${_css(AppColors.slateLight)};
        color: ${_css(Colors.white)};
        text-decoration: none;
        cursor: pointer;
        transition: transform 180ms ease-out, background-color 180ms,
          box-shadow 180ms;
      }
      .enactus-boton-social:hover, .enactus-boton-social:focus-visible {
        background: ${_css(AppColors.gold)};
        color: ${_css(AppColors.ink)};
        transform: scale(1.15);
        box-shadow: 0 0 16px 1px ${_css(AppColors.gold, alpha: 0.45)};
      }
      .enactus-boton-social svg { width: 18px; height: 18px; display: block; }
    ''';
  web.document.head!.appendChild(estilo);
}

/// El SVG de cada red, con el mismo trazo que las versiones dibujadas para
/// las demás plataformas (`social_icons.dart`) — mismas proporciones, para
/// que el pie se vea igual en web y en el resto.
String _svgDe(String label) {
  switch (label) {
    case 'Facebook':
      return '''
        <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <text x="12" y="17.5" text-anchor="middle"
                font-family="sans-serif" font-weight="800" font-size="17"
                fill="currentColor">f</text>
        </svg>
      ''';
    case 'Instagram':
      return '''
        <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <rect x="3" y="3" width="18" height="18" rx="6"
                stroke="currentColor" stroke-width="2"/>
          <circle cx="12" cy="12" r="4.3" stroke="currentColor" stroke-width="2"/>
          <circle cx="17.2" cy="6.8" r="1.15" fill="currentColor"/>
        </svg>
      ''';
    case 'LinkedIn':
      return '''
        <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <text x="12" y="16.5" text-anchor="middle"
                font-family="sans-serif" font-weight="800" font-size="13"
                letter-spacing="-0.5" fill="currentColor">in</text>
        </svg>
      ''';
    default:
      return '';
  }
}
