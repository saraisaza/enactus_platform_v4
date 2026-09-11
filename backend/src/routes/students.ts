import { and, eq, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';

import { users } from '../db/schema';
import { conflict, forbidden, notFound } from '../lib/errors';
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

/** Roles del equipo que pueden mirar el progreso de CUALQUIER estudiante. */
const STAFF = ['admin', 'superadmin', 'advisor', 'mentor', 'lxd'] as const;

/**
 * ¿Esta empresa patrocina algún laboratorio de este estudiante?
 *
 * Una empresa que patrocina un laboratorio ve a su gente —eso ya lo hacía el
 * alcance de `GET /users`— pero la Ruta de Impacto quedaba fuera: `company` no
 * estaba en `STAFF`, así que el progreso de Ruta devolvía 403.
 *
 * `company` NO entra en `STAFF`, y la diferencia importa: el equipo Enactus ve
 * a todo el mundo, una empresa ve **solo a la gente de los laboratorios que
 * paga**. Meterla en `STAFF` le habría abierto la plataforma entera, que es
 * precisamente la clase de permiso ancho que esta auditoría viene corrigiendo.
 *
 * La regla es la MISMA que usa el alcance de laboratorios en `routes/labs.ts`
 * —patrocinio directo, o un curso de alguno de sus LXD— para que no haya dos
 * definiciones de «mis laboratorios» que puedan discrepar.
 */
async function empresaAlcanzaAlEstudiante(
  db: AppEnv['Variables']['db'],
  companyId: string,
  studentId: string,
): Promise<boolean> {
  const filas = await db.execute<{ hay: number }>(sql`
    select 1 as hay
      from student_laboratories sl
      join laboratories l on l.id = sl.laboratory_id
     where sl.student_id = ${studentId}
       and l.deleted_at is null
       and (l.sponsor_company_id = ${companyId}
            or l.id in (select c.laboratory_id from courses c
                          join users u on u.id = c.creator_id
                         where u.company_id = ${companyId}
                           and c.laboratory_id is not null))
     limit 1`);
  return filas.length > 0;
}

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
  if (viewer.role === 'company') {
    if (!(await empresaAlcanzaAlEstudiante(db, viewer.id, targetId))) {
      throw forbidden(
        'Solo puede ver a los estudiantes de los laboratorios que patrocina.',
      );
    }
  } else {
    assertSelfOr(viewer, targetId, STAFF);
  }
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
