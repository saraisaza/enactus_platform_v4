import { randomUUID } from 'node:crypto';

import { asc, desc, eq, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import type { Database } from '../db/client';
import { auditLog, clients, storagePendingDeletes } from '../db/schema';
import { badRequest, conflict, notFound, payloadTooLarge } from '../lib/errors';
import { mediaStorage } from '../lib/media-storage';
import { parcial } from '../lib/parcial';
import { BYTES_PARA_RECONOCER_PNG, medidasDePng } from '../lib/png';
import { createDownloadUrl, isStorageConfigured } from '../lib/s3';
import { ADMIN_ROLES, currentUser, requireAuth, requireRole } from '../middleware/auth';
import type { AppEnv } from '../middleware/context';
import { drainStorageDeletes } from '../services/storage-cleanup';

/**
 * Clientes de la plataforma —las empresas y Enactus— y su marca.
 *
 * Todo esto es de administración: crear un cliente, ponerle logo y colores,
 * editarlo y desactivarlo. Quien pertenece a un cliente recibe su marca al
 * iniciar sesión, por otro camino (`/auth/me`), y nunca la de otro.
 */
export const clientRoutes = new Hono<AppEnv>();
clientRoutes.use('*', requireAuth, requireRole(...ADMIN_ROLES));

/** El logo: un PNG (admite transparencia) de hasta 1 MB. */
export const LOGO_TYPE = 'image/png';
export const MAX_LOGO_BYTES = 1024 * 1024;
/**
 * Medidas del logo. El lado mayor tiene que tener al menos 200 px: el logo se
 * dibuja hasta 64 px de alto en pantallas que tienen dos o tres píxeles
 * físicos por punto, y uno más chico se ve borroso. Más de 4000 px por lado
 * no aporta nada en un encabezado y pesa en un teléfono al decodificarlo.
 */
export const LOGO_MIN_LADO_MAYOR = 200;
export const LOGO_MAX_LADO = 4000;

const CARPETA_LOGOS = 'client-logos/';

/** Un color como lo puede escribir una persona: `#1a73e8`, `1A73E8`… */
const colorHex = z
  .string()
  .trim()
  .transform((v) => (v.startsWith('#') ? v : `#${v}`).toUpperCase())
  .refine((v) => /^#[0-9A-F]{6}$/.test(v), {
    message: 'El color tiene que ser un código hexadecimal de seis dígitos, como #1A73E8.',
  });

const crearBody = z.object({
  name: z
    .string()
    .trim()
    .min(2, 'Escriba el nombre del cliente.')
    .max(80, 'El nombre es demasiado largo.')
    .transform((v) => v.replace(/\s+/g, ' ')),
  primaryColor: colorHex.nullable().optional(),
  secondaryColor: colorHex.nullable().optional(),
  logoS3Key: z.string().trim().min(1).nullable().optional(),
  logoLightPlate: z.boolean().default(false),
});

/** Todo opcional; `null` en un color o en el logo los quita. */
const editarBody = parcial(crearBody).extend({ active: z.boolean().optional() });

const logoUploadBody = z.object({
  contentType: z.string().trim().min(1),
  sizeBytes: z.number().int().positive(),
});

/** Columnas que salen en la API (la URL del logo se agrega al responder). */
const columnas = {
  id: clients.id,
  name: clients.name,
  logoS3Key: clients.logoS3Key,
  logoWidth: clients.logoWidth,
  logoHeight: clients.logoHeight,
  logoLightPlate: clients.logoLightPlate,
  primaryColor: clients.primaryColor,
  secondaryColor: clients.secondaryColor,
  hasLaboratories: clients.hasLaboratories,
  active: clients.active,
  createdAt: clients.createdAt,
  updatedAt: clients.updatedAt,
};

/** `columnas` son todas las de la tabla: la fila completa. */
type FilaCliente = typeof clients.$inferSelect;

/**
 * El cliente con la URL de su logo ya firmada, como la galería de la portada:
 * el panel la pinta tal cual, sin un pedido más por cada logo.
 */
async function conUrlDelLogo(fila: FilaCliente) {
  let logoUrl: string | null = null;
  if (fila.logoS3Key && isStorageConfigured()) {
    try {
      logoUrl = (await createDownloadUrl({ key: fila.logoS3Key })).url;
    } catch {
      // Un logo que no se puede firmar no tumba la lista: se ve sin logo.
    }
  }
  return { ...fila, logoUrl };
}

