import { sql } from 'drizzle-orm';
import {
  check,
  index,
  integer,
  pgTable,
  primaryKey,
  timestamp,
  unique,
  uuid,
} from 'drizzle-orm/pg-core';

import { timestamps } from './_shared';
import { courses, lessons } from './courses';
import { laboratories } from './labs';
import { users } from './users';

/**
 * Progreso de un estudiante en un curso.
 *
 * Se guarda SOLO el hecho atómico ("completó esta lección"). La completitud
 * de curso, módulo, fase y Ruta NO se guarda en ninguna columna: se calcula
 * (ver `src/db/completeness.sql`). Es la decisión de diseño que ya tomó el
 * frontend y hay que conservarla — un `is_complete` guardado se desincroniza
 * a la primera, y la Fase 0 confirmó que la completitud cambia sola cuando un
 * LXD agrega contenido.
 */
export const progress = pgTable(
  'progress',
  {
    id: uuid().primaryKey().defaultRandom(),
    studentId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    courseId: uuid()
      .notNull()
      .references(() => courses.id, { onDelete: 'cascade' }),
    ...timestamps,
  },
  (t) => [
    unique('progress_student_course_unique').on(t.studentId, t.courseId),
    index('progress_student_id_idx').on(t.studentId),
    index('progress_course_id_idx').on(t.courseId),
  ],
);

export const progressLessons = pgTable(
  'progress_lessons',
  {
    progressId: uuid()
      .notNull()
      .references(() => progress.id, { onDelete: 'cascade' }),
    lessonId: uuid()
      .notNull()
      .references(() => lessons.id, { onDelete: 'cascade' }),
    completedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    primaryKey({ columns: [t.progressId, t.lessonId] }),
    index('progress_lessons_lesson_id_idx').on(t.lessonId),
  ],
);

/**
 * Progreso en la Ruta de Impacto de UN laboratorio. Un estudiante en varios
 * laboratorios tiene una Ruta independiente en cada uno.
 *
 * Guarda solo las entregas y lecturas PROPIAS de los módulos; el avance de
 * los cursos vinculados sale de `progress`.
 */
export const rutaProgress = pgTable(
  'ruta_progress',
  {
    id: uuid().primaryKey().defaultRandom(),
    studentId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    laboratoryId: uuid()
      .notNull()
      .references(() => laboratories.id, { onDelete: 'cascade' }),
    ...timestamps,
  },
  (t) => [
    unique('ruta_progress_student_lab_unique').on(t.studentId, t.laboratoryId),
    index('ruta_progress_student_id_idx').on(t.studentId),
    index('ruta_progress_laboratory_id_idx').on(t.laboratoryId),
  ],
);

export const rutaProgressLessons = pgTable(
  'ruta_progress_lessons',
  {
    rutaProgressId: uuid()
      .notNull()
      .references(() => rutaProgress.id, { onDelete: 'cascade' }),
    lessonId: uuid()
      .notNull()
      .references(() => lessons.id, { onDelete: 'cascade' }),
    completedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    primaryKey({ columns: [t.rutaProgressId, t.lessonId] }),
    index('ruta_progress_lessons_lesson_id_idx').on(t.lessonId),
  ],
);

/**
 * Hasta dónde vio un estudiante el video de una lección.
 *
 * NO es completitud: la lección se completa por el mismo camino de siempre
 * (`progress_lessons`, vía el toggle), y esta tabla no alimenta ninguna vista
 * de `0001_completeness.sql`. Guarda otro hecho atómico —«iba por el segundo
 * 312»— para retomar donde quedó, desde cualquier dispositivo.
 *
 * Dos posiciones porque responden preguntas distintas: `position_sec` es
 * dónde retomar (puede retroceder si vuelve a ver un tramo) y `furthest_sec`
 * es hasta dónde llegó alguna vez (solo crece; es lo que se muestra como
 * «visto»).
 */
export const lessonVideoProgress = pgTable(
  'lesson_video_progress',
  {
    studentId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    lessonId: uuid()
      .notNull()
      .references(() => lessons.id, { onDelete: 'cascade' }),
    positionSec: integer().notNull().default(0),
    furthestSec: integer().notNull().default(0),
    /** La que reporta el reproductor. Nula hasta que el video arranca. */
    durationSec: integer(),
    ...timestamps,
  },
  (t) => [
    primaryKey({ columns: [t.studentId, t.lessonId] }),
    index('lesson_video_progress_lesson_id_idx').on(t.lessonId),
    check(
      'lesson_video_progress_positions_valid',
      sql`${t.positionSec} >= 0 and ${t.furthestSec} >= ${t.positionSec}
          and (${t.durationSec} is null or ${t.durationSec} > 0)`,
    ),
  ],
);
