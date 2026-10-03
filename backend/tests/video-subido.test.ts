import { generateKeyPairSync } from 'node:crypto';

import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { env } from '../src/env';
import {
  VIDEO_PART_BYTES,
  awsMediaStorage,
  useMediaStorageForTests,
} from '../src/lib/media-storage';
import { createUploadUrl } from '../src/lib/s3';
import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';
import { FakeMediaStorage } from './helpers/fake-storage';

/**
 * Video subido como archivo: la subida por partes, la portada y el borrado de
 * los archivos que dejan de usarse.
 *
 * S3 es el de [FakeMediaStorage]: la suite corre sin AWS. Lo que se prueba es
 * lo que decide la API —qué permite, qué le cree al cliente (nada) y qué
 * borra (solo lo que ya nadie usa)—.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;
let s3: FakeMediaStorage;

let adminToken = '';
let lxdToken = ''; // lxd.ia: creó el curso de IA
let otroLxdToken = ''; // lxd.agua: no lo creó
let est1Token = '';

const MODULO_IA = seedId('mia1');
const MiB = 1024 * 1024;
/** Tres partes: dos de 8 MiB y una de 5 MiB + 7 bytes. */
const TAMANO = 2 * VIDEO_PART_BYTES + 5 * MiB + 7;

type Leccion = {
  id: string;
  videoType: string | null;
  videoS3Key: string | null;
  videoThumbnailS3Key: string | null;
  videoOriginalName: string | null;
  videoUploadedAt: string | null;
  videoSizeBytes: number | null;
  videoDurationSec: number | null;
  videoMimeType: string | null;
};

