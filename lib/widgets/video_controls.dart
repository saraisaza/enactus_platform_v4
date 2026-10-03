import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../utils/app_theme.dart';
import 'lesson_video_shell.dart';

/// Las velocidades que se ofrecen.
const videoSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

/// `0,5×`, `1×`, `1,25×`: con coma, como se escribe acá.
String speedLabel(double speed) {
  final texto = speed == speed.roundToDouble()
      ? speed.toStringAsFixed(0)
      : speed.toString().replaceAll('.', ',');
  return '$texto×';
}

/// Los controles del video subido, con los colores y la tipografía de la app.
///
/// Reproducir y pausar, barra de avance que se arrastra (y muestra lo ya
/// cargado), volumen, velocidad de 0,5× a 2× y pantalla completa. Con el
/// teclado: Espacio o K (reproducir/pausar), ← → (5 s), ↑ ↓ (volumen),
/// F (pantalla completa) y M (silencio). Cada botón tiene su etiqueta para el
/// lector de pantalla, y todos se alcanzan con Tab.
///
/// Se esconden solos a los 2,5 s mientras el video corre, y vuelven al mover
/// el mouse, tocar la pantalla o pasar el foco por ellos.
class LessonVideoControls extends StatefulWidget {
  const LessonVideoControls({
    super.key,
    required this.controller,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    this.autofocus = false,
  });

  final VideoPlayerController controller;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final bool autofocus;

  @override
  State<LessonVideoControls> createState() => _LessonVideoControlsState();
}

class _LessonVideoControlsState extends State<LessonVideoControls> {
  final FocusNode _foco = FocusNode(debugLabel: 'video');
  Timer? _ocultar;
  bool _visibles = true;
  bool _focoEnBarra = false;
  double? _arrastre;
  double _volumenAntes = 1;
  PointerDeviceKind _ultimoPuntero = PointerDeviceKind.mouse;

