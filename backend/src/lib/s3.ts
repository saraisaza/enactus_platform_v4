import { randomUUID } from 'node:crypto';
import { GetObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
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

  const uploadUrl = await signOrFail(() =>
    getSignedUrl(s3(), command, { expiresIn: UPLOAD_URL_TTL_SECONDS }),
  );

  return { uploadUrl, key: input.key, expiresInSeconds: UPLOAD_URL_TTL_SECONDS };
}

/**
 * Vigencia de la URL de lectura.
 *
 * Más larga que la de subida porque tiene que sobrevivir a que la persona deje
 * la pestaña abierta un rato antes de abrir el archivo, y bastante más corta
 * que la sesión: una URL firmada es un permiso que viaja suelto, sin token.
 */
const DOWNLOAD_URL_TTL_SECONDS = 3600; // 1 hora

/**
 * URL firmada de LECTURA para una key concreta.
 *
 * Quién puede leer qué **no se decide acá**: esta función solo firma. La
 * autorización vive en `services/file-access.ts`, que resuelve la key contra la
 * tabla que la referencia. Firmar sin ese paso equivale a publicar el bucket.
 */
export async function createDownloadUrl(input: {
  key: string;
  /** Nombre con el que se descarga. Sin esto el navegador usa el uuid. */
  fileName?: string;
}): Promise<{ url: string; expiresInSeconds: number }> {
  if (!isStorageConfigured()) {
    throw new AppError(
      503,
      'storage_not_configured',
      'El almacenamiento de archivos no está configurado en este entorno (falta S3_BUCKET).',
    );
  }

  const command = new GetObjectCommand({
    Bucket: env.S3_BUCKET,
    Key: input.key,
    ...(input.fileName
      ? {
          ResponseContentDisposition: `inline; filename="${input.fileName.replace(/"/g, '')}"`,
        }
      : {}),
  });

  const url = await signOrFail(() =>
    getSignedUrl(s3(), command, { expiresIn: DOWNLOAD_URL_TTL_SECONDS }),
  );

  return { url, expiresInSeconds: DOWNLOAD_URL_TTL_SECONDS };
}

/**
 * Traduce un fallo de FIRMA a un 503 con causa clara.
 *
 * Sin esto, unas credenciales de AWS vencidas —el caso más común: las
 * temporales de una sesión SSO— salen como 500 «error interno», y quien lo
 * recibe no puede distinguir "el servidor está roto" de "el almacenamiento no
 * está disponible ahora". Es exactamente lo que pasó al correr las pruebas con
 * la sesión de AWS caducada.
 *
 * 503 y no 500 porque es transitorio: se arregla renovando credenciales, no
 * tocando código.
 */
async function signOrFail<T>(sign: () => Promise<T>): Promise<T> {
  try {
    return await sign();
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    throw new AppError(
      503,
      'storage_unavailable',
      'No pudimos preparar el archivo: el almacenamiento no está disponible ' +
        'en este momento. Si el problema sigue, avisá al equipo técnico.',
      { detail },
    );
  }
}

/** Tope para documentos (evidencias, recursos, entregas). */
export const MAX_DOCUMENT_BYTES = 25 * 1024 * 1024; // 25 MB

export const ALLOWED_DOCUMENT_TYPES = [
  'application/pdf',
  'image/jpeg',
  'image/png',
  'image/svg+xml',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/zip',
] as const;

export function assertValidDocumentUpload(input: {
  contentType: string;
  sizeBytes: number;
}): void {
  if (!(ALLOWED_DOCUMENT_TYPES as readonly string[]).includes(input.contentType)) {
    throw badRequest(`Tipo de archivo no permitido: ${input.contentType}.`, {
      allowed: ALLOWED_DOCUMENT_TYPES,
    });
  }
  if (input.sizeBytes > MAX_DOCUMENT_BYTES) {
    throw payloadTooLarge(
      `El archivo pesa ${(input.sizeBytes / 1024 / 1024).toFixed(1)} MB y el máximo son 25 MB.`,
      { maxBytes: MAX_DOCUMENT_BYTES },
    );
  }
}

/** Key para un archivo que no es video: `<carpeta>/<uuid>.<ext>`. */
export function documentKeyFor(folder: string, fileName: string): string {
  const ext = fileName.includes('.') ? fileName.split('.').pop() : 'bin';
  return `${folder}/${randomUUID()}.${ext ?? 'bin'}`;
}
