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
        'updatedAt': '2026-10-03T06:30:00.000Z',
      });
      expect(p.positionSec, 125);
      expect(p.watchedRatio, closeTo(0.95, 0.001));
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
    late List<(int, int?)> guardados;
    late int vistos;
    late VideoWatchTracker tracker;

    setUp(() {
      ahora = DateTime(2026, 10, 3, 10);
      guardados = [];
      vistos = 0;
      tracker = VideoWatchTracker(
        onSave: (p, d) => guardados.add((p, d)),
        onWatched: () => vistos++,
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

    test('guarda cada 15 segundos de reproducción, no cada evento', () {
      reproducirHasta(0, 31);
      expect(guardados, [(15, 212), (30, 212)]);
    });

    test('abrir y cerrar enseguida guarda una sola vez, al cerrar', () {
      reproducirHasta(0, 4);
      expect(guardados, isEmpty);
      tracker.close();
      expect(guardados, [(4, 212)]);
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
      expect(guardados, [(7, 212)]);
    });

    test('pasar el 90% avisa UNA vez, aunque después termine', () {
      reproducirHasta(0, 190);
      expect(vistos, 0); // 190 / 212 = 89.6%
      reproducirHasta(191, 195);
      expect(vistos, 1);
      tracker.ended();
      expect(vistos, 1);
      expect(tracker.watched, isTrue);
    });

    test('terminar cuenta como visto y guarda el final', () {
      reproducirHasta(0, 10);
      tracker.ended();
      expect(vistos, 1);
      expect(guardados.last, (212, 212));
    });

    test('volver atrás después de verlo no avisa de nuevo', () {
      reproducirHasta(0, 200);
      reproducirHasta(0, 200);
      expect(vistos, 1);
    });

    test('la duración se redondea: 212.061 s son 212', () {
      reproducirHasta(0, 0);
      tracker.close();
      expect(guardados.single.$2, 212);
    });

    test('un directo (duración 0) guarda posición, pero nunca "visto"', () {
      reproducirHasta(0, 600, duracion: 0);
      tracker.close();
      expect(guardados.every((g) => g.$2 == null), isTrue);
      expect(vistos, 0);
    });

    test('una posición más allá del final se recorta', () {
      tracker.position(const Duration(seconds: 215),
          duration: const Duration(seconds: 212));
      tracker.close();
      expect(guardados.single, (212, 212));
    });
  });
}