  VideoPlayerController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_alCambiar);
    _programarOcultar();
    // `autofocus` no alcanza al volver de pantalla completa: el diálogo
    // restaura el foco que tenía antes, que era de unos controles que ya no
    // existen, y el teclado dejaba de responder. Se pide explícitamente.
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _foco.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant LessonVideoControls old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_alCambiar);
      widget.controller.addListener(_alCambiar);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_alCambiar);
    _ocultar?.cancel();
    _foco.dispose();
    super.dispose();
  }

  void _alCambiar() {
    if (mounted) setState(() {});
  }

  void _mostrar() {
    if (!_visibles) setState(() => _visibles = true);
    _programarOcultar();
  }

  void _programarOcultar() {
    _ocultar?.cancel();
    _ocultar = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      if (_c.value.isPlaying && _arrastre == null && !_focoEnBarra) {
        setState(() => _visibles = false);
      }
    });
  }

  Future<void> _alternar() async {
    final v = _c.value;
    if (v.isPlaying) {
      await _c.pause();
    } else {
      if (v.isCompleted ||
          (v.duration > Duration.zero && v.position >= v.duration)) {
        await _c.seekTo(Duration.zero);
      }
      await _c.play();
    }
    _mostrar();
  }

  Future<void> _saltar(Duration delta) async {
    final v = _c.value;
    final destino = v.position + delta;
    await _c.seekTo(
      destino < Duration.zero
          ? Duration.zero
          : destino > v.duration
          ? v.duration
          : destino,
    );
    _mostrar();
  }

  Future<void> _volumen(double valor) async {
    await _c.setVolume(valor.clamp(0.0, 1.0));
    _mostrar();
  }

  Future<void> _silenciar() async {
    final actual = _c.value.volume;
    if (actual > 0) {
      _volumenAntes = actual;
      await _c.setVolume(0);
    } else {
      await _c.setVolume(_volumenAntes > 0 ? _volumenAntes : 1);
    }
    _mostrar();
  }

  /// En pantallas táctiles el primer toque solo muestra los controles: si
  /// pausara, no habría forma de verlos sin parar el video.
  void _alTocar() {
    if (_ultimoPuntero == PointerDeviceKind.touch && !_visibles) {
      _mostrar();
      return;
    }
    _alternar();
  }

  @override
  Widget build(BuildContext context) {
    final v = _c.value;
    final mostrar = _visibles || !v.isPlaying || _arrastre != null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _alternar,
        const SingleActivator(LogicalKeyboardKey.keyK): _alternar,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _saltar(const Duration(seconds: -5)),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _saltar(const Duration(seconds: 5)),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _volumen(v.volume + 0.1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _volumen(v.volume - 0.1),
        const SingleActivator(LogicalKeyboardKey.keyF):
            widget.onToggleFullscreen,
        const SingleActivator(LogicalKeyboardKey.keyM): _silenciar,
      },
      child: Focus(
        focusNode: _foco,
        autofocus: widget.autofocus,
        onFocusChange: (_) => _mostrar(),
        child: MouseRegion(
          onHover: (_) => _mostrar(),
          cursor: mostrar ? MouseCursor.defer : SystemMouseCursors.none,
          child: Listener(
            onPointerDown: (e) => _ultimoPuntero = e.kind,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Cada control con SU nodo (`container`): sin eso, las
                // etiquetas se funden con el nodo de arriba y la barra entera
                // se anuncia como un solo botón con todos los nombres juntos.
                Semantics(
                  container: true,
                  label: v.isPlaying
                      ? 'Pausar el video'
                      : 'Reproducir el video',
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _alTocar,
                    onDoubleTap: widget.onToggleFullscreen,
                    child: const SizedBox.expand(),
                  ),
                ),
                if (v.isBuffering && !v.isCompleted)
                  Center(
                    child: IgnorePointer(
                      child: Semantics(
                        container: true,
                        label: 'Cargando el video',
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation(AppColors.gold),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (!v.isPlaying)
                  Center(child: _BotonGrande(onPressed: _alternar)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedOpacity(
                    opacity: mostrar ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !mostrar,
                      child: Focus(
                        canRequestFocus: false,
                        skipTraversal: true,
                        includeSemantics: false,
                        onFocusChange: (dentro) {
                          _focoEnBarra = dentro;
                          _mostrar();
                        },
                        child: _barra(context, v),
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
  }

  Widget _barra(BuildContext context, VideoPlayerValue v) {
    final total = v.duration;
    final totalSeg = math.max(total.inMilliseconds / 1000, 0.001);
    final posSeg = (_arrastre ?? v.position.inMilliseconds / 1000).clamp(
      0.0,
      totalSeg,
    );
    var cargado = 0.0;
    for (final r in v.buffered) {
      cargado = math.max(cargado, r.end.inMilliseconds / 1000);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth >= 520;
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0xCC000000)],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(ancho ? 12 : 4, 18, ancho ? 12 : 4, 4),
            child: IconTheme(
              data: const IconThemeData(color: Colors.white, size: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: AppColors.gold,
                      inactiveTrackColor: const Color(0x40FFFFFF),
                      secondaryActiveTrackColor: const Color(0x80FFFFFF),
                      thumbColor: AppColors.gold,
                      overlayColor: AppColors.gold.withValues(alpha: 0.2),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                    ),
                    child: SizedBox(
                      height: 28,
                      child: MergeSemantics(
                        child: Semantics(
                          label: 'Posición del video',
                          child: Slider(
                            value: posSeg,
                            max: totalSeg,
                            secondaryTrackValue: cargado.clamp(0.0, totalSeg),
                            semanticFormatterCallback: (s) =>
                                '${formatVideoTime(Duration(seconds: s.round()))} de '
                                '${formatVideoTime(total)}',
                            onChangeStart: (s) => setState(() => _arrastre = s),
                            onChanged: (s) => setState(() => _arrastre = s),
                            onChangeEnd: (s) async {
                              await _c.seekTo(
                                Duration(milliseconds: (s * 1000).round()),
                              );
                              if (mounted) setState(() => _arrastre = null);
                              _mostrar();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: v.isPlaying ? 'Pausar (K)' : 'Reproducir (K)',
                        icon: Icon(
                          v.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        onPressed: _alternar,
                      ),
                      IconButton(
                        tooltip: v.volume == 0
                            ? 'Activar el sonido (M)'
                            : 'Silenciar (M)',
                        icon: Icon(
                          v.volume == 0
                              ? Icons.volume_off_rounded
                              : v.volume < 0.5
                              ? Icons.volume_down_rounded
                              : Icons.volume_up_rounded,
                        ),
                        onPressed: _silenciar,
                      ),
                      if (ancho)
                        SizedBox(
                          width: 92,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: const Color(0x40FFFFFF),
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
                            ),
                            child: MergeSemantics(
                              child: Semantics(
                                label: 'Volumen',
                                child: Slider(
                                  value: v.volume.clamp(0.0, 1.0),
                                  semanticFormatterCallback: (s) =>
                                      '${(s * 100).round()} %',
                                  onChanged: _volumen,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Semantics(
                          container: true,
                          label:
                              'Minuto ${formatVideoTime(Duration(milliseconds: (posSeg * 1000).round()))}'
                              ' de ${formatVideoTime(total)}',
                          excludeSemantics: true,
                          child: Text(
                            '${formatVideoTime(Duration(milliseconds: (posSeg * 1000).round()))}'
                            ' / ${formatVideoTime(total)}',
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<double>(
                        tooltip: 'Velocidad de reproducción',
                        initialValue: v.playbackSpeed,
                        onSelected: (s) async {
                          await _c.setPlaybackSpeed(s);
                          _mostrar();
                        },
                        itemBuilder: (_) => [
                          for (final s in videoSpeeds)
                            PopupMenuItem(
                              value: s,
                              child: Text(
                                s == 1 ? 'Normal (1×)' : speedLabel(s),
                              ),
                            ),
                        ],
                        // Con un hijo propio, el menú queda como algo tocable
                        // sin rol: el lector de pantalla no lo anunciaría como
                        // botón ni diría la velocidad actual.
                        child: Semantics(
                          container: true,
                          button: true,
                          label:
                              'Velocidad de reproducción: '
                              '${speedLabel(v.playbackSpeed)}',
                          excludeSemantics: true,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            child: Text(
                              speedLabel(v.playbackSpeed),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: widget.isFullscreen
                            ? 'Salir de pantalla completa (F)'
                            : 'Pantalla completa (F)',
                        icon: Icon(
                          widget.isFullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                        ),
                        onPressed: widget.onToggleFullscreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// El botón grande del centro, con el ámbar de la marca.
class _BotonGrande extends StatelessWidget {
  final VoidCallback onPressed;
  const _BotonGrande({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      child: Material(
        color: AppColors.gold,
        shape: const CircleBorder(),
        elevation: 6,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.all(14),
            // Tinta oscura sobre el ámbar: blanco ahí da 1.6:1.
            child: Icon(
              Icons.play_arrow_rounded,
              size: 40,
              color: AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
