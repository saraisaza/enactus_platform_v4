import { type SQL, and, eq, isNull, sql } from 'drizzle-orm';

import type { Database } from '../db/client';
import { courses } from '../db/schema';
import { forbidden } from '../lib/errors';
import type { AuthUser } from '../middleware/context';

/**
 * Qué cursos puede VER cada rol.
 *
 * Traduce a SQL lo que hoy hacen las pantallas por convención — y que hoy no
 * impide nada, porque `DataProvider.courses` devuelve todo a todo el mundo
 * (AUDITORIA_BACKEND.md § A.8.7). Acá el filtro es del servidor: aunque el
 * cliente pida un id concreto, si no entra en su alcance recibe 404.
 *
 * Devuelve `null` cuando el rol no ve NINGÚN curso (el Donante), para que el
 * llamador pueda cortar sin consultar.
 */
export function visibleCoursesFilter(user: AuthUser): SQL | null {
  const alive = isNull(courses.deletedAt);

  switch (user.role) {
    case 'superadmin':
    case 'admin':
      return alive;

    case 'lxd':
      // Los suyos en cualquier estado (necesita ver sus borradores), más los
      // ya publicados de los laboratorios donde tiene contenido.
      return and(
        alive,
        sql`(${courses.creatorId} = ${user.id}
             or (${courses.status} = 'published'
                 and ${courses.laboratoryId} in (
                   select c2.laboratory_id from courses c2
                    where c2.creator_id = ${user.id}
                      and c2.laboratory_id is not null)))`,
      )!;

    case 'mentor':
      // Los que tiene asignados para revisar; si no tiene ninguno asignado,
      // todos los de sus laboratorios (regla `reviewableCoursesForMentor`).
      return and(
        alive,
        eq(courses.status, 'published'),
        sql`(
          case when exists (select 1 from mentor_review_courses m
                             where m.mentor_id = ${user.id})
            then ${courses.id} in (select m.course_id from mentor_review_courses m
                                    where m.mentor_id = ${user.id})
            else ${courses.laboratoryId} in (select lm.laboratory_id
                                               from laboratory_mentors lm
                                              where lm.user_id = ${user.id})
          end)`,
      )!;

    case 'student':
    case 'alumni':
      // Solo lo que la vista de acceso le permite, y solo publicado y
      // visible: un curso en borrador no existe para un estudiante.
      return and(
        alive,
        eq(courses.status, 'published'),
        eq(courses.visible, true),
        sql`${courses.id} in (select a.course_id from student_course_access a
                               where a.student_id = ${user.id})`,
      )!;

    case 'company':
      // Los creados por cualquiera de sus LXD (`coursesForCompany`).
      return and(
        alive,
        sql`${courses.creatorId} in (select u.id from users u
                                      where u.company_id = ${user.id}
                                        and u.role = 'lxd')`,
      )!;

    case 'advisor':
      // Publicados de los laboratorios donde están sus estudiantes.
      return and(
        alive,
        eq(courses.status, 'published'),
        sql`${courses.laboratoryId} in (
              select sl.laboratory_id from student_laboratories sl
                join users u on u.id = sl.student_id
               where u.university = ${user.university}
                 and u.university <> '')`,
      )!;

    case 'donor':
      // El portal de Donante no tiene cursos.
      return null;
  }
}

/**
 * Quién puede EDITAR un curso: su creador, o un administrador.
 *
 * Es la regla que hoy aplica la interfaz del LXD al listar solo
 * `courses.where(creatorId == lxd.id)`, pero que `saveCourse` no verifica.
 */
export function assertCanEditCourse(
  user: AuthUser,
  course: { creatorId: string | null },
): void {
  if (user.role === 'admin' || user.role === 'superadmin') return;
  if (user.role === 'lxd' && course.creatorId === user.id) return;
  throw forbidden('Solo el LXD que creó el curso (o un administrador) puede editarlo.');
}

/**
 * Qué impide borrar un curso (decisión B.7 de la Fase 0).
 *
 * Hoy `deleteCourse` borra la fila y ya: el progreso queda huérfano y los
 * `courseIds` de los módulos quedan colgando. Como `isObjectiveComplete`
 * exige que el curso exista, un curso borrado deja el objetivo —y con él el
 * módulo, la fase y la Ruta entera— bloqueado en silencio para todos los
 * estudiantes del laboratorio.
 */
export async function courseDeletionBlockers(
  db: Database,
  courseId: string,
): Promise<{ rutaModules: number; objectives: number; studentsWithProgress: number }> {
  const [row] = await db.execute<{
    ruta_modules: number;
    objectives: number;
    students_with_progress: number;
  }>(sql`
    select
      (select count(*)::int from ruta_module_courses where course_id = ${courseId}) as ruta_modules,
      (select count(*)::int from objective_courses  where course_id = ${courseId}) as objectives,
      (select count(*)::int from progress           where course_id = ${courseId}) as students_with_progress
  `);
  return {
    rutaModules: row?.ruta_modules ?? 0,
    objectives: row?.objectives ?? 0,
    studentsWithProgress: row?.students_with_progress ?? 0,
  };
}
