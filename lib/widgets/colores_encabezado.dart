import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/marca.dart';
import '../utils/tema.dart';

/// Los colores de lo que va SOBRE el encabezado.
///
/// El encabezado es oscuro, salvo el de un cliente cuyo logo es oscuro (el
/// que pedía placa clara): ahí el encabezado entero se vuelve claro y el logo
/// va directo sobre él, como en su propio sitio, sin una caja alrededor. Lo
/// que va encima —idioma, buscador, campana, cuenta— toma estos colores.
///
/// Sin cliente, son exactamente los de siempre ([oscuro]).
@immutable
class ColoresEncabezado {
  final bool claro;
  final Color fondo;
  final Color borde;
  final Color texto;
  final Color textoSecundario;
  final Color textoTenue;

  /// El fondo del buscador.
  final Color campo;

  const ColoresEncabezado._({
    required this.claro,
    required this.fondo,
    required this.borde,
    required this.texto,
    required this.textoSecundario,
    required this.textoTenue,
    required this.campo,
  });

  /// El de siempre: los grises del modo oscuro, FIJOS. No lee [AppColors]
  /// porque el encabezado de un cliente con logo claro sigue oscuro también
  /// en modo claro: su logo no se leería sobre blanco.
  static const oscuro = ColoresEncabezado._(
    claro: false,
    fondo: Color(0xFF35343A),
    borde: Color(0x14FFFFFF),
    texto: Color(0xFFF2F2F5),
    textoSecundario: Color(0xFFAEABB0),
    textoTenue: Color(0xFF8F8C92),
    campo: Color(0xFF26262A),
  );

  /// El que corresponde sin logo de cliente: el oscuro de siempre, o el
  /// claro en modo claro.
  static ColoresEncabezado get delTema =>
      Tema.oscuro ? oscuro : claroDeMarca;

  /// El de un cliente con logo oscuro, y el del modo claro. Los grises se eligieron por contraste
  /// sobre el blanco: el más tenue da 5.4:1.
  static const claroDeMarca = ColoresEncabezado._(
    claro: true,
    fondo: Colors.white,
    borde: Color(0xFFE3E3E8),
    texto: Color(0xFF1F1F23),
    textoSecundario: Color(0xFF45454D),
    textoTenue: Color(0xFF66666E),
    campo: Color(0xFFF2F2F5),
  );

  /// El oscuro, con el fondo del tono de la marca de un cliente.
  ColoresEncabezado conFondo(Color otro) => ColoresEncabezado._(
        claro: claro,
        fondo: otro,
        borde: borde,
        texto: texto,
        textoSecundario: textoSecundario,
        textoTenue: textoTenue,
        campo: campo,
      );

  /// El acento legible sobre este encabezado.
  Color get acento =>
      claro ? Marca.instancia.paleta.tintaSobreClaro : AppColors.gold;

  static ColoresEncabezado of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AmbitoEncabezado>()?.colores ??
      oscuro;

  @override
  bool operator ==(Object other) =>
      other is ColoresEncabezado && other.claro == claro && other.fondo == fondo;

  @override
  int get hashCode => Object.hash(claro, fondo);
}

/// Pone [colores] a disposición de lo que va dentro del encabezado.
class AmbitoEncabezado extends InheritedWidget {
  final ColoresEncabezado colores;

  const AmbitoEncabezado({
    super.key,
    required this.colores,
    required super.child,
  });

  @override
  bool updateShouldNotify(AmbitoEncabezado oldWidget) =>
      oldWidget.colores != colores;
}
