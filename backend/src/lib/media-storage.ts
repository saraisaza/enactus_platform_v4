import { randomUUID } from 'node:crypto';

import {
  AbortMultipartUploadCommand,
  CompleteMultipartUploadCommand,
  CreateMultipartUploadCommand,
  DeleteObjectsCommand,
  GetObjectCommand,
  HeadObjectCommand,
  ListPartsCommand,
  PutObjectCommand,
  UploadPartCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

import { env } from '../env';
import { AppError, badRequest, payloadTooLarge } from './errors';
import { MAX_VIDEO_BYTES, isStorageConfigured, s3 } from './s3';

/**
 * Video subido como archivo: subida por partes a S3 y borrado de huérfanos.
 *
 * El archivo va directo del navegador a S3, igual que siempre (API Gateway
 * corta en 10 MB). Lo nuevo es que va EN PARTES (*multipart upload*): cada
 * parte es un `PUT` firmado por separado, así que una conexión que se corta a
 * la mitad de un video de 400 MB no obliga a empezar de cero — se reintenta
 * la parte que falló, o se retoma después preguntando qué partes ya llegaron.
 *
 * A diferencia de firmar, crear, listar, completar y borrar SÍ son llamadas
 * de red a S3. Por eso todo pasa por la interfaz [MediaStorage]: la suite
 * corre sin AWS y la reemplaza por un S3 en memoria.
 */

/** Solo MP4: con H.264 y AAC, es lo único que reproduce cualquier navegador. */
export const UPLOADED_VIDEO_TYPE = 'video/mp4';

/**
 * Tamaño de cada parte. S3 exige al menos 5 MiB (salvo la última); con 8 MiB
 * un video de 500 MB son 63 partes, y perder una por un corte de red cuesta
 * segundos, no minutos.
 */
export const VIDEO_PART_BYTES = 8 * 1024 * 1024;

/** Cuántas URLs de parte se firman por pedido. */
export const MAX_PARTS_PER_SIGN = 100;

/**
 * Vigencia de la URL de cada parte. Más larga que la del `PUT` simple (15 min)
 * porque las partes de un video grande se suben durante varios minutos; si
 * igual vence, el cliente pide firmas nuevas para las que faltan.
 */
export const PART_URL_TTL_SECONDS = 3600;

/** La portada: una imagen chica. */
export const MAX_THUMBNAIL_BYTES = 5 * 1024 * 1024;
export const ALLOWED_THUMBNAIL_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
] as const;

const THUMBNAIL_URL_TTL_SECONDS = 900;

/** Cuántas partes tiene un archivo de [sizeBytes]. */
export function videoPartCount(sizeBytes: number): number {
  return Math.max(1, Math.ceil(sizeBytes / VIDEO_PART_BYTES));
}

/** El tamaño exacto que tiene que tener la parte [partNumber] (desde 1). */
export function expectedPartBytes(sizeBytes: number, partNumber: number): number {
  const total = videoPartCount(sizeBytes);
  return partNumber < total
    ? VIDEO_PART_BYTES
    : sizeBytes - VIDEO_PART_BYTES * (total - 1);
}

/** Tipo y tamaño ANTES de abrir la subida: es un permiso real de escritura. */
export function assertValidUploadedVideo(input: {
  contentType: string;
  sizeBytes: number;
}): void {
  if (input.contentType !== UPLOADED_VIDEO_TYPE) {
    throw badRequest(
      `Solo se aceptan videos MP4 (H.264 con audio AAC); este archivo es ${input.contentType}.`,
      { allowed: [UPLOADED_VIDEO_TYPE] },
    );
  }
  if (!Number.isInteger(input.sizeBytes) || input.sizeBytes <= 0) {
    throw badRequest('El tamaño del archivo es obligatorio y debe ser mayor a 0.');
  }
  if (input.sizeBytes > MAX_VIDEO_BYTES) {
    throw payloadTooLarge(
      `El video pesa ${(input.sizeBytes / 1024 / 1024).toFixed(1)} MB y el máximo son 500 MB.`,
      { maxBytes: MAX_VIDEO_BYTES },
    );
  }
}

