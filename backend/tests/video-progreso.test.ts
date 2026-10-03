import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Hasta dónde vio el video cada estudiante (`PUT /progress/lessons/:id/video`).
 *
 * Es una escritura de avance, así que se le exige lo mismo que al toggle: la
 * hace solo el propio estudiante, solo sobre lo que tiene asignado, y quien
 * no tiene acceso recibe una negativa — nunca una escritura que «no pasó
 * nada». Y se le exige lo que la distingue del toggle: NO completa la lección.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

let est1Id = '';
let est1Token = ''; // lab_ia: accede a crs_ia_1
let est3Token = ''; // lab_agua + lab_agricultura: NO accede a crs_ia_1
let mentorToken = '';
let lxdToken = '';
let adminToken = '';

const CURSO_IA = seedId('crs_ia_1');
const VIDEO_IA = seedId('lia1'); // video propio de crs_ia_1
const PDF_IA = seedId('lia3');

type Posicion = {
  lessonId: string;
  positionSec: number;
  furthestSec: number;
  durationSec: number | null;
  updatedAt: string;
};

const enviar = (method: string, path: string, token: string, body?: unknown) =>
  app.request(path, {
    method,
    headers: { 'content-type': 'application/json', ...auth(token) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });

const guardar = (lessonId: string, token: string, body: unknown) =>
  enviar('PUT', `/progress/lessons/${lessonId}/video`, token, body);

async function leer<T>(res: Response): Promise<T> {
  const texto = await res.text();
  return JSON.parse(texto) as T;
}

async function filas(lessonId: string) {
  return sql<{ student_id: string; position_sec: number }[]>`
    select student_id, position_sec from lesson_video_progress
     where lesson_id = ${lessonId}`;
}

beforeAll(async () => {
  const t = makeTestApp();
  app = t.app;
  sql = t.sql;
  await seedTestDatabase();
  const est1 = await login(app, 'estudiante1@uniandes.edu.co', 'Est123');
  est1Id = est1.userId;
  est1Token = est1.accessToken;
  est3Token = (await login(app, 'estudiante3@unal.edu.co', 'Est123')).accessToken;
  mentorToken = (await login(app, 'mentor.ia@enactus.co', 'Mentor123')).accessToken;
  lxdToken = (await login(app, 'lxd.ia@enactus.co', 'Lxd123')).accessToken;
  adminToken = (await login(app, 'admin@enactus.co', 'Admin123')).accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('guardar la posición', () => {
  it('la primera vez crea la fila; lo más lejos empieza donde va', async () => {
    const res = await guardar(VIDEO_IA, est1Token, {
      positionSec: 120,
      durationSec: 900,
    });
    const p = await leer<Posicion>(res);
    expect(res.status).toBe(200);
    expect(p).toMatchObject({
      lessonId: VIDEO_IA,
      positionSec: 120,
      furthestSec: 120,
      durationSec: 900,
    });
    expect(Number.isNaN(Date.parse(p.updatedAt))).toBe(false);
  });

  it('retroceder mueve dónde retomar, pero no resta lo ya visto', async () => {
    await guardar(VIDEO_IA, est1Token, { positionSec: 600, durationSec: 900 });
    const p = await leer<Posicion>(
      await guardar(VIDEO_IA, est1Token, { positionSec: 30, durationSec: 900 }),
    );
    expect(p.positionSec).toBe(30);
    expect(p.furthestSec).toBe(600);
  });

  it('un guardado sin duración conserva la que ya había', async () => {
    const p = await leer<Posicion>(
      await guardar(VIDEO_IA, est1Token, { positionSec: 40 }),
    );
    expect(p.durationSec).toBe(900);
  });

  it('una posición más allá del final se recorta a la duración', async () => {
    const p = await leer<Posicion>(
      await guardar(VIDEO_IA, est1Token, { positionSec: 905, durationSec: 900 }),
    );
    expect(p.positionSec).toBe(900);
    expect(p.furthestSec).toBe(900);
  });

  it('llegar al final NO completa la lección: eso es el toggle', async () => {
    // Si completara sola, quien desmarcó la lección para repasarla la vería
    // marcarse otra vez en el primer guardado. Una lección nueva, porque en
    // el seed est1 ya tiene `crs_ia_1` completo.
    const creada = await enviar(
      'POST',
      `/modules/${seedId('mia1')}/lessons`,
      adminToken,
      { title: 'Video sin completar', type: 'video' },
    );
    const { id } = await leer<{ id: string }>(creada);
    await enviar('POST', `/lessons/${id}/video-youtube`, adminToken, {
      videoId: 'dQw4w9WgXcQ',
    });

    const res = await guardar(id, est1Token, { positionSec: 212, durationSec: 212 });
    expect(res.status).toBe(200);

    const [fila] = await sql<{ n: number }[]>`
      select count(*)::int as n
        from progress_lessons pl
        join progress p on p.id = pl.progress_id
       where p.student_id = ${est1Id} and pl.lesson_id = ${id}`;
    expect(fila!.n).toBe(0);
  });

  it('valida el cuerpo: enteros, no negativos, con tope', async () => {
    for (const cuerpo of [
      {},
      { positionSec: -1 },
      { positionSec: 12.5 },
      { positionSec: '30' },
      { positionSec: 10, durationSec: 0 },
      { positionSec: 90_000 },
    ]) {
      resetRateLimits();
      const res = await guardar(VIDEO_IA, est1Token, cuerpo);
      expect(res.status, JSON.stringify(cuerpo)).toBe(400);
    }
  });
});

describe('quién puede', () => {
  it('nadie del equipo guarda posición: es avance de la persona', async () => {
    for (const token of [mentorToken, lxdToken, adminToken]) {
      resetRateLimits();
      const res = await guardar(VIDEO_IA, token, { positionSec: 10 });
      expect(res.status).toBe(403);
    }
  });

  it('una estudiante sin acceso al curso recibe 403 y no se escribe nada', async () => {
    const antes = (await filas(VIDEO_IA)).length;
    const res = await guardar(VIDEO_IA, est3Token, { positionSec: 10 });
    expect(res.status).toBe(403);
    expect((await filas(VIDEO_IA)).length).toBe(antes);
  });

  it('sin sesión, 401', async () => {
    const res = await app.request(`/progress/lessons/${VIDEO_IA}/video`, {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ positionSec: 1 }),
    });
    expect(res.status).toBe(401);
  });

  it('una lección que no es de video responde 409', async () => {
    const res = await guardar(PDF_IA, est1Token, { positionSec: 10 });
    expect(res.status).toBe(409);
  });

  it('una lección inexistente o un id mal formado responden 404', async () => {
    let res = await guardar('00000000-0000-4000-8000-000000000000', est1Token, {
      positionSec: 1,
    });
    expect(res.status).toBe(404);
    res = await guardar('no-es-un-uuid', est1Token, { positionSec: 1 });
    expect(res.status).toBe(404);
  });
});

describe('leerla de vuelta', () => {
  it('el progreso del curso trae la posición de cada video', async () => {
    await guardar(VIDEO_IA, est1Token, { positionSec: 300, durationSec: 900 });
    const res = await enviar(
      'GET',
      `/students/${est1Id}/course-progress/${CURSO_IA}`,
      est1Token,
    );
    const progreso = await leer<{
      videoProgress: Posicion[];
      completedLessonIds: string[];
    }>(res);
    expect(res.status).toBe(200);
    const video = progreso.videoProgress.find((v) => v.lessonId === VIDEO_IA);
    expect(video).toMatchObject({ positionSec: 300, furthestSec: 900 });
  });

  it('quien acompaña al estudiante también lo ve; otra estudiante no', async () => {
    let res = await enviar(
      'GET',
      `/students/${est1Id}/course-progress/${CURSO_IA}`,
      mentorToken,
    );
    const visto = await leer<{ videoProgress: Posicion[] }>(res);
    expect(res.status).toBe(200);
    expect(visto.videoProgress.some((v) => v.lessonId === VIDEO_IA)).toBe(true);

    res = await enviar(
      'GET',
      `/students/${est1Id}/course-progress/${CURSO_IA}`,
      est3Token,
    );
    expect(res.status).toBe(403);
  });

  it('un curso sin videos vistos trae la lista vacía, no la omite', async () => {
    // est2 está en lab_emprendimiento y nunca abrió un video.
    const est2 = await login(app, 'estudiante2@uniandes.edu.co', 'Est123');
    const [curso] = await sql<{ id: string }[]>`
      select id from courses
       where laboratory_id = ${seedId('lab_emprendimiento')}
         and deleted_at is null
       limit 1`;
    const res = await enviar(
      'GET',
      `/students/${est2.userId}/course-progress/${curso!.id}`,
      est2.accessToken,
    );
    const progreso = await leer<{ videoProgress: Posicion[] }>(res);
    expect(res.status).toBe(200);
    expect(progreso.videoProgress).toEqual([]);
  });
});

describe('lecciones propias de un módulo de la Ruta', () => {
  it('se guarda con el alcance del laboratorio, y la Ruta la devuelve', async () => {
    // El seed no trae lecciones propias de video: se crea una, de YouTube.
    const creada = await enviar(
      'POST',
      `/ruta-modules/${seedId('lab_ia_fase1_mod1')}/lessons`,
      adminToken,
      { title: 'Charla inaugural', type: 'video' },
    );
    const leccion = await leer<{ id: string }>(creada);
    expect(creada.status).toBe(201);
    const puesta = await enviar(
      'POST',
      `/lessons/${leccion.id}/video-youtube`,
      adminToken,
      { videoId: 'dQw4w9WgXcQ' },
    );
    expect(puesta.status).toBe(200);

    // est3 no está en lab_ia.
    expect((await guardar(leccion.id, est3Token, { positionSec: 5 })).status).toBe(403);

    const res = await guardar(leccion.id, est1Token, {
      positionSec: 75,
      durationSec: 212,
    });
    expect(res.status).toBe(200);

    const ruta = await leer<{
      laboratories: {
        phases: {
          modules: {
            ownLessons: {
              id: string;
              videoType: string | null;
              videoYoutubeId: string | null;
              videoProgress: { positionSec: number; durationSec: number } | null;
            }[];
          }[];
        }[];
      }[];
    }>(await enviar('GET', `/students/${est1Id}/ruta-progress`, est1Token));
    const propia = ruta.laboratories
      .flatMap((l) => l.phases)
      .flatMap((p) => p.modules)
      .flatMap((m) => m.ownLessons)
      .find((l) => l.id === leccion.id);
    expect(propia).toMatchObject({
      videoType: 'youtube',
      videoYoutubeId: 'dQw4w9WgXcQ',
      videoProgress: { positionSec: 75, durationSec: 212 },
    });
  });
});

describe('respaldo', () => {
  it('las posiciones viajan en el respaldo: son avance de las personas', async () => {
    const superadmin = await login(app, 'superadmin1@enactus.co', 'Super123');
    const res = await enviar('GET', '/admin/backup', superadmin.accessToken);
    const respaldo = await leer<{ data: Record<string, unknown[]> }>(res);
    expect(res.status).toBe(200);
    expect(respaldo.data['lesson_video_progress']?.length).toBeGreaterThan(0);
  });
});
