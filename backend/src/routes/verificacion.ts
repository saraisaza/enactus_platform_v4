import { eq } from 'drizzle-orm';
import { Hono } from 'hono';

import { certificates } from '../db/schema';
import { notFound } from '../lib/errors';
import type { AppEnv } from '../middleware/context';
import { rateLimit } from '../middleware/rate-limit';

/**
 * Verificar un certificado, sin iniciar sesión.
 *
 * Es lo que abre el QR impreso en el certificado: cualquiera que lo reciba
 * —una empresa que contrata, por ejemplo— comprueba que es real y qué dice.
 *
 * Se busca por el id del certificado (un UUID, imposible de adivinar), no por
 * el código visible: los códigos de la Ruta son de cinco cifras, y por código
 * alguien podría recorrerlos todos y sacar la lista de quiénes se
 * certificaron. Se responde solo lo que el certificado ya dice impreso.
 */
export const verificacionRoutes = new Hono<AppEnv>();

verificacionRoutes.use(
  '*',
  rateLimit({
    max: 30,
    windowMs: 60 * 1000,
    readsBody: false,
    keyOf: (c) => `verificar:${c.get('requestIp')}`,
  }),
);

verificacionRoutes.get('/:id', async (c) => {
  const [cert] = await c
    .get('db')
    .select()
    .from(certificates)
    .where(eq(certificates.id, c.req.param('id')))
    .limit(1);
  if (!cert) throw notFound('No encontramos ese certificado.');

  return c.json({
    code: cert.code,
    studentName: cert.studentNameSnapshot,
    kind: cert.courseId ? 'course' : 'ruta',
    title: cert.courseNameSnapshot ?? cert.laboratoryNameSnapshot ?? '',
    hours: cert.hours,
    issuer: cert.issuerNameSnapshot,
    issuedAt: cert.issuedAt,
  });
});
