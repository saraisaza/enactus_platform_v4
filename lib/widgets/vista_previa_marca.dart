import 'package:flutter/material.dart';

import '../l10n/textos.dart';
import '../models/client.dart';
import '../utils/app_theme.dart';
import '../utils/formatos.dart';
import '../utils/marca.dart';
import 'animated_logo.dart';
import 'logo_de_cliente.dart';

/// Maqueta del portal con la marca de un cliente, para verla ANTES de
/// guardarla.
///
/// Pinta con los colores de [paleta] directamente, no con `AppColors`: la
/// marca activa es la de quien administra (la de eduXaction), y la maqueta
/// tiene que mostrar la del cliente sin cambiarle la pantalla al admin.
///
/// Los usos son los mismos que tendrá el portal: el primario en botones,
/// enlaces, títulos y la franja de arriba; el secundario en la opción activa
/// del menú, las insignias y las barras de progreso.
class VistaPreviaMarca extends StatelessWidget {
  final PaletaMarca paleta;
  final String nombre;
  final ImageProvider? logo;
  final bool placaClara;

  /// Oscuro y claro uno al lado del otro, o uno debajo del otro. Lo decide
  /// quien la muestra: la vista previa vive dentro de un diálogo, que mide su
  /// contenido antes de dibujarlo, y un `LayoutBuilder` no admite esa medida.
  final bool ladoALado;

  const VistaPreviaMarca({
    super.key,
    required this.paleta,
    required this.nombre,
    this.logo,
    this.placaClara = false,
    this.ladoALado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr.clientesVistaPrevia,
      child: Builder(builder: (context) {
        final oscuro = _Panel(
            paleta: paleta,
            nombre: nombre,
            logo: logo,
            placaClara: placaClara,
            claro: false);
        final claro = _Panel(
            paleta: paleta,
            nombre: nombre,
            logo: logo,
            placaClara: placaClara,
            claro: true);
        if (ladoALado) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: oscuro),
              const SizedBox(width: 12),
              Expanded(child: claro),
            ],
          );
        }
        return Column(children: [oscuro, const SizedBox(height: 12), claro]);
      }),
    );
  }
}

class _Panel extends StatelessWidget {
  final PaletaMarca paleta;
  final String nombre;
  final ImageProvider? logo;
  final bool placaClara;
  final bool claro;

  const _Panel({
    required this.paleta,
    required this.nombre,
    required this.logo,
    required this.placaClara,
    required this.claro,
  });

  @override
  Widget build(BuildContext context) {
    final c = claro ? ContentColors.light : ContentColors.dark;
    final tinta = claro ? paleta.tintaSobreClaro : paleta.tintaSobreOscuro;
    final insignia =
        claro ? paleta.secundarioSobreClaro : paleta.secundarioSobreOscuro;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(claro ? tr.clientesModoClaro : tr.clientesModoOscuro,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: AppWeights.uiSemibold)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // El encabezado es oscuro en los dos modos, como en el portal.
                Container(height: 3, color: paleta.primario),
                Container(
                  height: 52,
                  color: AppColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const FittedBox(child: AnimatedLogo(height: 28)),
                      Container(
                        width: 1,
                        height: 26,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        color: AppColors.textMuted,
                      ),
                      Flexible(
                        child: logo == null
                            ? Text(nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: AppWeights.uiSemibold))
                            : LogoDeCliente(
                                imagen: logo!,
                                nombre: nombre,
                                placaClara: placaClara,
                                altoMaximo: 30,
                                anchoMaximo: 110,
                              ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 196,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 88,
                        color: AppColors.slate,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          children: [
                            _OpcionDeMenu(
                                icono: Icons.dashboard_outlined,
                                texto: tr.tabInicioCorto,
                                activa: true,
                                paleta: paleta),
                            _OpcionDeMenu(
                                icono: Icons.school_outlined,
                                texto: tr.tabCursosCorto,
                                activa: false,
                                paleta: paleta),
                            _OpcionDeMenu(
                                icono: Icons.person_outline,
                                texto: tr.tabPerfilCorto,
                                activa: false,
                                paleta: paleta),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: c.bg,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      tr.clientesMaquetaSaludo.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: displayHeading(
                                          fontSize: 20, color: tinta),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: paleta.secundario
                                          .withValues(alpha: claro ? 0.16 : 0.18),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(tr.clientesMaquetaNuevo,
                                        style: TextStyle(
                                            color: insignia,
                                            fontSize: 10.5,
                                            fontWeight: AppWeights.uiSemibold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: c.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: c.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(tr.clientesMaquetaCurso,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: c.text,
                                            fontSize: 12.5,
                                            fontWeight: AppWeights.uiSemibold)),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: 0.6,
                                        minHeight: 5,
                                        backgroundColor: c.surface2,
                                        valueColor: AlwaysStoppedAnimation(
                                            paleta.secundario),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: paleta.primario,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(tr.clientesMaquetaContinuar,
                                              style: TextStyle(
                                                  color: paleta.sobrePrimario,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      AppWeights.uiSemibold)),
                                        ),
                                        const SizedBox(width: 10),
                                        Flexible(
                                          child: Text(
                                            tr.clientesMaquetaEnlace,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: tinta,
                                              fontSize: 12,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: tinta,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OpcionDeMenu extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool activa;
  final PaletaMarca paleta;

  const _OpcionDeMenu({
    required this.icono,
    required this.texto,
    required this.activa,
    required this.paleta,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        activa ? paleta.secundarioSobreOscuro : AppColors.textSecondary;
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 2, 6, 2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: activa ? paleta.secundario.withValues(alpha: 0.16) : null,
        borderRadius: BorderRadius.circular(6),
        border: activa
            ? Border(left: BorderSide(color: paleta.secundario, width: 3))
            : null,
      ),
      child: Row(
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: activa
                        ? AppWeights.uiSemibold
                        : AppWeights.uiRegular)),
          ),
        ],
      ),
    );
  }
}

/// Qué hizo la plataforma con los colores para que todo se lea, dicho para
/// quien administra: cada uso, si quedó tal cual o si se ajustó y a qué.
///
/// Es el «avisa al admin» de la regla de contraste: el ajuste lo hace la
/// plataforma sola, pero quien eligió el color tiene que saber que en algunos
/// lugares no se va a ver exactamente igual.
class InformeDeContraste extends StatelessWidget {
  final PaletaMarca paleta;
  const InformeDeContraste({super.key, required this.paleta});

