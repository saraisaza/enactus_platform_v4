import { asc, count, eq, inArray, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import {
  activityAllowedTypes,
  activityRubricItems,
  courseModules,
  lessonActivities,
  lessons,
  quizAttempts,
  quizQuestionOptions,
  quizQuestions,
} from '../db/schema';
import { createVideoUrl } from '../lib/cloudfront';
import { badRequest, conflict, forbidden, notFound } from '../lib/errors';
import {
  MAX_PARTS_PER_SIGN,
  PART_URL_TTL_SECONDS,
  THUMBNAIL_URL_TTL_SECONDS,
  UPLOADED_VIDEO_TYPE,
  VIDEO_PART_BYTES,
  assertValidThumbnail,
  assertValidUploadedVideo,
  expectedPartBytes,
  mediaStorage,
  thumbnailKeyFor,
  videoPartCount,
} from '../lib/media-storage';
import {
  assertValidDocumentUpload,
  assertValidVideoUpload,
  createUploadUrl,
  videoKeyFor,
} from '../lib/s3';
import { parcial } from '../lib/parcial';
import { authorizeLessonVideo } from '../services/file-access';
import { drainStorageDeletes } from '../services/storage-cleanup';
import {
  CONTENT_ROLES,
  currentUser,
  isStudentLike,
  requireAuth,
  requireRole,
} from '../middleware/auth';
import type { AppEnv } from '../middleware/context';
import { loadEditableCourse } from './courses';

type Db = AppEnv['Variables']['db'];

const lessonType = z.enum([
  'video',
  'pdf',
  'resource',
  'link',
  'quiz',
  'activity',
  'survey',
]);

const lessonBody = z.object({
  title: z.string().trim().min(1, 'El título es obligatorio.'),
  type: lessonType.default('video'),
  description: z.string().trim().default(''),
  durationMin: z.number().int().min(0).default(0),
  /** Solo `type = 'link'`. */
  externalUrl: z.url().nullable().optional(),
});

const lessonUpdate = parcial(lessonBody);

const reorderBody = z.object({
  orderedIds: z.array(z.uuid()).min(1, 'Hace falta al menos un id.'),
});

const uploadUrlBody = z.object({
  contentType: z.string().trim().min(1, 'Falta el content-type del archivo.'),
  sizeBytes: z.number().int().positive('El tamaño debe ser mayor a 0.'),
});

const confirmUploadBody = z.object({
  key: z.string().trim().min(1),
  sizeBytes: z.number().int().positive(),
  mimeType: z.string().trim().min(1),
  durationSec: z.number().int().min(0).optional(),
});

const externalVideoBody = z.object({
  url: z.url('Tiene que ser una URL válida (YouTube o Vimeo).'),
  durationSec: z.number().int().min(0).optional(),
});

/**
 * El id de un video de YouTube: 11 caracteres de `[A-Za-z0-9_-]`.
 *
 * Es la misma expresión que el CHECK `lessons_video_youtube_id_format`. La
 * API la valida igual para contestar 400 con un mensaje que se entienda, en
 * vez del 500 de una restricción violada.
 */
const YOUTUBE_VIDEO_ID = /^[A-Za-z0-9_-]{11}$/;

/**
 * Se recibe el id, NO el enlace. Sacar el id de las muchas formas de enlace
 * (`watch?v=`, `youtu.be/`, `shorts/`, `embed/`, con `&t=` o `?si=`…) lo hace
 * el cliente en un solo lugar; acá se exige que lo que llegue ya sea el id.
 * Un enlace pegado tal cual se rechaza: guardar solo el id es el punto.
 */
const youtubeVideoBody = z.object({
  videoId: z
    .string()
    .trim()
    .regex(
      YOUTUBE_VIDEO_ID,
      'Tiene que ser el id del video de YouTube (11 caracteres), no el enlace.',
    ),
  durationSec: z.number().int().min(0).optional(),
});

/**
 * El nombre con que se subió, para mostrárselo al LXD. Sin rutas ni
 * caracteres de control: es texto que se muestra, no un camino.
 */
const fileNameField = z
  .string()
  .trim()
  .min(1, 'Falta el nombre del archivo.')
  .transform((nombre) =>
    nombre
      .replace(/^.*[\\/]/, '')
      // eslint-disable-next-line no-control-regex
      .replace(/[\u0000-\u001f\u007f]/g, '')
      .slice(0, 255),
  );

const startVideoUploadBody = z.object({
  fileName: fileNameField,
  contentType: z.string().trim().min(1, 'Falta el content-type del archivo.'),
  sizeBytes: z.number().int().positive('El tamaño debe ser mayor a 0.'),
});

const uploadRef = {
  key: z.string().trim().min(1),
  uploadId: z.string().trim().min(1),
};

const signPartsBody = z.object({
  ...uploadRef,
  sizeBytes: z.number().int().positive(),
  partNumbers: z
    .array(z.number().int().min(1))
    .min(1, 'Hace falta al menos una parte.')
    .max(MAX_PARTS_PER_SIGN, `Se firman hasta ${MAX_PARTS_PER_SIGN} partes por pedido.`),
});

const uploadQuery = z.object(uploadRef);

const completeVideoUploadBody = z.object({
  ...uploadRef,
  fileName: fileNameField,
  sizeBytes: z.number().int().positive(),
  durationSec: z.number().int().min(0).max(24 * 3600).optional(),
  thumbnailKey: z.string().trim().min(1).optional(),
});

const thumbnailUploadBody = z.object({
  contentType: z.string().trim().min(1),
  sizeBytes: z.number().int().positive(),
});

/** `null` quita la portada propia. */
const setThumbnailBody = z.object({
  key: z.string().trim().min(1).nullable(),
});

const resourceBody = z.object({
  key: z.string().trim().min(1),
  fileName: z.string().trim().min(1, 'Falta el nombre del archivo.'),
  contentType: z.string().trim().min(1),
  sizeBytes: z.number().int().positive(),
});

// ---------------------------------------------------------------------------
// Rutas colgadas de un módulo: crear y reordenar lecciones
// ---------------------------------------------------------------------------

export const moduleLessonRoutes = new Hono<AppEnv>();
moduleLessonRoutes.use('*', requireAuth);

moduleLessonRoutes.post('/:id/lessons', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = lessonBody.parse(await c.req.json());
  const db = c.get('db');
  const mod = await loadEditableModule(db, c.req.param('id'), user);

  if (body.type === 'link' && !body.externalUrl) {
    throw conflict('Una lección de tipo enlace necesita su URL.');
  }

  const [{ value: existing } = { value: 0 }] = await db
    .select({ value: count() })
    .from(lessons)
    .where(eq(lessons.courseModuleId, mod.id));

  const [created] = await db
    .insert(lessons)
    .values({
      courseModuleId: mod.id,
      title: body.title,
      type: body.type,
      description: body.description,
      durationMin: body.durationMin,
      externalUrl: body.externalUrl ?? null,
      orderIndex: existing + 1,
    })
    .returning();

  return c.json(created, 201);
});