clientRoutes.get('/', async (c) => {
  const filas = await c
    .get('db')
    .select(columnas)
    .from(clients)
    // Enactus primero: es el cliente que más cuentas tiene.
    .orderBy(desc(clients.hasLaboratories), asc(clients.name));
  return c.json({ data: await Promise.all(filas.map(conUrlDelLogo)) });
});

/**
 * Permiso para subir un logo: un `PUT` simple, como la portada de un video.
 *
 * No va atado a un cliente porque el logo se elige en el mismo formulario en
 * que se crea el cliente, antes de que exista. Lo que sí queda atado es la
 * carpeta: la key la arma el servidor y `POST`/`PATCH` solo aceptan keys de
 * `client-logos/`.
 */
clientRoutes.post('/logo-upload-url', async (c) => {
  const body = logoUploadBody.parse(await c.req.json());
  if (body.contentType !== LOGO_TYPE) {
    throw badRequest(
      `El logo tiene que ser PNG (idealmente con fondo transparente); este archivo es ${body.contentType}.`,
      { allowed: [LOGO_TYPE] },
    );
  }
  if (body.sizeBytes > MAX_LOGO_BYTES) {
    throw payloadTooLarge(
      `El logo pesa ${(body.sizeBytes / 1024 / 1024).toFixed(1)} MB y el máximo es 1 MB.`,
      { maxBytes: MAX_LOGO_BYTES },
    );
  }

  const key = `${CARPETA_LOGOS}${randomUUID()}.png`;
  const uploadUrl = await mediaStorage().signPutObject(key, LOGO_TYPE, body.sizeBytes);
  return c.json({
    key,
    uploadUrl,
    method: 'PUT',
    headers: { 'Content-Type': LOGO_TYPE },
  });
});

/**
 * Comprueba el logo YA subido y devuelve sus medidas.
 *
 * No se fía de lo que dijo el navegador al pedir el permiso: mira el archivo.
 * Que exista, que pese lo permitido y que sus primeros bytes sean de un PNG.
 */
async function verificarLogo(key: string): Promise<{ width: number; height: number }> {
  if (!key.startsWith(CARPETA_LOGOS) || key.includes('..')) {
    throw badRequest('El logo tiene que subirse desde el panel de clientes.');
  }
  const storage = mediaStorage();
  const tamano = await storage.objectSize(key);
  if (tamano === null) {
    throw conflict('El logo no llegó al almacenamiento. Súbalo de nuevo.');
  }
  if (tamano > MAX_LOGO_BYTES) {
    throw payloadTooLarge(
      `El logo pesa ${(tamano / 1024 / 1024).toFixed(1)} MB y el máximo es 1 MB.`,
      { maxBytes: MAX_LOGO_BYTES },
    );
  }
  const inicio = await storage.readObjectStart(key, BYTES_PARA_RECONOCER_PNG);
  const medidas = inicio ? medidasDePng(inicio) : null;
  if (!medidas) {
    throw badRequest(
      'El archivo no es un PNG, aunque su nombre termine en .png. Expórtelo de nuevo como PNG.',
    );
  }
  const mayor = Math.max(medidas.width, medidas.height);
  if (mayor < LOGO_MIN_LADO_MAYOR) {
    throw badRequest(
      `El logo mide ${medidas.width}×${medidas.height} px: se vería borroso. Súbalo de al menos ${LOGO_MIN_LADO_MAYOR} px en su lado más largo.`,
    );
  }
  if (medidas.width > LOGO_MAX_LADO || medidas.height > LOGO_MAX_LADO) {
    throw badRequest(
      `El logo mide ${medidas.width}×${medidas.height} px y el máximo son ${LOGO_MAX_LADO} px por lado. Redúzcalo antes de subirlo.`,
    );
  }
  return medidas;
}

async function nombreLibre(db: Database, name: string, salvoId?: string): Promise<void> {
  const [otro] = await db
    .select({ id: clients.id })
    .from(clients)
    .where(sql`lower(${clients.name}) = lower(${name})`)
    .limit(1);
  if (otro && otro.id !== salvoId) {
    throw conflict(`Ya existe un cliente llamado «${name}».`);
  }
}

