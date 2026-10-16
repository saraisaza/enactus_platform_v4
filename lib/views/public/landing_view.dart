import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/textos.dart';
import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../utils/formatos.dart';
import '../../widgets/async_states.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/responsive.dart';
import '../../widgets/animated_logo.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/common.dart';
import '../../widgets/contact_dialog.dart';
import '../../widgets/selector_idioma.dart';

/// Página principal pública: qué es eduXaction —una plataforma de formación
/// para empresas que integra a todos los roles del aprendizaje—, cómo
/// funciona, qué trae, quiénes ya la usan (Enactus) y la invitación a
/// escribirnos («Contáctenos»).
///
/// Lo que el admin edita en «Contenido página» que se ve acá: el anuncio de
/// arriba, las cifras de Enactus y su galería. El texto de la portada es de
/// la plataforma y está en los dos idiomas.
class LandingView extends StatelessWidget {
  const LandingView({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    // La portada es pública: este es el único dato que se pide sin sesión.
    return data.siteContent.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: BrandLoader()),
      ),
      error: (e) => Scaffold(
        backgroundColor: AppColors.background,
        body: ErrorState(e, onRetry: data.reloadSiteContent),
      ),
      data: (content) => _buildLanding(context, content),
    );
  }

  Widget _buildLanding(BuildContext context, SiteContent content) {
    final isCompact = context.isCompact;

    return Scaffold(
      body: Column(
        children: [
          // Barra superior pública. Con el logo a 135px de alto (~esa
          // proporción de ancho) más los botones, la fila no cabe en un
          // teléfono: ahí el logo es el compacto y «Agendar» se va al hero.
          Container(
            height: isCompact ? 64 : 160,
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                AnimatedLogo(height: isCompact ? 36 : 135, compact: isCompact),
                const Spacer(),
                SelectorIdioma(compacto: isCompact),
                SizedBox(width: isCompact ? 8 : 16),
                if (!isCompact) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: Text(tr.portadaAgendarDemo),
                    onPressed: () => showContactDialog(context),
                  ),
                  const SizedBox(width: 12),
                ],
                // En el teléfono, sin ícono y más angosto: con el ícono, la
                // fila no cabía en 360 px («Iniciar sesión» es largo).
                // Y si aun así no cabe (un teléfono muy angosto), se achica en
                // vez de salirse.
                if (isCompact)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14)),
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.login),
                        child: Text(tr.portadaIniciarSesion),
                      ),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login, size: 18),
                    label: Text(tr.portadaIniciarSesion),
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
                  // Anuncio opcional, editable por el admin.
                  if (content.bannerVisible.isNotEmpty)
                    Container(
                      width: double.infinity,
                      color: AppColors.relleno,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        content.bannerVisible,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: AppWeights.uiSemibold,
                            fontSize: 13),
                      ),
                    ),
                  _Hero(personas: content.statStudents),
                  const _Roles(),
                  const _ComoFunciona(),
                  const _Funciones(),
                  _Clientes(content: content),
                  const _Cierre(),
                  const AppFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El ancho de lectura de la página: en pantallas grandes el contenido no
/// se estira de borde a borde.
class _Ancho extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Ancho({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(padding: padding, child: child),
        ),
      );
}

/// Eyebrow, título y bajada de una sección, centrados.
class _Encabezado extends StatelessWidget {
  final String eyebrow;
  final String titulo;
  final String? texto;
  const _Encabezado(
      {required this.eyebrow, required this.titulo, this.texto});

