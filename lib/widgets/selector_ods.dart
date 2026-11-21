import 'package:flutter/material.dart';

import '../l10n/textos.dart';
import '../utils/app_theme.dart';

/// Un ODS que se puede elegir: su código (lo que se guarda), su número y su
/// título.
typedef OpcionOds = ({String codigo, int numero, String titulo});

/// Los 17 Objetivos de Desarrollo Sostenible en una cuadrícula pareja: cada
/// uno en un cuadro del mismo tamaño, con su color oficial, su número grande
/// y su título. Elegido, lleva un borde y un check.
///
/// Antes eran fichas de texto sueltas en un `Wrap`, cada una de su largo, y
/// las 17 quedaban desalineadas (recomendaciones del 20 de noviembre).
class SelectorDeOds extends StatelessWidget {
  final List<OpcionOds> opciones;
  final Set<String> elegidos;
  final void Function(String codigo, bool elegido)? alCambiar;

  const SelectorDeOds({
    super.key,
    required this.opciones,
    required this.elegidos,
    required this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, caja) {
      // Seis por fila en un computador (3 filas para los 17), tres en un
      // teléfono. Todas las casillas, cuadradas e iguales.
      final columnas = caja.maxWidth >= 900
          ? 6
          : caja.maxWidth >= 600
              ? 5
              : caja.maxWidth >= 380
                  ? 3
                  : 2;
      return GridView.count(
        key: const ValueKey('selector-ods'),
        crossAxisCount: columnas,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        // Más anchas que altas: con el número y el título caben de sobra, y
        // las 17 se ven sin desplazar.
        childAspectRatio: columnas >= 5 ? 1.75 : 1.35,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final o in opciones)
            _CasillaOds(
              opcion: o,
              elegido: elegidos.contains(o.codigo),
              alTocar: alCambiar == null
                  ? null
                  : () => alCambiar!(o.codigo, !elegidos.contains(o.codigo)),
            ),
        ],
      );
    });
  }
}

class _CasillaOds extends StatelessWidget {
  final OpcionOds opcion;
  final bool elegido;
  final VoidCallback? alTocar;

  const _CasillaOds(
      {required this.opcion, required this.elegido, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.odsColors[opcion.numero] ?? AppColors.relleno;
    final tinta = inkSobre(color);
    return Semantics(
      button: true,
      selected: elegido,
      label: tr.odsEtiqueta(opcion.numero, opcion.titulo),
      child: Tooltip(
        message: opcion.titulo,
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: elegido ? color : color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: ValueKey('ods-${opcion.numero}'),
            borderRadius: BorderRadius.circular(10),
            onTap: alTocar,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: elegido ? AppColors.textPrimary : color,
                    width: elegido ? 2 : 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('${opcion.numero}',
                          style: displayHeading(
                              fontSize: 24,
                              color: elegido ? tinta : AppColors.textPrimary)),
                      const Spacer(),
                      if (elegido)
                        Icon(Icons.check_circle, size: 18, color: tinta),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Text(
                      opcion.titulo,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: elegido ? tinta : AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
