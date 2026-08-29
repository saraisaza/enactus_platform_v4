import { desc, eq } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import { certificates } from '../db/schema';
import { paginated, paginationSchema } from '../lib/pagination';
import {
  assertCanGrade,
  assertSelfOr,
  currentUser,
  isStudentLike,
  requireAuth,
  requireCanGrade,
} from '../middleware/auth';
import type { AppEnv } from '../middleware/context';
import { issueRutaCertificate } from '../services/certificates';

export const certificateRoutes = new Hono<AppEnv>();
certificateRoutes.use('*', requireAuth);

const issueBody = z.object({
  studentId: z.uuid(),
  laboratoryId: z.uuid(),
});

const listQuery = paginationSchema.extend({ studentId: z.uuid().optional() });

/**
 * Emite el certificado de Ruta de Impacto.
 *
 * Doble candado, a propósito:
 * 1. Acá se valida que las 3 fases estén completas y, si no, se responde 409
 *    con el detalle de qué falta.
 * 2. La base lo hace cumplir igual con el trigger
 *    `certificates_require_complete_ruta`. Si algún día alguien agrega otra
 *    vía de escritura, el requisito sigue en pie.
 *
 * `assertCanGrade(user, false)`: la Ruta de Impacto es contexto Enactus, así
 * que hace falta `can_grade_enactus` — no alcanza con el de Open Learning.
 */
certificateRoutes.post('/ruta', requireCanGrade, async (c) => {
  const user = currentUser(c);
  assertCanGrade(user, false);

  const body = issueBody.parse(await c.req.json());
  const created = await issueRutaCertificate(c.get('db'), {
    studentId: body.studentId,
    laboratoryId: body.laboratoryId,
    issuerId: user.id,
    ip: c.get('requestIp'),
  });

  return c.json(created, 201);
});

/** Certificados: los propios, o los de un estudiante si el rol lo permite. */
certificateRoutes.get('/', async (c) => {
  const user = currentUser(c);
  const query = listQuery.parse(c.req.query());
  const db = c.get('db');

  const targetId = query.studentId ?? (isStudentLike(user.role) ? user.id : null);

  if (targetId) {
    assertSelfOr(user, targetId, ['admin', 'superadmin', 'advisor', 'mentor', 'lxd']);
    const rows = await db
      .select()
      .from(certificates)
      .where(eq(certificates.studentId, targetId))
      .orderBy(desc(certificates.issuedAt));
    return c.json(paginated(rows, rows.length, query));
  }

  // Sin `studentId`, cada rol ve lo suyo: el emisor los que emitió, el
  // administrador todos.
  const rows =
    user.role === 'admin' || user.role === 'superadmin'
      ? await db
          .select()
          .from(certificates)
          .orderBy(desc(certificates.issuedAt))
          .limit(query.pageSize)
          .offset((query.page - 1) * query.pageSize)
      : await db
          .select()
          .from(certificates)
          .where(eq(certificates.issuerId, user.id))
          .orderBy(desc(certificates.issuedAt));

  return c.json(paginated(rows, rows.length, query));
});
