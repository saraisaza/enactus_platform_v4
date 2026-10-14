import { Hono } from 'hono';
import type { Context } from 'hono';
import { z } from 'zod';

import { forbidden } from '../lib/errors';
import { currentUser, isStudentLike, requireAuth } from '../middleware/auth';
import type { AppEnv } from '../middleware/context';
import { completarLeccion } from '../services/avance-de-leccion';
import { saveVideoProgress } from '../services/video-progress';

export const progressRoutes = new Hono<AppEnv>();
progressRoutes.use('*', requireAuth);

/**
 * Tope de cordura para las posiciones: un día. YouTube corta las subidas en
 * 12 horas, así que un número mayor no es un video largo, es basura.
 */
const MAX_VIDEO_SECONDS = 24 * 60 * 60;

const segundo = z.number().int().min(0).max(MAX_VIDEO_SECONDS);

const videoProgressBody = z.object({
  positionSec: segundo,
  durationSec: z.number().int().min(1).max(MAX_VIDEO_SECONDS).optional(),
  /** El tramo que se reprodujo desde el guardado anterior. */
  watchedFromSec: segundo.optional(),
  watchedToSec: segundo.optional(),
});

/**
 * Completar una lección.
 *
 * Solo el propio estudiante, y solo si ya le toca y cumplió lo que esa
 * lección pide (`services/avance-de-leccion.ts`): si no, 409 con lo que le
 * falta. NO existe «desmarcar» ni una versión «completar a otro»: sería una
 * forma de fabricar avance. La única vía indirecta legítima —calificar una
 * actividad como aprobada— vive en el endpoint de calificación.
 *
 * La respuesta trae el progreso recalculado de curso, módulo, fase y Ruta:
 * el cliente no necesita ninguna llamada adicional para saber en qué quedó.
 */
async function completar(c: Context<AppEnv>) {
  const user = currentUser(c);
  if (!isStudentLike(user.role)) {
    throw forbidden('Solo un estudiante puede completar sus propias lecciones.');
  }
  const impact = await completarLeccion(c.get('db'), user.id, c.req.param('lessonId')!);
  return c.json(impact);
}

progressRoutes.post('/lessons/:lessonId/complete', completar);

/**
 * El nombre viejo. Antes alternaba —y por eso se podía marcar a mano—; ahora
 * hace lo mismo que `complete`. Queda para la app que alguien tenga abierta
 * durante el despliegue: con ella, tocar el círculo recibe el 409 que explica
 * qué falta, en vez de un 404.
 */
progressRoutes.post('/lessons/:lessonId/toggle', completar);

/**
 * Guardar hasta dónde vio el video de una lección, para retomar ahí, y el
 * tramo que se reprodujo.
 *
 * Solo el propio estudiante, sobre lecciones a las que tiene acceso y que ya
 * le tocan. Es `PUT` porque es idempotente: mandar dos veces lo mismo deja lo
 * mismo, y el reproductor lo manda cada pocos segundos.
 *
 * Cuando lo visto llega al 90%, completa la lección: la respuesta trae
 * `completion` con el progreso recalculado (ver `services/video-progress.ts`).
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
