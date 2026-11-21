import 'package:flutter/material.dart';

import '../l10n/textos.dart';
import '../utils/tema.dart';
import 'colores_encabezado.dart';

/// El interruptor claro/oscuro del encabezado: siempre visible, en todos los
/// portales y detalles.
///
/// Un riel con el sol a un lado y la luna al otro, y una perilla que se
/// desliza hacia el modo activo. Cambia TODA la plataforma ([Tema]).
class InterruptorTema extends StatelessWidget {
  const InterruptorTema({super.key});

  /// Para encontrarlo en las pruebas.
  static const clave = ValueKey('interruptor-tema');

  @override
  Widget build(BuildContext context) {
    final colores = ColoresEncabezado.of(context);
    final oscuro = Tema.oscuro;
    final ayuda = oscuro ? tr.temaPasarAClaro : tr.temaPasarAOscuro;
    const ancho = 56.0, alto = 30.0, perilla = 24.0;

    return Tooltip(
      message: ayuda,
      child: Semantics(
        button: true,
        toggled: !oscuro,
        label: ayuda,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: clave,
            behavior: HitTestBehavior.opaque,
            onTap: Tema.instancia.alternar,
            // 48 de alto: el mínimo tocable en el teléfono.
            child: SizedBox(
              height: 48,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: ancho,
                  height: alto,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colores.campo,
                    borderRadius: BorderRadius.circular(alto / 2),
                    border: Border.all(color: colores.borde),
                  ),
                  child: Stack(
                    children: [
                      // Los dos íconos fijos, tenues.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(
                            width: perilla,
                            child: Icon(Icons.light_mode_rounded,
                                size: 14, color: colores.textoTenue),
                          ),
                          SizedBox(
                            width: perilla,
                            child: Icon(Icons.dark_mode_rounded,
                                size: 14, color: colores.textoTenue),
                          ),
                        ],
                      ),
                      // La perilla, sobre el modo activo.
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        alignment: oscuro
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: perilla,
                          height: perilla,
                          decoration: BoxDecoration(
                            color: colores.acento,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            oscuro
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            size: 14,
                            color: colores.claro
                                ? const Color(0xFFFFFFFF)
                                : const Color(0xFF21120A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
