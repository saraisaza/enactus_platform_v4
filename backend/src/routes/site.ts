import { asc, eq, isNull } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import { laboratories, siteContent, siteGalleryImages } from '../db/schema';
import { createDownloadUrl, isStorageConfigured } from '../lib/s3';
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
  const db = c.get('db');
  const [row] = await db
    .select()
    .from(siteContent)
    .where(eq(siteContent.id, 1))
    .limit(1);

  // Los laboratorios de la portada son contenido de marketing: nombre y
  // descripción, nada más. Van acá y NO en `/laboratories`, que sigue
  // exigiendo sesión y aislando por rol — un estudiante de Open Learning
  // debe seguir recibiendo 403 ahí.
  const labs = await db
    .select({
      id: laboratories.id,
      name: laboratories.name,
      description: laboratories.description,
    })
    .from(laboratories)
    .where(isNull(laboratories.deletedAt))
    .orderBy(asc(laboratories.name));

  // Galería del hero: acá se devuelven URLs YA FIRMADAS, no keys.
  //
  // Es la excepción al resto de los archivos, que se firman uno por uno con
  // `POST /files/download-url` tras comprobar permisos. Acá no hay a quién
  // comprobarle nada —la portada se ve sin sesión— y el contenido es público
  // por definición, así que el servidor firma al construir la respuesta. Si
  // no lo hiciera, un visitante sin cuenta no tendría forma de ver la galería.
  const gallery = await db
    .select({ s3Key: siteGalleryImages.s3Key })
    .from(siteGalleryImages)
    .orderBy(asc(siteGalleryImages.orderIndex));

  const galleryImages = isStorageConfigured()
    ? (
        await Promise.all(
          gallery.map(async (g) => {
            try {
              return (await createDownloadUrl({ key: g.s3Key })).url;
            } catch {
              // Una imagen que no se puede firmar se omite. La portada se
              // dibuja igual: una galería incompleta es mejor que una portada
              // caída por un archivo que alguien borró del bucket.
              return null;
            }
          }),
        )
      ).filter((url): url is string => url !== null)
    : [];

  // Sin fila todavía se devuelven los valores por defecto: la portada nunca
  // debe quedar en blanco por un dato de configuración que falta.
  return c.json({
    ...(row ?? DEFAULTS),
    laboratories: labs,
    galleryImages,
  });
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
