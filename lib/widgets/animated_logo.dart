import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Logo institucional animado: wordmark tipográfico "eduXaction" en Manrope
/// 700, con "edu" y "action" en blanco.
///
/// **La X va blanca, y el destello que la recorre va en ámbar**
/// ([AppColors.gold]). Es la regla de marca vigente, y reemplaza a la
/// anterior —"la X siempre en el acento, nunca cambia de tono"— que valía
/// cuando el acento era naranja. El motivo del cambio no es estético sino
/// mecánico: con la X ya en color, el barrido claro apenas se notaba; con la
/// X en blanco y el barrido en ámbar aparece el efecto de diamante que el
/// logo buscaba desde el principio. Por lo mismo, una X blanca con destello
/// blanco no se ve — los dos tonos tienen que seguir siendo distintos.
///
/// El barrido es continuo (3.6 s, ver `--exa-sweep` en el paquete de marca
/// `assets/media/eduxaction-logo.css` § `.exa-x::after`), no un efecto de
/// hover. En espacios angostos ([compact]) se reduce a la X sola en Manrope
/// 800 sobre el cuadrado oscuro `.exa-mark` (fondo `#0B0B0D`, radio 25%).
/// Además, al pasar el cursor todo el logo hace un zoom sutil, se inclina
/// apenas y emite un resplandor — eso es interacción propia de este widget
/// (no del paquete CSS) y se conserva tal cual, solo que el resplandor pasó
/// de ámbar a blanco para acompañar a la X.
///
/// No hay DOM/CSS real dentro del canvas de Flutter, así que este widget es
/// la traducción 1:1 de esas reglas de marca; ese CSS solo aplica tal cual
/// al splash de `web/index.html`, antes de que Flutter monte.
class AnimatedLogo extends StatefulWidget {
  final double height;
  final bool compact;
  final VoidCallback? onTap;

  /// Equivalente a la clase `exa-logo--on-light` del CSS: pone "edu"/
  /// "action" en tinta oscura para fondos claros. Hoy ningún sitio de la
  /// app llama a [AnimatedLogo] sobre fondo claro (header/sidebar/footer
  /// son oscuros fijos — ver `ContentColors` en app_theme.dart), así que
  /// este parámetro queda listo pero sin usar todavía.
  final bool onLight;

  const AnimatedLogo(
      {super.key,
      this.height = 60,
      this.compact = false,
      this.onTap,
      this.onLight = false})
      // Regla de marca: por debajo de 32px no se usa la X tipográfica como
      // ícono (se aprieta y pierde legibilidad) — a esos tamaños hay que
      // usar favicon-32.png o eduxaction-x.svg en su lugar, no este widget
      // en modo compact.
      : assert(!compact || height >= 32,
            'AnimatedLogo(compact: true) por debajo de 32px viola la regla de marca — usa favicon-*.png o eduxaction-x.svg en su lugar.');

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.28),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ]
                : const [],
          ),
          child: AnimatedScale(
            scale: _hover ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: AnimatedRotation(
              turns: _hover ? -0.004 : 0, // inclinación muy sutil
              duration: const Duration(milliseconds: 250),
              child: widget.compact
                  ? _CompactMark(height: widget.height)
                  : _Wordmark(height: widget.height, onLight: widget.onLight),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wordmark completo: "edu" + "X" + "action", Manrope 700 uniforme (igual
/// que `.exa-logo` en el CSS). La X es [_SweepingX] incrustada como
/// [WidgetSpan] (alineada al baseline del resto del texto) para que lleve
/// su propio barrido de luz sin romper el texto real seleccionable de
/// "edu"/"action".
class _Wordmark extends StatelessWidget {
  final double height;
  final bool onLight;
  const _Wordmark({required this.height, required this.onLight});

  @override
  Widget build(BuildContext context) {
    // Mismo factor que ya usaba el fallback de texto anterior — probado a
    // las alturas reales de header/footer/login (36-135px).
    final fontSize = height * 0.42;
    // rgba/hex tal cual .exa-logo--on-light { color: #101014 } en el CSS.
    final baseColor = onLight ? const Color(0xFF101014) : Colors.white;
    final letterSpacing = fontSize * -0.025;
    return Text.rich(
      TextSpan(children: [
        TextSpan(
            text: 'edu',
            style: TextStyle(
                fontFamily: AppFonts.logo,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: letterSpacing,
                color: baseColor,
                height: 1)),
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _SweepingX(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: letterSpacing),
        ),
        TextSpan(
            text: 'action',
            style: TextStyle(
                fontFamily: AppFonts.logo,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: letterSpacing,
                color: baseColor,
                height: 1)),
      ]),
    );
  }
}

/// Variante compacta: `.exa-mark` del CSS — cuadrado oscuro (`#0B0B0D`,
/// hoy [AppColors.backgroundDeep]) con radio 25%, y adentro la X sola
/// en Manrope 800 con su barrido ([_SweepingX]) — para sidebar colapsado,
/// header en compact, etc. Nunca se instancia por debajo de 32px (ver el
/// assert en [AnimatedLogo]).
class _CompactMark extends StatelessWidget {
  final double height;
  const _CompactMark({required this.height});

  @override
  Widget build(BuildContext context) {
    final side = height;
    final fontSize = side * 0.5; // calc(var(--exa-size) * 0.5) en el CSS
    return Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // El cuadrado se queda en el negro del paquete de marca aunque
        // `surface` se haya aclarado a #17171A: la X blanca necesita el
        // fondo más oscuro para separarse.
        color: AppColors.backgroundDeep,
        borderRadius: BorderRadius.circular(side * 0.25),
      ),
      child: _SweepingX(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: fontSize * -0.025),
    );
  }
}

