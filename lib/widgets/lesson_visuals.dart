import 'package:flutter/material.dart';

import '../models/models.dart';

/// Ícono y etiqueta de cada tipo de lección.
///
/// Vivían dentro del editor de lecciones del LXD, así que el portal Estudiante
/// tenía que importar una herramienta de autoría entera solo para pintar un
/// ícono. Acá quedan donde corresponde: son presentación, no edición.

IconData lessonTypeIcon(LessonType t) => switch (t) {
      LessonType.video => Icons.play_circle_outline,
      LessonType.pdf => Icons.picture_as_pdf_outlined,
      LessonType.resource => Icons.attach_file,
      LessonType.link => Icons.link,
      LessonType.quiz => Icons.quiz_outlined,
      LessonType.activity => Icons.assignment_outlined,
      LessonType.survey => Icons.poll_outlined,
    };

String lessonTypeLabel(LessonType t) => switch (t) {
      LessonType.video => 'Video',
      LessonType.pdf => 'PDF',
      LessonType.resource => 'Recurso',
      LessonType.link => 'Enlace',
      LessonType.quiz => 'Quiz',
      LessonType.activity => 'Actividad',
      LessonType.survey => 'Encuesta',
    };
