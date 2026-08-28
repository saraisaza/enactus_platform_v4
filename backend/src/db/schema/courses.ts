import { sql } from 'drizzle-orm';
import type { AnyPgColumn } from 'drizzle-orm/pg-core';
import {
  bigint,
  boolean,
  check,
  date,
  index,
  integer,
  pgTable,
  primaryKey,
  text,
  unique,
  uuid,
} from 'drizzle-orm/pg-core';

import { softDelete, timestamps } from './_shared';
import { competencies, odsGoals } from './catalogs';
import {
  courseLevel,
  courseStatus,
  deliverableType,
  gradingMode,
  lessonType,
  objectiveCategory,
  quizKind,
  videoType,
} from './enums';
import { laboratories, rutaModules } from './labs';
import { users } from './users';

export const courses = pgTable(
  'courses',
  {
    id: uuid().primaryKey().defaultRandom(),
    name: text().notNull(),
    subtitle: text().notNull().default(''),
    description: text().notNull().default(''),
    fullDescription: text().notNull().default(''),
    /** Key en S3 (antes `coverImagePath`, una ruta local). */
    coverS3Key: text('cover_s3_key'),

    /**
     * Video de introducción. Mismas seis columnas que una lección, con
     * prefijo — un LXD tiene que poder subir su propia intro, no solo pegar
     * un enlace.
     */
    introVideoType: videoType(),
    introVideoUrl: text(),
    introVideoS3Key: text('intro_video_s3_key'),
    introVideoSizeBytes: bigint({ mode: 'number' }),
    introVideoDurationSec: integer(),
    introVideoMimeType: text(),

    /** Vacío en Open Learning y en la RUTA NATIONAL EXPO (legado). */
    laboratoryId: uuid().references(() => laboratories.id, {
      onDelete: 'set null',
    }),
    /** El LXD que creó el curso. Determina quién puede editarlo. */
    creatorId: uuid().references(() => users.id, { onDelete: 'set null' }),

    /** Se asigna directo a estudiantes, sin laboratorio ni Ruta de Impacto. */
    isOpenLearning: boolean().notNull().default(false),
    /** Legado: RUTA NATIONAL EXPO. Ya no se crean rutas nuevas así. */
    isRutaExpo: boolean().notNull().default(false),
    legacyProjectId: uuid(),

    level: courseLevel().notNull().default('basic'),
    estimatedHours: integer().notNull().default(0),
    language: text().notNull().default('es'),
    status: courseStatus().notNull().default('published'),

    generatesCertificate: boolean().notNull().default(false),
    certifiedHours: integer().notNull().default(0),

    openDate: date(),
    closeDate: date(),
    /** 0 = sin límite. */
    maxStudents: integer().notNull().default(0),
    visible: boolean().notNull().default(true),
    sponsorCompanyId: uuid().references(() => users.id, {
      onDelete: 'set null',
    }),

    ...timestamps,
    ...softDelete,
  },
  (t) => [
    index('courses_laboratory_id_idx').on(t.laboratoryId),
    index('courses_creator_id_idx').on(t.creatorId),
    index('courses_sponsor_company_id_idx').on(t.sponsorCompanyId),
    index('courses_status_idx').on(t.status),
    index('courses_is_open_learning_idx').on(t.isOpenLearning),
    index('courses_deleted_at_idx').on(t.deletedAt),
    check(
      'courses_intro_video_source',
      sql`(${t.introVideoType} is null and ${t.introVideoUrl} is null and ${t.introVideoS3Key} is null)
       or (${t.introVideoType} = 'external' and ${t.introVideoUrl} is not null and ${t.introVideoS3Key} is null)
       or (${t.introVideoType} = 'uploaded' and ${t.introVideoS3Key} is not null and ${t.introVideoUrl} is null)`,
    ),
    check('courses_hours_non_negative', sql`${t.estimatedHours} >= 0 and ${t.certifiedHours} >= 0`),
    check('courses_max_students_non_negative', sql`${t.maxStudents} >= 0`),
  ],
);

/** Etiquetas libres. Hay un catálogo sugerido, pero el LXD puede agregar. */
export const courseTags = pgTable(
  'course_tags',
  {
    courseId: uuid()
      .notNull()
      .references(() => courses.id, { onDelete: 'cascade' }),
    tag: text().notNull(),
  },
  (t) => [
    primaryKey({ columns: [t.courseId, t.tag] }),
    index('course_tags_tag_idx').on(t.tag),
  ],
);

/**
 * Objetivos del curso, en una sola tabla.
 *
 * En Flutter eran tres listas separadas (`objectives`,
 * `entrepreneurshipObjectives`, `businessObjectives`) con la misma forma.
 * `category` nula = objetivo general; con categoría = el que se copia a la
 * fase al vincular el curso a un módulo (`importCourseObjectives`).
 */