/** Mismo mecanismo de dos pasos que el reordenamiento de módulos. */
moduleLessonRoutes.put(
  '/:id/lessons/order',
  requireRole(...CONTENT_ROLES),
  async (c) => {
    const user = currentUser(c);
    const { orderedIds } = reorderBody.parse(await c.req.json());
    const db = c.get('db');
    const mod = await loadEditableModule(db, c.req.param('id'), user);

    const existing = await db
      .select({ id: lessons.id })
      .from(lessons)
      .where(eq(lessons.courseModuleId, mod.id));

    const existingIds = new Set(existing.map((l) => l.id));
    const alien = orderedIds.filter((id) => !existingIds.has(id));
    const missing = existing.filter((l) => !orderedIds.includes(l.id));
    if (alien.length > 0 || missing.length > 0) {
      throw conflict(
        'La lista de reordenamiento tiene que incluir exactamente las lecciones de este módulo, una sola vez cada una.',
        { alien, missing: missing.map((l) => l.id) },
      );
    }

    await db.transaction(async (tx) => {
      for (const [i, id] of orderedIds.entries()) {
        await tx.update(lessons).set({ orderIndex: -(i + 1) }).where(eq(lessons.id, id));
      }
      for (const [i, id] of orderedIds.entries()) {
        await tx
          .update(lessons)
          .set({ orderIndex: i + 1, updatedAt: new Date() })
          .where(eq(lessons.id, id));
      }
    });

    const ordered = await db
      .select()
      .from(lessons)
      .where(eq(lessons.courseModuleId, mod.id))
      .orderBy(asc(lessons.orderIndex));
    return c.json(ordered);
  },
);

// ---------------------------------------------------------------------------
// Rutas de una lección
// ---------------------------------------------------------------------------

export const lessonRoutes = new Hono<AppEnv>();
lessonRoutes.use('*', requireAuth);

lessonRoutes.patch('/:id', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = lessonUpdate.parse(await c.req.json());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  const [updated] = await db
    .update(lessons)
    .set({ ...body, updatedAt: new Date() })
    .where(eq(lessons.id, lesson.id))
    .returning();

  return c.json(updated);
});

lessonRoutes.delete('/:id', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  await db.delete(lessons).where(eq(lessons.id, lesson.id));
  if (lesson.courseModuleId) await renumberLessons(db, lesson.courseModuleId);
  // El trigger anotó su video y su portada; acá se borran de S3.
  await drainStorageDeletes(db);
  return c.body(null, 204);
});

/**
 * Paso 1 del flujo de subida: la API firma un permiso de escritura sobre S3.
 *
 * El archivo NO pasa por acá — va directo del navegador a S3. API Gateway
 * corta el payload en 10 MB y un video de 400 MB lo revienta.
 *
 * Se valida ANTES de firmar: tipo permitido (solo mp4), tamaño ≤ 500 MB y rol
 * con permiso de crear contenido. Una URL firmada es un permiso real de
 * escritura sobre el bucket; no se emite a la ligera.
 */
lessonRoutes.post('/:id/video-upload-url', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = uploadUrlBody.parse(await c.req.json());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  assertValidVideoUpload(body);

  const key = videoKeyFor(lesson.id, body.contentType);
  const signed = await createUploadUrl({
    key,
    contentType: body.contentType,
    sizeBytes: body.sizeBytes,
  });

  return c.json({
    ...signed,
    // El cliente sube con PUT y este content-type exacto, o S3 rechaza.
    method: 'PUT',
    headers: { 'Content-Type': body.contentType },
  });
});

/**
 * Paso 3: el navegador confirma que la subida terminó y la lección queda
 * apuntando al archivo. Los videos propios se sirven después por CloudFront
 * con URL firmada, nunca por URL directa de S3.
 */
