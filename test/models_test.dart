// Prueba mínima de humo: los modelos serializan y deserializan sin pérdida.
import 'package:flutter_test/flutter_test.dart';

import 'package:enactus_platform/models/models.dart';

void main() {
  test('AppUser serializa y deserializa', () {
    final user = AppUser(
      id: 'u1',
      name: 'Test',
      email: 't@t.co',
      password: 'x',
      role: 'student',
      extra: {'university': 'U', 'courseIds': ['c1']},
    );
    final restored = AppUser.fromJson(user.toJson());
    expect(restored.name, 'Test');
    expect(restored.university, 'U');
    expect(restored.courseIds, ['c1']);
  });

  test('Course con módulos y lecciones serializa', () {
    final course = Course(
      id: 'c1',
      name: 'Curso',
      modules: [
        CourseModule(id: 'm1', title: 'M1', lessons: [
          Lesson(id: 'l1', title: 'L1', resourcePath: 'a/b.mp4'),
        ]),
      ],
    );
    final restored = Course.fromJson(course.toJson());
    expect(restored.lessonCount, 1);
    expect(restored.modules.first.lessons.first.resourcePath, 'a/b.mp4');
  });
}