export const courseObjectives = pgTable(
  'course_objectives',
  {
    id: uuid().primaryKey().defaultRandom(),
    courseId: uuid()
      .notNull()
      .references(() => courses.id, { onDelete: 'cascade' }),
    category: objectiveCategory(),
    text: text().notNull(),
    orderIndex: integer().notNull().default(0),
    ...timestamps,
  },
  (t) => [index('course_objectives_course_id_idx').on(t.courseId)],
);

/** Competencias que desarrolla. Alimenta `hoursByCompetency()`. */
export const courseCompetencies = pgTable(
  'course_competencies',
  {
    courseId: uuid()
      .notNull()
      .references(() => courses.id, { onDelete: 'cascade' }),
    competencyCode: text()
      .notNull()
      .references(() => competencies.code, { onDelete: 'restrict' }),
  },
  (t) => [
    primaryKey({ columns: [t.courseId, t.competencyCode] }),
    index('course_competencies_code_idx').on(t.competencyCode),
  ],
);

export const courseLearningOutcomes = pgTable(
  'course_learning_outcomes',
  {
    id: uuid().primaryKey().defaultRandom(),
    courseId: uuid()
      .notNull()
      .references(() => courses.id, { onDelete: 'cascade' }),
    text: text().notNull(),
    orderIndex: integer().notNull().default(0),
    ...timestamps,
  },
  (t) => [index('course_learning_outcomes_course_id_idx').on(t.courseId)],
);

export const coursePrerequisites = pgTable(
  'course_prerequisites',
  {
    courseId: uuid()
      .notNull()
      .references(() => courses.id, { onDelete: 'cascade' }),
    prerequisiteCourseId: uuid()
      .notNull()
      .references((): AnyPgColumn => courses.id, { onDelete: 'cascade' }),
  },
  (t) => [
    primaryKey({ columns: [t.courseId, t.prerequisiteCourseId] }),
    index('course_prerequisites_prereq_idx').on(t.prerequisiteCourseId),
    check('course_prerequisites_no_self', sql`${t.courseId} <> ${t.prerequisiteCourseId}`),
  ],
);

/** ODS del curso. Alimenta `odsCompletionRate()`. */
export const courseOds = pgTable(
  'course_ods',
  {
    courseId: uuid()
      .notNull()
      .references(() => courses.id, { onDelete: 'cascade' }),
    odsCode: text()
      .notNull()
      .references(() => odsGoals.code, { onDelete: 'restrict' }),
  },
  (t) => [
    primaryKey({ columns: [t.courseId, t.odsCode] }),
    index('course_ods_ods_code_idx').on(t.odsCode),
  ],
);

/** Módulo de un curso: agrupa lecciones. */
export const courseModules = pgTable(
  'course_modules',
  {
    id: uuid().primaryKey().defaultRandom(),
    courseId: uuid()
      .notNull()
      .references(() => courses.id, { onDelete: 'cascade' }),
    orderIndex: integer().notNull(),
    title: text().notNull(),
    ...timestamps,
  },
  (t) => [
    unique('course_modules_course_order_unique').on(t.courseId, t.orderIndex),
    index('course_modules_course_id_idx').on(t.courseId),
  ],
);

/**
 * Lección. Tiene DOS padres posibles, igual que hoy en Flutter, donde la
 * misma clase `Lesson` la usan `CourseModule.lessons` y
 * `RutaModule.ownLessons`: exactamente uno de los dos está presente (CHECK).
 *
 * Sobre el video: el prompt pide `video_type NOT NULL`, pero una lección de
 * tipo `pdf`, `quiz` o `activity` no tiene video ninguno. Acá las tres
 * columnas de video son nulables Y el CHECK exige la coherencia pedida —
 * "exactamente uno de video_url / video_s3_key según video_type" — más una
 * regla extra: si la lección es de tipo `video`, el origen es obligatorio.
 * Es la misma garantía, sin obligar a inventar un `video_type` para lecciones
 * que no son video.
 */
