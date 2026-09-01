import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/widgets/video_player_dialog.dart';

import 'helpers/fake_api.dart';

/// El reproductor de video: conversión de enlaces y estados de la pantalla.
///
/// Se prueba en dos niveles porque fallan por razones distintas:
///
/// 1. **[embedUrlFor]** es lógica pura con muchos casos raros, y es la que se
///    rompe EN SILENCIO: un iframe con una URL que YouTube no deja embeber no
///    lanza ningún error, solo queda un recuadro gris. Por eso se prueba
///    exhaustivamente acá y no a ojo en el navegador.
///
/// 2. **Los estados del diálogo** (cargando / error / vacío) se prueban con la
///    API falsa. La reproducción en sí NO: `video_player` necesita el plugin de
///    la plataforma, que en `flutter test` no existe, y montar un doble del
///    reproductor probaría el doble. Que el `<video>` y el `<iframe>` pinten se
///    comprueba en el navegador — está anotado como tal en MIGRACION_FRONT.md,
///    no dado por hecho.

Lesson _leccion({
  VideoSourceType? videoType,
  String? videoUrl,
  String? videoS3Key,
}) =>
    Lesson(
      id: 'lec-1',
      title: 'Lección de prueba',
      type: LessonType.video,
      orderIndex: 1,
      videoType: videoType,
      videoUrl: videoUrl,
      videoS3Key: videoS3Key,
    );

Widget _app(Lesson lesson, FakeApi fake) {
  final api = fake.build();
  final data = DataProvider(api);
  return MultiProvider(
    providers: [ChangeNotifierProvider.value(value: data)],
    child: MaterialApp(
      home: Scaffold(body: VideoPlayerDialog(lesson: lesson)),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('embedUrlFor — YouTube', () {
    const esperado = 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ';

    for (final entrada in [
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      'https://youtube.com/watch?v=dQw4w9WgXcQ',
      'https://m.youtube.com/watch?v=dQw4w9WgXcQ',
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s',
      'https://youtu.be/dQw4w9WgXcQ',
      'https://youtu.be/dQw4w9WgXcQ?si=abc123',
      'https://www.youtube.com/embed/dQw4w9WgXcQ',
      'https://www.youtube.com/shorts/dQw4w9WgXcQ',
      '  https://www.youtube.com/watch?v=dQw4w9WgXcQ  ',
    ]) {
      test('reconoce $entrada', () {
        expect(embedUrlFor(entrada), esperado);
      });
    }

    test('usa el dominio sin cookies', () {
      // No deja cookies de seguimiento hasta que alguien da play, que es lo
      // correcto para una plataforma educativa.
      expect(embedUrlFor('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
          contains('youtube-nocookie.com'));
    });
  });

  group('embedUrlFor — Vimeo', () {
    for (final entrada in [
      'https://vimeo.com/123456789',
      'https://player.vimeo.com/video/123456789',
      'https://vimeo.com/channels/staffpicks/123456789',
    ]) {
      test('reconoce $entrada', () {
        expect(embedUrlFor(entrada), 'https://player.vimeo.com/video/123456789');
      });
    }
  });

  group('embedUrlFor — lo que NO se embebe', () {
    for (final entrada in [
      '',
      'no es una url',
      'https://ejemplo.com/video.mp4',
      'https://www.youtube.com/', // sin id
      'https://vimeo.com/canal-sin-numero',
      'ftp://youtube.com/watch?v=abc',
    ]) {
      test('devuelve null para "$entrada"', () {
        expect(embedUrlFor(entrada), isNull);
      });
    }

    test('un enlace desconocido NO se intenta embeber a ciegas', () {
      // La mayoría de los sitios responden `X-Frame-Options` y el recuadro
      // queda en blanco sin decir por qué. Es mejor ofrecer abrirlo afuera.
      expect(embedUrlFor('https://drive.google.com/file/d/abc/view'), isNull);
    });
  });

  group('el diálogo', () {
    testWidgets('una lección sin video lo dice, no se queda en blanco',
        (tester) async {
      await tester.pumpWidget(_app(_leccion(), FakeApi()));
      await tester.pump();
      expect(find.textContaining('todavía no tiene video'), findsOneWidget);
    });

    testWidgets('un enlace externo no embebible ofrece abrirlo afuera',
        (tester) async {
      await tester.pumpWidget(_app(
        _leccion(
          videoType: VideoSourceType.external,
          videoUrl: 'https://ejemplo.com/charla',
        ),
        FakeApi(),
      ));
      await tester.pump();
      expect(find.text('Abrir video'), findsOneWidget);
    });

    testWidgets('el video propio muestra un estado de carga mientras pide la URL',
        (tester) async {
      final fake = FakeApi(
        routes: {
          '/lessons/lec-1/video-url': {
            'url': 'https://videos.enactus.co/x.mp4?Signature=abc',
            'expiresInSeconds': 300,
          },
        },
        delay: const Duration(milliseconds: 300),
      );
      await tester.pumpWidget(_app(
        _leccion(videoType: VideoSourceType.uploaded, videoS3Key: 'lessons/1/a.mp4'),
        fake,
      ));
      await tester.pump();
      expect(find.textContaining('Preparando el video'), findsOneWidget);

      // Se deja terminar la petición para no dejar temporizadores vivos.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    });

    testWidgets('pide la URL al endpoint de CloudFront, no a /files/download-url',
        (tester) async {
      // El servidor rechaza con 400 cualquier key de video en
      // `/files/download-url`: si el cliente la pidiera por ahí, el video no
      // se vería nunca y el error diría "solicitud inválida".
      final fake = FakeApi(routes: {
        '/lessons/lec-1/video-url': {
          'url': 'https://videos.enactus.co/x.mp4?Signature=abc',
          'expiresInSeconds': 300,
        },
      });
      await tester.pumpWidget(_app(
        _leccion(videoType: VideoSourceType.uploaded, videoS3Key: 'lessons/1/a.mp4'),
        fake,
      ));
      await tester.pump();
      await tester.pump();

      expect(fake.requested, contains('GET /lessons/lec-1/video-url'));
      expect(
        fake.requested.where((r) => r.contains('download-url')),
        isEmpty,
      );
    });

    testWidgets('si la API falla, se ve el error con botón de reintentar',
        (tester) async {
      final fake = FakeApi(notFound: {'/lessons/lec-1/video-url'});
      await tester.pumpWidget(_app(
        _leccion(videoType: VideoSourceType.uploaded, videoS3Key: 'lessons/1/a.mp4'),
        fake,
      ));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('No pudimos preparar el video'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('sin CloudFront configurado se explica, sin ofrecer reintentar',
        (tester) async {
      // Reintentar un 503 de configuración no arregla nada: ofrecerlo sería
      // mandar a la persona a apretar un botón que no puede funcionar.
      final fake = FakeApi(
        routes: {
          '/lessons/lec-1/video-url': {
            'error': {
              'code': 'cdn_not_configured',
              'message': 'La reproducción de video no está configurada en este '
                  'entorno (falta CLOUDFRONT_DOMAIN).',
            },
          },
        },
        statuses: {'/lessons/lec-1/video-url': 503},
      );
      await tester.pumpWidget(_app(
        _leccion(videoType: VideoSourceType.uploaded, videoS3Key: 'lessons/1/a.mp4'),
        fake,
      ));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('no disponible en este entorno'), findsOneWidget);
      expect(find.textContaining('CLOUDFRONT_DOMAIN'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });
  });
}
