import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Logo institucional animado: wordmark tipográfico "eduXaction" ("edu" y
/// "action" en blanco peso 500, la "X" en peso 800 color de marca). En
/// espacios angostos ([compact]) se reduce a la X sola sobre un cuadrado
/// naranja de esquinas redondeadas (radio 30% del lado). Al pasar el
/// cursor hace un zoom sutil, se inclina apenas y emite un resplandor
/// dorado. Si recibe [onTap], navega (cursor pointer incluido).
class AnimatedLogo extends StatefulWidget {
  final double height;
  final bool compact;
  final VoidCallback? onTap;
  const AnimatedLogo(
      {super.key, this.height = 60, this.compact = false, this.onTap});

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
                      color: AppColors.gold.withValues(alpha: 0.35),
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
              child: widget.compact ? _CompactMark(height: widget.height) : _Wordmark(
                  height: widget.height, hover: _hover),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wordmark completo: "edu" + "X" + "action".
class _Wordmark extends StatelessWidget {
  final double height;
  final bool hover;
  const _Wordmark({required this.height, required this.hover});

  @override
  Widget build(BuildContext context) {
    // Mismo factor que ya usaba el fallback de texto anterior — probado a
    // las alturas reales de header/footer/login (36-135px).
    final fontSize = height * 0.42;
    final xColor = hover ? AppColors.goldBright : AppColors.gold;
    return Text.rich(
      TextSpan(children: [
        TextSpan(
            text: 'edu',
            style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1)),
        TextSpan(
            text: 'X',
            style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: xColor,
                height: 1)),
        TextSpan(
            text: 'action',
            style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1)),
      ]),
    );
  }
}

/// Variante compacta: solo la X, blanca, sobre un cuadrado naranja de
/// esquinas redondeadas (radio 30% del lado) — para sidebar colapsado,
/// header en compact, etc.
class _CompactMark extends StatelessWidget {
  final double height;
  const _CompactMark({required this.height});

  @override
  Widget build(BuildContext context) {
    final side = height;
    return Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(side * 0.3),
      ),
      child: Text('X',
          style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: side * 0.56,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1)),
    );
  }
}
