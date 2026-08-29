import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Grupo 3 de la Fase 4: aislamiento Enactus vs Open Learning.
 *
 * Esto NO es una preferencia de interfaz. Un estudiante de Open Learning no
 * debe poder obtener datos de Ruta de Impacto ni manipulando la URL ni
 * llamando el endpoint directamente — y la respuesta tiene que ser 403, no
 * una lista vacía: una lista vacía haría ver un bug de permisos como si fuera
 * "todavía no hay datos".
 *
 * El tipo de estudiante sale SIEMPRE del registro del usuario. No hay ningún
 * parámetro de petición que lo pueda cambiar.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

let olToken = '';
let enactusToken = '';
let alumniToken = '';
let adminToken = '';

const req = (path: string, token: string, init: RequestInit = {}) =>
  app.request(path, {
    ...init,
    headers: { ...(init.headers ?? {}), ...auth(token) },
  });

const body = async <T>(res: Response): Promise<T> => (await res.json()) as T;

/** Endpoints exclusivos de Enactus: un Open Learning no entra a ninguno. */
const SOLO_ENACTUS: [string, string, RequestInit?][] = [
  ['GET', '/laboratories'],
  ['GET', `/laboratories/${seedId('lab_ia')}`],
  ['GET', '/projects'],
  ['GET', `/projects/${seedId('prj1')}`],
  ['GET', '/groups'],
  ['GET', `/groups/${seedId('grp1')}`],
  ['GET', '/forum-posts'],
  ['GET', `/forum-posts/${seedId('post1')}`],
];

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;

  olToken = (await login(app, 'camila.rivas@gmail.com', 'Est123')).accessToken;
  enactusToken = (await login(app, 'estudiante1@uniandes.edu.co', 'Est123')).accessToken;
  alumniToken = (await login(app, 'alumni1@uniandes.edu.co', 'Alumni123')).accessToken;
  adminToken = (await login(app, 'admin@enactus.co', 'Admin123')).accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('Open Learning contra cada endpoint exclusivo de Enactus', () => {
  it.each(SOLO_ENACTUS)('%s %s → 403', async (method, path) => {
    const res = await req(path, olToken, { method });
    expect(res.status).toBe(403);
    const b = await body<{ error: { code: string } }>(res);
    expect(b.error.code).toBe('forbidden');
  });

  it('GET /students/:id/ruta-progress sobre sí mismo → 403, no vacío', async () => {
    const yo = await login(app, 'camila.rivas@gmail.com', 'Est123');
    const res = await req(`/students/${yo.userId}/ruta-progress`, olToken);
    expect(res.status).toBe(403);
    const b = await body<{ error: { message: string } }>(res);
    expect(b.error.message).toContain('Open Learning');
  });

  it('manipular el ID de la URL no le da datos ajenos', async () => {
    // Intenta pedir la Ruta de una estudiante Enactus poniendo su id.
    const res = await req(`/students/${seedId('est1')}/ruta-progress`, olToken);
    expect(res.status).toBe(403);

    // Y el progreso de curso de otra persona, también.
    const otro = await req(
      `/students/${seedId('est1')}/course-progress/${seedId('crs_ia_1')}`,
      olToken,
    );
    expect(otro.status).toBe(403);
  });

  it('no puede marcar una lección de un curso al que no tiene acceso', async () => {
    const res = await req(`/progress/lessons/${seedId('lia1')}/toggle`, olToken, {
      method: 'POST',
    });
    expect(res.status).toBe(403);
  });

  it('no puede publicar en el foro', async () => {
    const res = await req('/forum-posts', olToken, {
      ...json({ body: 'Hola', category: 'question' }),
    });
    expect(res.status).toBe(403);
  });
});

describe('Open Learning no ve laboratorios en NINGÚN listado', () => {
  it('el listado de cursos no incluye ninguno de laboratorio', async () => {
    const res = await req('/courses?pageSize=100', olToken);
    expect(res.status).toBe(200);
    const page = await body<{ data: { id: string; laboratoryId: string | null }[] }>(res);
    expect(page.data).toHaveLength(1);
    expect(page.data[0]?.id).toBe(seedId('crs_ol_marketing'));
    expect(page.data.every((c) => c.laboratoryId === null)).toBe(true);
  });

  it('el calendario no le muestra eventos de Ruta de Impacto ni de mentoría', async () => {
    await sql`
      insert into calendar_events (title, starts_at, type, laboratory_id)
      values ('Encuentro de Ruta', now(), 'ruta_impacto', ${seedId('lab_ia')})
    `;
    await sql`
      insert into calendar_events (title, starts_at, type, laboratory_id)
      values ('Mentoría IA', now(), 'mentoria', ${seedId('lab_ia')})
    `;

    const res = await req('/calendar-events?pageSize=100', olToken);
    const page = await body<{ data: { type: string }[] }>(res);
    expect(page.data.every((e) => e.type === 'open_learning_sync')).toBe(true);

    // La estudiante Enactus sí los ve.
    const enactus = await req('/calendar-events?pageSize=100', enactusToken);
    const suyos = await body<{ data: { type: string }[] }>(enactus);
    expect(suyos.data.some((e) => e.type === 'ruta_impacto')).toBe(true);
  });

  it('no tiene certificados de Ruta ni acceso a los de otros', async () => {
    const res = await req(`/certificates?studentId=${seedId('est1')}`, olToken);
    expect(res.status).toBe(403);
  });
});

describe('Enactus sí accede a todo lo suyo', () => {
  it.each(SOLO_ENACTUS)('%s %s → 200', async (method, path) => {
    const res = await req(path, enactusToken, { method });
    expect(res.status).toBe(200);
  });

  it('la alumni tiene el mismo acceso que una estudiante', async () => {
    for (const [method, path] of SOLO_ENACTUS) {
      const res = await req(path, alumniToken, { method });
      expect([200, 404]).toContain(res.status);
      expect(res.status).not.toBe(403);
    }
  });

  it('su Ruta de Impacto trae datos reales', async () => {
    const res = await req(`/students/${seedId('est1')}/ruta-progress`, enactusToken);
    expect(res.status).toBe(200);
    const b = await body<{ laboratories: { laboratoryName: string }[] }>(res);
    expect(b.laboratories.length).toBeGreaterThan(0);
  });
});

describe('el tipo de estudiante no se puede falsear desde la petición', () => {
  it('mandar studentType en el cuerpo no cambia nada', async () => {
    // Se intenta pasar `studentType: 'enactus'` en el cuerpo de una petición
    // de la estudiante Open Learning. El servidor lo ignora: el tipo sale del
    // registro del usuario.
    const res = await app.request('/forum-posts', {
      method: 'POST',
      headers: { ...auth(olToken), 'content-type': 'application/json' },
      body: JSON.stringify({
        body: 'Intento colarme',
        category: 'question',
        studentType: 'enactus',
        role: 'admin',
      }),
    });
    expect(res.status).toBe(403);
  });

  it('un admin sí ve el laboratorio, así que el 403 no es un 404 disfrazado', async () => {
    const res = await req(`/laboratories/${seedId('lab_ia')}`, adminToken);
    expect(res.status).toBe(200);
  });
});
