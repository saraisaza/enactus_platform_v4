import 'package:video_player/video_player.dart';

/// Web: el servidor de desarrollo de Flutter sirve `web/course_resources/`
/// como rutas relativas. Al migrar a AWS, esta URL pasa a ser la de S3
/// (basta con cambiar el prefijo).
Future<VideoPlayerController?> createCourseVideoController(
    String resourcePath) async {
  final controller =
      VideoPlayerController.networkUrl(Uri.parse('course_resources/$resourcePath'));
  await controller.initialize();
  return controller;
}
