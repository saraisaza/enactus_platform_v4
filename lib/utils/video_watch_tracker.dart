/// Cuándo guardar hasta dónde va un video, y cuándo darlo por visto.
///
/// Vive aparte del reproductor porque es la parte con casos raros —adelantar,
/// volver atrás, terminar, cerrar a la mitad— y así se prueba sin montar un
/// reproductor de YouTube, que en `flutter test` no existe.
///
/// Reglas:
///
/// - **Guardar** cada [saveEvery] de reproducción, al pausar, al terminar y al
///   cerrar. Nunca dos veces la misma posición: el reproductor informa varias
///   veces por segundo y la API no necesita enterarse de cada una.
/// - **Visto** cuando la reproducción pasa por [watchedAt] de la duración
///   (90%: los créditos finales no cuentan) o cuando el video termina. Se
///   avisa UNA vez por sesión: lo que se hace con eso —completar la lección—
///   no es idempotente si llega dos veces seguidas.
///
/// Lo que NO decide es si la lección ya estaba completa: eso lo sabe quien la
/// completa (`DataProvider.toggleLessonIfPending`).
class VideoWatchTracker {
  VideoWatchTracker({
    required this.onSave,
    this.onWatched,
    this.saveEvery = const Duration(seconds: 15),
    this.watchedAt = 0.9,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Posición y duración en segundos enteros. La duración es `null` mientras
  /// el reproductor no la sabe.
  final void Function(int positionSec, int? durationSec) onSave;

  final void Function()? onWatched;
  final Duration saveEvery;
  final double watchedAt;
  final DateTime Function() _now;

  int? _position;
  int? _duration;
  int? _savedPosition;
  DateTime? _lastSave;
  bool _watched = false;

  /// Si ya se avisó [onWatched] en esta sesión.
  bool get watched => _watched;

  /// Lo que informa el reproductor mientras reproduce.
  void position(Duration position, {Duration? duration}) {
    _learnDuration(duration);
    final total = _duration;
    final seconds = position.inSeconds;
    _position = total != null && seconds > total ? total : seconds;

    if (total != null && position.inMilliseconds >= total * 1000 * watchedAt) {
      _markWatched();
    }

    // El reloj arranca con la primera posición, sin guardarla: abrir el video
    // y cerrarlo a los dos segundos no merece una escritura intermedia (la de
    // [close] alcanza).
    final now = _now();
    final last = _lastSave;
    if (last == null) {
      _lastSave = now;
    } else if (now.difference(last) >= saveEvery) {
      _save();
    }
  }

  /// La duración apenas se sabe, aunque todavía no haya posición.
  void duration(Duration duration) => _learnDuration(duration);

  void paused() => _save();

  /// Terminó: se guarda la posición final y cuenta como visto.
  void ended() {
    final total = _duration;
    if (total != null) _position = total;
    _markWatched();
    _save();
  }

  /// Se cerró el reproductor. Lo que quedó sin guardar, se guarda ahora.
  void close() => _save();

  void _learnDuration(Duration? duration) {
    if (duration == null) return;
    // Redondeada: YouTube informa 212.061 y eso son 212 segundos, no 213.
    final seconds = (duration.inMilliseconds / 1000).round();
    // Un directo informa 0: no hay final contra el cual medir.
    if (seconds > 0) _duration = seconds;
  }

  void _markWatched() {
    if (_watched) return;
    _watched = true;
    onWatched?.call();
  }

  void _save() {
    final position = _position;
    if (position == null || position == _savedPosition) return;
    _savedPosition = position;
    _lastSave = _now();
    onSave(position, _duration);
  }
}
