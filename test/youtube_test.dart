import 'package:flutter_test/flutter_test.dart';

import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/models/progress.dart';
import 'package:enactus_platform/utils/video_watch_tracker.dart';
import 'package:enactus_platform/utils/youtube.dart';

/// Lo que se guarda de un video de YouTube es el id, y nada más.
///
/// El enlace que pega el LXD viene en una docena de formas —con o sin
/// `https://`, de la app del teléfono con `?si=`, de un `short`, de un
/// `embed` copiado de otra página— y todas tienen que dar el mismo id. Y al
/// revés: un enlace que NO es de un video tiene que rechazarse, no "más o
/// menos aceptarse", porque guardaría un video equivocado sin que nadie se
/// entere hasta que una estudiante lo abra.

const id = 'dQw4w9WgXcQ';

void main() {
  group('youtubeVideoIdFrom — las formas que la gente pega', () {
    for (final entrada in [
      id,
      'https://www.youtube.com/watch?v=$id',
      'https://youtube.com/watch?v=$id',
      'http://www.youtube.com/watch?v=$id',
      'https://m.youtube.com/watch?v=$id',
      'https://music.youtube.com/watch?v=$id',
      'https://www.youtube.com/watch?v=$id&t=42s',
      'https://www.youtube.com/watch?app=desktop&v=$id&list=PL123',
      'https://youtu.be/$id',
      'https://youtu.be/$id?si=AbCdEf123_xyz&t=10',
      'youtu.be/$id',
      'www.youtube.com/watch?v=$id',
      'youtube.com/watch?v=$id',
      'https://www.youtube.com/embed/$id',
      'https://www.youtube.com/embed/$id?start=30&rel=0',
      'https://www.youtube-nocookie.com/embed/$id',
      'https://www.youtube.com/shorts/$id',
      'https://youtube.com/shorts/$id?feature=share',
      'https://www.youtube.com/live/$id',
      'https://www.youtube.com/v/$id',
      '  https://www.youtube.com/watch?v=$id  ',
      'HTTPS://WWW.YOUTUBE.COM/watch?v=$id',
    ]) {
      test('"$entrada"', () => expect(youtubeVideoIdFrom(entrada), id));
    }

    test('ids con guion y guion bajo, que también son válidos', () {
      expect(youtubeVideoIdFrom('https://youtu.be/a-b_c-d_e-f'), 'a-b_c-d_e-f');
    });
  });

  group('youtubeVideoIdFrom — lo que NO es un video de YouTube', () {
    for (final entrada in [
      '',
      '   ',
      'no es un enlace',
      'dQw4w9WgXc', // 10 caracteres
      'dQw4w9WgXcQQ', // 12
      'https://www.youtube.com/watch?v=dQw4w9WgXc',
      'https://www.youtube.com/watch?v=dQw4w9WgXcQQ',
      'https://youtu.be/dQw4w9WgXcQQ',
      'https://www.youtube.com/watch?v=dQw4w9WgX%21Q',
      'https://www.youtube.com/',
      'https://www.youtube.com/@canalEducativo',
      'https://www.youtube.com/playlist?list=PL590L5WQmH8fJ54F369BLDSqIwcs-TCfs',
      'https://www.youtube.com/channel/UC1234567890',
      'https://notyoutube.com/watch?v=$id',
      'https://youtube.com.otro-sitio.example/watch?v=$id',
      'https://otro-sitio.example/?u=https://youtu.be/$id',
      'ftp://youtube.com/watch?v=$id',
      'https://vimeo.com/76979871',
      'https://www.youtube.com/watch?v=$id con texto',
    ]) {
      test('"$entrada" -> null', () => expect(youtubeVideoIdFrom(entrada), isNull));
    }
  });

  group('VideoLink — lo que ve el LXD en el campo', () {
    test('vacío se puede guardar: la lección queda sin video', () {
      final link = VideoLink.parse('  ');
      expect(link.kind, VideoLinkKind.empty);
      expect(link.isValid, isTrue);
      expect(link.problem, isNull);
    });

    test('un enlace de YouTube da el id, y solo el id', () {
      final link = VideoLink.parse('https://youtu.be/$id?si=rastreo');
      expect(link.kind, VideoLinkKind.youtube);
      expect(link.youtubeId, id);
      expect(link.url, isNull);
      expect(link.problem, isNull);
    });

    test('Vimeo se sigue aceptando, como enlace', () {
      final link = VideoLink.parse(' https://vimeo.com/76979871 ');
      expect(link.kind, VideoLinkKind.vimeo);
      expect(link.url, 'https://vimeo.com/76979871');
    });

    test('un canal o una lista de YouTube se rechazan diciendo qué son', () {
      for (final entrada in [
        'https://www.youtube.com/@canalEducativo',
        'https://www.youtube.com/playlist?list=PL123',
      ]) {
        final link = VideoLink.parse(entrada);
        expect(link.kind, VideoLinkKind.youtubeNotVideo);
        expect(link.isValid, isFalse);
        expect(link.problem, contains('no de un video'));
      }
    });

    test('cualquier otra cosa se rechaza con un ejemplo de lo que sí sirve', () {
      final link = VideoLink.parse('https://drive.google.com/file/d/abc/view');
      expect(link.kind, VideoLinkKind.unsupported);
      expect(link.problem, contains('youtube.com/watch?v='));
    });

    test('el enlace canónico vuelve a dar el mismo id', () {
      expect(youtubeVideoIdFrom(youtubeWatchUrl(id)), id);
    });

    test('la miniatura sale de i.ytimg.com, el único dominio para la CSP', () {
      expect(youtubeThumbnailUrl(id),
          'https://i.ytimg.com/vi/$id/hqdefault.jpg');
    });
  });

  group('Lesson.youtubeVideoId', () {
    test('una lección `youtube` reproduce su id', () {
      final lesson = Lesson.fromJson({
        'id': 'l1',
        'title': 'Video',
        'type': 'video',
        'videoType': 'youtube',
        'videoYoutubeId': id,
      });
      expect(lesson.videoType, VideoSourceType.youtube);
      expect(lesson.youtubeVideoId, id);
    });

    test('una lección vieja con el ENLACE de YouTube también tiene id', () {
      // Se guardaron como `external` antes de que existiera `youtube`, y la
      // base no se migró: el id se saca del enlace al reproducir.
      final lesson = Lesson.fromJson({
        'id': 'l1',
        'title': 'Video',
        'type': 'video',
        'videoType': 'external',
        'videoUrl': 'https://www.youtube.com/watch?v=$id&t=5s',
      });
      expect(lesson.youtubeVideoId, id);
    });

    test('Vimeo, un video propio o ningún video no tienen id de YouTube', () {
      for (final json in [
        {'videoType': 'external', 'videoUrl': 'https://vimeo.com/76979871'},
        {'videoType': 'uploaded', 'videoS3Key': 'lessons/x/v.mp4'},
        <String, Object>{},
      ]) {
        final lesson =
            Lesson.fromJson({'id': 'l1', 'title': 'V', 'type': 'video', ...json});
        expect(lesson.youtubeVideoId, isNull, reason: '$json');
      }
    });
  });

  group('VideoProgress', () {
    test('se lee como lo devuelve la API', () {
      final p = VideoProgress.fromJson({
        'lessonId': 'l1',
        'positionSec': 125,
        'furthestSec': 190,
        'durationSec': 200,
        'watchedSec': 150,
        'updatedAt': '2026-10-03T06:30:00.000Z',
      });
      expect(p.positionSec, 125);
      // «Visto» es lo reproducido de verdad, no hasta dónde se adelantó.
      expect(p.watchedRatio, closeTo(0.75, 0.001));
      expect(p.resumeAt, const Duration(seconds: 125));
    });

    test('no retoma en los primeros segundos ni sobre el final', () {
      VideoProgress at(int s) =>
          VideoProgress(lessonId: 'l', positionSec: s, furthestSec: s, durationSec: 600);
      expect(at(3).resumeAt, isNull); // volver al segundo 3 es empezar
      expect(at(30).resumeAt, const Duration(seconds: 30));
      expect(at(575).resumeAt, isNull); // pasado el 95%: terminado
      expect(at(595).resumeAt, isNull); // últimos 10 segundos
    });

    test('sin duración no hay porcentaje, pero sí desde dónde retomar', () {
      const p = VideoProgress(lessonId: 'l', positionSec: 40, furthestSec: 40);
      expect(p.watchedRatio, isNull);
      expect(p.resumeAt, const Duration(seconds: 40));
    });

    test('avanzar copia la regla del servidor: lo visto nunca baja', () {
      const p = VideoProgress(
          lessonId: 'l', positionSec: 100, furthestSec: 150, durationSec: 200);
      final atras = p.advancedTo(20);
      expect(atras.positionSec, 20);
      expect(atras.furthestSec, 150);
      expect(atras.durationSec, 200); // una duración nula no borra la conocida
      expect(p.advancedTo(250).positionSec, 200); // se recorta al final
    });

    test('el progreso del curso trae la posición de cada video', () {
      final progress = CourseProgress.fromJson({
        'courseId': 'c1',
        'completedLessonIds': ['l2'],
        'videoProgress': [
          {'lessonId': 'l1', 'positionSec': 30, 'furthestSec': 60, 'durationSec': 120},
        ],
      });
      expect(progress.videoProgressFor('l1')?.furthestSec, 60);
      expect(progress.videoProgressFor('l2'), isNull);
    });

    test('un servidor viejo sin `videoProgress` no rompe nada', () {
      final progress = CourseProgress.fromJson({'courseId': 'c1'});
      expect(progress.videoProgress, isEmpty);
    });

    test('la lectura propia de la Ruta trae id y posición', () {
      final own = OwnLesson.fromJson({
        'id': 'o1',
        'title': 'Charla',
        'type': 'video',
        'videoType': 'youtube',
        'videoYoutubeId': id,
        'videoProgress': {'positionSec': 75, 'furthestSec': 75, 'durationSec': 212},
      });
      expect(own.videoProgress?.lessonId, 'o1');
      expect(own.videoProgress?.positionSec, 75);
      // Al abrirla se convierte en `Lesson`: el id no se puede perder ahí.
      expect(own.toLesson().youtubeVideoId, id);
    });
  });

  group('VideoWatchTracker', () {
    late DateTime ahora;
    late List<VideoSave> guardados;
    late VideoWatchTracker tracker;

    setUp(() {
      ahora = DateTime(2026, 10, 3, 10);
      guardados = [];
      tracker = VideoWatchTracker(
        onSave: guardados.add,
        now: () => ahora,
      );
    });

    void reproducirHasta(int desde, int hasta, {double duracion = 212.061}) {
      for (var s = desde; s <= hasta; s++) {
        tracker.position(Duration(seconds: s),
            duration: Duration(milliseconds: (duracion * 1000).round()));
        ahora = ahora.add(const Duration(seconds: 1));
      }
    }

    /// Un salto: el reproductor informa, un segundo después, otra posición.
    void saltarA(int segundo) {
      tracker.position(Duration(seconds: segundo),
          duration: const Duration(milliseconds: 212061));
      ahora = ahora.add(const Duration(seconds: 1));
    }

    VideoSave g(int posicion, int desde, int hasta, [int? duracion = 212]) =>
        VideoSave(
            positionSec: posicion,
            durationSec: duracion,
            watchedFromSec: desde,
            watchedToSec: hasta);

    int visto() => guardados.fold(
        0, (total, x) => total + (x.watchedToSec - x.watchedFromSec));

    test('al arrancar guarda el punto de partida, sin tramo', () {
      reproducirHasta(0, 0);
      expect(guardados, [g(0, 0, 0)]);
    });

    test('guarda cada 15 segundos de reproducción, con el tramo visto', () {
      reproducirHasta(0, 31);
      expect(guardados, [g(0, 0, 0), g(15, 0, 15), g(30, 15, 30)]);
    });

    test('abrir y cerrar enseguida: el punto de partida y el cierre', () {
      reproducirHasta(0, 4);
      tracker.close();
      expect(guardados, [g(0, 0, 0), g(4, 0, 4)]);
    });

    test('cerrar sin haber reproducido no escribe nada', () {
      tracker.close();
      expect(guardados, isEmpty);
    });

    test('pausar guarda en el acto, y pausar otra vez no repite', () {
      reproducirHasta(0, 7);
      tracker.paused();
      tracker.paused();
      tracker.close();
      expect(guardados, [g(0, 0, 0), g(7, 0, 7)]);
    });

    test('adelantar no suma: el tramo se cierra donde estaba', () {
      reproducirHasta(0, 10);
      saltarA(200);
      reproducirHasta(201, 205);
      tracker.close();
      // Lo saltado (de 10 a 200) no está en ningún tramo.
      expect(guardados, [g(0, 0, 0), g(10, 0, 10), g(205, 200, 205)]);
      expect(visto(), 15);
    });

    test('saltar al final y terminar no cuenta el video entero', () {
      reproducirHasta(0, 5);
      saltarA(212);
      tracker.ended();
      expect(visto(), lessThan(10));
      expect(guardados.last.positionSec, 212);
    });

    test('verlo entero suma todo el video', () {
      reproducirHasta(0, 212);
      tracker.ended();
      expect(visto(), 212);
      expect(guardados.last, g(212, 210, 212));
    });

    test('volver atrás abre un tramo nuevo, y lo repetido se vuelve a mandar', () {
      reproducirHasta(0, 40);
      saltarA(10);
      reproducirHasta(11, 20);
      tracker.close();
      // El servidor une los tramos: lo visto dos veces cuenta una.
      expect(guardados.map((x) => (x.watchedFromSec, x.watchedToSec)),
          [(0, 0), (0, 15), (15, 30), (30, 40), (10, 20)]);
    });

    test('a doble velocidad no es un salto', () {
      for (var s = 0; s <= 30; s += 2) {
        tracker.position(Duration(seconds: s),
            duration: const Duration(seconds: 212));
        ahora = ahora.add(const Duration(seconds: 1));
      }
      tracker.close();
      expect(visto(), 30);
    });

    test('una pausa larga no deja pasar un salto como reproducción', () {
      reproducirHasta(0, 10);
      tracker.paused();
      ahora = ahora.add(const Duration(minutes: 3));
      saltarA(150);
      tracker.close();
      expect(visto(), 10);
    });

    test('terminar después de verlo guarda el final', () {
      reproducirHasta(0, 210);
      tracker.ended();
      expect(guardados.last.positionSec, 212);
      expect(guardados.last.watchedToSec, 212);
    });

    test('la duración se redondea: 212.061 s son 212', () {
      reproducirHasta(0, 0);
      tracker.close();
      expect(guardados.single.durationSec, 212);
    });

    test('un directo (duración 0) guarda posición sin duración', () {
      reproducirHasta(0, 600, duracion: 0);
      tracker.close();
      expect(guardados.every((x) => x.durationSec == null), isTrue);
    });

    test('una posición más allá del final se recorta', () {
      tracker.position(const Duration(seconds: 215),
          duration: const Duration(seconds: 212));
      tracker.close();
      expect(guardados.single, g(212, 212, 212));
    });
  });
}