  @override
  Widget build(BuildContext context) {
    final p = paleta;
    String r(double v) => decimal(v, 2);

    // El botón tiene que distinguirse de la tarjeta sobre la que va —3:1, el
    // mínimo de WCAG para el contorno de un control—, aparte de que su texto
    // se lea. Un primario muy oscuro deja el texto perfecto y el botón casi
    // invisible. No se corrige: es el color exacto del cliente. Se avisa.
    //
    // Se mide contra las tarjetas, donde vive casi todo botón, y no contra
    // el gris de la página: ahí el azul medio del ejemplo daba 2.74:1 y se
    // avisaba de un botón que a la vista resalta bien.
    final botonContraFondo = contraste(p.primario, AppColors.surface);

    final filas = <(bool, String)>[
      (
        true,
        tr.clientesInformeBoton(
          p.sobrePrimario == Colors.white
              ? tr.clientesTintaBlanca
              : tr.clientesTintaOscura,
          r(contraste(p.sobrePrimario, p.primario)),
        ),
      ),
      if (botonContraFondo < 3)
        (false, tr.clientesInformeBotonSeFunde(r(botonContraFondo))),
      if (p.tintaSobreOscuro == p.primario)
        (
          true,
          tr.clientesInformeOscuroIgual(
              r(contraste(p.primario, PaletaMarca.fondoOscuroMasClaro))),
        )
      else
        (
          false,
          // El orden es el de la frase: antes, el color nuevo, después.
          tr.clientesInformeOscuroAjustado(
            r(contraste(p.primario, PaletaMarca.fondoOscuroMasClaro)),
            hexDe(p.tintaSobreOscuro),
            r(contraste(p.tintaSobreOscuro, PaletaMarca.fondoOscuroMasClaro)),
          ),
        ),
      if (p.tintaSobreClaro == p.primario)
        (
          true,
          tr.clientesInformeClaroIgual(
              r(contraste(p.primario, PaletaMarca.fondoClaroMasOscuro))),
        )
      else
        (
          false,
          tr.clientesInformeClaroAjustado(
            r(contraste(p.primario, PaletaMarca.fondoClaroMasOscuro)),
            hexDe(p.tintaSobreClaro),
            r(contraste(p.tintaSobreClaro, PaletaMarca.fondoClaroMasOscuro)),
          ),
        ),
      // El secundario se informa solo donde se ajustó: decir «se ajustó a
      // #0B5394» de un color que quedó igual confunde.
      if (p.secundario != p.primario) ...[
        if (p.secundarioSobreOscuro == p.secundario &&
            p.secundarioSobreClaro == p.secundario)
          (true, tr.clientesInformeSecundarioIgual),
        if (p.secundarioSobreOscuro != p.secundario)
          (
            false,
            tr.clientesInformeSecundarioOscuro(hexDe(p.secundarioSobreOscuro)),
          ),
        if (p.secundarioSobreClaro != p.secundario)
          (
            false,
            tr.clientesInformeSecundarioClaro(hexDe(p.secundarioSobreClaro)),
          ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (bien, texto) in filas)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  bien ? Icons.check_circle_outline : Icons.info_outline,
                  size: 17,
                  color: bien ? AppColors.statusGood : AppColors.statusWarning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(texto,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.4)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
