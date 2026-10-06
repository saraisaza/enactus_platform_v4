import 'package:flutter/material.dart';

import '../l10n/textos.dart';
import '../utils/app_theme.dart';

/// Desplegable "Español / English" de la barra superior.
///
/// Está en el encabezado de todos los portales y detalles ([AppHeader]), en
/// la portada, el ingreso y las pantallas sueltas (sin conexión, página no
/// encontrada). Al elegir, la interfaz cambia en el acto y la elección queda
/// guardada en el dispositivo (ver [Idioma]).
class SelectorIdioma extends StatelessWidget {
  /// Solo "ES" / "EN" en el botón, para barras angostas como la del
  /// teléfono. El menú que se abre muestra siempre los nombres completos.
  final bool compacto;

  const SelectorIdioma({super.key, this.compacto = false});

  /// Para encontrarlo en las pruebas.
  static const clave = ValueKey('selector-idioma');

  @override
  Widget build(BuildContext context) {
    final idioma = Idioma.instancia;
    return ListenableBuilder(
      listenable: idioma,
      builder: (context, _) {
        final nombres = {'es': tr.idiomaEspanol, 'en': tr.idiomaIngles};
        return Tooltip(
          message: tr.idiomaSelector,
          child: Semantics(
            label: tr.idiomaSelector,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: clave,
                value: idioma.codigo,
                isDense: true,
                dropdownColor: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                focusColor: Colors.transparent,
                icon: const Icon(Icons.expand_more,
                    size: 18, color: AppColors.textSecondary),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: AppFonts.ui,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                selectedItemBuilder: (_) => [
                  for (final c in Idioma.codigos)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.language,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(compacto ? c.toUpperCase() : nombres[c]!),
                      ],
                    ),
                ],
                items: [
                  for (final c in Idioma.codigos)
                    DropdownMenuItem(value: c, child: Text(nombres[c]!)),
                ],
                onChanged: (c) {
                  if (c != null) idioma.cambiar(c);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// El selector arriba a la derecha, para las pantallas que no tienen el
/// encabezado de los portales: ingreso, sin conexión, página no encontrada.
class BarraIdioma extends StatelessWidget {
  const BarraIdioma({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SelectorIdioma(),
      ),
    );
  }
}