lessonRoutes.post('/:id/video', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = confirmUploadBody.parse(await c.req.json());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  assertValidVideoUpload({
    contentType: body.mimeType,
    sizeBytes: body.sizeBytes,
  });

  // La key tiene que ser la de ESTA lección: si no, alguien podría apuntar
  // su lección a un archivo subido para otra.
  if (!body.key.startsWith(`lessons/${lesson.id}/`)) {
    throw conflict('Esa key no corresponde a esta lección.');
  }

  const [updated] = await db
    .update(lessons)
    .set({
      type: 'video',
      videoType: 'uploaded',
      videoS3Key: body.key,
      videoUrl: null,
      videoYoutubeId: null,
      videoSizeBytes: body.sizeBytes,
      videoMimeType: body.mimeType,
      videoDurationSec: body.durationSec ?? null,
      // La portada y el nombre eran del video anterior.
      videoThumbnailS3Key: null,
      videoOriginalName: null,
      videoUploadedAt: new Date(),
      updatedAt: new Date(),
    })
    .where(eq(lessons.id, lesson.id))
    .returning();

  await drainStorageDeletes(db);
  return c.json(updated);
});

/**
 * URL de REPRODUCCIÓN del video propio de una lección.
 *
 * Es el endpoint que menciona el rechazo de `/files/download-url`: los videos
 * no se sirven por S3 firmado (cuesta varias veces más), se sirven por
 * CloudFront con una URL de vigencia corta.
 *
 * Sin `requireRole`: quien mira un video no es quien lo edita. El alcance lo
 * resuelve `authorizeLessonVideo` contra la fila de la lección — un estudiante
 * sin acceso al curso recibe 404, no 403, para no confirmar que existe.
 */
lessonRoutes.get('/:id/video-url', async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const { key, thumbnailKey } = await authorizeLessonVideo(
    db,
    user,
    c.req.param('id'),
  );
  return c.json({
    ...createVideoUrl({ key }),
    // Misma autorización que el video: quien no puede verlo, tampoco su portada.
    thumbnailUrl: thumbnailKey
      ? createVideoUrl({ key: thumbnailKey, ttlSeconds: 3600 }).url
      : null,
  });
});

// ---------------------------------------------------------------------------
// Video subido por partes (multipart)
//
// 1. `POST video-uploads`           abre la subida en S3
// 2. `POST video-uploads/sign`      firma las partes que faltan
//    (el navegador sube cada parte directo a S3, con su URL)
// 3. `GET  video-uploads/parts`     qué partes ya llegaron: para retomar
// 4. `POST video-uploads/complete`  cierra la subida y la lección queda apuntando
//    `DELETE video-uploads`         cancela
//
// Mismos permisos que el resto de la edición: el LXD o el admin que pueden
// editar ese curso. Ver el video es otra regla (`GET /:id/video-url`).
// ---------------------------------------------------------------------------

/** La key es de un video de ESTA lección, no de otra ni de su portada. */
function assertVideoKeyOf(lessonId: string, key: string): void {
  const ok =
    key.startsWith(`lessons/${lessonId}/`) &&
    key.endsWith('.mp4') &&
    !key.includes('/thumb-') &&
    !key.includes('..');
  if (!ok) throw conflict('Esa subida no corresponde a esta lección.');
}

function assertThumbnailKeyOf(lessonId: string, key: string): void {
  const ok = key.startsWith(`lessons/${lessonId}/thumb-`) && !key.includes('..');
  if (!ok) throw conflict('Esa portada no corresponde a esta lección.');
}

lessonRoutes.post('/:id/video-uploads', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = startVideoUploadBody.parse(await c.req.json());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  assertValidUploadedVideo(body);

  const key = videoKeyFor(lesson.id, UPLOADED_VIDEO_TYPE);
  const uploadId = await mediaStorage().createMultipartUpload(key, UPLOADED_VIDEO_TYPE);

  return c.json(
    {
      key,
      uploadId,
      partSizeBytes: VIDEO_PART_BYTES,
      partCount: videoPartCount(body.sizeBytes),
    },
    201,
  );
});

lessonRoutes.post('/:id/video-uploads/sign', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = signPartsBody.parse(await c.req.json());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  assertValidUploadedVideo({ contentType: UPLOADED_VIDEO_TYPE, sizeBytes: body.sizeBytes });
  assertVideoKeyOf(lesson.id, body.key);

  const total = videoPartCount(body.sizeBytes);
  const fuera = body.partNumbers.find((n) => n > total);
  if (fuera !== undefined) {
    throw badRequest(`El video tiene ${total} partes; no existe la parte ${fuera}.`);
  }

  const storage = mediaStorage();
  const parts = await Promise.all(
    [...new Set(body.partNumbers)].map(async (partNumber) => ({
      partNumber,
      url: await storage.signUploadPart(
        body.key,
        body.uploadId,
        partNumber,
        expectedPartBytes(body.sizeBytes, partNumber),
      ),
    })),
  );

  return c.json({ parts, expiresInSeconds: PART_URL_TTL_SECONDS });
});

lessonRoutes.get('/:id/video-uploads/parts', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const query = uploadQuery.parse(c.req.query());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);
  assertVideoKeyOf(lesson.id, query.key);

  const parts = await mediaStorage().listParts(query.key, query.uploadId);
  return c.json({
    parts: parts
      .map(({ partNumber, sizeBytes }) => ({ partNumber, sizeBytes }))
      .sort((a, b) => a.partNumber - b.partNumber),
  });
});

/**
 * Cierra la subida y deja la lección apuntando al video.
 *
 * Las partes NO se le creen al cliente: se le preguntan a S3, y tienen que
 * estar todas y cada una del tamaño exacto. Después de cerrar, se comprueba
 * el tamaño del objeto que quedó.
 */
