import { and, eq, isNull } from 'drizzle-orm';
import { Hono } from 'hono';

import { users } from '../db/schema';
import { conflict, notFound } from '../lib/errors';
import {
  assertSelfOr,
  currentUser,
  isStudentLike,
  requireAuth,
  requireEnactus,
} from '../middleware/auth';
import type { AppEnv, AuthUser } from '../middleware/context';
import { rutaCertificateEligibility } from '../services/certificates';
import {
  completedLessonIds,
  courseProgressFor,
  rutaProgressFor,
} from '../services/progress';

export const studentRoutes = new Hono<AppEnv>();
studentRoutes.use('*', requireAuth);

/** Roles del equipo que pueden mirar el progreso de un estudiante. */
const STAFF = ['admin', 'superadmin', 'advisor', 'mentor', 'lxd'] as const;

/**
 * Carga al estudiante objetivo y confirma que quien pregunta puede verlo.
 *
 * Es la defensa que hoy no existe: `CourseDetailView(studentId:)` acepta el id
 * de cualquiera, y `DataProvider` no filtra por nadie.
 */
async function loadTarget(
  db: AppEnv['Variables']['db'],
  viewer: AuthUser,
  targetId: string,
): Promise<AuthUser> {
  assertSelfOr(viewer, targetId, STAFF);
  const [target] = await db
    .select()
    .from(users)
    .where(and(eq(users.id, targetId), isNull(users.deletedAt)))
    .limit(1);
  if (!target || !isStudentLike(target.role)) {
    throw notFound('No se encontró el estudiante.');
  }
  return target;
}

/**
 * Estado completo de la Ruta de Impacto: laboratorios, fases, módulos,
 * objetivos y cursos, con el desbloqueo y el estado de cada deadline.
 *
 * `requireEnactus` corta antes a un estudiante de Open Learning: recibe 403,
 * NO una respuesta vacía. Una respuesta vacía haría ver un bug de permisos
 * como si fuera "todavía no hay datos".
 */
studentRoutes.get('/:id/ruta-progress', requireEnactus, async (c) => {
  const db = c.get('db');
  const target = await loadTarget(db, currentUser(c), c.req.param('id'));

  if (target.studentType === 'open_learning') {
    // Quien pregunta sí es Enactus (pasó requireEnactus), pero el objetivo no
    // tiene Ruta. Se dice explícitamente en vez de devolver una lista vacía.
    throw conflict(
      'Esa cuenta es de Open Learning: no tiene Ruta de Impacto.',
      { studentType: target.studentType },
    );
  }

  return c.json({
    studentId: target.id,
    studentName: target.name,
    laboratories: await rutaProgressFor(db, target.id),
  });
});

/** Progreso de un estudiante en UN curso, con las lecciones ya completadas. */
studentRoutes.get('/:id/course-progress/:courseId', async (c) => {
  const db = c.get('db');
  const target = await loadTarget(db, currentUser(c), c.req.param('id'));
  const courseId = c.req.param('courseId');

  const progress = await courseProgressFor(db, target.id, courseId);
  if (!progress) {
    // Sin fila en la vista, el estudiante no tiene acceso a ese curso.
    throw notFound('El estudiante no tiene acceso a ese curso.');
  }

  return c.json({
    ...progress,
    studentId: target.id,
    completedLessonIds: await completedLessonIds(db, target.id, courseId),
  });
});

/** Si ya puede emitirse el certificado, y si no, qué falta exactamente. */
studentRoutes.get(
  '/:id/certificate-eligibility/:laboratoryId',
  requireEnactus,
  async (c) => {
    const db = c.get('db');
    const target = await loadTarget(db, currentUser(c), c.req.param('id'));
    const eligibility = await rutaCertificateEligibility(
      db,
      target.id,
      c.req.param('laboratoryId'),
    );
    return c.json(eligibility);
  },
);
