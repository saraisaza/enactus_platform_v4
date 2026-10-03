import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Video de YouTube guardado como id (`POST /lessons/:id/video-youtube`).
 *
 * Lo que se pide es «guardar SOLO el id», así que se comprueba en las dos
 * capas que pueden fallar por separado: la API —que un enlace pegado tal cual
 * se rechace— y la base —que ni una escritura directa pueda dejar una URL en
 * la columna del id, ni dos orígenes a la vez—.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

let adminToken = '';
let lxdToken = '';
let est1Token = '';

const ID = 'dQw4w9WgXcQ';
const CURSO_IA = seedId('crs_ia_1');
const MODULO_IA = seedId('mia1');

type Leccion = {
  id: string;
  type: string;
  videoType: string | null;
  videoYoutubeId: string | null;
  videoUrl: string | null;
  videoS3Key: string | null;
};

const enviar = (method: string, path: string, token: string, body?: unknown) =>
  app.request(path, {
    method,
    headers: { 'content-type': 'application/json', ...auth(token) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });

async function leer<T>(res: Response): Promise<T> {
  // Se lee UNA vez: `Response` no se puede leer dos veces.
  const texto = await res.text();
  return JSON.parse(texto) as T;
}

/** Una lección de video sin origen en el curso de IA (al que est1 accede). */
async function nuevaLeccion(titulo = 'Lección de YouTube'): Promise<string> {
  const res = await enviar('POST', `/modules/${MODULO_IA}/lessons`, adminToken, {
    title: titulo,
    type: 'video',
  });
  const texto = await res.text();
  expect(res.status, texto).toBe(201);
  return (JSON.parse(texto) as { id: string }).id;
}

async function fila(id: string) {
  const [f] = await sql<
    {
      video_type: string | null;
      video_youtube_id: string | null;
      video_url: string | null;
      video_s3_key: string | null;
    }[]
  >`select video_type, video_youtube_id, video_url, video_s3_key
      from lessons where id = ${id}`;
  return f!;
}

beforeAll(async () => {
  const t = makeTestApp();
  app = t.app;
  sql = t.sql;
  await seedTestDatabase();
  adminToken = (await login(app, 'admin@enactus.co', 'Admin123')).accessToken;
  lxdToken = (await login(app, 'lxd.ia@enactus.co', 'Lxd123')).accessToken;
  est1Token = (await login(app, 'estudiante1@uniandes.edu.co', 'Est123'))
    .accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('POST /lessons/:id/video-youtube', () => {
  it('guarda el id, y nada más', async () => {
    const id = await nuevaLeccion();
    const res = await enviar('POST', `/lessons/${id}/video-youtube`, adminToken, {
      videoId: ID,
    });
    const leccion = await leer<Leccion>(res);
    expect(res.status).toBe(200);
    expect(leccion.videoType).toBe('youtube');
    expect(leccion.videoYoutubeId).toBe(ID);
    expect(leccion.videoUrl).toBeNull();
    expect(leccion.videoS3Key).toBeNull();

    expect(await fila(id)).toEqual({
      video_type: 'youtube',
      video_youtube_id: ID,
      video_url: null,
      video_s3_key: null,
    });
  });

  it('el detalle del curso trae el id, que es lo que el reproductor necesita', async () => {
    const id = await nuevaLeccion('Para el detalle');
    await enviar('POST', `/lessons/${id}/video-youtube`, adminToken, { videoId: ID });

    // Lo pide la estudiante: es su lectura del curso, no la del editor.
    const res = await enviar(
      'GET',
      `/courses/${CURSO_IA}?include=modules,lessons`,
      est1Token,
    );
    const curso = await leer<{ modules: { lessons: Leccion[] }[] }>(res);
    expect(res.status).toBe(200);
    const leccion = curso.modules
      .flatMap((m) => m.lessons)
      .find((l) => l.id === id);
    expect(leccion?.videoType).toBe('youtube');
    expect(leccion?.videoYoutubeId).toBe(ID);
  });

  it('un enlace pegado tal cual se rechaza: el id lo saca el cliente', async () => {
    const id = await nuevaLeccion('Rechazos');
    for (const videoId of [
      `https://www.youtube.com/watch?v=${ID}`,
      `youtu.be/${ID}`,
      'dQw4w9WgXc', // 10
      'dQw4w9WgXcQQ', // 12
      'dQw4w9WgX!Q', // caracter fuera del alfabeto
      '',
    ]) {
      resetRateLimits();
      const res = await enviar('POST', `/lessons/${id}/video-youtube`, adminToken, {
        videoId,
      });
      const texto = await res.text();
      expect(res.status, `${videoId} -> ${texto}`).toBe(400);
      expect(texto).toContain('validation_error');
    }
    // Y la lección quedó como estaba: sin origen.
    expect((await fila(id)).video_type).toBeNull();
  });

  it('acepta un id con espacios alrededor, que es como llega de un copiar y pegar', async () => {
    const id = await nuevaLeccion('Con espacios');
    const res = await enviar('POST', `/lessons/${id}/video-youtube`, adminToken, {
      videoId: `  ${ID} `,
    });
    expect(res.status).toBe(200);
    expect((await fila(id)).video_youtube_id).toBe(ID);
  });

  it('un estudiante no puede ponerle video a una lección', async () => {
    const id = await nuevaLeccion('Ajena');
    const res = await enviar('POST', `/lessons/${id}/video-youtube`, est1Token, {
      videoId: ID,
    });
    expect(res.status).toBe(403);
    expect((await fila(id)).video_type).toBeNull();
  });

  it('un LXD que no creó el curso tampoco', async () => {
    // `crs_ia_1` lo creó lxd.ia; lxd.agua no tiene nada que hacer ahí.
    const otroLxd = (await login(app, 'lxd.agua@enactus.co', 'Lxd123'))
      .accessToken;
    const id = await nuevaLeccion('De otro');
    const res = await enviar('POST', `/lessons/${id}/video-youtube`, otroLxd, {
      videoId: ID,
    });
    expect(res.status).toBe(403);
    expect((await fila(id)).video_type).toBeNull();
  });

  it('el LXD que creó el curso sí', async () => {
    const id = await nuevaLeccion('Del creador');
    const res = await enviar('POST', `/lessons/${id}/video-youtube`, lxdToken, {
      videoId: ID,
    });
    expect(res.status).toBe(200);
  });

  it('cambiar de origen limpia los otros: nunca dos a la vez', async () => {
    const id = await nuevaLeccion('Cambios de origen');

    // youtube -> externo
    await enviar('POST', `/lessons/${id}/video-youtube`, adminToken, { videoId: ID });
    let res = await enviar('POST', `/lessons/${id}/video-external`, adminToken, {
      url: 'https://vimeo.com/76979871',
    });
    expect(res.status).toBe(200);
    expect(await fila(id)).toEqual({
      video_type: 'external',
      video_youtube_id: null,
      video_url: 'https://vimeo.com/76979871',
      video_s3_key: null,
    });

    // externo -> youtube
    res = await enviar('POST', `/lessons/${id}/video-youtube`, adminToken, {
      videoId: ID,
    });
    expect(res.status).toBe(200);
    expect((await fila(id)).video_url).toBeNull();

    // youtube -> archivo propio (paso 3 de la subida: solo confirma la key)
    res = await enviar('POST', `/lessons/${id}/video`, adminToken, {
      key: `lessons/${id}/video.mp4`,
      sizeBytes: 1024,
      mimeType: 'video/mp4',
    });
    expect(res.status, await res.clone().text()).toBe(200);
    expect(await fila(id)).toEqual({
      video_type: 'uploaded',
      video_youtube_id: null,
      video_url: null,
      video_s3_key: `lessons/${id}/video.mp4`,
    });

    // archivo propio -> youtube
    res = await enviar('POST', `/lessons/${id}/video-youtube`, adminToken, {
      videoId: ID,
    });
    expect(res.status).toBe(200);
    expect((await fila(id)).video_s3_key).toBeNull();
  });

  it('no se pide URL firmada para un video de YouTube, y el 409 lo dice', async () => {
    const id = await nuevaLeccion('Sin firma');
    await enviar('POST', `/lessons/${id}/video-youtube`, adminToken, { videoId: ID });

    const res = await enviar('GET', `/lessons/${id}/video-url`, est1Token);
    const cuerpo = await leer<{ error: { message: string } }>(res);
    expect(res.status).toBe(409);
    expect(cuerpo.error.message).toContain('YouTube');
  });

  it('un curso cuyo video es de YouTube se puede publicar', async () => {
    // La regla de publicar exige que toda lección de video tenga origen; el
    // id de YouTube cuenta como origen.
    const curso = await leer<{ id: string }>(
      await enviar('POST', '/courses', lxdToken, { name: 'Curso con YouTube' }),
    );
    const modulo = await leer<{ id: string }>(
      await enviar('POST', `/courses/${curso.id}/modules`, lxdToken, {
        title: 'Módulo 1',
      }),
    );
    const leccion = await leer<{ id: string }>(
      await enviar('POST', `/modules/${modulo.id}/lessons`, lxdToken, {
        title: 'Video',
        type: 'video',
      }),
    );

    let res = await enviar('POST', `/courses/${curso.id}/publish`, lxdToken);
    expect(res.status).toBe(409); // todavía sin origen

    await enviar('POST', `/lessons/${leccion.id}/video-youtube`, lxdToken, {
      videoId: ID,
    });
    res = await enviar('POST', `/courses/${curso.id}/publish`, lxdToken);
    expect(res.status, await res.clone().text()).toBe(200);
  });
});

describe('la base no deja guardar otra cosa que el id', () => {
  // Se escribe directo en la base, salteando la API: es justo el caso que el
  // CHECK tiene que cubrir — un error de la API, un script, una corrección a
  // mano.

  it('una URL en la columna del id viola el CHECK de formato', async () => {
    const id = await nuevaLeccion('CHECK formato');
    await expect(
      sql`update lessons
             set video_type = 'youtube',
                 video_youtube_id = ${`https://youtu.be/${ID}`}
           where id = ${id}`,
    ).rejects.toThrow(/lessons_video_youtube_id_format/);
  });

  it('youtube sin id, o youtube con URL, violan el CHECK de origen', async () => {
    const id = await nuevaLeccion('CHECK origen');
    await expect(
      sql`update lessons set video_type = 'youtube' where id = ${id}`,
    ).rejects.toThrow(/lessons_video_source/);
    await expect(
      sql`update lessons
             set video_type = 'youtube', video_youtube_id = ${ID},
                 video_url = ${`https://www.youtube.com/watch?v=${ID}`}
           where id = ${id}`,
    ).rejects.toThrow(/lessons_video_source/);
  });

  it('lo que el código anterior escribía sigue entrando', async () => {
    // El CHECK nuevo tiene que aceptar TODO lo que aceptaba el viejo: entre
    // migrar y publicar corre el código anterior contra este esquema, y tras
    // un rollback también. Ese código no conoce `video_youtube_id`, así que
    // al pasar una lección de youtube a externo deja el id puesto.
    const id = await nuevaLeccion('Código anterior');
    await enviar('POST', `/lessons/${id}/video-youtube`, adminToken, { videoId: ID });
    await sql`update lessons
                 set video_type = 'external',
                     video_url = ${`https://www.youtube.com/watch?v=${ID}`},
                     video_s3_key = null
               where id = ${id}`;
    expect((await fila(id)).video_type).toBe('external');
  });
});
