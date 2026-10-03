import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_service.dart';
import 'package:enactus_platform/views/student/course_detail_view.dart';

import 'helpers/fake_api.dart';

/// La lista de lecciones muestra hasta dónde vio cada video.
///
/// Guardar la posición sirve si la persona se entera: «Seguir desde 2:05»
/// le dice que puede retomar, y la barrita le muestra cuánto le falta — sin
/// abrir el video.

const _ana = {
  'id': 'student1',
  'name': 'Ana Estudiante',
  'email': 'ana@test.co',
  'role': 'student',
  'studentType': 'enactus',
};

const _curso = {
  'id': 'course1',
  'name': 'Curso Test',
  'description': 'Un curso de prueba',
  'level': 'basic',
  'status': 'published',
  'language': 'es',
  'tags': <String>[],
  'objectives': <Object>[],
  'modules': [
    {
      'id': 'm1',
      'title': 'Módulo 1',
      'lessons': [
        {
          'id': 'ly1',
          'title': 'Charla de apertura',
          'type': 'video',
          'durationMin': 4,
          'videoType': 'youtube',
          'videoYoutubeId': 'dQw4w9WgXcQ',
        },
        {
          'id': 'ly2',
          'title': 'Segunda charla',
          'type': 'video',
          'videoType': 'youtube',
          'videoYoutubeId': 'a-b_c-d_e-f',
        },
        {'id': 'lp1', 'title': 'Lectura', 'type': 'pdf'},
      ],
    },
  ],
};

Map<String, Object?> _page(List<Object> data) =>
    {'data': data, 'page': 1, 'pageSize': 100, 'total': data.length};

Widget _wrap(Widget child, FakeApi fake) {
  final api = fake.build();
  final data = DataProvider(api)..setCurrentUser('student1');
  final auth = AuthProvider(api, data);
  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: api),
      ChangeNotifierProvider.value(value: data),
      ChangeNotifierProvider.value(value: auth),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  setUp(useFakeTokenStorage);

  testWidgets('cada video dice desde dónde seguir y cuánto se vio',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 2000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(
      const CourseDetailView(courseId: 'course1'),
      FakeApi(routes: {
        '/auth/me': _ana,
        '/courses/course1': _curso,
        '/students/student1/course-progress/course1': {
          'courseId': 'course1',
          'totalLessons': 3,
          'completedLessons': 1,
          'ratio': 0.3333,
          'completedLessonIds': ['ly2'],
          'videoProgress': [
            {'lessonId': 'ly1', 'positionSec': 125, 'furthestSec': 150, 'durationSec': 212},
            {'lessonId': 'ly2', 'positionSec': 212, 'furthestSec': 212, 'durationSec': 212},
          ],
        },
        '/submissions': _page([]),
        '/notifications': _page([]),
      }),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // A medias: se ofrece seguir, y la barrita muestra lo visto (150/212).
    expect(find.text('Video de YouTube · 4 min · Seguir desde 2:05'), findsOneWidget);
    final barras = tester
        .widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .where((b) => b.minHeight == 3);
    expect(barras.single.value, closeTo(150 / 212, 0.001));

    // Terminada: no se ofrece "seguir" un video ya visto.
    expect(find.text('Video de YouTube · Visto 100%'), findsOneWidget);
    // Lo que no es video, como siempre.
    expect(find.text('PDF'), findsOneWidget);
  });
}