lessonRoutes.post('/:id/video-uploads/complete', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = completeVideoUploadBody.parse(await c.req.json());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  assertValidUploadedVideo({ contentType: UPLOADED_VIDEO_TYPE, sizeBytes: body.sizeBytes });
  assertVideoKeyOf(lesson.id, body.key);
  if (body.thumbnailKey) assertThumbnailKeyOf(lesson.id, body.thumbnailKey);

  const storage = mediaStorage();
  const total = videoPartCount(body.sizeBytes);
  const llegaron = new Map(
    (await storage.listParts(body.key, body.uploadId)).map((p) => [p.partNumber, p]),
  );

  const faltan: number[] = [];
  for (let n = 1; n <= total; n++) {
    const parte = llegaron.get(n);
    if (!parte) {
      faltan.push(n);
      continue;
    }
    const esperado = expectedPartBytes(body.sizeBytes, n);
    if (parte.sizeBytes !== esperado) {
      throw conflict(
        `La parte ${n} llegó con ${parte.sizeBytes} bytes y debía tener ${esperado}.`,
        { partNumber: n },
      );
    }
  }
  if (faltan.length > 0) {
    throw conflict(`Faltan ${faltan.length} de ${total} partes del video.`, {
      missingParts: faltan,
    });
  }
  if ([...llegaron.keys()].some((n) => n > total)) {
    throw conflict('Llegaron más partes de las que tiene el video.');
  }

  await storage.completeMultipartUpload(
    body.key,
    body.uploadId,
    [...llegaron.values()]
      .sort((a, b) => a.partNumber - b.partNumber)
      .map(({ partNumber, etag }) => ({ partNumber, etag })),
  );

  const tamano = await storage.objectSize(body.key);
  if (tamano !== body.sizeBytes) {
    await storage.deleteObjects([body.key]).catch(() => undefined);
    throw conflict(
      'El archivo que quedó en el almacenamiento no tiene el tamaño esperado. ' +
        'Súbalo de nuevo.',
    );
  }

  // Una portada que no llegó no tumba un video de 400 MB que sí llegó: se
  // guarda sin portada y el LXD la puede subir después.
  const portada =
    body.thumbnailKey && (await storage.objectSize(body.thumbnailKey)) !== null
      ? body.thumbnailKey
      : null;

  let updated;
  try {
    [updated] = await db
      .update(lessons)
      .set({
        type: 'video',
        videoType: 'uploaded',
        videoS3Key: body.key,
        videoUrl: null,
        videoYoutubeId: null,
        videoSizeBytes: body.sizeBytes,
        videoMimeType: UPLOADED_VIDEO_TYPE,
        videoDurationSec: body.durationSec ?? null,
        videoThumbnailS3Key: portada,
        videoOriginalName: body.fileName,
        videoUploadedAt: new Date(),
        updatedAt: new Date(),
      })
      .where(eq(lessons.id, lesson.id))
      .returning();
  } catch (error) {
    // Sin la fila apuntándolo, el archivo nuevo sería un huérfano desde ya.
    await storage
      .deleteObjects([body.key, ...(portada ? [portada] : [])])
      .catch(() => undefined);
    throw error;
  }

  // El video anterior y su portada, si había, quedaron anotados por el trigger.
  await drainStorageDeletes(db);
  return c.json(updated);
});

lessonRoutes.delete('/:id/video-uploads', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const query = uploadQuery.parse(c.req.query());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);
  assertVideoKeyOf(lesson.id, query.key);

  await mediaStorage().abortMultipartUpload(query.key, query.uploadId);
  return c.body(null, 204);
});

/** Permiso para subir la portada (un `PUT` simple: es una imagen chica). */
lessonRoutes.post(
  '/:id/video-thumbnail-upload-url',
  requireRole(...CONTENT_ROLES),
  async (c) => {
    const user = currentUser(c);
    const body = thumbnailUploadBody.parse(await c.req.json());
    const db = c.get('db');
    const lesson = await loadEditableLesson(db, c.req.param('id'), user);

    assertValidThumbnail(body);
    const key = thumbnailKeyFor(lesson.id, body.contentType);
    const uploadUrl = await mediaStorage().signPutObject(
      key,
      body.contentType,
      body.sizeBytes,
    );

    return c.json({
      key,
      uploadUrl,
      method: 'PUT',
      headers: { 'Content-Type': body.contentType },
      expiresInSeconds: THUMBNAIL_URL_TTL_SECONDS,
    });
  },
);

/** Pone, cambia o quita (`key: null`) la portada de un video ya subido. */
lessonRoutes.put('/:id/video-thumbnail', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = setThumbnailBody.parse(await c.req.json());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  if (lesson.videoType !== 'uploaded') {
    throw conflict(
      'Solo los videos subidos llevan portada propia; los de YouTube usan la de YouTube.',
    );
  }
  if (body.key) {
    assertThumbnailKeyOf(lesson.id, body.key);
    if ((await mediaStorage().objectSize(body.key)) === null) {
      throw conflict('La portada no llegó al almacenamiento. Súbala de nuevo.');
    }
  }

  const [updated] = await db
    .update(lessons)
    .set({ videoThumbnailS3Key: body.key, updatedAt: new Date() })
    .where(eq(lessons.id, lesson.id))
    .returning();

  await drainStorageDeletes(db);
  return c.json(updated);
});

/** Video externo: se guarda el enlace, no hay archivo ni S3 de por medio. */
lessonRoutes.post('/:id/video-external', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = externalVideoBody.parse(await c.req.json());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  const [updated] = await db
    .update(lessons)
    .set({
      type: 'video',
      videoType: 'external',
      videoUrl: body.url,
      videoS3Key: null,
      videoYoutubeId: null,
      videoSizeBytes: null,
      videoMimeType: null,
      videoDurationSec: body.durationSec ?? null,
      videoThumbnailS3Key: null,
      videoOriginalName: null,
      videoUploadedAt: null,
      updatedAt: new Date(),
    })
    .where(eq(lessons.id, lesson.id))
    .returning();

  // Si antes era un video subido, el trigger anotó el archivo y la portada.
  await drainStorageDeletes(db);
  return c.json(updated);
});