export function assertValidThumbnail(input: {
  contentType: string;
  sizeBytes: number;
}): void {
  if (!(ALLOWED_THUMBNAIL_TYPES as readonly string[]).includes(input.contentType)) {
    throw badRequest(
      `La portada tiene que ser JPG, PNG o WebP; esta es ${input.contentType}.`,
      { allowed: ALLOWED_THUMBNAIL_TYPES },
    );
  }
  if (!Number.isInteger(input.sizeBytes) || input.sizeBytes <= 0) {
    throw badRequest('El tamaño de la portada es obligatorio y debe ser mayor a 0.');
  }
  if (input.sizeBytes > MAX_THUMBNAIL_BYTES) {
    throw payloadTooLarge(
      `La portada pesa ${(input.sizeBytes / 1024 / 1024).toFixed(1)} MB y el máximo son 5 MB.`,
      { maxBytes: MAX_THUMBNAIL_BYTES },
    );
  }
}

/** `lessons/<lección>/thumb-<uuid>.<ext>`: junto al video, y nunca se pisa. */
export function thumbnailKeyFor(lessonId: string, contentType: string): string {
  const ext =
    contentType === 'image/png' ? 'png' : contentType === 'image/webp' ? 'webp' : 'jpg';
  return `lessons/${lessonId}/thumb-${randomUUID()}.${ext}`;
}

/** Una parte que ya llegó a S3. */
export interface UploadedPart {
  partNumber: number;
  sizeBytes: number;
  etag: string;
}

/**
 * Lo que la aplicación necesita de S3 para el video subido. Ver el
 * encabezado del archivo: existe para que la suite pueda correr sin AWS.
 */
export interface MediaStorage {
  configured(): boolean;
  createMultipartUpload(key: string, contentType: string): Promise<string>;
  signUploadPart(
    key: string,
    uploadId: string,
    partNumber: number,
    sizeBytes: number,
  ): Promise<string>;
  /** Las partes que ya llegaron. Lanza 404 si la subida ya no existe. */
  listParts(key: string, uploadId: string): Promise<UploadedPart[]>;
  completeMultipartUpload(
    key: string,
    uploadId: string,
    parts: { partNumber: number; etag: string }[],
  ): Promise<void>;
  abortMultipartUpload(key: string, uploadId: string): Promise<void>;
  /** El tamaño del objeto, o `null` si no existe. */
  objectSize(key: string): Promise<number | null>;
  /**
   * Los primeros [bytes] del objeto, o `null` si no existe. Para mirar QUÉ es
   * un archivo (su firma, sus medidas) sin bajarlo entero.
   */
  readObjectStart(key: string, bytes: number): Promise<Uint8Array | null>;
  signPutObject(key: string, contentType: string, sizeBytes: number): Promise<string>;
  deleteObjects(
    keys: string[],
  ): Promise<{ deleted: string[]; failed: { key: string; error: string }[] }>;
}

function storageUnavailable(error: unknown): AppError {
  const detail = error instanceof Error ? error.message : String(error);
  return new AppError(
    503,
    'storage_unavailable',
    'No pudimos hablar con el almacenamiento de archivos en este momento. ' +
      'Intente de nuevo en unos minutos; si sigue, avise al equipo técnico.',
    { detail },
  );
}

function notConfigured(): AppError {
  return new AppError(
    503,
    'storage_not_configured',
    'El almacenamiento de archivos no está configurado en este entorno (falta S3_BUCKET).',
  );
}

const nombreDe = (error: unknown) =>
  error && typeof error === 'object' && 'name' in error ? String(error.name) : '';

/** Una llamada a S3, con sus fallos traducidos a errores que se entienden. */
async function s3Call<T>(fn: () => Promise<T>): Promise<T> {
  if (!isStorageConfigured()) throw notConfigured();
  try {
    return await fn();
  } catch (error) {
    if (nombreDe(error) === 'NoSuchUpload') {
      throw new AppError(
        404,
        'upload_not_found',
        'Esa subida ya no existe: se canceló o venció. Hay que empezarla de nuevo.',
      );
    }
    throw storageUnavailable(error);
  }
}

const bucket = () => env.S3_BUCKET;

