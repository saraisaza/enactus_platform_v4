import 'package:flutter/material.dart';

import '../l10n/textos.dart';
import '../utils/app_theme.dart';

/// El logo de un cliente, siempre dentro de una caja de [altoMaximo] ×
/// [anchoMaximo], sin deformarse.
///
/// Un logo puede ser ancho (un nombre escrito) o casi cuadrado (un símbolo).
/// Con `BoxFit.contain` cualquiera de los dos entra entero en la caja; lo que
/// cambia es cuál de los dos lados la llena.
///
/// Con [placaClara], va sobre un rectángulo claro: un logo oscuro con fondo
/// transparente desaparece sobre el gris del encabezado.
class LogoDeCliente extends StatelessWidget {
  final ImageProvider imagen;
  final String nombre;
  final bool placaClara;
  final double altoMaximo;
  final double anchoMaximo;

  const LogoDeCliente({
    super.key,
    required this.imagen,
    required this.nombre,
    this.placaClara = false,
    required this.altoMaximo,
    required this.anchoMaximo,
  });

  /// La placa se come un poco del alto: el relleno es proporcional, para que
  /// el logo no quede apretado en un encabezado de teléfono.
  double get _relleno => placaClara ? altoMaximo * 0.14 : 0;

  @override
  Widget build(BuildContext context) {
    final logo = Image(
      image: imagen,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      // Un logo que no carga (URL vencida, sin conexión) no deja un ícono de
      // imagen rota en el encabezado: deja el nombre del cliente.
      errorBuilder: (_, _, _) => Text(
        nombre,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: placaClara ? AppColors.tintaOscura : AppColors.textPrimary,
          fontWeight: AppWeights.uiSemibold,
          fontSize: (altoMaximo * 0.32).clamp(11, 18),
        ),
      ),
    );
    return Semantics(
      label: tr.clientesLogoDe(nombre),
      image: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: altoMaximo,
          maxWidth: anchoMaximo,
        ),
        child: placaClara
            ? DecoratedBox(
                decoration: BoxDecoration(
                  // El fondo claro de la plataforma, no un blanco puro: sobre
                  // el gris del encabezado, el blanco encandila.
                  color: ContentColors.light.bg,
                  borderRadius: BorderRadius.circular(altoMaximo * 0.16),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: _relleno * 1.4, vertical: _relleno),
                  child: logo,
                ),
              )
            : logo,
      ),
    );
  }
}