/**
 * Video de YouTube: se guarda SOLO el id.
 *
 * Con el id el cliente arma el reproductor y la miniatura; el enlace que pegó
 * el LXD no aporta nada y traía basura (`&t=`, `?si=` de rastreo, la lista de
 * reproducción de donde lo sacó). Cambiar de origen limpia los otros dos:
 * nunca quedan dos orígenes a la vez.
 */
lessonRoutes.post('/:id/video-youtube', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = youtubeVideoBody.parse(await c.req.json());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  const [updated] = await db
    .update(lessons)
    .set({
      type: 'video',
      videoType: 'youtube',
      videoYoutubeId: body.videoId,
      videoUrl: null,
      videoS3Key: null,
      videoSizeBytes: null,
      videoMimeType: null,
      videoDurationSec: body.durationSec ?? null,
      videoThumbnailS3Key: null,
      videoOriginalName: null,
      videoUploadedAt: null,
      updatedAt: new Date(),
    })
    .where(eq(lessons.id, lesson.id))
    .returning();

  // Si antes era un video subido, el trigger anotó el archivo y la portada.
  await drainStorageDeletes(db);
  return c.json(updated);
});

/**
 * Recurso descargable de una lección (PDF, plantilla, hoja de cálculo).
 *
 * Tercer paso del mismo flujo que el video: el navegador ya subió el archivo
 * con la URL firmada de `POST /files/upload-url` y acá confirma la key.
 *
 * La key tiene que venir de la carpeta que firma ese endpoint. Es la misma
 * garantía que da el avatar —prefijo, no id de lección— porque
 * `documentKeyFor` genera `lesson-resources/<uuid>.<ext>`, sin la lección
 * adentro: no se puede crear la key antes de tener el archivo.
 */
lessonRoutes.post('/:id/resource', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = resourceBody.parse(await c.req.json());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  assertValidDocumentUpload({
    contentType: body.contentType,
    sizeBytes: body.sizeBytes,
  });

  if (!body.key.startsWith('lesson-resources/')) {
    throw conflict(
      'Esa key no salió del endpoint de subida de recursos de lección.',
      { key: body.key },
    );
  }

  const [updated] = await db
    .update(lessons)
    .set({
      resourceS3Key: body.key,
      resourceFileName: body.fileName,
      resourceContentType: body.contentType,
      resourceSizeBytes: body.sizeBytes,
      updatedAt: new Date(),
    })
    .where(eq(lessons.id, lesson.id))
    .returning();

  return c.json(updated);
});

// ---------------------------------------------------------------------------
// Autoría del quiz
// ---------------------------------------------------------------------------

const quizKindEnum = z.enum(['multiple', 'truefalse', 'short', 'fill', 'order']);

/** Una pregunta tal como la manda el constructor de lecciones. */
const quizQuestionInput = z.object({
  kind: quizKindEnum.default('multiple'),
  question: z.string().trim().min(1, 'Cada pregunta necesita su enunciado.'),
  options: z.array(z.string().trim()).default([]),
  answerIndex: z.number().int().min(0).nullable().default(null),
  answerText: z.string().trim().nullable().default(null),
});

const quizBody = z.object({
  questions: z.array(quizQuestionInput).max(100, 'Son demasiadas preguntas.'),
});

type QuizQuestionInput = z.infer<typeof quizQuestionInput>;

/**
 * Lee las preguntas CON su clave de respuestas.
 *
 * Es la única lectura de la API que devuelve `answerIndex`/`answerText`, y
 * existe por una razón concreta: sin ella, abrir una lección ya hecha en el
 * constructor mostraría las respuestas en blanco y el primer guardado borraría
 * la clave sin que nadie se enterara.
 *
 * Va detrás de `loadEditableLesson`, no de la visibilidad del curso: quien
 * puede reescribir el quiz es exactamente quien puede leer su clave.
 */
lessonRoutes.get('/:id/quiz', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);
  return c.json({ questions: await loadAuthoringQuiz(db, lesson.id) });
});

/**
 * Reemplaza TODAS las preguntas de la lección.
 *
 * Reemplazo y no parcheo pregunta por pregunta: el constructor edita la lista
 * entera en un formulario y manda el resultado. Con endpoints por pregunta,
 * quien borrara una fila y guardara vería la pregunta seguir ahí.
 *
 * Los intentos ya resueltos (`quiz_attempts`) no se tocan: guardan su nota
 * calculada en el servidor, así que siguen siendo un registro válido de lo que
 * pasó aunque el quiz cambie después.
 */
lessonRoutes.put('/:id/quiz', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = quizBody.parse(await c.req.json());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  if (lesson.type !== 'quiz' && lesson.type !== 'survey') {
    throw conflict(
      'Solo una lección de tipo quiz o encuesta tiene preguntas. Cambie el tipo de la lección primero.',
      { type: lesson.type },
    );
  }

  const isSurvey = lesson.type === 'survey';
  const problems = quizProblems(body.questions, isSurvey);
  if (problems.length > 0) {
    throw conflict(
      'Hay preguntas incompletas. Revíselas antes de guardar.',
      { problems },
    );
  }

  await db.transaction(async (tx) => {
    // Las opciones caen por CASCADE con su pregunta.
    await tx.delete(quizQuestions).where(eq(quizQuestions.lessonId, lesson.id));

    for (const [i, q] of body.questions.entries()) {
      const stored = storableAnswer(q, isSurvey);
      const [created] = await tx
        .insert(quizQuestions)
        .values({
          lessonId: lesson.id,
          orderIndex: i + 1,
          kind: q.kind,
          question: q.question,
          answerIndex: stored.answerIndex,
          answerText: stored.answerText,
        })
        .returning();

      if (stored.options.length > 0) {
        await tx.insert(quizQuestionOptions).values(
          stored.options.map((text, o) => ({
            quizQuestionId: created!.id,
            orderIndex: o,
            text,
          })),
        );
      }
    }
  });

  return c.json({ questions: await loadAuthoringQuiz(db, lesson.id) });
});