export const awsMediaStorage: MediaStorage = {
  configured: isStorageConfigured,

  async createMultipartUpload(key, contentType) {
    const out = await s3Call(() =>
      s3().send(
        new CreateMultipartUploadCommand({
          Bucket: bucket(),
          Key: key,
          ContentType: contentType,
        }),
      ),
    );
    if (!out.UploadId) throw storageUnavailable('S3 no devolvió el id de la subida.');
    return out.UploadId;
  },

  signUploadPart(key, uploadId, partNumber, sizeBytes) {
    return s3Call(() =>
      getSignedUrl(
        s3(),
        new UploadPartCommand({
          Bucket: bucket(),
          Key: key,
          UploadId: uploadId,
          PartNumber: partNumber,
          // Firmado: una parte de otro tamaño la rechaza S3, así que el total
          // no puede pasar del que se validó al abrir la subida.
          ContentLength: sizeBytes,
        }),
        { expiresIn: PART_URL_TTL_SECONDS },
      ),
    );
  },

  async listParts(key, uploadId) {
    const parts: UploadedPart[] = [];
    let marker: string | undefined;
    do {
      const out = await s3Call(() =>
        s3().send(
          new ListPartsCommand({
            Bucket: bucket(),
            Key: key,
            UploadId: uploadId,
            PartNumberMarker: marker,
          }),
        ),
      );
      for (const p of out.Parts ?? []) {
        if (p.PartNumber === undefined || !p.ETag) continue;
        parts.push({ partNumber: p.PartNumber, sizeBytes: p.Size ?? 0, etag: p.ETag });
      }
      marker = out.IsTruncated ? out.NextPartNumberMarker : undefined;
    } while (marker);
    return parts;
  },

  async completeMultipartUpload(key, uploadId, parts) {
    await s3Call(() =>
      s3().send(
        new CompleteMultipartUploadCommand({
          Bucket: bucket(),
          Key: key,
          UploadId: uploadId,
          MultipartUpload: {
            Parts: parts.map((p) => ({ PartNumber: p.partNumber, ETag: p.etag })),
          },
        }),
      ),
    );
  },

  async abortMultipartUpload(key, uploadId) {
    try {
      await s3Call(() =>
        s3().send(
          new AbortMultipartUploadCommand({
            Bucket: bucket(),
            Key: key,
            UploadId: uploadId,
          }),
        ),
      );
    } catch (error) {
      // Cancelar algo que ya no existe es haber cancelado.
      if (error instanceof AppError && error.code === 'upload_not_found') return;
      throw error;
    }
  },

  async objectSize(key) {
    if (!isStorageConfigured()) throw notConfigured();
    try {
      const out = await s3().send(new HeadObjectCommand({ Bucket: bucket(), Key: key }));
      return out.ContentLength ?? 0;
    } catch (error) {
      const nombre = nombreDe(error);
      if (nombre === 'NotFound' || nombre === 'NoSuchKey') return null;
      throw storageUnavailable(error);
    }
  },

  async readObjectStart(key, bytes) {
    if (!isStorageConfigured()) throw notConfigured();
    try {
      const out = await s3().send(
        new GetObjectCommand({ Bucket: bucket(), Key: key, Range: `bytes=0-${bytes - 1}` }),
      );
      return out.Body ? await out.Body.transformToByteArray() : new Uint8Array();
    } catch (error) {
      const nombre = nombreDe(error);
      if (nombre === 'NotFound' || nombre === 'NoSuchKey') return null;
      throw storageUnavailable(error);
    }
  },

  signPutObject(key, contentType, sizeBytes) {
    return s3Call(() =>
      getSignedUrl(
        s3(),
        new PutObjectCommand({
          Bucket: bucket(),
          Key: key,
          ContentType: contentType,
          ContentLength: sizeBytes,
        }),
        { expiresIn: THUMBNAIL_URL_TTL_SECONDS },
      ),
    );
  },

  async deleteObjects(keys) {
    if (keys.length === 0) return { deleted: [], failed: [] };
    const out = await s3Call(() =>
      s3().send(
        new DeleteObjectsCommand({
          Bucket: bucket(),
          Delete: { Objects: keys.map((Key) => ({ Key })), Quiet: false },
        }),
      ),
    );
    return {
      deleted: (out.Deleted ?? []).flatMap((d) => (d.Key ? [d.Key] : [])),
      failed: (out.Errors ?? []).flatMap((e) =>
        e.Key ? [{ key: e.Key, error: `${e.Code ?? 'Error'}: ${e.Message ?? ''}`.trim() }] : [],
      ),
    };
  },
};

let current: MediaStorage = awsMediaStorage;

/** El almacenamiento en uso: el de AWS, salvo en las pruebas. */
export function mediaStorage(): MediaStorage {
  return current;
}

/** Solo para pruebas: `null` vuelve al de AWS. */
export function useMediaStorageForTests(storage: MediaStorage | null): void {
  current = storage ?? awsMediaStorage;
}

export { THUMBNAIL_URL_TTL_SECONDS };
