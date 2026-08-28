import { randomUUID } from 'node:crypto';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

import { env } from '../env';
import { AppError, badRequest, payloadTooLarge } from './errors';

/**
 * Subida de archivos a S3 con presigned URL.
 *
 * El archivo va SIEMPRE directo del navegador a S3, nunca a través de la API:
 * API Gateway corta el payload en 10 MB y un video lo revienta. La API solo
 * firma el permiso y después recibe la confirmación.
 */

/** Tope por archivo de video. */
export const MAX_VIDEO_BYTES = 500 * 1024 * 1024; // 500 MB

/** Los dos formatos que reproducen nativamente todos los navegadores. */
export const ALLOWED_VIDEO_TYPES = ['video/mp4', 'video/webm'] as const;

/** Vigencia de la URL de subida: corta, es un permiso puntual. */
const UPLOAD_URL_TTL_SECONDS = 900; // 15 min

let client: S3Client | null = null;

function s3(): S3Client {
  client ??= new S3Client({ region: env.AWS_REGION });
  return client;
}

export function isStorageConfigured(): boolean {
  return env.S3_BUCKET.length > 0;
}

/**
 * Valida tamaño y tipo ANTES de firmar nada.
 *
 * El orden importa: una URL firmada es un permiso de escritura sobre el
 * bucket, así que no se emite hasta que el archivo pasa las reglas.
 */
export function assertValidVideoUpload(input: {
  contentType: string;
  sizeBytes: number;
}): void {
  if (!(ALLOWED_VIDEO_TYPES as readonly string[]).includes(input.contentType)) {
    throw badRequest(
      `Formato de video no permitido: ${input.contentType}. ` +
        `Se aceptan ${ALLOWED_VIDEO_TYPES.join(' y ')}. ` +
        'Recomendación: MP4 con H.264 a 720p.',
      { allowed: ALLOWED_VIDEO_TYPES },
    );
  }
  if (!Number.isFinite(input.sizeBytes) || input.sizeBytes <= 0) {
    throw badRequest('El tamaño del archivo es obligatorio y debe ser mayor a 0.');
  }
  if (input.sizeBytes > MAX_VIDEO_BYTES) {
    throw payloadTooLarge(
      `El video pesa ${(input.sizeBytes / 1024 / 1024).toFixed(1)} MB y el máximo son 500 MB.`,
      { maxBytes: MAX_VIDEO_BYTES },
    );
  }
}

/** Key determinística y sin colisiones para un archivo de video de lección. */
export function videoKeyFor(lessonId: string, contentType: string): string {
  const ext = contentType === 'video/webm' ? 'webm' : 'mp4';
  return `lessons/${lessonId}/${randomUUID()}.${ext}`;
}

/** Genera la URL firmada de subida (PUT directo del navegador a S3). */
export async function createUploadUrl(input: {
  key: string;
  contentType: string;
  sizeBytes: number;
}): Promise<{ uploadUrl: string; key: string; expiresInSeconds: number }> {
  if (!isStorageConfigured()) {
    // Se dice qué falta en vez de devolver una URL falsa que rompería más
    // adelante, cuando el navegador intente subir.
    throw new AppError(
      503,
      'storage_not_configured',
      'El almacenamiento de archivos no está configurado en este entorno (falta S3_BUCKET).',
    );
  }

  const command = new PutObjectCommand({
    Bucket: env.S3_BUCKET,
    Key: input.key,
    ContentType: input.contentType,
    ContentLength: input.sizeBytes,
  });

  const uploadUrl = await getSignedUrl(s3(), command, {
    expiresIn: UPLOAD_URL_TTL_SECONDS,
  });

  return { uploadUrl, key: input.key, expiresInSeconds: UPLOAD_URL_TTL_SECONDS };
}
