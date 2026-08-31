import { Hono } from 'hono';
import { z } from 'zod';

import {
  assertValidDocumentUpload,
  createDownloadUrl,
  createUploadUrl,
  documentKeyFor,
} from '../lib/s3';
import { forbidden } from '../lib/errors';
import { currentUser, requireAuth } from '../middleware/auth';
import type { AppEnv } from '../middleware/context';
import { authorizeFileRead } from '../services/file-access';

/**
 * URLs firmadas para archivos que NO son video (evidencias, recursos de
 * comunicaciones, adjuntos de entregas, avatares).
 *
 * Mismo principio que el video: el archivo va directo del navegador a S3 y la
 * API solo firma el permiso. Se valida ANTES de firmar.
 */
export const fileRoutes = new Hono<AppEnv>();
fileRoutes.use('*', requireAuth);

const uploadBody = z.object({
  purpose: z.enum([
    'evidence',
    'communication_resource',
    'submission',
    'avatar',
    'course_cover',
    'lesson_resource',
    'site_gallery',
  ]),
  fileName: z.string().trim().min(1, 'Falta el nombre del archivo.'),
  contentType: z.string().trim().min(1, 'Falta el content-type.'),
  sizeBytes: z.number().int().positive('El tamaño debe ser mayor a 0.'),
});

/** Qué roles pueden subir para cada propósito. */
const ALLOWED_ROLES: Record<string, readonly string[]> = {
  evidence: ['admin', 'superadmin'],
  communication_resource: ['admin', 'superadmin'],
  submission: ['student', 'alumni'],
  avatar: ['superadmin', 'admin', 'advisor', 'donor', 'lxd', 'mentor', 'company', 'student', 'alumni'],
  // Material de curso: lo sube quien puede editar contenido. Que la portada o
  // el PDF terminen en ESTE curso lo decide después `PATCH /courses/:id` y
  // `POST /lessons/:id/resource`, cada uno con su propio permiso de edición.
  course_cover: ['lxd', 'admin', 'superadmin'],
  lesson_resource: ['lxd', 'admin', 'superadmin'],
  // La galería de la portada se ve SIN sesión: solo la administra el equipo.
  site_gallery: ['admin', 'superadmin'],
};

const FOLDER: Record<string, string> = {
  evidence: 'evidences',
  communication_resource: 'communication-resources',
  submission: 'submissions',
  avatar: 'avatars',
  course_cover: 'covers',
  lesson_resource: 'lesson-resources',
  site_gallery: 'site-gallery',
};

fileRoutes.post('/upload-url', async (c) => {
  const user = currentUser(c);
  const body = uploadBody.parse(await c.req.json());

  const allowed = ALLOWED_ROLES[body.purpose] ?? [];
  if (!allowed.includes(user.role)) {
    throw forbidden(`Tu rol no puede subir archivos de tipo ${body.purpose}.`);
  }

  assertValidDocumentUpload(body);

  const signed = await createUploadUrl({
    key: documentKeyFor(FOLDER[body.purpose] ?? 'misc', body.fileName),
    contentType: body.contentType,
    sizeBytes: body.sizeBytes,
  });

  return c.json({
    ...signed,
    method: 'PUT',
    headers: { 'Content-Type': body.contentType },
  });
});

const downloadBody = z.object({
  key: z.string().trim().min(1, 'Falta la key del archivo.'),
});

/**
 * URL firmada de LECTURA para un archivo ya subido.
 *
 * Sin esto el cliente puede guardar keys pero no mostrar nada: ni la foto de
 * perfil, ni el PDF de una lección, ni el adjunto que entregó un estudiante.
 *
 * Quién puede leer qué lo decide `authorizeFileRead`, resolviendo la key
 * contra la fila que la referencia — no contra su prefijo. Una key que ninguna
 * tabla referencia responde 404, no 403: un 403 confirmaría que el objeto
 * existe en el bucket.
 *
 * Es POST y no GET a propósito: así la key no queda en el log de acceso de
 * API Gateway ni en el historial del navegador.
 */
fileRoutes.post('/download-url', async (c) => {
  const user = currentUser(c);
  const { key } = downloadBody.parse(await c.req.json());

  const grant = await authorizeFileRead(c.get('db'), user, key);
  const signed = await createDownloadUrl({
    key: grant.key,
    fileName: grant.fileName ?? undefined,
  });

  return c.json({
    url: signed.url,
    expiresInSeconds: signed.expiresInSeconds,
    fileName: grant.fileName,
    contentType: grant.contentType,
  });
});
