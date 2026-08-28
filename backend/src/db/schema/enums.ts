import { pgEnum } from 'drizzle-orm/pg-core';

/**
 * Enums del dominio.
 *
 * Regla de traducción: los nombres de código van en inglés (incluidos los
 * valores de enum, que son identificadores, no texto de interfaz). La etiqueta
 * en español la pone el cliente — igual que hoy hace `Roles.label()` en
 * `lib/utils/constants.dart`. Guardar 'Ideación' en la base ataría el dato al
 * idioma de la interfaz.
 */

/**
 * Los 9 roles. `lxd` y `mentor` son roles DISTINTOS que coexisten: la
 * migración histórica mentor→lxd fue una corrección de datos locales de Hive
 * (ver `lib/services/migration_service.dart`), no aplica acá.
 */
export const userRole = pgEnum('user_role', [
  'superadmin',
  'admin',
  'advisor',
  'donor',
  'lxd',
  'mentor',
  'company',
  'student',
  'alumni',
]);

/**
 * Define qué ve un estudiante: `enactus` ve Laboratorios y Ruta de Impacto;
 * `open_learning` solo los cursos que se le asignaron directamente, sin
 * laboratorios, fases ni Ruta (ver `DataProvider.studentHasCourse`).
 */
export const studentType = pgEnum('student_type', ['enactus', 'open_learning']);

/** Rol de una persona DENTRO del proyecto de su equipo (`group_members`). */
export const projectMemberRole = pgEnum('project_member_role', [
  'leader',
  'research',
  'finance',
  'communications',
  'design',
  'operations',
  'member',
]);

export const projectStage = pgEnum('project_stage', [
  'ideation',
  'validation',
  'prototype',
  'pilot',
  'scaling',
  'national_expo',
]);

/** Categoría de un objetivo, de fase o de curso. */
export const objectiveCategory = pgEnum('objective_category', [
  'entrepreneurship',
  'business',
]);

export const courseLevel = pgEnum('course_level', [
  'basic',
  'intermediate',
  'advanced',
]);

export const courseStatus = pgEnum('course_status', [
  'draft',
  'published',
  'archived',
]);

export const lessonType = pgEnum('lesson_type', [
  'video',
  'pdf',
  'resource',
  'link',
  'quiz',
  'activity',
  'survey',
]);

/**
 * Origen del video de una lección. `external` = enlace a YouTube/Vimeo;
 * `uploaded` = archivo propio en S3, servido SIEMPRE por CloudFront.
 */
export const videoType = pgEnum('video_type', ['external', 'uploaded']);

export const quizKind = pgEnum('quiz_kind', [
  'multiple',
  'truefalse',
  'short',
  'fill',
  'order',
]);

/**
 * Escala de calificación. Se guarda JUNTO a la nota (`submissions.grading_mode`)
 * porque hoy conviven cuatro escalas en el mismo campo `double? grade` de
 * Flutter y el número por sí solo no significa nada: 100 es "aprobado" en
 * passfail y "nota perfecta" en points100; `scale5` es el implícito de las
 * entregas libres, sin actividad asociada.
 */
export const gradingMode = pgEnum('grading_mode', [
  'points100',
  'passfail',
  'review',
  'scale5',
]);

export const calendarEventType = pgEnum('calendar_event_type', [
  'open_learning_sync',
  'ruta_impacto',
  'mentoria',
]);

export const forumCategory = pgEnum('forum_category', [
  'question',
  'progress',
  'resource',
  'announcement',
]);

export const evidenceType = pgEnum('evidence_type', [
  'photo',
  'video',
  'testimonial',
  'report',
  'story',
]);

export const commResourceType = pgEnum('comm_resource_type', ['file', 'link']);

/** Tipos de archivo aceptables en un entregable (`deliverableTypes`). */
export const deliverableType = pgEnum('deliverable_type', [
  'pdf',
  'video',
  'document',
  'image',
  'zip',
]);
