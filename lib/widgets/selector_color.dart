import 'package:flutter/material.dart';

import '../l10n/textos.dart';
import '../models/client.dart';
import '../utils/app_theme.dart';

/// Campo para elegir un color de dos formas: escribiendo su código
/// hexadecimal (`#1A73E8`) o en un selector visual.
///
/// El código es la forma exacta —es el que viene en el manual de marca de una
/// empresa— y el selector, la forma de explorar. Los dos escriben en el mismo
/// valor.
class CampoDeColor extends StatefulWidget {
  final String etiqueta;
  final String? ayuda;
  final Color? valor;
  final ValueChanged<Color?> alCambiar;

  /// Si el campo puede quedar vacío. Vacío dice [textoVacio] (p. ej. «se usa
  /// el primario»).
  final bool permiteVaciar;
  final String? textoVacio;
  final bool habilitado;

  const CampoDeColor({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.alCambiar,
    this.ayuda,
    this.permiteVaciar = false,
    this.textoVacio,
    this.habilitado = true,
  });

  @override
  State<CampoDeColor> createState() => _CampoDeColorState();
}

class _CampoDeColorState extends State<CampoDeColor> {
  late final TextEditingController _texto =
      TextEditingController(text: widget.valor == null ? '' : hexDe(widget.valor!));
  String? _error;

  @override
  void didUpdateWidget(CampoDeColor anterior) {
    super.didUpdateWidget(anterior);
    // El valor cambió desde afuera (el selector visual, o "quitar"): el texto
    // lo sigue, salvo que sea lo mismo que ya está escrito.
    if (widget.valor != anterior.valor &&
        colorDesdeHex(_texto.text) != widget.valor) {
      _texto.text = widget.valor == null ? '' : hexDe(widget.valor!);
      _error = null;
    }
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _alEscribir(String texto) {
    if (texto.trim().isEmpty) {
      setState(() => _error = widget.permiteVaciar ? null : tr.clientesColorFalta);
      if (widget.permiteVaciar) widget.alCambiar(null);
      return;
    }
    final color = colorDesdeHex(texto);
    setState(() => _error = color == null ? tr.clientesColorInvalido : null);
    if (color != null) widget.alCambiar(color);
  }

  Future<void> _abrirSelector() async {
    final elegido = await showDialog<Color>(
      context: context,
      builder: (_) => _SelectorVisual(
        inicial: widget.valor ?? PaletaMarcaInicial.sugerido,
        titulo: widget.etiqueta,
      ),
    );
    if (elegido != null) {
      _texto.text = hexDe(elegido);
      setState(() => _error = null);
      widget.alCambiar(elegido);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valor = widget.valor;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: tr.clientesAbrirSelector(widget.etiqueta),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.habilitado ? _abrirSelector : null,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: valor ?? AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, width: 2),
              ),
              child: valor == null
                  ? const Icon(Icons.palette_outlined,
                      color: AppColors.textMuted, size: 22)
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _texto,
            enabled: widget.habilitado,
            maxLength: 7,
            onChanged: _alEscribir,
            decoration: InputDecoration(
              labelText: widget.etiqueta,
              hintText: '#1A73E8',
              helperText: valor == null && widget.permiteVaciar
                  ? widget.textoVacio
                  : widget.ayuda,
              helperMaxLines: 3,
              errorText: _error,
              counterText: '',
              suffixIcon: IconButton(
                tooltip: tr.clientesAbrirSelector(widget.etiqueta),
                icon: const Icon(Icons.colorize_outlined, size: 20),
                onPressed: widget.habilitado ? _abrirSelector : null,
              ),
            ),
          ),
        ),
        if (widget.permiteVaciar && valor != null) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: tr.clientesQuitarColor(widget.etiqueta.toLowerCase()),
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.habilitado
                ? () {
                    _texto.clear();
                    setState(() => _error = null);
                    widget.alCambiar(null);
                  }
                : null,
          ),
        ],
      ],
    );
  }
}

