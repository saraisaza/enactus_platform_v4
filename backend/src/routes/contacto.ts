import { and, inArray, isNull } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import { notifications, users } from '../db/schema';
import type { AppEnv } from '../middleware/context';
import { ADMIN_ROLES } from '../middleware/auth';
import { rateLimit } from '../middleware/rate-limit';

/**
 * El formulario «Contáctenos» de la portada, sin iniciar sesión.
 *
 * Antes el formulario decía «¡Mensaje enviado!» pero el mensaje no salía de
 * la consola del navegador: quien escribía para conocer eduXaction se perdía
 * sin que nadie se enterara. Ahora llega como aviso a cada administrador, con
 * nombre, correo, empresa y mensaje, en la campana de su portal.
 *
 * Es público, así que va con su propio límite —pocos mensajes por IP— y con
 * una trampa para robots: el campo `website` no se ve en la página; si llega
 * lleno, lo escribió un programa, y se responde como si nada sin avisar.
 */
export const contactoRoutes = new Hono<AppEnv>();

contactoRoutes.use(
  '*',
  rateLimit({
    max: 5,
    windowMs: 10 * 60 * 1000,
    readsBody: false,
    keyOf: (c) => `contacto:${c.get('requestIp')}`,
  }),
);

const mensajeBody = z.object({
  name: z.string().trim().min(1, 'Escriba su nombre.').max(120),
  email: z.email('Ese correo no parece válido.').max(200),
  company: z.string().trim().max(160).default(''),
  message: z.string().trim().min(1, 'Escriba su mensaje.').max(2000),
  website: z.string().default(''),
});

contactoRoutes.post('/', async (c) => {
  const body = mensajeBody.parse(await c.req.json());
  if (body.website.trim() !== '') return c.json({ ok: true }, 202);

  const db = c.get('db');
  const admins = await db
    .select({ id: users.id })
    .from(users)
    .where(and(inArray(users.role, [...ADMIN_ROLES]), isNull(users.deletedAt)));

  const quien = body.company ? `${body.name} (${body.company})` : body.name;
  if (admins.length > 0) {
    await db.insert(notifications).values(
      admins.map((a) => ({
        userId: a.id,
        title: 'Nuevo contacto desde la portada',
        body: `${quien} <${body.email}> escribió:\n\n${body.message}`,
        kind: 'contacto',
        params: {
          nombre: body.name,
          correo: body.email,
          empresa: body.company,
          mensaje: body.message,
        },
      })),
    );
  }
  return c.json({ ok: true }, 202);
});
