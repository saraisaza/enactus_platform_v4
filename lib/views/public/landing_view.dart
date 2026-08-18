import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/responsive.dart';
import '../../widgets/animated_logo.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_image.dart';
import '../../widgets/common.dart';
import '../../widgets/contact_dialog.dart';

/// Página principal pública: hero editable por el admin, laboratorios,
/// contadores animados de impacto y acceso al login.
class LandingView extends StatelessWidget {
  const LandingView({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final content = data.siteContent;
    final labs = data.labs;
    final isCompact = context.isCompact;

    return Scaffold(
      body: Column(
        children: [
          // Barra superior pública. Con el logo a 135px de alto (~esa
          // proporción de ancho) más el botón, la fila ya no cabe en un
          // teléfono aunque tenga un Spacer entre los dos — un Spacer
          // absorbe espacio sobrante, pero no encoge a sus vecinos cuando
          // ni siquiera hay espacio sobrante que absorber.
          Container(
            height: isCompact ? 64 : 160,
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                AnimatedLogo(height: isCompact ? 36 : 135),
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
                  // Prueba social inmediata: los campeones reales de la última
                  // National Expo, justo debajo del hero — antes de los
                  // contadores, para que el primer impacto visual sea gente
                  // real, no solo números.
                  const _ExpoShowcase(),
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
                            icon: Icons.groups_outlined,
                            value: content.statStudents,
                            label: 'Estudiantes activos'),
                        _AnimatedCounter(
                            icon: Icons.lightbulb_outline,
                            value: content.statProjects,
                            label: 'Proyectos de impacto'),
                        _AnimatedCounter(
                            icon: Icons.science_outlined,
                            value: content.statLabs,
                            label: 'Laboratorios'),
                        _AnimatedCounter(
                            icon: Icons.school_outlined,
                            value: content.statUniversities,
                            label: 'Universidades aliadas'),
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
                  // Galería: fotos que el Admin sube desde "Contenido
                  // página". Se oculta por completo si no hay ninguna.
                  if (content.galleryImages.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 6),
                      child: Text('Nuestro trabajo en imágenes'.toUpperCase(),
                          style: knockoutHeading(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: AppColors.gold)),
                    ),
                    const Text('Momentos de la comunidad Enactus Colombia',
                        style: TextStyle(color: AppColors.textMuted)),
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: [
                          for (var i = 0; i < content.galleryImages.length; i++)
                            Entrance(
                              delayMs: 90 * i,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 220,
                                  height: 160,
                                  child: AppImage(
                                      source: content.galleryImages[i],
                                      fit: BoxFit.cover),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  // Invitación cálida a unirse, para que la página no
                  // termine de golpe justo después de los laboratorios.
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(40, 8, 40, 40),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 36),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.gold.withValues(alpha: 0.14),
                          AppColors.slate,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      children: [
                        Text('¿Listo para sumarte? 💛'.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: knockoutHeading(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: const Text(
                            'Sin importar si eres estudiante, mentor, empresa o donante: '
                            'hay un lugar para ti en Enactus Colombia.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                height: 1.6),
                          ),
                        ),
                        const SizedBox(height: 22),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.favorite_outline, size: 18),
                          label: const Text('Quiero unirme'),
                          onPressed: () => showContactDialog(context),
                        ),
                      ],
                    ),
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

/// Fotos reales de los campeones de la National Expo 2026 (Santa Marta):
/// la foto grupal (horizontal) junto a los dos equipos ganadores por
/// categoría (verticales). Alturas iguales, ancho según su proporción
/// real — así conviven una foto horizontal y dos verticales sin recortes
/// forzados ni casillas vacías.
class _ExpoShowcase extends StatelessWidget {
  const _ExpoShowcase();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 44, 40, 8),
      child: Column(
        children: [
          Text('Campeones National Expo 2026'.toUpperCase(),
              textAlign: TextAlign.center,
              style: knockoutHeading(
                  fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.gold)),
          const SizedBox(height: 6),
          const Text(
              'Santa Marta, julio 2026 — nuestros equipos rumbo al Enactus World Cup en São Paulo',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 26),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 760;
            final photoHeight = wide ? 340.0 : 260.0;
            final photos = [
              Entrance(
                child: _ExpoPhoto(
                  asset: 'assets/media/foto1.jpeg',
                  aspectRatio: 1600 / 1107,
                  height: photoHeight,
                  fillWidth: !wide,
                  caption: 'Delegación Enactus Colombia · National Expo 2026',
                ),
              ),
              Entrance(
                delayMs: 90,
                child: _ExpoPhoto(
                  asset: 'assets/media/foto2.jpeg',
                  aspectRatio: 3 / 4,
                  height: photoHeight,
                  fillWidth: !wide,
                  // Sin leyenda propia: la foto ya trae "EARLY STAGE
                  // CHAMPION · ENERUNITY" impreso — duplicarla se veía
                  // encimado con el texto real de la foto.
                  caption: null,
                ),
              ),
              Entrance(
                delayMs: 180,
                child: _ExpoPhoto(
                  asset: 'assets/media/foto3.jpeg',
                  aspectRatio: 3 / 4,
                  height: photoHeight,
                  fillWidth: !wide,
                  caption: null,
                ),
              ),
            ];
            if (!wide) {
              return Column(
                children: [
                  for (var i = 0; i < photos.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    photos[i],
                  ],
                ],
              );
            }
            return Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: photos,
            );
          }),
        ],
      ),
    );
  }
}

/// Una foto con su relación de aspecto real (nunca recortada a la fuerza)
/// y una leyenda superpuesta con degradado, mismo lenguaje visual que la
/// portada de las tarjetas de proyecto del portal interno.
class _ExpoPhoto extends StatelessWidget {
  final String asset;
  final double aspectRatio;
  final double height;
  final bool fillWidth;

  /// `null` cuando la foto ya trae su propio letrero impreso (los
  /// carteles de categoría/equipo) — evita duplicar el texto encimado.
  final String? caption;
  const _ExpoPhoto(
      {required this.asset,
      required this.aspectRatio,
      required this.height,
      required this.fillWidth,
      required this.caption});

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(asset, fit: BoxFit.cover),
          if (caption != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 26, 14, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.78)],
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events, color: AppColors.gold, size: 15),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(caption!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (fillWidth) {
      // Móvil: alto fijo, ancho completo hasta un máximo legible — el
      // recorte de BoxFit.cover ya resuelve la proporción.
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SizedBox(height: height, width: double.infinity, child: image),
        ),
      );
    }
    // Escritorio: alto fijo, ancho derivado de la proporción real de la
    // foto — sin recorte, para que convivan una horizontal y dos
    // verticales en la misma fila sin casillas vacías.
    return SizedBox(height: height, width: height * aspectRatio, child: image);
  }
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

/// Contador que anima desde 0 hasta su valor al aparecer, con un ícono
/// amigable arriba para que se sienta más humano que un número suelto.
class _AnimatedCounter extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  const _AnimatedCounter(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 160,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.slate.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.gold, size: 22),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text(
              v.round().toString(),
              style: knockoutHeading(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: AppColors.gold,
                  height: 1.0),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 32,
            child: Center(
              child: Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }
}
