/// Un guardado del avance de un video: dónde retomar y el tramo que se
/// reprodujo desde el guardado anterior.
///
/// [watchedFromSec] → [watchedToSec] es lo que de verdad se vio. Es lo que
/// cuenta el servidor para completar la lección (el 90% del video); la
/// posición solo dice dónde retomar.
class VideoSave {
  final int positionSec;
  final int? durationSec;
  final int watchedFromSec;
  final int watchedToSec;

  const VideoSave({
    required this.positionSec,
    required this.durationSec,
    required this.watchedFromSec,
    required this.watchedToSec,
  });

  @override
  bool operator ==(Object other) =>
      other is VideoSave &&
      other.positionSec == positionSec &&
      other.durationSec == durationSec &&
      other.watchedFromSec == watchedFromSec &&
      other.watchedToSec == watchedToSec;

  @override
  int get hashCode =>
      Object.hash(positionSec, durationSec, watchedFromSec, watchedToSec);

  @override
  String toString() =>
      'VideoSave($positionSec/$durationSec, visto $watchedFromSec→$watchedToSec)';
}

/// Cuándo guardar el avance de un video, y qué tramo se vio de verdad.
///
/// Vive aparte del reproductor porque es la parte con casos raros —adelantar,
/// volver atrás, terminar, cerrar a la mitad— y así se prueba sin montar un
/// reproductor de YouTube, que en `flutter test` no existe.
///
/// Reglas:
///
/// - **Al arrancar**, un guardado sin tramo: es el punto de partida contra el
///   que el servidor mide el tiempo real de lo que venga después.
/// - **Cada [saveEvery]** de reproducción, al pausar, al terminar y al cerrar,
///   se guarda la posición y el tramo reproducido desde el guardado anterior.
/// - **Un salto** —adelantar o volver atrás— cierra el tramo donde estaba y
///   abre uno nuevo donde cae. Lo saltado nunca entra en un tramo: por eso
///   adelantar hasta el final no completa la lección.
///
/// Completar no lo decide esto, sino el servidor, con los tramos que recibe
/// (`services/video-progress.ts`).
class VideoWatchTracker {
  VideoWatchTracker({
    required this.onSave,
    this.saveEvery = const Duration(seconds: 15),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final void Function(VideoSave save) onSave;
  final Duration saveEvery;
  final DateTime Function() _now;

  /// Lo más rápido que avanza la reproducción (2× en YouTube), con margen
  /// por los segundos redondeados. Más que eso entre dos avisos es un salto.
  static const _velocidadMaxima = 2.5;
  static const _margenSec = 2;

  /// El reproductor avisa una vez por segundo. Un silencio más largo es una
  /// pausa (o una pestaña en segundo plano), no reproducción: no puede
  /// justificar un avance grande, que entonces es un salto.
  static const _silencioMaximo = Duration(seconds: 5);

  int? _position;
  int? _duration;
  DateTime? _lastReport;
  DateTime? _lastSave;

  /// Dónde empezó el tramo que se está reproduciendo.
  int? _segmentStart;
  VideoSave? _lastSaved;

  /// Lo que informa el reproductor mientras reproduce.
  void position(Duration position, {Duration? duration}) {
    _learnDuration(duration);
    final seconds = _clamp(position.inSeconds);
    final now = _now();

    final previous = _position;
    if (previous == null) {
      // La primera posición: el punto de partida, guardado en el acto.
      _position = seconds;
      _segmentStart = seconds;
      _lastReport = now;
      _save();
      return;
    }

    if (_isJump(previous, seconds, now)) {
      // Lo reproducido hasta el salto se guarda; lo saltado, no.
      _save();
      _position = seconds;
      _segmentStart = seconds;
      _lastReport = now;
      return;
    }

    _position = seconds;
    _lastReport = now;
    final last = _lastSave;
    if (last == null || now.difference(last) >= saveEvery) _save();
  }

  /// La duración apenas se sabe, aunque todavía no haya posición.
  void duration(Duration duration) => _learnDuration(duration);

  void paused() => _save();

  /// Terminó: se guarda hasta el final, si de verdad venía reproduciendo
  /// hasta ahí. Si el aviso llega justo después de un salto al final, lo
  /// saltado no se cuenta.
  void ended() {
    final total = _duration;
    if (total != null) position(Duration(seconds: total));
    _save();
  }

  /// Se cerró el reproductor. Lo que quedó sin guardar, se guarda ahora.
  void close() => _save();

  bool _isJump(int previous, int seconds, DateTime now) {
    if (seconds < previous - _margenSec) return true;
    final last = _lastReport;
    var elapsed = last == null ? Duration.zero : now.difference(last);
    if (elapsed > _silencioMaximo) elapsed = _silencioMaximo;
    return seconds >
        previous + elapsed.inMilliseconds / 1000 * _velocidadMaxima + _margenSec;
  }

  int _clamp(int seconds) {
    final total = _duration;
    return total != null && seconds > total ? total : seconds;
  }

  void _learnDuration(Duration? duration) {
    if (duration == null) return;
    // Redondeada: YouTube informa 212.061 y eso son 212 segundos, no 213.
    final seconds = (duration.inMilliseconds / 1000).round();
    // Un directo informa 0: no hay final contra el cual medir.
    if (seconds > 0) _duration = seconds;
  }

  /// Guarda la posición y el tramo abierto, salvo que no haya nada nuevo
  /// (pausar dos veces, o cerrar justo después de guardar, no escriben).
  void _save() {
    final position = _position;
    final start = _segmentStart;
    if (position == null || start == null) return;
    final anterior = _lastSaved;
    if (start == position &&
        anterior != null &&
        anterior.positionSec == position &&
        anterior.durationSec == _duration) {
      return;
    }
    final save = VideoSave(
      positionSec: position,
      durationSec: _duration,
      watchedFromSec: start,
      watchedToSec: position,
    );
    _lastSaved = save;
    _lastSave = _now();
    _segmentStart = position;
    onSave(save);
  }
}
