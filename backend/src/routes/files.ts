import { Hono } from 'hono';
import { z } from 'zod';

import {
  assertValidDocumentUpload,
  createUploadUrl,
  documentKeyFor,
} from '../lib/s3';
import { forbidden } from '../lib/errors';
import { currentUser, requireAuth } from '../middleware/auth';
import type { AppEnv } from '../middleware/context';

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
  purpose: z.enum(['evidence', 'communication_resource', 'submission', 'avatar']),
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
};

const FOLDER: Record<string, string> = {
  evidence: 'evidences',
  communication_resource: 'communication-resources',
  submission: 'submissions',
  avatar: 'avatars',
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