/// La "X" de marca con su barrido de luz continuo — la traducción a Flutter
/// de `.exa-x` + `.exa-x::before` (halo) + `.exa-x::after` (destello
/// animado) en `assets/media/eduxaction-logo.css`. Corre en bucle mientras
/// el widget esté montado; se desactiva sola si el sistema tiene activado
/// "reducir movimiento" ([MediaQueryData.disableAnimations], el equivalente
/// Flutter de `prefers-reduced-motion`) — igual que el `@media` del CSS.
class _SweepingX extends StatefulWidget {
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  const _SweepingX(
      {required this.fontSize,
      required this.fontWeight,
      required this.letterSpacing});

  @override
  State<_SweepingX> createState() => _SweepingXState();
}

class _SweepingXState extends State<_SweepingX>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWithReducedMotion();
  }

  void _syncWithReducedMotion() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    // Halo + tinta base — .exa-x { color; text-shadow } y ::before, siempre
    // visibles (no dependen del movimiento reducido, solo el barrido sí).
    final baseStyle = TextStyle(
      fontFamily: AppFonts.logo,
      fontSize: widget.fontSize,
      fontWeight: widget.fontWeight,
      letterSpacing: widget.letterSpacing,
      height: 1,
      color: Colors.white,
      shadows: [
        Shadow(
            color: Colors.white.withValues(alpha: 0.75),
            blurRadius: widget.fontSize * 0.22),
      ],
    );
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.loose,
      children: [
        Text('X', style: baseStyle),
        if (!reduceMotion)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              // from 210% a -110% de background-position en el CSS =
              // recorre ~2.2x el ancho del glifo, de derecha a izquierda.
              final dx = 1.1 - 2.2 * _controller.value;
              return ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment(dx - 1, 0),
                  end: Alignment(dx + 1, 0),
                  stops: const [0.38, 0.5, 0.62],
                  // `--exa-shine`: el destello es lo único ámbar de la X.
                  colors: [
                    AppColors.gold.withValues(alpha: 0),
                    AppColors.gold.withValues(alpha: 0.95),
                    AppColors.gold.withValues(alpha: 0),
                  ],
                ).createShader(bounds),
                child: Text('X', style: baseStyle.copyWith(shadows: const [])),
              );
            },
          ),
      ],
    );
  }
}
