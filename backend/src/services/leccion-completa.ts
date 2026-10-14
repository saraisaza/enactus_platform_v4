import { eq } from 'drizzle-orm';

import type { Database } from '../db/client';
import { lessons, progress, progressLessons } from '../db/schema';
import { emitirCertificadoDeCurso } from './certificates';

/**
 * Marca una lección de curso como completa, sin alternar: lo que la completa
 * —calificar una actividad, responder una encuesta— nunca debe des-completarla.
 *
 * Si con esa lección el curso quedó completo, emite su certificado.
 */
export async function marcarLeccionCompleta(
  db: Database,
  studentId: string,
  courseId: string,
  lessonId: string,
): Promise<void> {
  const [existe] = await db
    .select({ id: lessons.id })
    .from(lessons)
    .where(eq(lessons.id, lessonId))
    .limit(1);
  if (!existe) return;

  const [fila] = await db
    .insert(progress)
    .values({ studentId, courseId })
    .onConflictDoUpdate({
      target: [progress.studentId, progress.courseId],
      set: { updatedAt: new Date() },
    })
    .returning({ id: progress.id });

  await db
    .insert(progressLessons)
    .values({ progressId: fila!.id, lessonId })
    .onConflictDoNothing();
  await emitirCertificadoDeCurso(db, studentId, courseId);
}
