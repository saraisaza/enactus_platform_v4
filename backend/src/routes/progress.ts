import { Hono } from 'hono';

import { forbidden } from '../lib/errors';
import { currentUser, isStudentLike, requireAuth } from '../middleware/auth';
import type { AppEnv } from '../middleware/context';
import { toggleLesson } from '../services/lesson-toggle';

export const progressRoutes = new Hono<AppEnv>();
progressRoutes.use('*', requireAuth);

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
