import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Logo institucional animado: al pasar el cursor hace un zoom sutil,
/// se inclina apenas y emite un resplandor dorado. Si recibe [onTap],
/// navega (cursor pointer incluido).
class AnimatedLogo extends StatefulWidget {
  final double height;
  final VoidCallback? onTap;
  const AnimatedLogo({super.key, this.height = 60, this.onTap});

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
              child: Image.asset(
                'assets/media/mainlogo.png',
                height: widget.height,
                errorBuilder: (_, __, ___) => Text(
                  'ENACTUS',
                  style: knockoutHeading(
                    color: _hover ? AppColors.goldBright : AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: widget.height * 0.42,
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