const enviar = (method: string, path: string, token: string, body?: unknown) =>
  app.request(path, {
    method,
    headers: { 'content-type': 'application/json', ...auth(token) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });

async function leer<T>(res: Response): Promise<T> {
  const texto = await res.text();
  return (texto ? JSON.parse(texto) : null) as T;
}

async function nuevaLeccion(titulo = 'Lección con video propio'): Promise<string> {
  const res = await enviar('POST', `/modules/${MODULO_IA}/lessons`, adminToken, {
    title: titulo,
    type: 'video',
  });
  const texto = await res.text();
  expect(res.status, texto).toBe(201);
  return (JSON.parse(texto) as { id: string }).id;
}

type Abierta = { key: string; uploadId: string; partSizeBytes: number; partCount: number };

async function abrir(leccion: string, tamano = TAMANO, token = adminToken) {
  const res = await enviar('POST', `/lessons/${leccion}/video-uploads`, token, {
    fileName: 'clase 1.mp4',
    contentType: 'video/mp4',
    sizeBytes: tamano,
  });
  const cuerpo = await leer<Abierta>(res);
  expect(res.status, JSON.stringify(cuerpo)).toBe(201);
  return cuerpo;
}

/** Sube TODAS las partes con su tamaño exacto, como lo haría el navegador. */
function subirTodo(abierta: Abierta, tamano = TAMANO) {
  for (let n = 1; n <= abierta.partCount; n++) {
    const parte = n < abierta.partCount ? VIDEO_PART_BYTES : tamano - VIDEO_PART_BYTES * (n - 1);
    s3.subirParte(abierta.uploadId, n, parte);
  }
}

async function completar(
  leccion: string,
  abierta: Abierta,
  extra: Record<string, unknown> = {},
  tamano = TAMANO,
) {
  return enviar('POST', `/lessons/${leccion}/video-uploads/complete`, adminToken, {
    key: abierta.key,
    uploadId: abierta.uploadId,
    fileName: 'C:\\Users\\lxd\\Videos\\clase 1.mp4',
    sizeBytes: tamano,
    durationSec: 754,
    ...extra,
  });
}

/** Una lección con un video ya subido (y su portada, si se pide). */
async function leccionConVideo(conPortada = true) {
  const id = await nuevaLeccion();
  const abierta = await abrir(id);
  subirTodo(abierta);
  let portada: string | undefined;
  if (conPortada) {
    const res = await enviar('POST', `/lessons/${id}/video-thumbnail-upload-url`, adminToken, {
      contentType: 'image/jpeg',
      sizeBytes: 40_000,
    });
    portada = (await leer<{ key: string }>(res)).key;
    s3.subirObjeto(portada, 40_000);
  }
  const res = await completar(id, abierta, portada ? { thumbnailKey: portada } : {});
  expect(res.status, await res.clone().text()).toBe(200);
  return { id, video: abierta.key, portada };
}

const cola = async () =>
  (
    await sql<{ key: string; attempts: number }[]>`
      select key, attempts from storage_pending_deletes order by key`
  ).map((r) => ({ key: r.key, attempts: r.attempts }));

beforeAll(async () => {
  const t = makeTestApp();
  app = t.app;
  sql = t.sql;
  await seedTestDatabase();
  adminToken = (await login(app, 'admin@enactus.co', 'Admin123')).accessToken;
  lxdToken = (await login(app, 'lxd.ia@enactus.co', 'Lxd123')).accessToken;
  otroLxdToken = (await login(app, 'lxd.agua@enactus.co', 'Lxd123')).accessToken;
  est1Token = (await login(app, 'estudiante1@uniandes.edu.co', 'Est123')).accessToken;
}, 120_000);

beforeEach(async () => {
  resetRateLimits();
  s3 = new FakeMediaStorage();
  useMediaStorageForTests(s3);
  await sql`delete from storage_pending_deletes`;
});

afterAll(async () => {
  useMediaStorageForTests(null);
  await sql.end();
});

describe('abrir la subida', () => {
  it('solo MP4: otro formato se rechaza diciendo cuál es', async () => {
    const id = await nuevaLeccion();
    const res = await enviar('POST', `/lessons/${id}/video-uploads`, adminToken, {
      fileName: 'clase.webm',
      contentType: 'video/webm',
      sizeBytes: 1000,
    });
    const cuerpo = await leer<{ error: { message: string } }>(res);
    expect(res.status).toBe(400);
    expect(cuerpo.error.message).toMatch(/Solo se aceptan videos MP4.*video\/webm/);
    expect(s3.subidas.size).toBe(0);
  });

  it('más de 500 MB se rechaza con 413, sin abrir nada en S3', async () => {
    const id = await nuevaLeccion();
    const res = await enviar('POST', `/lessons/${id}/video-uploads`, adminToken, {
      fileName: 'largo.mp4',
      contentType: 'video/mp4',
      sizeBytes: 501 * 1024 * 1024,
    });
    expect(res.status).toBe(413);
    expect(s3.subidas.size).toBe(0);
  });

  it('devuelve la key de esta lección, el id de la subida y cuántas partes van', async () => {
    const id = await nuevaLeccion();
    const abierta = await abrir(id);
    expect(abierta.key).toMatch(new RegExp(`^lessons/${id}/[0-9a-f-]{36}\\.mp4$`));
    expect(abierta.partSizeBytes).toBe(VIDEO_PART_BYTES);
    expect(abierta.partCount).toBe(3);
    expect(s3.subidas.get(abierta.uploadId)?.key).toBe(abierta.key);
  });

  it('el LXD que creó el curso puede; un estudiante y otro LXD no', async () => {
    const id = await nuevaLeccion();
    await abrir(id, TAMANO, lxdToken);
    const cuerpo = { fileName: 'a.mp4', contentType: 'video/mp4', sizeBytes: 10 };
    expect(
      (await enviar('POST', `/lessons/${id}/video-uploads`, est1Token, cuerpo)).status,
    ).toBe(403);
    expect(
      (await enviar('POST', `/lessons/${id}/video-uploads`, otroLxdToken, cuerpo)).status,
    ).toBe(403);
  });
});

describe('firmar las partes', () => {
  it('cada URL va firmada con el tamaño exacto de su parte', async () => {
    const id = await nuevaLeccion();
    const abierta = await abrir(id);
    const res = await enviar('POST', `/lessons/${id}/video-uploads/sign`, adminToken, {
      key: abierta.key,
      uploadId: abierta.uploadId,
      sizeBytes: TAMANO,
      partNumbers: [1, 3, 3],
    });
    const cuerpo = await leer<{ parts: { partNumber: number; url: string }[] }>(res);
    expect(res.status).toBe(200);
    expect(cuerpo.parts.map((p) => p.partNumber)).toEqual([1, 3]);
    expect(cuerpo.parts[0]!.url).toContain(`size=${VIDEO_PART_BYTES}`);
    expect(cuerpo.parts[1]!.url).toContain(`size=${5 * MiB + 7}`);
  });

  it('una parte que no existe es un 400', async () => {
    const id = await nuevaLeccion();
    const abierta = await abrir(id);
    const res = await enviar('POST', `/lessons/${id}/video-uploads/sign`, adminToken, {
      key: abierta.key,
      uploadId: abierta.uploadId,
      sizeBytes: TAMANO,
      partNumbers: [4],
    });
    expect(res.status).toBe(400);
  });

  it('la key de otra lección no se firma', async () => {
    const id = await nuevaLeccion();
    const otra = await nuevaLeccion('Otra');
    const abierta = await abrir(otra);
    const res = await enviar('POST', `/lessons/${id}/video-uploads/sign`, adminToken, {
      key: abierta.key,
      uploadId: abierta.uploadId,
      sizeBytes: TAMANO,
      partNumbers: [1],
    });
    expect(res.status).toBe(409);
  });
});

describe('retomar', () => {
  it('lista las partes que ya llegaron, para subir solo las que faltan', async () => {
    const id = await nuevaLeccion();
    const abierta = await abrir(id);
    s3.subirParte(abierta.uploadId, 3, 5 * MiB + 7);
    s3.subirParte(abierta.uploadId, 1, VIDEO_PART_BYTES);
    const res = await enviar(
      'GET',
      `/lessons/${id}/video-uploads/parts?key=${encodeURIComponent(abierta.key)}&uploadId=${abierta.uploadId}`,
      adminToken,
    );
    expect(res.status).toBe(200);
    expect(await leer(res)).toEqual({
      parts: [
        { partNumber: 1, sizeBytes: VIDEO_PART_BYTES },
        { partNumber: 3, sizeBytes: 5 * MiB + 7 },
      ],
    });
  });

  it('una subida que ya no existe responde 404 con su código', async () => {
    const id = await nuevaLeccion();
    const abierta = await abrir(id);
    s3.subidas.clear();
    const res = await enviar(
      'GET',
      `/lessons/${id}/video-uploads/parts?key=${encodeURIComponent(abierta.key)}&uploadId=${abierta.uploadId}`,
      adminToken,
    );
    const cuerpo = await leer<{ error: { code: string } }>(res);
    expect(res.status).toBe(404);
    expect(cuerpo.error.code).toBe('upload_not_found');
  });
});

describe('completar', () => {
  it('si falta una parte no cierra nada y dice cuál', async () => {
    const id = await nuevaLeccion();
    const abierta = await abrir(id);
    s3.subirParte(abierta.uploadId, 1, VIDEO_PART_BYTES);
    s3.subirParte(abierta.uploadId, 3, 5 * MiB + 7);
    const res = await completar(id, abierta);
    const cuerpo = await leer<{ error: { details: { missingParts: number[] } } }>(res);
    expect(res.status).toBe(409);
    expect(cuerpo.error.details.missingParts).toEqual([2]);
    expect(s3.objetos.has(abierta.key)).toBe(false);
    const [fila] = await sql<{ video_s3_key: string | null }[]>`
      select video_s3_key from lessons where id = ${id}`;
    expect(fila!.video_s3_key).toBeNull();
  });

  it('una parte de otro tamaño tampoco: el cliente no decide qué quedó', async () => {
    const id = await nuevaLeccion();
    const abierta = await abrir(id);
    s3.subirParte(abierta.uploadId, 1, VIDEO_PART_BYTES);
    s3.subirParte(abierta.uploadId, 2, VIDEO_PART_BYTES - 1);
    s3.subirParte(abierta.uploadId, 3, 5 * MiB + 7);
    expect((await completar(id, abierta)).status).toBe(409);
  });

  it('con todo en orden, la lección queda apuntando al video', async () => {
    const { id, video, portada } = await leccionConVideo();
    const [fila] = await sql<
      {
        type: string;
        video_type: string;
        video_s3_key: string;
        video_thumbnail_s3_key: string;
        video_original_name: string;
        video_uploaded_at: Date | null;
        video_size_bytes: string;
        video_mime_type: string;
        video_duration_sec: number;
      }[]
    >`select type, video_type, video_s3_key, video_thumbnail_s3_key,
             video_original_name, video_uploaded_at, video_size_bytes,
             video_mime_type, video_duration_sec
        from lessons where id = ${id}`;
    expect(fila).toMatchObject({
      type: 'video',
      video_type: 'uploaded',
      video_s3_key: video,
      video_thumbnail_s3_key: portada,
      // Sin la ruta de la máquina de quien lo subió.
      video_original_name: 'clase 1.mp4',
      video_mime_type: 'video/mp4',
      video_duration_sec: 754,
    });
    expect(Number(fila!.video_size_bytes)).toBe(TAMANO);
    expect(fila!.video_uploaded_at).not.toBeNull();
    expect(s3.objetos.get(video)).toBe(TAMANO);
  });

  it('una portada que no llegó no tumba el video: queda sin portada', async () => {
    const id = await nuevaLeccion();
    const abierta = await abrir(id);
    subirTodo(abierta);
    const res = await completar(id, abierta, {
      thumbnailKey: `lessons/${id}/thumb-no-llego.jpg`,
    });
    const leccion = await leer<Leccion>(res);
    expect(res.status).toBe(200);
    expect(leccion.videoS3Key).toBe(abierta.key);
    expect(leccion.videoThumbnailS3Key).toBeNull();
  });

  it('la portada de otra lección no se acepta', async () => {
    const id = await nuevaLeccion();
    const otra = await nuevaLeccion('Otra');
    const abierta = await abrir(id);
    subirTodo(abierta);
    const res = await completar(id, abierta, { thumbnailKey: `lessons/${otra}/thumb-x.jpg` });
    expect(res.status).toBe(409);
  });

  it('reemplazar el video borra el anterior y su portada', async () => {
    const { id, video, portada } = await leccionConVideo();
    const abierta = await abrir(id);
    subirTodo(abierta);
    const res = await completar(id, abierta);
    expect(res.status).toBe(200);
    expect(s3.borrados.sort()).toEqual([portada!, video].sort());
    expect(s3.objetos.has(video)).toBe(false);
    expect(s3.objetos.has(abierta.key)).toBe(true);
    expect(await cola()).toEqual([]);
  });
});

describe('cancelar', () => {
  it('cancela la subida en S3', async () => {
    const id = await nuevaLeccion();
    const abierta = await abrir(id);
    const res = await enviar(
      'DELETE',
      `/lessons/${id}/video-uploads?key=${encodeURIComponent(abierta.key)}&uploadId=${abierta.uploadId}`,
      adminToken,
    );
    expect(res.status).toBe(204);
    expect(s3.canceladas).toEqual([abierta.uploadId]);
    expect(s3.subidas.has(abierta.uploadId)).toBe(false);
  });
});

describe('portada', () => {
  it('pide permiso solo para JPG, PNG o WebP de hasta 5 MB', async () => {
    const { id } = await leccionConVideo(false);
    const ok = await enviar('POST', `/lessons/${id}/video-thumbnail-upload-url`, adminToken, {
      contentType: 'image/png',
      sizeBytes: 1000,
    });
    const cuerpo = await leer<{ key: string; uploadUrl: string; method: string }>(ok);
    expect(ok.status).toBe(200);
    expect(cuerpo.key).toMatch(new RegExp(`^lessons/${id}/thumb-[0-9a-f-]{36}\\.png$`));
    expect(cuerpo.method).toBe('PUT');

    const gif = await enviar('POST', `/lessons/${id}/video-thumbnail-upload-url`, adminToken, {
      contentType: 'image/gif',
      sizeBytes: 1000,
    });
    expect(gif.status).toBe(400);
    const grande = await enviar('POST', `/lessons/${id}/video-thumbnail-upload-url`, adminToken, {
      contentType: 'image/jpeg',
      sizeBytes: 6 * MiB,
    });
    expect(grande.status).toBe(413);
  });

  it('cambiarla borra la anterior; quitarla también', async () => {
    const { id, portada } = await leccionConVideo();
    const nueva = `lessons/${id}/thumb-nueva.jpg`;

    // Una portada que no llegó a S3 no se acepta.
    expect(
      (await enviar('PUT', `/lessons/${id}/video-thumbnail`, adminToken, { key: nueva })).status,
    ).toBe(409);

    s3.subirObjeto(nueva, 1000);
    const res = await enviar('PUT', `/lessons/${id}/video-thumbnail`, adminToken, { key: nueva });
    expect(res.status).toBe(200);
    expect((await leer<Leccion>(res)).videoThumbnailS3Key).toBe(nueva);
    expect(s3.borrados).toEqual([portada]);

    const sin = await enviar('PUT', `/lessons/${id}/video-thumbnail`, adminToken, { key: null });
    expect((await leer<Leccion>(sin)).videoThumbnailS3Key).toBeNull();
    expect(s3.borrados).toEqual([portada, nueva]);
  });

  it('una lección de YouTube no lleva portada propia', async () => {
    const id = await nuevaLeccion();
    await enviar('POST', `/lessons/${id}/video-youtube`, adminToken, { videoId: 'dQw4w9WgXcQ' });
    const res = await enviar('PUT', `/lessons/${id}/video-thumbnail`, adminToken, {
      key: `lessons/${id}/thumb-x.jpg`,
    });
    expect(res.status).toBe(409);
  });
});

describe('archivos huérfanos', () => {
  it('pasar la lección a YouTube borra el video y la portada', async () => {
    const { id, video, portada } = await leccionConVideo();
    const res = await enviar('POST', `/lessons/${id}/video-youtube`, adminToken, {
      videoId: 'dQw4w9WgXcQ',
    });
    const leccion = await leer<Leccion>(res);
    expect(res.status).toBe(200);
    expect(leccion.videoThumbnailS3Key).toBeNull();
    expect(leccion.videoOriginalName).toBeNull();
    expect(s3.borrados.sort()).toEqual([portada!, video].sort());
  });

  it('borrar la lección borra sus archivos', async () => {
    const { id, video, portada } = await leccionConVideo();
    expect((await enviar('DELETE', `/lessons/${id}`, adminToken)).status).toBe(204);
    expect(s3.borrados.sort()).toEqual([portada!, video].sort());
    expect(await cola()).toEqual([]);
  });

  it('borrar el módulo también, aunque las lecciones se vayan en cascada', async () => {
    const mod = await enviar('POST', `/courses/${seedId('crs_ia_1')}/modules`, adminToken, {
      title: 'Módulo que se va',
    });
    const texto = await mod.text();
    expect(mod.status, texto).toBe(201);
    const moduloId = (JSON.parse(texto) as { id: string }).id;
    const creada = await enviar('POST', `/modules/${moduloId}/lessons`, adminToken, {
      title: 'Dentro del módulo',
      type: 'video',
    });
    const id = (await leer<{ id: string }>(creada)).id;
    const abierta = await abrir(id);
    subirTodo(abierta);
    expect((await completar(id, abierta)).status).toBe(200);

    expect((await enviar('DELETE', `/modules/${moduloId}`, adminToken)).status).toBe(204);
    expect(s3.borrados).toEqual([abierta.key]);
  });

  it('si S3 no deja borrar, queda en la cola y se reintenta en el siguiente cambio', async () => {
    const { id, video, portada } = await leccionConVideo();
    s3.borradoFalla.add(video);
    await enviar('POST', `/lessons/${id}/video-youtube`, adminToken, { videoId: 'dQw4w9WgXcQ' });
    expect(s3.borrados).toEqual([portada]);
    expect(await cola()).toEqual([{ key: video, attempts: 1 }]);
    const [fila] = await sql<{ last_error: string }[]>`
      select last_error from storage_pending_deletes where key = ${video}`;
    expect(fila!.last_error).toMatch(/AccessDenied/);

    // Cualquier otro cambio de video vacía lo pendiente.
    s3.borradoFalla.clear();
    const otra = await leccionConVideo(false);
    await enviar('DELETE', `/lessons/${otra.id}`, adminToken);
    expect(s3.borrados).toContain(video);
    expect(await cola()).toEqual([]);
  });

  it('una key que volvió a quedar en uso no se borra (restaurar un respaldo)', async () => {
    const { video } = await leccionConVideo();
    // Lo que deja una restauración: la cola anotó la key al borrar la fila,
    // y la fila volvió con la misma key.
    await sql`insert into storage_pending_deletes (key, reason)
              values (${video}, 'lesson_deleted')`;
    const otra = await leccionConVideo(false);
    await enviar('DELETE', `/lessons/${otra.id}`, adminToken);
    expect(s3.borrados).not.toContain(video);
    expect(s3.objetos.has(video)).toBe(true);
    expect(await cola()).toEqual([]);
  });

  it('las keys del seed nunca se anotan: staging y producción comparten el bucket', async () => {
    const [delSeed] = await sql<{ id: string; video_s3_key: string }[]>`
      select id, video_s3_key from lessons
       where video_type = 'uploaded' and video_s3_key not like 'lessons/%'
       limit 1`;
    expect(delSeed, 'el seed tiene que traer un video propio').toBeDefined();
    await enviar('POST', `/lessons/${delSeed!.id}/video-youtube`, adminToken, {
      videoId: 'dQw4w9WgXcQ',
    });
    expect(s3.borrados).toEqual([]);
    expect(await cola()).toEqual([]);
  });
});

describe('GET /lessons/:id/video-url', () => {
  it('trae la portada firmada, con la misma autorización que el video', async () => {
    const { id, portada } = await leccionConVideo();
    const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
    const antes = {
      d: env.CLOUDFRONT_DOMAIN,
      k: env.CLOUDFRONT_KEY_PAIR_ID,
      p: env.CLOUDFRONT_PRIVATE_KEY,
    };
    env.CLOUDFRONT_DOMAIN = 'videos.prueba';
    env.CLOUDFRONT_KEY_PAIR_ID = 'KPRUEBA';
    env.CLOUDFRONT_PRIVATE_KEY = privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
    try {
      const res = await enviar('GET', `/lessons/${id}/video-url`, est1Token);
      const cuerpo = await leer<{ url: string; thumbnailUrl: string | null }>(res);
      expect(res.status).toBe(200);
      expect(cuerpo.url).toContain('https://videos.prueba/lessons/');
      expect(cuerpo.thumbnailUrl).toContain(`https://videos.prueba/${portada}?`);
      expect(cuerpo.thumbnailUrl).toContain('Signature=');

      // Quien no tiene acceso al curso no recibe ni el video ni la portada.
      const ajeno = (await login(app, 'estudiante3@unal.edu.co', 'Est123')).accessToken;
      expect((await enviar('GET', `/lessons/${id}/video-url`, ajeno)).status).toBe(404);
    } finally {
      env.CLOUDFRONT_DOMAIN = antes.d;
      env.CLOUDFRONT_KEY_PAIR_ID = antes.k;
      env.CLOUDFRONT_PRIVATE_KEY = antes.p;
    }
  });
});

describe('sin almacenamiento configurado', () => {
  it('abrir una subida responde 503 diciendo qué falta', async () => {
    useMediaStorageForTests(null);
    try {
      const id = await nuevaLeccion();
      const res = await enviar('POST', `/lessons/${id}/video-uploads`, adminToken, {
        fileName: 'a.mp4',
        contentType: 'video/mp4',
        sizeBytes: 1000,
      });
      const cuerpo = await leer<{ error: { code: string; message: string } }>(res);
      expect(res.status).toBe(503);
      expect(cuerpo.error.code).toBe('storage_not_configured');
      expect(cuerpo.error.message).toMatch(/S3_BUCKET/);
    } finally {
      useMediaStorageForTests(s3);
    }
  });
});

describe('las URLs firmadas de verdad (SDK de AWS, sin S3 de por medio)', () => {
  it('no llevan el checksum de un cuerpo vacío: S3 rechazaría la subida', async () => {
    // Firmar es un cálculo local: alcanza con un bucket y unas credenciales
    // de mentira para ver la URL que recibiría el navegador.
    const antes = {
      bucket: env.S3_BUCKET,
      id: process.env.AWS_ACCESS_KEY_ID,
      secreto: process.env.AWS_SECRET_ACCESS_KEY,
    };
    env.S3_BUCKET = 'bucket-de-prueba';
    process.env.AWS_ACCESS_KEY_ID = 'AKIAPRUEBA';
    process.env.AWS_SECRET_ACCESS_KEY = 'secreto-de-prueba';
    try {
      const parte = await awsMediaStorage.signUploadPart(
        'lessons/x/video.mp4',
        'subida-1',
        1,
        VIDEO_PART_BYTES,
      );
      const portada = await awsMediaStorage.signPutObject(
        'lessons/x/thumb-1.jpg',
        'image/jpeg',
        1000,
      );
      const simple = await createUploadUrl({
        key: 'covers/x.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 1000,
      });
      for (const url of [parte, portada, simple.uploadUrl]) {
        expect(url).toContain('X-Amz-Signature=');
        expect(url.toLowerCase()).not.toContain('x-amz-checksum');
        expect(url.toLowerCase()).not.toContain('x-amz-sdk-checksum-algorithm');
      }
      expect(parte).toContain('partNumber=1');
      expect(parte).toContain('uploadId=subida-1');
    } finally {
      env.S3_BUCKET = antes.bucket;
      if (antes.id === undefined) delete process.env.AWS_ACCESS_KEY_ID;
      else process.env.AWS_ACCESS_KEY_ID = antes.id;
      if (antes.secreto === undefined) delete process.env.AWS_SECRET_ACCESS_KEY;
      else process.env.AWS_SECRET_ACCESS_KEY = antes.secreto;
    }
  });
});