/** Un `23505` de Postgres: dos altas con el mismo nombre al mismo tiempo. */
function esNombreRepetido(error: unknown): boolean {
  const causa = (error as { cause?: unknown })?.cause ?? error;
  return (causa as { code?: unknown })?.code === '23505';
}

clientRoutes.post('/', async (c) => {
  const admin = currentUser(c);
  const body = crearBody.parse(await c.req.json());
  const db = c.get('db');

  await nombreLibre(db, body.name);
  const logo = body.logoS3Key ? await verificarLogo(body.logoS3Key) : null;

  let creado: FilaCliente | undefined;
  try {
    [creado] = await db
      .insert(clients)
      .values({
        name: body.name,
        primaryColor: body.primaryColor ?? null,
        secondaryColor: body.secondaryColor ?? null,
        logoS3Key: logo ? body.logoS3Key : null,
        logoWidth: logo?.width ?? null,
        logoHeight: logo?.height ?? null,
        logoLightPlate: body.logoLightPlate,
      })
      .returning(columnas);
  } catch (error) {
    if (esNombreRepetido(error)) throw conflict(`Ya existe un cliente llamado «${body.name}».`);
    throw error;
  }

  await db.insert(auditLog).values({
    actorId: admin.id,
    action: 'client.create',
    entityType: 'client',
    entityId: creado!.id,
    newValue: creado,
    ip: c.get('requestIp'),
  });
  return c.json(await conUrlDelLogo(creado!), 201);
});

clientRoutes.patch('/:id', async (c) => {
  const admin = currentUser(c);
  const body = editarBody.parse(await c.req.json());
  const db = c.get('db');
  const id = c.req.param('id');

  const [antes] = await db.select(columnas).from(clients).where(eq(clients.id, id)).limit(1);
  if (!antes) throw notFound('No se encontró el cliente.');

  // Desactivar un cliente le cierra la sesión a todas sus cuentas. Con
  // Enactus serían todos los estudiantes, asesores y mentores de la red, con
  // un solo clic: no se hace desde el panel.
  if (body.active === false && antes.hasLaboratories) {
    throw conflict(
      'Enactus no se puede desactivar desde el panel: dejaría sin acceso a toda su red.',
    );
  }
  if (body.name !== undefined) await nombreLibre(db, body.name, id);

  const cambios: Partial<typeof clients.$inferInsert> = { updatedAt: new Date() };
  if (body.name !== undefined) cambios.name = body.name;
  if (body.primaryColor !== undefined) cambios.primaryColor = body.primaryColor;
  if (body.secondaryColor !== undefined) cambios.secondaryColor = body.secondaryColor;
  if (body.logoLightPlate !== undefined) cambios.logoLightPlate = body.logoLightPlate;
  if (body.active !== undefined) cambios.active = body.active;
  if (body.logoS3Key !== undefined && body.logoS3Key !== antes.logoS3Key) {
    const logo = body.logoS3Key ? await verificarLogo(body.logoS3Key) : null;
    cambios.logoS3Key = body.logoS3Key;
    cambios.logoWidth = logo?.width ?? null;
    cambios.logoHeight = logo?.height ?? null;
  }

  let despues: FilaCliente | undefined;
  try {
    [despues] = await db.update(clients).set(cambios).where(eq(clients.id, id)).returning(columnas);
  } catch (error) {
    if (esNombreRepetido(error)) throw conflict(`Ya existe un cliente llamado «${body.name}».`);
    throw error;
  }

  // El logo anterior ya no lo usa nadie: a la cola de borrado. La cola
  // comprueba antes de borrar que ningún cliente lo haya vuelto a tomar.
  if (antes.logoS3Key && despues!.logoS3Key !== antes.logoS3Key) {
    await db
      .insert(storagePendingDeletes)
      .values({ key: antes.logoS3Key, reason: 'client_logo_replaced' })
      .onConflictDoNothing();
    await drainStorageDeletes(db);
  }

  await db.insert(auditLog).values({
    actorId: admin.id,
    action:
      body.active === false && antes.active
        ? 'client.deactivate'
        : body.active === true && !antes.active
          ? 'client.activate'
          : 'client.update',
    entityType: 'client',
    entityId: id,
    oldValue: antes,
    newValue: despues,
    ip: c.get('requestIp'),
  });
  return c.json(await conUrlDelLogo(despues!));
});
