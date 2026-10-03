import { and, asc, eq, sql } from 'drizzle-orm';

import type { Database } from '../db/client';
import { courseModules, lessonVideoProgress, lessons } from '../db/schema';
import { conflict, notFound } from '../lib/errors';
import { courseAccessForModule, labAccessForRutaModule } from './lesson-toggle';

/**
 * Hasta dónde vio un estudiante el video de una lección.
 *
 * Lo que esto NO hace es completar la lección. Completar sigue siendo el
 * toggle —reversible y de la persona—, y lo pide el cliente al llegar al
 * final igual que lo pide al aprobar un quiz. Si esto completara solo, una
 * estudiante que desmarcó la lección para repasarla la vería marcarse de
 * nuevo en el primer guardado: `furthest_sec` ya estaba al final.
 */

export interface VideoProgress {
  lessonId: string;
  positionSec: number;
  furthestSec: number;
  durationSec: number | null;
  updatedAt: string;
}

export interface VideoProgressInput {
  positionSec: number;
  durationSec?: number | undefined;
}

export async function saveVideoProgress(
  db: Database,
  studentId: string,
  lessonId: string,
  input: VideoProgressInput,
): Promise<VideoProgress> {
  const [lesson] = await db
    .select({
      id: lessons.id,
      type: lessons.type,
      courseModuleId: lessons.courseModuleId,
      rutaModuleId: lessons.rutaModuleId,
    })
    .from(lessons)
    .where(eq(lessons.id, lessonId))
    .limit(1);
  if (!lesson) throw notFound('No se encontró la lección.');

  // Mismo alcance que el toggle, y ANTES de mirar el tipo: un 409 «no es de
  // video» le confirmaría a alguien sin acceso que la lección existe.
  if (lesson.courseModuleId) {
    await courseAccessForModule(db, studentId, lesson.courseModuleId);
  } else {
    await labAccessForRutaModule(db, studentId, lesson.rutaModuleId!);
  }

  if (lesson.type !== 'video') {
    throw conflict('Esta lección no es de video: no hay posición que guardar.', {
      type: lesson.type,
    });
  }

  // Una posición más allá del final es un reporte desprolijo del reproductor
  // (el último evento llega con unos milisegundos de más), no un dato: se
  // recorta en vez de rechazar la escritura entera.
  const duration = input.durationSec ?? null;
  const position =
    duration === null ? input.positionSec : Math.min(input.positionSec, duration);

  const [row] = await db
    .insert(lessonVideoProgress)
    .values({
      studentId,
      lessonId: lesson.id,
      positionSec: position,
      furthestSec: position,
      durationSec: duration,
    })
    .onConflictDoUpdate({
      target: [lessonVideoProgress.studentId, lessonVideoProgress.lessonId],
      set: {
        positionSec: sql`excluded.position_sec`,
        // Solo crece: volver a ver un tramo no le resta lo que ya vio.
        furthestSec: sql`greatest(${lessonVideoProgress.furthestSec}, excluded.position_sec)`,
        // Un guardado sin duración (el reproductor todavía no la sabía) no
        // borra la que ya se tenía.
        durationSec: sql`coalesce(excluded.duration_sec, ${lessonVideoProgress.durationSec})`,
        updatedAt: new Date(),
      },
    })
    .returning();

  return toVideoProgress(row!);
}

/** Las posiciones de UN estudiante en las lecciones de UN curso. */
export async function videoProgressForCourse(
  db: Database,
  studentId: string,
  courseId: string,
): Promise<VideoProgress[]> {
  const rows = await db
    .select({
      lessonId: lessonVideoProgress.lessonId,
      positionSec: lessonVideoProgress.positionSec,
      furthestSec: lessonVideoProgress.furthestSec,
      durationSec: lessonVideoProgress.durationSec,
      updatedAt: lessonVideoProgress.updatedAt,
    })
    .from(lessonVideoProgress)
    .innerJoin(lessons, eq(lessons.id, lessonVideoProgress.lessonId))
    .innerJoin(courseModules, eq(courseModules.id, lessons.courseModuleId))
    .where(
      and(
        eq(lessonVideoProgress.studentId, studentId),
        eq(courseModules.courseId, courseId),
      ),
    )
    .orderBy(asc(courseModules.orderIndex), asc(lessons.orderIndex));
  return rows.map(toVideoProgress);
}

function toVideoProgress(row: {
  lessonId: string;
  positionSec: number;
  furthestSec: number;
  durationSec: number | null;
  updatedAt: Date;
}): VideoProgress {
  return {
    lessonId: row.lessonId,
    positionSec: row.positionSec,
    furthestSec: row.furthestSec,
    durationSec: row.durationSec,
    updatedAt: row.updatedAt.toISOString(),
  };
}
