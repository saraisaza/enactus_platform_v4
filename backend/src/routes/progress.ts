import { Hono } from 'hono';
import { z } from 'zod';

import { forbidden } from '../lib/errors';
import { currentUser, isStudentLike, requireAuth } from '../middleware/auth';
import type { AppEnv } from '../middleware/context';
import { toggleLesson } from '../services/lesson-toggle';
import { saveVideoProgress } from '../services/video-progress';

export const progressRoutes = new Hono<AppEnv>();
progressRoutes.use('*', requireAuth);

/**
 * Tope de cordura para las posiciones: un día. YouTube corta las subidas en
 * 12 horas, así que un número mayor no es un video largo, es basura.
 */
const MAX_VIDEO_SECONDS = 24 * 60 * 60;

const videoProgressBody = z.object({
  positionSec: z.number().int().min(0).max(MAX_VIDEO_SECONDS),
  durationSec: z.number().int().min(1).max(MAX_VIDEO_SECONDS).optional(),
});

/**
 * Alternar una lección.
 *
 * Solo el propio estudiante. NO existe una versión "marcar completa a otro":
 * sería una forma de fabricar progreso, y la única vía indirecta legítima
 * —calificar una actividad, que completa su lección— vive en el endpoint de
 * calificación (decisión C.6 de la Fase 0).
 *
 * La respuesta trae el progreso recalculado de curso, módulo, fase y Ruta:
 * el cliente no necesita ninguna llamada adicional para saber en qué quedó.
 */
progressRoutes.post('/lessons/:lessonId/toggle', async (c) => {
  const user = currentUser(c);
  if (!isStudentLike(user.role)) {
    throw forbidden('Solo un estudiante puede marcar sus propias lecciones.');
  }
  const impact = await toggleLesson(c.get('db'), user.id, c.req.param('lessonId'));
  return c.json(impact);
});

/**
 * Guardar hasta dónde vio el video de una lección, para retomar ahí.
 *
 * Solo el propio estudiante y sobre lecciones a las que tiene acceso — las
 * mismas reglas que el toggle. Es `PUT` porque es idempotente: mandar dos
 * veces la misma posición deja lo mismo, y el reproductor la manda cada pocos
 * segundos.
 *
 * NO completa la lección (ver `services/video-progress.ts`).
 */
progressRoutes.put('/lessons/:lessonId/video', async (c) => {
  const user = currentUser(c);
  if (!isStudentLike(user.role)) {
    throw forbidden('Solo un estudiante guarda su propio avance en un video.');
  }
  const body = videoProgressBody.parse(await c.req.json());
  const saved = await saveVideoProgress(
    c.get('db'),
    user.id,
    c.req.param('lessonId'),
    body,
  );
  return c.json(saved);
});