/**
 * Qué le falta a cada pregunta para poder calificarse.
 *
 * Devuelve la lista completa de problemas, no el primero: quien está armando
 * un quiz de diez preguntas prefiere verlos todos a descubrirlos de a uno.
 *
 * Las opciones vacías se rechazan en vez de filtrarse. Filtrarlas correría los
 * índices y cambiaría en silencio cuál es la respuesta correcta.
 */
function quizProblems(
  questions: QuizQuestionInput[],
  isSurvey: boolean,
): { question: number; problem: string }[] {
  const problems: { question: number; problem: string }[] = [];
  const add = (question: number, problem: string) =>
    problems.push({ question, problem });

  for (const [i, q] of questions.entries()) {
    const at = i + 1;

    if (isSurvey) {
      if (q.answerIndex !== null || (q.answerText ?? '') !== '') {
        add(at, 'Una encuesta no tiene respuesta correcta.');
      }
      continue;
    }

    if (q.kind === 'multiple' || q.kind === 'order') {
      if (q.options.some((o) => o === '')) {
        add(at, 'Hay opciones sin texto. Complételas o quítelas.');
      } else if (q.options.length < 2) {
        add(
          at,
          q.kind === 'multiple'
            ? 'Necesita al menos dos opciones.'
            : 'Necesita al menos dos elementos para ordenar.',
        );
      }
    }

    switch (q.kind) {
      case 'multiple':
        if (q.answerIndex === null || q.answerIndex >= q.options.length) {
          add(at, 'Marcá cuál de las opciones es la correcta.');
        }
        break;
      case 'truefalse':
        if (q.answerIndex !== 0 && q.answerIndex !== 1) {
          add(at, 'Elija si la respuesta correcta es Verdadero o Falso.');
        }
        break;
      case 'short':
      case 'fill':
        if ((q.answerText ?? '') === '') {
          add(at, 'Falta la respuesta correcta.');
        }
        break;
      case 'order':
        // El orden correcto ES el de las opciones; no hay clave aparte.
        break;
    }
  }
  return problems;
}

/** Normaliza lo que se guarda según el tipo: cada uno usa una sola de las claves. */
function storableAnswer(q: QuizQuestionInput, isSurvey: boolean) {
  if (isSurvey) {
    return { options: q.options, answerIndex: null, answerText: null };
  }
  switch (q.kind) {
    case 'multiple':
      return { options: q.options, answerIndex: q.answerIndex, answerText: null };
    case 'order':
      // Guardadas en el orden CORRECTO: esa es la clave.
      return { options: q.options, answerIndex: null, answerText: null };
    case 'truefalse':
      // Verdadero/Falso los dibuja el cliente; no se guardan como opciones.
      return { options: [], answerIndex: q.answerIndex, answerText: null };
    default:
      return { options: [], answerIndex: null, answerText: q.answerText };
  }
}

async function loadAuthoringQuiz(db: Db, lessonId: string) {
  return db.execute<Record<string, unknown>>(sql`
    select q.id, q.kind, q.question,
           q.answer_index as "answerIndex", q.answer_text as "answerText",
           coalesce((
             select json_agg(o.text order by o.order_index)
               from quiz_question_options o
              where o.quiz_question_id = q.id), '[]'::json) as options
      from quiz_questions q
     where q.lesson_id = ${lessonId}
     order by q.order_index
  `);
}

// ---------------------------------------------------------------------------
// Autoría de la actividad
// ---------------------------------------------------------------------------

const rubricItemInput = z.object({
  criterion: z.string().trim().min(1, 'Cada criterio necesita su texto.'),
  points: z.number().int().min(0, 'Los puntos no pueden ser negativos.').default(0),
});

const activityBody = z.object({
  description: z.string().trim().default(''),
  deadline: z.iso.date('La fecha límite tiene que ser AAAA-MM-DD.').nullable().default(null),
  requiresFile: z.boolean().default(false),
  requiresText: z.boolean().default(true),
  maxFiles: z.number().int().positive('Tiene que aceptar al menos un archivo.').default(1),
  gradingMode: z.enum(['points100', 'passfail', 'review', 'scale5']).default('points100'),
  allowedTypes: z
    .array(z.enum(['pdf', 'video', 'document', 'image', 'zip']))
    .default([]),
  rubric: z.array(rubricItemInput).max(50, 'Son demasiados criterios.').default([]),
});

/**
 * Configura la actividad de una lección: consigna, fecha, qué se entrega y con
 * qué rúbrica se califica.
 *
 * Igual que el quiz, reemplaza el conjunto entero. La rúbrica y los tipos de
 * archivo permitidos son listas que el formulario edita completas.
 *
 * `allowedTypes` vacío significa "cualquier tipo": es lo que ya asumía el
 * portal del estudiante, y obligar a elegir uno rompería las actividades que
 * hoy no tienen ninguno marcado.
 */
