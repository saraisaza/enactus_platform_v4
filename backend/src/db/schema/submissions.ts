import { sql } from 'drizzle-orm';
import {
  bigint,
  boolean,
  check,
  index,
  integer,
  jsonb,
  numeric,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

import { softDelete, timestamps } from './_shared';
import { courses, lessons } from './courses';
import { gradingMode } from './enums';
import { laboratories, rutaModules } from './labs';
import { groups } from './orgs';
import { users } from './users';

/**
 * Entrega de un estudiante o de un equipo.
 *
 * Cuatro campos que en Flutter eran "uno u otro" codificados con string
 * vacío pasan a nulables con CHECK:
 * - `courseId` XOR `rutaModuleId` (actividad de curso vs. entrega propia de
 *   un módulo de la Ruta).
 * - `studentId` XOR `groupId` (individual vs. grupal, legado Expo).
 *
 * `gradingMode` se guarda JUNTO a la nota: hoy conviven cuatro escalas en el
 * mismo `double? grade` y el número por sí solo no significa nada.
 */
export const submissions = pgTable(
  'submissions',
  {
    id: uuid().primaryKey().defaultRandom(),
    courseId: uuid().references(() => courses.id, { onDelete: 'cascade' }),
    rutaModuleId: uuid().references(() => rutaModules.id, {
      onDelete: 'cascade',
    }),
    studentId: uuid().references(() => users.id, { onDelete: 'cascade' }),
    groupId: uuid().references(() => groups.id, { onDelete: 'cascade' }),
    /** Actividad/encuesta asociada. Nulo = entrega libre. */
    lessonId: uuid().references(() => lessons.id, { onDelete: 'set null' }),

    taskName: text().notNull(),
    comment: text().notNull().default(''),
    submittedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),

    /** Nota. Nula mientras no se califique, y siempre nula en modo `review`. */
    grade: numeric({ precision: 5, scale: 2 }),
    gradingMode: gradingMode(),
    /** Quién puso la nota. Sobrevive a que le quiten `can_grade` (decisión B.2). */
    gradedBy: uuid().references(() => users.id, { onDelete: 'set null' }),
    gradedAt: timestamp({ withTimezone: true }),

    /** Comentario del Mentor: revisa y comenta, pero NO califica. */
    feedback: text().notNull().default(''),
    reviewedBy: uuid().references(() => users.id, { onDelete: 'set null' }),
    reviewedAt: timestamp({ withTimezone: true }),

    ...timestamps,
    ...softDelete,
  },
  (t) => [
    index('submissions_course_id_idx').on(t.courseId),
    index('submissions_ruta_module_id_idx').on(t.rutaModuleId),
    index('submissions_student_id_idx').on(t.studentId),
    index('submissions_group_id_idx').on(t.groupId),
    index('submissions_lesson_id_idx').on(t.lessonId),
    index('submissions_graded_by_idx').on(t.gradedBy),
    index('submissions_deleted_at_idx').on(t.deletedAt),
    check(
      'submissions_exactly_one_context',
      sql`(${t.courseId} is not null) <> (${t.rutaModuleId} is not null)`,
    ),
    check(
      'submissions_exactly_one_author',
      sql`(${t.studentId} is not null) <> (${t.groupId} is not null)`,
    ),
    // Una nota siempre trae su escala y su autor; sin ellos el número no
    // significa nada y no se puede auditar quién la puso.
    check(
      'submissions_grade_has_scale_and_author',
      sql`${t.grade} is null or (${t.gradingMode} is not null and ${t.gradedBy} is not null and ${t.gradedAt} is not null)`,
    ),
    check(
      'submissions_review_mode_has_no_grade',
      sql`${t.gradingMode} is distinct from 'review' or ${t.grade} is null`,
    ),
  ],
);

/** Archivos adjuntos de una entrega. Antes `filePath` separado por " | ". */
export const submissionFiles = pgTable(
  'submission_files',
  {
    id: uuid().primaryKey().defaultRandom(),
    submissionId: uuid()
      .notNull()
      .references(() => submissions.id, { onDelete: 'cascade' }),
    s3Key: text('s3_key').notNull(),
    fileName: text().notNull(),
    contentType: text().notNull(),
    sizeBytes: bigint({ mode: 'number' }).notNull(),
    ...timestamps,
  },
  (t) => [
    index('submission_files_submission_id_idx').on(t.submissionId),
    uniqueIndex('submission_files_s3_key_unique').on(t.s3Key),
  ],
);

/**
 * Intento de quiz. NUEVO: hoy el quiz se califica en el navegador y no queda
 * registro de nada (AUDITORIA_BACKEND.md § A.8.2).
 *
 * `answers` es JSONB legítimo: su forma depende del tipo de cada pregunta
 * (índice, texto, u orden de opciones) y no se consulta por dentro.
 */
export const quizAttempts = pgTable(
  'quiz_attempts',
  {
    id: uuid().primaryKey().defaultRandom(),
    lessonId: uuid()
      .notNull()
      .references(() => lessons.id, { onDelete: 'cascade' }),
    studentId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    answers: jsonb().notNull(),
    /** 0..100, calculado en el servidor a partir de la clave de respuestas. */
    score: integer().notNull(),
    /** Umbral de aprobación: 60%, el mismo que aplica hoy `_QuizDialog`. */
    passed: boolean().notNull(),
    attemptedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    ...timestamps,
  },
  (t) => [
    index('quiz_attempts_lesson_student_idx').on(t.lessonId, t.studentId),
    check('quiz_attempts_score_range', sql`${t.score} between 0 and 100`),
  ],
);

/**
 * Certificado por completar la Ruta de Impacto COMPLETA de un laboratorio.
 * Ya no existe certificado por curso individual.
 *
 * Los campos `*Snapshot` congelan el estado al momento de emitir: un
 * certificado dice "completó esto A FECHA DE", no "cumple los requisitos
 * vigentes hoy". Por eso agregar contenido nuevo a la Ruta después NO lo
 * invalida (decisión B.1) — y `labContentVersion` deja registrado contra qué
 * versión del laboratorio se emitió.
 */
export const certificates = pgTable(
  'certificates',
  {
    id: uuid().primaryKey().defaultRandom(),
    code: text().notNull(),
    studentId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'restrict' }),
    laboratoryId: uuid()
      .notNull()
      .references(() => laboratories.id, { onDelete: 'restrict' }),
    /** Quién emitió. FK real, no el string suelto `issuerName` de hoy. */
    issuerId: uuid().references(() => users.id, { onDelete: 'set null' }),

    studentNameSnapshot: text().notNull(),
    laboratoryNameSnapshot: text().notNull(),
    issuerNameSnapshot: text().notNull(),
    hours: integer().notNull().default(0),
    labContentVersion: integer().notNull().default(1),
    /** Ids de fases/módulos/cursos que se exigían al emitir. Auditable. */
    requirementsSnapshot: jsonb().notNull(),

    issuedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    ...timestamps,
  },
  (t) => [
    uniqueIndex('certificates_code_unique').on(t.code),
    // Un solo certificado por estudiante y laboratorio.
    uniqueIndex('certificates_student_lab_unique').on(t.studentId, t.laboratoryId),
    index('certificates_student_id_idx').on(t.studentId),
    index('certificates_laboratory_id_idx').on(t.laboratoryId),
    index('certificates_issuer_id_idx').on(t.issuerId),
    check('certificates_hours_non_negative', sql`${t.hours} >= 0`),
  ],
);