export const lessons = pgTable(
  'lessons',
  {
    id: uuid().primaryKey().defaultRandom(),
    courseModuleId: uuid().references(() => courseModules.id, {
      onDelete: 'cascade',
    }),
    rutaModuleId: uuid().references(() => rutaModules.id, {
      onDelete: 'cascade',
    }),
    orderIndex: integer().notNull().default(0),
    title: text().notNull(),
    type: lessonType().notNull().default('video'),
    description: text().notNull().default(''),
    durationMin: integer().notNull().default(0),

    /** PDF / recurso descargable: key en S3. Antes `resourcePath` local. */
    resourceS3Key: text('resource_s3_key'),
    resourceFileName: text(),
    resourceContentType: text(),
    resourceSizeBytes: bigint({ mode: 'number' }),
    /** Solo `type = 'link'`. */
    externalUrl: text(),

    videoType: videoType(),
    videoUrl: text(),
    videoS3Key: text('video_s3_key'),
    videoSizeBytes: bigint({ mode: 'number' }),
    videoDurationSec: integer(),
    videoMimeType: text(),

    ...timestamps,
  },
  (t) => [
    index('lessons_course_module_id_idx').on(t.courseModuleId),
    index('lessons_ruta_module_id_idx').on(t.rutaModuleId),
    index('lessons_type_idx').on(t.type),
    check(
      'lessons_exactly_one_parent',
      sql`(${t.courseModuleId} is not null) <> (${t.rutaModuleId} is not null)`,
    ),
    check(
      'lessons_video_source',
      sql`(${t.videoType} is null and ${t.videoUrl} is null and ${t.videoS3Key} is null)
       or (${t.videoType} = 'external' and ${t.videoUrl} is not null and ${t.videoS3Key} is null)
       or (${t.videoType} = 'uploaded' and ${t.videoS3Key} is not null and ${t.videoUrl} is null)`,
    ),
    // Ojo: NO hay un CHECK que exija que una lección de tipo `video` tenga
    // origen. Se quitó en la migración 0002 porque hacía imposible el flujo
    // de subida (no se puede crear la lección sin la key, ni obtener la key
    // sin la lección). Esa regla vive ahora en `POST /courses/:id/publish`:
    // una lección a medio construir puede estar vacía, un curso publicado no.
    check(
      'lessons_link_requires_url',
      sql`${t.type} <> 'link' or ${t.externalUrl} is not null`,
    ),
  ],
);

/**
 * Pregunta de quiz o de encuesta.
 *
 * `answerIndex`/`answerText` son la CLAVE DE RESPUESTAS: hoy viajan al
 * navegador dentro del `Course` y el quiz se califica en el cliente
 * (AUDITORIA_BACKEND.md § A.8.2). En el backend estas dos columnas NUNCA
 * salen en el DTO que ve un estudiante — solo las lee el endpoint que
 * califica el intento.
 *
 * En las preguntas de tipo `order`, la respuesta correcta es el
 * `orderIndex` de las opciones; no hay clave aparte.
 */
export const quizQuestions = pgTable(
  'quiz_questions',
  {
    id: uuid().primaryKey().defaultRandom(),
    lessonId: uuid()
      .notNull()
      .references(() => lessons.id, { onDelete: 'cascade' }),
    orderIndex: integer().notNull().default(0),
    kind: quizKind().notNull().default('multiple'),
    question: text().notNull().default(''),
    answerIndex: integer(),
    answerText: text(),
    ...timestamps,
  },
  (t) => [index('quiz_questions_lesson_id_idx').on(t.lessonId)],
);

/** Opciones de una pregunta. En `order`, guardadas en el orden CORRECTO. */
export const quizQuestionOptions = pgTable(
  'quiz_question_options',
  {
    id: uuid().primaryKey().defaultRandom(),
    quizQuestionId: uuid()
      .notNull()
      .references(() => quizQuestions.id, { onDelete: 'cascade' }),
    orderIndex: integer().notNull(),
    text: text().notNull(),
  },
  (t) => [
    unique('quiz_question_options_order_unique').on(t.quizQuestionId, t.orderIndex),
    index('quiz_question_options_question_id_idx').on(t.quizQuestionId),
  ],
);

/** Configuración de una lección de tipo `activity` (entregable). */
export const lessonActivities = pgTable(
  'lesson_activities',
  {
    lessonId: uuid()
      .primaryKey()
      .references(() => lessons.id, { onDelete: 'cascade' }),
    description: text().notNull().default(''),
    deadline: date(),
    requiresFile: boolean().notNull().default(false),
    requiresText: boolean().notNull().default(true),
    maxFiles: integer().notNull().default(1),
    gradingMode: gradingMode().notNull().default('points100'),
    ...timestamps,
  },
  (t) => [check('lesson_activities_max_files_positive', sql`${t.maxFiles} > 0`)],
);

export const activityAllowedTypes = pgTable(
  'activity_allowed_types',
  {
    lessonId: uuid()
      .notNull()
      .references(() => lessonActivities.lessonId, { onDelete: 'cascade' }),
    fileType: deliverableType().notNull(),
  },
  (t) => [primaryKey({ columns: [t.lessonId, t.fileType] })],
);

/** Rúbrica: criterio + puntos. Antes `List<Map<String,dynamic>>` sin forma. */
export const activityRubricItems = pgTable(
  'activity_rubric_items',
  {
    id: uuid().primaryKey().defaultRandom(),
    lessonId: uuid()
      .notNull()
      .references(() => lessonActivities.lessonId, { onDelete: 'cascade' }),
    orderIndex: integer().notNull().default(0),
    criterion: text().notNull(),
    points: integer().notNull().default(0),
    ...timestamps,
  },
  (t) => [
    index('activity_rubric_items_lesson_id_idx').on(t.lessonId),
    check('activity_rubric_items_points_non_negative', sql`${t.points} >= 0`),
  ],
);
