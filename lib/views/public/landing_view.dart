import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/animated_logo.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/common.dart';

/// Página principal pública: hero editable por el admin, laboratorios,
/// contadores animados de impacto y acceso al login.
class LandingView extends StatelessWidget {
  const LandingView({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final content = data.siteContent;
    // Estudiantes y Alumni cuentan igual (ver Roles.isStudentLike), como en
    // el resto de la plataforma.
    final students = data.studentsAndAlumni.length;
    final projects = data.projects.length;
    final labs = data.labs;

    return Scaffold(
      body: Column(
        children: [
          // Barra superior pública
          Container(
            height: 160,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const AnimatedLogo(height: 135),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Iniciar sesión'),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.login),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Banner de anuncio
                  if (content.bannerText.isNotEmpty)
                    Container(
                      width: double.infinity,
                      color: AppColors.gold,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        content.bannerText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFF1A1400),
                            fontWeight: AppWeights.uiSemibold,
                            fontSize: 13),
                      ),
                    ),
                  // Hero
                  _Hero(title: content.heroTitle, subtitle: content.heroSubtitle),
                  // Contadores de impacto
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 30),
                    child: Wrap(
                      spacing: 40,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
                      children: [
                        _AnimatedCounter(
                            value: students, label: 'Estudiantes activos'),
                        _AnimatedCounter(
                            value: projects, label: 'Proyectos de impacto'),
                        _AnimatedCounter(
                            value: labs.length, label: 'Laboratorios'),
                        const _AnimatedCounter(
                            value: 12, label: 'Universidades aliadas'),
                      ],
                    ),
                  ),
                  // Sobre nosotros
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.slate,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      content.aboutText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          height: 1.6),
                    ),
                  ),
                  // Laboratorios
                  Padding(
                    padding: const EdgeInsets.only(top: 40, bottom: 6),
                    child: Text('Nuestros Laboratorios'.toUpperCase(),
                        style: knockoutHeading(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.gold)),
                  ),
                  const Text('Áreas de conocimiento donde formamos a nuestros equipos',
                      style: TextStyle(color: AppColors.textMuted)),
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: LayoutBuilder(builder: (context, c) {
                      final perRow =
                          c.maxWidth > 1000 ? 3 : (c.maxWidth > 640 ? 2 : 1);
                      final width =
                          (c.maxWidth - (perRow - 1) * 16) / perRow;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          // Los laboratorios aparecen uno tras otro (stagger)
                          for (var i = 0; i < labs.length; i++)
                            SizedBox(
                              width: width,
                              child: Entrance(
                                delayMs: 90 * i,
                                child: HoverCard(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(_labIcon(labs[i].id),
                                          color: AppColors.gold, size: 30),
                                      const SizedBox(height: 12),
                                      Text(labs[i].name.toUpperCase(),
                                          style: knockoutHeading(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      Text(labs[i].description,
                                          style: const TextStyle(
                                              color:
                                                  AppColors.textSecondary,
                                              fontSize: 13,
                                              height: 1.5)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                  const AppFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _labIcon(String labId) => switch (labId) {
        'lab_ia' => Icons.smart_toy_outlined,
        'lab_agua' => Icons.water_drop_outlined,
        'lab_energia' => Icons.bolt_outlined,
        'lab_impacto' => Icons.insights_outlined,
        'lab_emprendimiento' => Icons.rocket_launch_outlined,
        'lab_agricultura' => Icons.agriculture_outlined,
        _ => Icons.science_outlined,
      };
}

class _Hero extends StatefulWidget {
  final String title;
  final String subtitle;
  const _Hero({required this.title, required this.subtitle});

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _particles = AnimationController(
      vsync: this, duration: const Duration(seconds: 24))
    ..repeat();

  @override
  void dispose() {
    _particles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.background, AppColors.slate],
        ),
      ),
      child: Stack(
        // passthrough: el contenido conserva el ancho completo del hero,
        // así el título, el subtítulo y el botón quedan centrados.
        fit: StackFit.passthrough,
        children: [
          // Partículas doradas muy sutiles flotando hacia arriba
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particles,
              builder: (_, __) => CustomPaint(
                painter: _ParticlesPainter(_particles.value),
              ),
            ),
          ),
          _HeroContent(title: widget.title, subtitle: widget.subtitle),
        ],
      ),
    );
  }
}

/// Pocas partículas, lentas y tenues: presencia, no distracción.
class _ParticlesPainter extends CustomPainter {
  final double t;
  _ParticlesPainter(this.t);

  static const _count = 14;

  // Tricolor de la bandera de Colombia: cada partícula toma uno de los tres.
  static const _colors = [
    AppColors.colombiaYellow,
    AppColors.colombiaBlue,
    AppColors.colombiaRed,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < _count; i++) {
      // Posiciones pseudoaleatorias estables derivadas del índice
      final seed = i * 0.618033988749; // proporción áurea
      final x = ((seed * 7.13) % 1.0) * size.width;
      final speed = 0.35 + ((seed * 3.7) % 1.0) * 0.65;
      final y = size.height * (1.2 - ((t * speed + seed) % 1.2));
      final radius = 1.2 + ((seed * 5.3) % 1.0) * 2.2;
      final opacity = 0.08 + ((seed * 9.1) % 1.0) * 0.16;
      paint.color = _colors[i % _colors.length].withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) => old.t != t;
}

class _HeroContent extends StatelessWidget {
  final String title;
  final String subtitle;
  const _HeroContent({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 40),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOut,
        builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
              offset: Offset(0, 20 * (1 - v)), child: child),
        ),
        child: Column(
          children: [
            Text(title.toUpperCase(),
                textAlign: TextAlign.center,
                style: knockoutHeading(
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    color: AppColors.gold,
                    height: 1.1)),
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 17,
                      color: AppColors.textSecondary,
                      height: 1.6)),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Entrar a la plataforma'),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contador que anima desde 0 hasta su valor al aparecer.
class _AnimatedCounter extends StatelessWidget {
  final int value;
  final String label;
  const _AnimatedCounter({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.toDouble()),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Text(
            v.round().toString(),
            style: knockoutHeading(
                fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.gold),
          ),
        ),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
      ],
    );
  }
}
