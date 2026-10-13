import { desc, eq, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import { certificates } from '../db/schema';
import { forbidden, notFound } from '../lib/errors';
import { paginated, paginationSchema } from '../lib/pagination';
import {
  assertCanGrade,
  assertSelfOr,
  currentUser,
  isStudentLike,
  requireAuth,
  requireCanGrade,
} from '../middleware/auth';
import type { AppEnv, AuthUser } from '../middleware/context';
import { issueRutaCertificate } from '../services/certificates';
import { moldeParaCertificado, moldeParaLaApp } from '../services/moldes-de-certificado';
import { genteDeLaEmpresa, supervisorAlcanza } from '../services/alcance-supervisor';
import { mismoCliente } from '../services/frontera-de-cliente';

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
    if (user.role === 'supervisor') {
      if (!(await supervisorAlcanza(db, user, targetId))) {
        throw forbidden('Solo puede ver a la gente de su empresa.');
      }
    } else {
      assertSelfOr(user, targetId, ['admin', 'superadmin', 'advisor', 'mentor', 'lxd']);
    }
    // De otro cliente es lo mismo que no existir.
    if (!(await mismoCliente(db, user, targetId))) {
      throw notFound('No se encontró el estudiante.');
    }
    const rows = await db
      .select()
      .from(certificates)
      .where(eq(certificates.studentId, targetId))
      .orderBy(desc(certificates.issuedAt));
    return c.json(paginated(rows, rows.length, query));
  }

  // Sin `studentId`, cada rol ve lo suyo: el emisor los que emitió, el
  // administrador todos.
  if (user.role === 'supervisor') {
    // Quién de su empresa se certificó: es una de las tres cosas que le
    // importan, junto con el avance y las entregas.
    const rows = await db
      .select()
      .from(certificates)
      .where(sql`${certificates.studentId} in ${genteDeLaEmpresa(user.clientId)}`)
      .orderBy(desc(certificates.issuedAt));
    return c.json(paginated(rows, rows.length, query));
  }

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

/**
 * ¿[user] puede ver el certificado [cert]? Las mismas reglas que el listado:
 * la persona, quien lo emitió, la administración, el supervisor de su empresa
 * y el equipo (asesor, mentor, LXD) del mismo cliente.
 */
async function puedeVerCertificado(
  db: AppEnv['Variables']['db'],
  user: AuthUser,
  cert: typeof certificates.$inferSelect,
): Promise<boolean> {
  if (user.role === 'admin' || user.role === 'superadmin') return true;
  if (cert.studentId === user.id || cert.issuerId === user.id) return true;
  if (user.role === 'supervisor') return supervisorAlcanza(db, user, cert.studentId);
  if (user.role === 'advisor' || user.role === 'mentor' || user.role === 'lxd') {
    return mismoCliente(db, user, cert.studentId);
  }
  return false;
}

/**
 * El molde con que se imprime un certificado: el de su cliente emisor, o el
 * de eduXaction; `null` = el diseño de siempre. Con los enlaces firmados del
 * fondo y la firma, para que la app arme el PDF.
 */
certificateRoutes.get('/:id/template', async (c) => {
  const db = c.get('db');
  const [cert] = await db
    .select()
    .from(certificates)
    .where(eq(certificates.id, c.req.param('id')))
    .limit(1);
  if (!cert || !(await puedeVerCertificado(db, currentUser(c), cert))) {
    throw notFound('No encontramos ese certificado.');
  }
  const molde = await moldeParaCertificado(db, cert.issuerClientId);
  return c.json({ template: molde ? await moldeParaLaApp(molde) : null });
});