  @override
  Widget build(BuildContext context) {
    final compacto = context.isCompact;
    return Column(
      children: [
        _Eyebrow(eyebrow),
        const SizedBox(height: 8),
        Text(titulo.toUpperCase(),
            textAlign: TextAlign.center,
            style: displayHeading(
                fontSize: compacto ? 28 : 38,
                color: AppColors.textPrimary)),
        if (texto != null) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(texto!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.6)),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _Hero extends StatefulWidget {
  /// Cuántas personas ya aprenden: la cifra que edita el admin.
  final int personas;
  const _Hero({required this.personas});

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
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
          colors: [AppColors.background, AppColors.backgroundDeep],
        ),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particles,
              builder: (_, _) => CustomPaint(
                painter: _ParticlesPainter(_particles.value),
              ),
            ),
          ),
          _Ancho(
            padding: EdgeInsets.symmetric(
                horizontal: context.isCompact ? 20 : 40,
                vertical: context.isCompact ? 44 : 72),
            child: LayoutBuilder(builder: (context, c) {
              final ancho = c.maxWidth >= 940;
              final texto = _TextoDelHero(centrado: !ancho);
              final producto = _ProductoEnVivo(personas: widget.personas);
              if (!ancho) {
                return Column(children: [
                  texto,
                  const SizedBox(height: 44),
                  producto,
                ]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 11, child: texto),
                  const SizedBox(width: 48),
                  Expanded(flex: 9, child: producto),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _TextoDelHero extends StatelessWidget {
  final bool centrado;
  const _TextoDelHero({required this.centrado});

  @override
  Widget build(BuildContext context) {
    final compacto = context.isCompact;
    final alineado = centrado ? TextAlign.center : TextAlign.start;
    final tamano = compacto ? 33.0 : 62.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child),
      ),
      child: Column(
        crossAxisAlignment:
            centrado ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          _Eyebrow(tr.portadaEyebrow),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: '${tr.portadaTitulo1.toUpperCase()}\n',
                  style: displayHeading(
                      fontSize: tamano,
                      height: 1.0,
                      color: AppColors.textPrimary)),
              TextSpan(
                  text: tr.portadaTitulo2.toUpperCase(),
                  style: displayHeading(
                      fontSize: tamano, height: 1.0, color: AppColors.gold)),
            ]),
            textAlign: alineado,
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(tr.portadaSubtitulo,
                textAlign: alineado,
                style: TextStyle(
                    fontSize: compacto ? 15.5 : 17,
                    color: AppColors.textSecondary,
                    height: 1.6)),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: centrado ? WrapAlignment.center : WrapAlignment.start,
            children: [
              ElevatedButton.icon(
                key: const ValueKey('portada-agendar'),
                icon: const Icon(Icons.mail_outline, size: 18),
                label: Text(tr.portadaAgendarDemo),
                onPressed: () => showContactDialog(context),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(tr.portadaEntrar),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            alignment: centrado ? WrapAlignment.center : WrapAlignment.start,
            children: [
              for (final (icono, texto) in [
                (Icons.palette_outlined, tr.portadaVentajaMarca),
                (Icons.devices_outlined, tr.portadaVentajaDispositivos),
                (Icons.translate, tr.portadaVentajaIdiomas),
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icono, size: 16, color: AppColors.gold),
                    const SizedBox(width: 6),
                    // En un teléfono angosto el texto parte en dos líneas en
                    // vez de salirse de la pantalla.
                    Flexible(
                      child: Text(texto,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Una vista de la plataforma por dentro, dibujada (no una captura): una
/// capacitación con su avance y sus lecciones en orden, y dos avisos que
/// flotan —la entrega aprobada, el certificado con QR—. Muestra en un vistazo
/// lo que el texto promete.
class _ProductoEnVivo extends StatefulWidget {
  final int personas;
  const _ProductoEnVivo({required this.personas});

  @override
  State<_ProductoEnVivo> createState() => _ProductoEnVivoState();
}

class _ProductoEnVivoState extends State<_ProductoEnVivo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flote = AnimationController(
      vsync: this, duration: const Duration(seconds: 6))
    ..repeat();

  @override
  void dispose() {
    _flote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compacto = context.isCompact;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470),
        child: AnimatedBuilder(
          animation: _flote,
          builder: (context, _) {
            final t = _flote.value * 2 * math.pi;
            return Padding(
              padding: EdgeInsets.only(
                  top: 48, bottom: 30, left: compacto ? 0 : 18, right: compacto ? 0 : 18),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const _TarjetaCapacitacion(),
                  Positioned(
                    // Por encima del anillo de avance, sin taparlo.
                    top: -50 + 4 * math.sin(t),
                    right: compacto ? -4 : -26,
                    child: _Aviso(
                      icono: Icons.check_circle,
                      color: AppColors.statusGood,
                      titulo: tr.portadaMockAprobada,
                    ),
                  ),
                  Positioned(
                    bottom: -26 + 4 * math.sin(t + math.pi),
                    left: compacto ? -4 : -30,
                    child: _Aviso(
                      icono: Icons.workspace_premium_outlined,
                      color: AppColors.gold,
                      titulo: tr.portadaMockCertificado,
                      detalle: tr.portadaMockQr,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TarjetaCapacitacion extends StatelessWidget {
  const _TarjetaCapacitacion();

  @override
  Widget build(BuildContext context) {
    const avance = 0.72;
    final lecciones = [
      (tr.portadaMockLeccion1, Icons.play_circle_outline, _Estado.hecha),
      (tr.portadaMockLeccion2, Icons.description_outlined, _Estado.hecha),
      (tr.portadaMockLeccion3, Icons.quiz_outlined, _Estado.ahora),
      (tr.portadaMockLeccion4, Icons.assignment_outlined, _Estado.bloqueada),
    ];
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 18)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(tr.portadaMockEtiqueta.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10.5,
                              letterSpacing: 1.2,
                              fontWeight: AppWeights.uiSemibold,
                              color: AppColors.gold)),
                    ),
                    const SizedBox(height: 10),
                    Text(tr.portadaMockTitulo,
                        style: displayHeading(
                            fontSize: 22, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: avance,
                      strokeWidth: 7,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(AppColors.gold),
                    ),
                    Center(
                      child: Text('${(avance * 100).round()}%',
                          style: displayHeading(
                              fontSize: 20, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final (titulo, icono, estado) in lecciones)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: estado == _Estado.ahora
                    ? AppColors.gold.withValues(alpha: 0.10)
                    : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: estado == _Estado.ahora
                        ? AppColors.gold.withValues(alpha: 0.5)
                        : Colors.transparent),
              ),
              child: Row(
                children: [
                  Icon(icono,
                      size: 18,
                      color: estado == _Estado.bloqueada
                          ? AppColors.textMuted
                          : AppColors.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(titulo,
                        style: TextStyle(
                            fontSize: 13.5,
                            color: estado == _Estado.bloqueada
                                ? AppColors.textMuted
                                : AppColors.textPrimary)),
                  ),
                  Icon(
                    switch (estado) {
                      _Estado.hecha => Icons.check_circle,
                      _Estado.ahora => Icons.radio_button_unchecked,
                      _Estado.bloqueada => Icons.lock_outline,
                    },
                    size: 18,
                    color: switch (estado) {
                      _Estado.hecha => AppColors.statusGood,
                      _Estado.ahora => AppColors.gold,
                      _Estado.bloqueada => AppColors.textMuted,
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _Estado { hecha, ahora, bloqueada }

/// Un aviso flotante sobre la tarjeta.
class _Aviso extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String? detalle;
  const _Aviso(
      {required this.icono,
      required this.color,
      required this.titulo,
      this.detalle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.slateLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              if (detalle != null)
                Text(detalle!,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Los roles
// ---------------------------------------------------------------------------

class _Roles extends StatelessWidget {
  const _Roles();

  @override
  Widget build(BuildContext context) {
    final roles = [
      (Icons.design_services_outlined, tr.portadaRolDisenoTitulo,
          tr.portadaRolDisenoTexto),
      (Icons.fact_check_outlined, tr.portadaRolAcompanaTitulo,
          tr.portadaRolAcompanaTexto),
      (Icons.school_outlined, tr.portadaRolAprendeTitulo,
          tr.portadaRolAprendeTexto),
      (Icons.insights_outlined, tr.portadaRolDecideTitulo,
          tr.portadaRolDecideTexto),
    ];
    return _Ancho(
      padding: EdgeInsets.fromLTRB(
          context.isCompact ? 20 : 40, 72, context.isCompact ? 20 : 40, 24),
      child: Column(
        children: [
          _Encabezado(
              eyebrow: tr.portadaRolesEyebrow,
              titulo: tr.portadaRolesTitulo,
              texto: tr.portadaRolesTexto),
          const SizedBox(height: 36),
          _Rejilla(
            minimo: 240,
            hijos: [
              for (final (i, (icono, titulo, texto)) in roles.indexed)
                Entrance(
                  delayMs: 90 * i,
                  child: _Tarjeta(icono: icono, titulo: titulo, texto: texto),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reparte [hijos] en columnas de al menos [minimo] de ancho, todas iguales.
class _Rejilla extends StatelessWidget {
  final double minimo;
  final List<Widget> hijos;
  const _Rejilla({required this.minimo, required this.hijos});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const separacion = 16.0;
      final columnas = math.max(
          1, math.min(hijos.length, (c.maxWidth + separacion) ~/ (minimo + separacion)));
      final ancho = (c.maxWidth - separacion * (columnas - 1)) / columnas;
      return Wrap(
        spacing: separacion,
        runSpacing: separacion,
        children: [
          for (final h in hijos) SizedBox(width: ancho, child: h),
        ],
      );
    });
  }
}

class _Tarjeta extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  const _Tarjeta(
      {required this.icono, required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      padding: const EdgeInsets.all(22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: AppColors.gold, size: 24),
            ),
            const SizedBox(height: 16),
            Text(titulo,
                style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(texto,
                style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                    height: 1.55)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cómo funciona
// ---------------------------------------------------------------------------

class _ComoFunciona extends StatelessWidget {
  const _ComoFunciona();

  @override
  Widget build(BuildContext context) {
    final pasos = [
      (tr.portadaPaso1Titulo, tr.portadaPaso1Texto),
      (tr.portadaPaso2Titulo, tr.portadaPaso2Texto),
      (tr.portadaPaso3Titulo, tr.portadaPaso3Texto),
    ];
    return _Ancho(
      padding: EdgeInsets.symmetric(
          horizontal: context.isCompact ? 20 : 40, vertical: 56),
      child: Column(
        children: [
          _Encabezado(
              eyebrow: tr.portadaComoEyebrow, titulo: tr.portadaComoTitulo),
          const SizedBox(height: 36),
          _Rejilla(
            minimo: 260,
            hijos: [
              for (final (i, (titulo, texto)) in pasos.indexed)
                Entrance(
                  delayMs: 90 * i,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.relleno,
                              shape: BoxShape.circle,
                            ),
                            child: Text('${i + 1}',
                                style: displayHeading(
                                    fontSize: 20, color: AppColors.ink)),
                          ),
                          const SizedBox(width: 12),
                          // La línea que une un paso con el siguiente.
                          if (i < pasos.length - 1)
                            Expanded(
                              child: Container(
                                  height: 1,
                                  color: AppColors.gold.withValues(alpha: 0.3)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(titulo.toUpperCase(),
                          style: displayHeading(
                              fontSize: 22, color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Text(texto,
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.6)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lo que trae
// ---------------------------------------------------------------------------

class _Funciones extends StatelessWidget {
  const _Funciones();

  @override
  Widget build(BuildContext context) {
    final funciones = [
      (Icons.verified_outlined, tr.portadaFuncionAvanceTitulo,
          tr.portadaFuncionAvanceTexto),
      (Icons.task_alt, tr.portadaFuncionAprobacionesTitulo,
          tr.portadaFuncionAprobacionesTexto),
      (Icons.qr_code_2, tr.portadaFuncionCertificadosTitulo,
          tr.portadaFuncionCertificadosTexto),
      (Icons.palette_outlined, tr.portadaFuncionMarcaTitulo,
          tr.portadaFuncionMarcaTexto),
      (Icons.poll_outlined, tr.portadaFuncionEncuestasTitulo,
          tr.portadaFuncionEncuestasTexto),
      (Icons.devices_outlined, tr.portadaFuncionDispositivosTitulo,
          tr.portadaFuncionDispositivosTexto),
    ];
    // Su propia banda, del gris al negro: separa «lo que trae» del resto.
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.slateLight, AppColors.backgroundDeep],
        ),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: _Ancho(
        padding: EdgeInsets.symmetric(
            horizontal: context.isCompact ? 20 : 40, vertical: 64),
        child: Column(
          children: [
            _Encabezado(
                eyebrow: tr.portadaFuncionesEyebrow,
                titulo: tr.portadaFuncionesTitulo),
            const SizedBox(height: 36),
            _Rejilla(
              minimo: 300,
              hijos: [
                for (final (i, (icono, titulo, texto)) in funciones.indexed)
                  Entrance(
                    delayMs: 60 * i,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icono, color: AppColors.gold, size: 26),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(titulo,
                                  style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                              const SizedBox(height: 6),
                              Text(texto,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      color: AppColors.textSecondary,
                                      height: 1.55)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nuestros clientes
// ---------------------------------------------------------------------------

/// Enactus Colombia, el primer cliente: su red en cifras (las que edita el
/// admin), los campeones de su National Expo y su galería, si tiene.
class _Clientes extends StatelessWidget {
  final SiteContent content;
  const _Clientes({required this.content});

  @override
  Widget build(BuildContext context) {
    final compacto = context.isCompact;
    return _Ancho(
      padding: EdgeInsets.fromLTRB(compacto ? 20 : 40, 72, compacto ? 20 : 40, 24),
      child: Column(
        children: [
          _Encabezado(
              eyebrow: tr.portadaClientesEyebrow,
              titulo: tr.portadaClientesTitulo),
          const SizedBox(height: 36),
          Container(
            key: const ValueKey('cliente-enactus'),
            width: double.infinity,
            padding: EdgeInsets.all(compacto ? 20 : 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.05),
                  AppColors.backgroundDeep.withValues(alpha: 0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ENACTUS COLOMBIA',
                    style: displayHeading(
                        fontSize: compacto ? 26 : 34,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Text(tr.portadaEnactusTexto,
                      style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          height: 1.6)),
                ),
                const SizedBox(height: 24),
                // De a cuatro en el computador y de a dos en el teléfono, a
                // todo el ancho de la tarjeta.
                _Rejilla(
                  minimo: 120,
                  hijos: [
                    _AnimatedCounter(
                        icon: Icons.groups_outlined,
                        value: content.statStudents,
                        label: tr.portadaEstudiantesActivos),
                    _AnimatedCounter(
                        icon: Icons.lightbulb_outline,
                        value: content.statProjects,
                        label: tr.portadaProyectosImpacto),
                    _AnimatedCounter(
                        icon: Icons.science_outlined,
                        value: content.statLabs,
                        label: tr.portadaLaboratorios),
                    _AnimatedCounter(
                        icon: Icons.school_outlined,
                        value: content.statUniversities,
                        label: tr.portadaUniversidadesAliadas),
                  ],
                ),
                const SizedBox(height: 28),
                LayoutBuilder(builder: (context, c) {
                  final ancho = c.maxWidth > 760;
                  // En el computador, el alto que hace que las tres fotos
                  // —una horizontal y dos verticales— llenen la fila justo.
                  const proporciones = 1600 / 1107 + 3 / 4 + 3 / 4;
                  final alto = ancho
                      ? math.min(340.0, (c.maxWidth - 2 * 14) / proporciones)
                      : 220.0;
                  final fotos = [
                    _ExpoPhoto(
                      asset: 'assets/media/foto1.jpeg',
                      aspectRatio: 1600 / 1107,
                      height: alto,
                      fillWidth: !ancho,
                      caption: tr.portadaExpoPie,
                    ),
                    _ExpoPhoto(
                      asset: 'assets/media/foto2.jpeg',
                      aspectRatio: 3 / 4,
                      height: alto,
                      fillWidth: !ancho,
                      caption: null,
                    ),
                    _ExpoPhoto(
                      asset: 'assets/media/foto3.jpeg',
                      aspectRatio: 3 / 4,
                      height: alto,
                      fillWidth: !ancho,
                      caption: null,
                    ),
                  ];
                  if (!ancho) {
                    return Column(children: [
                      for (var i = 0; i < fotos.length; i++) ...[
                        if (i > 0) const SizedBox(height: 14),
                        fotos[i],
                      ],
                    ]);
                  }
                  return Wrap(spacing: 14, runSpacing: 14, children: fotos);
                }),
                // Lo que el admin sube en «Contenido página».
                if (content.galleryImages.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (final url in content.galleryImages)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 200,
                            height: 140,
                            // Ya vienen firmadas del servidor: la portada no
                            // tiene sesión con la que pedir la firma.
                            child: Image.network(url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                    color: AppColors.surfaceAlt)),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cierre
// ---------------------------------------------------------------------------

class _Cierre extends StatelessWidget {
  const _Cierre();

  @override
  Widget build(BuildContext context) {
    final compacto = context.isCompact;
    return _Ancho(
      padding: EdgeInsets.fromLTRB(compacto ? 20 : 40, 40, compacto ? 20 : 40, 64),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
            horizontal: compacto ? 22 : 48, vertical: compacto ? 36 : 52),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.gold.withValues(alpha: 0.16),
              AppColors.backgroundDeep,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text(tr.portadaCierreTitulo.toUpperCase(),
                textAlign: TextAlign.center,
                style: displayHeading(
                    fontSize: compacto ? 28 : 40,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(tr.portadaCierreTexto,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15.5,
                      height: 1.6)),
            ),
            const SizedBox(height: 26),
            ElevatedButton.icon(
              icon: const Icon(Icons.mail_outline, size: 18),
              label: Text(tr.portadaAgendarDemo),
              onPressed: () => showContactDialog(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Línea corta en ámbar sobre un título de sección.
///
/// Es lo que sostiene la jerarquía después del rebranding: los títulos de
/// sección pasaron de ámbar a blanco, y sin este renglón el acento
/// desaparecía por completo de esa zona de la página. El ámbar se conserva,
/// pero en el elemento pequeño en vez del grande.
class _Eyebrow extends StatelessWidget {
  final String texto;

  const _Eyebrow(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: AppWeights.uiSemibold,
        // .14em a 11.5 px. El tracking abierto es lo que distingue un
        // eyebrow de un subtítulo chico.
        letterSpacing: 11.5 * 0.14,
        color: AppColors.gold,
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
                    Icon(Icons.emoji_events, color: AppColors.gold, size: 15),
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

/// Pocas partículas, lentas y tenues: presencia, no distracción.
class _ParticlesPainter extends CustomPainter {
  final double t;
  _ParticlesPainter(this.t);

  static const _count = 14;

  // Tonos cálidos de marca: cada partícula toma uno de los cuatro.
  static const _colors = AppColors.heroParticleColors;

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
      height: 160,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        // "Negro difuminado": el radial aclara el borde superior y se hunde
        // hacia el negro abajo. Plano —como era, un slate al 40 %— la
        // tarjeta se leía como un rectángulo pegado sobre el fondo.
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            AppColors.backgroundDeep.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
            builder: (_, v, _) => Text(
              entero(v),
              style: displayHeading(
                  fontSize: 36,
                  color: AppColors.gold,
                  height: 1.0,
                  letterSpacing: 0),
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