lessonRoutes.put('/:id/activity', requireRole(...CONTENT_ROLES), async (c) => {
  const user = currentUser(c);
  const body = activityBody.parse(await c.req.json());
  const db = c.get('db');
  const lesson = await loadEditableLesson(db, c.req.param('id'), user);

  if (lesson.type !== 'activity') {
    throw conflict(
      'Solo una lección de tipo actividad tiene entregable. Cambie el tipo de la lección primero.',
      { type: lesson.type },
    );
  }

  if (!body.requiresFile && !body.requiresText) {
    throw conflict(
      'La actividad tiene que pedir al menos texto o archivo: si no, no hay nada que entregar.',
    );
  }

  await db.transaction(async (tx) => {
    await tx
      .insert(lessonActivities)
      .values({
        lessonId: lesson.id,
        description: body.description,
        deadline: body.deadline,
        requiresFile: body.requiresFile,
        requiresText: body.requiresText,
        maxFiles: body.maxFiles,
        gradingMode: body.gradingMode,
      })
      .onConflictDoUpdate({
        target: lessonActivities.lessonId,
        set: {
          description: body.description,
          deadline: body.deadline,
          requiresFile: body.requiresFile,
          requiresText: body.requiresText,
          maxFiles: body.maxFiles,
          gradingMode: body.gradingMode,
          updatedAt: new Date(),
        },
      });

    await tx
      .delete(activityAllowedTypes)
      .where(eq(activityAllowedTypes.lessonId, lesson.id));
    if (body.allowedTypes.length > 0) {
      await tx.insert(activityAllowedTypes).values(
        // Repetir un tipo en el formulario no es un error del que valga la
        // pena avisar: la clave primaria lo rechazaría, así que se deduplica.
        [...new Set(body.allowedTypes)].map((fileType) => ({
          lessonId: lesson.id,
          fileType,
        })),
      );
    }

    await tx
      .delete(activityRubricItems)
      .where(eq(activityRubricItems.lessonId, lesson.id));
    if (body.rubric.length > 0) {
      await tx.insert(activityRubricItems).values(
        body.rubric.map((r, i) => ({
          lessonId: lesson.id,
          orderIndex: i + 1,
          criterion: r.criterion,
          points: r.points,
        })),
      );
    }
  });

  return c.json(await loadActivity(db, lesson.id));
});

async function loadActivity(db: Db, lessonId: string) {
  const [row] = await db.execute<Record<string, unknown>>(sql`
    select a.description, a.deadline::text,
           a.requires_file as "requiresFile", a.requires_text as "requiresText",
           a.max_files as "maxFiles", a.grading_mode as "gradingMode",
           coalesce((select json_agg(t.file_type order by t.file_type)
                       from activity_allowed_types t
                      where t.lesson_id = a.lesson_id), '[]'::json) as "allowedTypes",
           coalesce((select json_agg(json_build_object(
                              'criterion', r.criterion, 'points', r.points)
                            order by r.order_index)
                       from activity_rubric_items r
                      where r.lesson_id = a.lesson_id), '[]'::json) as rubric
      from lesson_activities a
     where a.lesson_id = ${lessonId}
  `);
  if (!row) throw notFound('Esta lección no tiene actividad configurada.');
  return row;
}

// ---------------------------------------------------------------------------
// Quiz
// ---------------------------------------------------------------------------

const quizAttemptBody = z.object({
  /** Una respuesta por pregunta: `{ [questionId]: índice | texto }`. */
  answers: z.record(z.string(), z.union([z.number().int(), z.string()])),
});

/** Umbral de aprobación. El mismo 60% que aplicaba el diálogo en Flutter. */
const PASSING_SCORE = 60;

/**
 * Resuelve un quiz y devuelve la nota.
 *
 * **La corrección ocurre acá, nunca en el cliente.** Antes el curso viajaba al
 * navegador con la clave de respuestas dentro, así que cualquiera podía leerla
 * desde las herramientas de desarrollo, y la nota que el cliente reportaba se
 * guardaba sin verificar. Ahora `answer_index`/`answer_text` no salen de la
 * base: llegan las respuestas, se comparan contra la clave y vuelve el
 * resultado.
 *
 * Se devuelve qué preguntas estuvieron bien —eso es retroalimentación
 * legítima— pero NO cuál era la respuesta correcta de las falladas: si la
 * devolviera, bastaría con enviar un intento en blanco para obtener la clave
 * completa.
 */
lessonRoutes.post('/:id/quiz-attempt', async (c) => {
  const user = currentUser(c);
  if (!isStudentLike(user.role)) {
    throw forbidden('Solo un estudiante resuelve un quiz.');
  }

  const db = c.get('db');
  const lessonId = c.req.param('id');
  const body = quizAttemptBody.parse(await c.req.json());

  const lesson = await assertLessonVisible(db, user, lessonId);

  // Una encuesta no tiene respuestas correctas: calificarla daría siempre 0 y
  // dejaría un intento reprobado en el historial de quien solo dio su opinión.
  // El portal la manda por `POST /submissions`, no por acá.
  if (lesson.type !== 'quiz') {
    throw conflict(
      'Esta lección no es un quiz, así que no se califica.',
      { type: lesson.type },
    );
  }

  const questions = await db
    .select()
    .from(quizQuestions)
    .where(eq(quizQuestions.lessonId, lessonId))
    .orderBy(asc(quizQuestions.orderIndex));

  if (questions.length === 0) {
    throw conflict('Esta lección no tiene preguntas configuradas.');
  }

  const correctOrders = await loadCorrectOrders(db, questions);

  const correctness: Record<string, boolean> = {};
  let correct = 0;
  for (const question of questions) {
    const given = body.answers[question.id];
    const ok = isCorrect(question, given, correctOrders.get(question.id));
    correctness[question.id] = ok;
    if (ok) correct += 1;
  }

  const score = Math.round((correct / questions.length) * 100);
  const passed = score >= PASSING_SCORE;

  const [attempt] = await db
    .insert(quizAttempts)
    .values({
      lessonId,
      studentId: user.id,
      answers: body.answers,
      score,
      passed,
    })
    .returning();

  return c.json({
    attemptId: attempt!.id,
    score,
    passed,
    correctCount: correct,
    totalQuestions: questions.length,
    correctness,
  });
});

