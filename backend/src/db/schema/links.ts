import { index, pgTable, primaryKey, uuid } from 'drizzle-orm/pg-core';

import { timestamps } from './_shared';
import { courses } from './courses';
import { laboratories, objectives, rutaModules } from './labs';
import { users } from './users';

/**
 * Tablas puente que cruzan cursos con la Ruta de Impacto y con las personas.
 * Viven en su propio archivo para que `labs.ts` no tenga que importar
 * `courses.ts` ni al revés (import circular).
 */

/**
 * Cursos que hacen falta para dar por cumplido un objetivo de fase.
 * Reemplaza `Objective.sourceCourseIds`. El objetivo se completa cuando el
 * estudiante terminó el 100% de TODOS ellos.
 */
export const objectiveCourses = pgTable(
  'objective_courses',
  {
    objectiveId: uuid()
      .notNull()
      .references(() => objectives.id, { onDelete: 'cascade' }),
    courseId: uuid()
      .notNull()
      .references(() => courses.id, { onDelete: 'cascade' }),
  },
  (t) => [
    primaryKey({ columns: [t.objectiveId, t.courseId] }),
    index('objective_courses_course_id_idx').on(t.courseId),
  ],
);

/**
 * Cursos asignados a un módulo de la Ruta. Reemplaza `RutaModule.courseIds`.
 * Un curso vive en un solo módulo a la vez dentro de un mismo laboratorio;
 * eso lo garantiza el endpoint de vinculación, no la base (el mismo curso sí
 * puede estar en módulos de laboratorios distintos).
 */
export const rutaModuleCourses = pgTable(
  'ruta_module_courses',
  {
    rutaModuleId: uuid()
      .notNull()
      .references(() => rutaModules.id, { onDelete: 'cascade' }),
    courseId: uuid()
      .notNull()
      .references(() => courses.id, { onDelete: 'cascade' }),
    ...timestamps,
  },
  (t) => [
    primaryKey({ columns: [t.rutaModuleId, t.courseId] }),
    index('ruta_module_courses_course_id_idx').on(t.courseId),
  ],
);

/**
 * Laboratorios asignados a un estudiante Enactus. Reemplaza
 * `AppUser.extra['labIds']`. Cada uno tiene su propia Ruta de Impacto,
 * independiente de las demás.
 *
 * Ojo: esto es también lo que da acceso a los CURSOS del laboratorio, sin
 * asignarlos aparte (regla `studentHasCourse` para Enactus).
 */
export const studentLaboratories = pgTable(
  'student_laboratories',
  {
    studentId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    laboratoryId: uuid()
      .notNull()
      .references(() => laboratories.id, { onDelete: 'cascade' }),
    ...timestamps,
  },
  (t) => [
    primaryKey({ columns: [t.studentId, t.laboratoryId] }),
    index('student_laboratories_laboratory_id_idx').on(t.laboratoryId),
  ],
);

/**
 * Cursos asignados directamente a un estudiante. Reemplaza
 * `AppUser.extra['courseIds']`. Es la única vía de acceso para Open Learning.
 */
export const studentCourses = pgTable(
  'student_courses',
  {
    studentId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    courseId: uuid()
      .notNull()
      .references(() => courses.id, { onDelete: 'cascade' }),
    ...timestamps,
  },
  (t) => [
    primaryKey({ columns: [t.studentId, t.courseId] }),
    index('student_courses_course_id_idx').on(t.courseId),
  ],
);

/**
 * Cursos que un Mentor tiene asignados para revisar. Reemplaza
 * `AppUser.extra['reviewCourseIds']`. Sin filas = revisa todos los cursos de
 * sus laboratorios (`reviewableCoursesForMentor`).
 */
export const mentorReviewCourses = pgTable(
  'mentor_review_courses',
  {
    mentorId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    courseId: uuid()
      .notNull()
      .references(() => courses.id, { onDelete: 'cascade' }),
    ...timestamps,
  },
  (t) => [
    primaryKey({ columns: [t.mentorId, t.courseId] }),
    index('mentor_review_courses_course_id_idx').on(t.courseId),
  ],
);
