import 'dart:io';

import 'package:video_player/video_player.dart';

import '../utils/constants.dart';

/// Escritorio/móvil: reproduce el archivo local de `course_resources/`.
Future<VideoPlayerController?> createCourseVideoController(
    String resourcePath) async {
  final file = File('$courseResourcesPath/$resourcePath');
  if (!file.existsSync() || file.lengthSync() == 0) return null;
  final controller = VideoPlayerController.file(file);
  await controller.initialize();
  return controller;
}
