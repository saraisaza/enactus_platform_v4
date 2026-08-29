import { eq } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import { siteContent } from '../db/schema';
import { ADMIN_ROLES, currentUser, requireAuth, requireRole } from '../middleware/auth';
import type { AppEnv } from '../middleware/context';

/**
 * Contenido de la página principal.
 *
 * La lectura es PÚBLICA: la portada se ve sin sesión, así que este es el único
 * endpoint de la API sin `requireAuth`. No expone nada sensible — es el texto
 * y las cifras que el equipo cura a mano para el hero.
 */
export const siteRoutes = new Hono<AppEnv>();

const bodySchema = z.object({
  heroTitle: z.string().trim().min(1),
  heroSubtitle: z.string().trim().default(''),
  bannerText: z.string().trim().default(''),
  aboutText: z.string().trim().default(''),
  meetingLink: z.string().trim().default(''),
  statStudents: z.number().int().min(0).default(0),
  statProjects: z.number().int().min(0).default(0),
  statLabs: z.number().int().min(0).default(0),
  statUniversities: z.number().int().min(0).default(0),
});

const DEFAULTS = {
  id: 1,
  heroTitle: 'eduXaction Colombia',
  heroSubtitle: '',
  bannerText: '',
  aboutText: '',
  meetingLink: '',
  statStudents: 0,
  statProjects: 0,
  statLabs: 0,
  statUniversities: 0,
};

siteRoutes.get('/', async (c) => {
  const [row] = await c
    .get('db')
    .select()
    .from(siteContent)
    .where(eq(siteContent.id, 1))
    .limit(1);
  // Sin fila todavía se devuelven los valores por defecto: la portada nunca
  // debe quedar en blanco por un dato de configuración que falta.
  return c.json(row ?? DEFAULTS);
});

siteRoutes.patch('/', requireAuth, requireRole(...ADMIN_ROLES), async (c) => {
  const body = bodySchema.parse(await c.req.json());
  const db = c.get('db');
  const [updated] = await db
    .insert(siteContent)
    .values({ ...body, id: 1, updatedBy: currentUser(c).id })
    .onConflictDoUpdate({
      target: siteContent.id,
      set: { ...body, updatedBy: currentUser(c).id, updatedAt: new Date() },
    })
    .returning();
  return c.json(updated);
});
