import { and, count, eq, sql } from 'drizzle-orm';

import type { Database } from '../db/client';
import { courseModules, lessons } from '../db/schema';

/**
 * Reglas de contenido que se verifican al PUBLICAR un curso.
 *
 * Viven acá y no en un CHECK de la base porque un curso a medio construir
 * puede —y debe poder— estar incompleto: la exigencia aparece recién cuando
 * el curso va a hacerse visible para estudiantes (ver migración 0002).
 */

export async function lessonCountFor(
  db: Database,
  courseId: string,
): Promise<number> {
  const [row] = await db
    .select({ value: count() })
    .from(lessons)
    .innerJoin(courseModules, eq(lessons.courseModuleId, courseModules.id))
    .where(eq(courseModules.courseId, courseId));
  return row?.value ?? 0;
}

/** Lecciones de tipo video que todavía no tienen ni enlace ni archivo. */
export async function videoLessonsWithoutSource(
  db: Database,
  courseId: string,
): Promise<{ id: string; title: string }[]> {
  return db
    .select({ id: lessons.id, title: lessons.title })
    .from(lessons)
    .innerJoin(courseModules, eq(lessons.courseModuleId, courseModules.id))
    .where(
      and(
        eq(courseModules.courseId, courseId),
        eq(lessons.type, 'video'),
        sql`${lessons.videoType} is null`,
      ),
    );
}