/**
 * Compara una respuesta contra la clave.
 *
 * `multiple` y `truefalse` van por índice; `short` y `fill` por texto,
 * normalizando espacios, mayúsculas y tildes — quien escribe "Analisis" no
 * está equivocado respecto de "análisis".
 *
 * `order` sí se corrige: su clave es el orden en que están guardadas las
 * opciones y el cliente manda los elementos unidos por `|`. Antes devolvía
 * siempre `false` porque el formato no estaba definido en ningún lado; ahora lo
 * fija el constructor de lecciones, que es quien escribe esas opciones. Sin
 * esto, una pregunta de ordenar bajaba la nota de quien la respondía bien.
 */
function isCorrect(
  question: typeof quizQuestions.$inferSelect,
  given: number | string | undefined,
  correctOrder: string[] | undefined,
): boolean {
  if (given === undefined) return false;

  if (question.kind === 'multiple' || question.kind === 'truefalse') {
    return typeof given === 'number' && given === question.answerIndex;
  }
  if (question.kind === 'short' || question.kind === 'fill') {
    if (typeof given !== 'string' || question.answerText === null) return false;
    return normalize(given) === normalize(question.answerText);
  }
  if (question.kind === 'order') {
    if (typeof given !== 'string' || !correctOrder || correctOrder.length === 0) {
      return false;
    }
    return given === correctOrder.join(ORDER_SEPARATOR);
  }
  return false;
}

/**
 * Separador con el que el cliente une los elementos de una pregunta `order`.
 * Se comparan las dos cadenas ya unidas —nunca se parte la respuesta— así que
 * un elemento que contenga el separador sigue comparándose bien.
 */
const ORDER_SEPARATOR = '|';

/** El orden correcto de cada pregunta `order`, en una sola consulta. */
async function loadCorrectOrders(
  db: Db,
  questions: (typeof quizQuestions.$inferSelect)[],
): Promise<Map<string, string[]>> {
  const ids = questions.filter((q) => q.kind === 'order').map((q) => q.id);
  const byQuestion = new Map<string, string[]>();
  if (ids.length === 0) return byQuestion;

  const options = await db
    .select({
      questionId: quizQuestionOptions.quizQuestionId,
      text: quizQuestionOptions.text,
    })
    .from(quizQuestionOptions)
    .where(inArray(quizQuestionOptions.quizQuestionId, ids))
    .orderBy(asc(quizQuestionOptions.orderIndex));

  for (const option of options) {
    const list = byQuestion.get(option.questionId) ?? [];
    list.push(option.text);
    byQuestion.set(option.questionId, list);
  }
  return byQuestion;
}

const normalize = (text: string) =>
  text
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/\s+/g, ' ');

/**
 * Una persona solo resuelve quizzes de cursos a los que tiene acceso.
 *
 * Se apoya en `student_course_access`, la misma vista con la que se calcula la
 * completitud: si un curso no está en su acceso, tampoco cuenta para su avance.
 */
async function assertLessonVisible(
  db: Db,
  user: ReturnType<typeof currentUser>,
  lessonId: string,
): Promise<{ type: string }> {
  const [row] = await db.execute<{ type: string }>(sql`
    select l.type
      from lessons l
      join course_modules cm on cm.id = l.course_module_id
      join student_course_access a
        on a.course_id = cm.course_id and a.student_id = ${user.id}
     where l.id = ${lessonId}
     limit 1
  `);
  if (!row) throw notFound('No se encontró la lección.');
  return row;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function loadEditableModule(
  db: Db,
  moduleId: string,
  user: ReturnType<typeof currentUser>,
) {
  const [mod] = await db
    .select()
    .from(courseModules)
    .where(eq(courseModules.id, moduleId))
    .limit(1);
  if (!mod) throw notFound('No se encontró el módulo.');
  await loadEditableCourse(db, mod.courseId, user);
  return mod;
}

async function loadEditableLesson(
  db: Db,
  lessonId: string,
  user: ReturnType<typeof currentUser>,
) {
  const [lesson] = await db
    .select()
    .from(lessons)
    .where(eq(lessons.id, lessonId))
    .limit(1);
  if (!lesson) throw notFound('No se encontró la lección.');

  if (lesson.courseModuleId) {
    const [mod] = await db
      .select()
      .from(courseModules)
      .where(eq(courseModules.id, lesson.courseModuleId))
      .limit(1);
    if (!mod) throw notFound('No se encontró el módulo de la lección.');
    await loadEditableCourse(db, mod.courseId, user);
  } else if (user.role !== 'admin' && user.role !== 'superadmin') {
    // Las lecciones propias de un módulo de la Ruta de Impacto las edita el
    // Admin desde el editor de Ruta, no el LXD desde su curso.
    throw notFound('No se encontró la lección.');
  }
  return lesson;
}

async function renumberLessons(db: Db, moduleId: string) {
  await db.execute(sql`
    with ordenados as (
      select id, row_number() over (order by order_index) as nuevo
        from lessons where course_module_id = ${moduleId}
    )
    update lessons l set order_index = -o.nuevo
      from ordenados o where o.id = l.id
  `);
  await db.execute(sql`
    update lessons set order_index = -order_index
     where course_module_id = ${moduleId} and order_index < 0
  `);
}

