import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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

/// Una sola hoja de estilos para los tres botones, inyectada una vez.
///
/// Los colores son los mismos `AppColors.slateLight`/`gold`/`ink` que usa el
/// resto del pie — repetidos acá en hexadecimal porque este archivo no
/// importa el tema (es DOM puro, sin `BuildContext`).
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
        background: #573D31;
        color: #ffffff;
        text-decoration: none;
        cursor: pointer;
        transition: transform 180ms ease-out, background-color 180ms,
          box-shadow 180ms;
      }
      .enactus-boton-social:hover, .enactus-boton-social:focus-visible {
        background: #FA6A1E;
        color: #21120A;
        transform: scale(1.15);
        box-shadow: 0 0 16px 1px rgba(250, 106, 30, 0.45);
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
