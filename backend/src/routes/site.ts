import { asc, eq, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import { laboratories, siteContent, siteGalleryImages } from '../db/schema';
import { conflict, notFound } from '../lib/errors';
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
    .select({ id: siteGalleryImages.id, s3Key: siteGalleryImages.s3Key })
    .from(siteGalleryImages)
    .orderBy(asc(siteGalleryImages.orderIndex));

  const galleryFirmada = isStorageConfigured()
    ? (
        await Promise.all(
          gallery.map(async (g) => {
            try {
              return {
                id: g.id,
                url: (await createDownloadUrl({ key: g.s3Key })).url,
              };
            } catch {
              // Una imagen que no se puede firmar se omite. La portada se
              // dibuja igual: una galería incompleta es mejor que una portada
              // caída por un archivo que alguien borró del bucket.
              return null;
            }
          }),
        )
      ).filter((g): g is { id: string; url: string } => g !== null)
    : [];

  const galleryImages = galleryFirmada.map((g) => g.url);

  // Sin fila todavía se devuelven los valores por defecto: la portada nunca
  // debe quedar en blanco por un dato de configuración que falta.
  return c.json({
    ...(row ?? DEFAULTS),
    laboratories: labs,
    galleryImages,
    // La misma galería con su id, para poder administrarla. `galleryImages`
    // se queda como está —una lista de URLs listas para pintar— porque es lo
    // que consume la portada, que no necesita ids ni sabe qué es un id.
    gallery: galleryFirmada,
  });
});

const galleryBody = z.object({
  s3Key: z
    .string()
    .trim()
    .regex(/^site-gallery\//, 'La imagen tiene que subirse desde el editor.'),
});

/**
 * Agrega una imagen a la galería de la portada.
 *
 * La key va restringida a `site-gallery/`, que es donde la deja
 * `POST /files/upload-url`. Sin esa restricción, quien administra el sitio
 * podría publicar en la portada —que se ve SIN sesión— la key de un adjunto
 * de entrega o de una evidencia privada, y el servidor la firmaría para
 * cualquiera que entrara.
 */
siteRoutes.post('/gallery', requireAuth, requireRole(...ADMIN_ROLES), async (c) => {
  const body = galleryBody.parse(await c.req.json());
  const db = c.get('db');

  const [{ next } = { next: 0 }] = await db.execute<{ next: number }>(sql`
    select coalesce(max(order_index), -1) + 1 as next from site_gallery_images
  `);

  const [created] = await db
    .insert(siteGalleryImages)
    .values({ s3Key: body.s3Key, orderIndex: next })
    // La misma imagen dos veces no es un error: ya estaba.
    .onConflictDoNothing()
    .returning();

  if (!created) throw conflict('Esa imagen ya está en la galería.');
  return c.json(created, 201);
});

siteRoutes.delete(
  '/gallery/:id',
  requireAuth,
  requireRole(...ADMIN_ROLES),
  async (c) => {
    const [deleted] = await c
      .get('db')
      .delete(siteGalleryImages)
      .where(eq(siteGalleryImages.id, c.req.param('id')))
      .returning({ id: siteGalleryImages.id });
    if (!deleted) throw notFound('No se encontró esa imagen.');
    return c.body(null, 204);
  },
);

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