/// Punto de partida del selector cuando el campo está vacío.
abstract final class PaletaMarcaInicial {
  /// Un azul medio: deja ver de entrada los tres controles del selector (un
  /// gris o el negro dejarían la barra de tono sin efecto aparente).
  static final sugerido = HSVColor.fromAHSV(1, 214, 0.72, 0.85).toColor();
}

/// Ancho del selector visual. Fijo y conocido: el selector vive en un
/// diálogo, que mide su contenido antes de dibujarlo, y un `LayoutBuilder` no
/// admite esa medida.
const _anchoSelector = 300.0;

/// Selector visual: un cuadro de saturación y brillo, y una barra de tono.
class _SelectorVisual extends StatefulWidget {
  final Color inicial;
  final String titulo;
  const _SelectorVisual({required this.inicial, required this.titulo});

  @override
  State<_SelectorVisual> createState() => _SelectorVisualState();
}

class _SelectorVisualState extends State<_SelectorVisual> {
  late HSVColor _hsv = HSVColor.fromColor(widget.inicial);

  Color get _color => _hsv.toColor();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: _anchoSelector,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CuadroSaturacionBrillo(
              ancho: _anchoSelector,
              hsv: _hsv,
              alCambiar: (hsv) => setState(() => _hsv = hsv),
            ),
            const SizedBox(height: 16),
            _BarraDeTono(
              ancho: _anchoSelector,
              tono: _hsv.hue,
              alCambiar: (tono) => setState(() => _hsv = _hsv.withHue(tono)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                ),
                const SizedBox(width: 12),
                SelectableText(
                  hexDe(_color),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: AppWeights.uiSemibold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr.comunCancelar),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _color),
          child: Text(tr.clientesUsarEsteColor),
        ),
      ],
    );
  }
}

/// El cuadro: a la derecha más saturado, arriba más brillante.
class _CuadroSaturacionBrillo extends StatelessWidget {
  final double ancho;
  final HSVColor hsv;
  final ValueChanged<HSVColor> alCambiar;
  const _CuadroSaturacionBrillo(
      {required this.ancho, required this.hsv, required this.alCambiar});

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) {
      const alto = 180.0;
      void mover(Offset p) => alCambiar(hsv
          .withSaturation((p.dx / ancho).clamp(0.0, 1.0))
          .withValue((1 - p.dy / alto).clamp(0.0, 1.0)));
      return Semantics(
        label: tr.clientesSaturacionBrillo,
        child: GestureDetector(
          onPanDown: (d) => mover(d.localPosition),
          onPanUpdate: (d) => mover(d.localPosition),
          child: SizedBox(
            width: ancho,
            height: alto,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  // Del blanco al tono puro, y encima del transparente al
                  // negro: es la definición del modelo HSV, no una paleta.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.white,
                          HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                        ]),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: hsv.saturation * ancho - 9,
                    top: (1 - hsv.value) * alto - 9,
                    child: IgnorePointer(
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 3),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// La barra de tono: el círculo cromático estirado de 0° a 360°.
class _BarraDeTono extends StatelessWidget {
  final double ancho;
  final double tono;
  final ValueChanged<double> alCambiar;
  const _BarraDeTono(
      {required this.ancho, required this.tono, required this.alCambiar});

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) {
      void mover(Offset p) => alCambiar((p.dx / ancho).clamp(0.0, 1.0) * 359.9);
      return Semantics(
        label: tr.clientesTono,
        child: GestureDetector(
          onPanDown: (d) => mover(d.localPosition),
          onPanUpdate: (d) => mover(d.localPosition),
          child: SizedBox(
            height: 22,
            width: ancho,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: LinearGradient(colors: [
                        for (var h = 0; h <= 360; h += 60)
                          HSVColor.fromAHSV(1, h % 360, 1, 1).toColor(),
                      ]),
                    ),
                  ),
                ),
                Positioned(
                  left: tono / 360 * ancho - 11,
                  top: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: HSVColor.fromAHSV(1, tono, 1, 1).toColor(),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
