import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * El calendario por alcance (pedido de Sara, 2026-10-17).
 *
 * El LXD y el admin agendan para un curso, para un laboratorio o para toda
 * una organización (su empresa, o Enactus). Quien está en ese curso,
 * laboratorio u organización lo ve; nadie más. Antes un LXD solo agendaba
 * sesiones de Open Learning y el servidor no revisaba que el curso fuera
 * suyo.
 */

let t: ReturnType<typeof makeTestApp>;
let sql: Sql;
const tok: Record<string, string> = {};
let andino = '';
let norte = '';
let enactus = '';
let cursoAndino = '';

const CURSO_IA = seedId('crs_ia_1'); // de lxd.ia, en lab_ia
const CURSO_AGUA = seedId('crs_agua_1'); // de lxd.agua
const LAB_IA = seedId('lab_ia');
const LAB_AGUA = seedId('lab_agua');

const pedir = (ruta: string, metodo: string, token: string, cuerpo?: unknown) =>
  t.app.request(ruta, {
    method: metodo,
    headers: { 'content-type': 'application/json', ...auth(token) },
    body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
  });

const evento = (titulo: string, destino: Record<string, unknown>) => ({
  title: titulo,
  startsAt: '2026-11-03T15:00:00.000Z',
  ...destino,
});

const agendar = (quien: string, titulo: string, destino: Record<string, unknown>) =>
  pedir('/calendar-events', 'POST', tok[quien]!, evento(titulo, destino));

async function titulosDe(quien: string): Promise<string[]> {
  const res = await pedir('/calendar-events?pageSize=100', 'GET', tok[quien]!);
  expect(res.status).toBe(200);
  return ((await res.json()) as { data: { title: string }[] }).data.map((e) => e.title);
}

beforeAll(async () => {
  await seedTestDatabase();
  t = makeTestApp();
  sql = t.sql;
  tok.admin = (await login(t.app, 'admin@enactus.co', 'Admin123')).accessToken;
  const crear = async (ruta: string, cuerpo: unknown, token = tok.admin!) => {
    const res = await pedir(ruta, 'POST', token, cuerpo);
    expect(res.status, `${ruta}: ${await res.clone().text()}`).toBe(201);
    return ((await res.json()) as { id: string }).id;
  };

  andino = await crear('/clients', { name: 'Banco Andino' });
  norte = await crear('/clients', { name: 'Banco Norte' });
  const [e] = await sql<{ id: string }[]>`select id from clients where has_laboratories`;
  enactus = e!.id;

  const cuenta = (email: string, campos: Record<string, unknown>) =>
    crear('/users', { name: email.split('@')[0], email, password: 'Clave123', ...campos });
  const ana = await cuenta('ana@andino.co', {
    role: 'student', studentType: 'open_learning', clientId: andino,
  });
  await cuenta('luis@norte.co', { role: 'student', studentType: 'open_learning', clientId: norte });
  await cuenta('jefa@andino.co', { role: 'supervisor', clientId: andino });
  await cuenta('lxd@andino.co', { role: 'lxd', clientId: andino });

  for (const [clave, correo, clave2] of [
    ['ana', 'ana@andino.co', 'Clave123'],
    ['luis', 'luis@norte.co', 'Clave123'],
    ['jefa', 'jefa@andino.co', 'Clave123'],
    ['lxdAndino', 'lxd@andino.co', 'Clave123'],
    ['lxdIa', 'lxd.ia@enactus.co', 'Lxd123'],
    ['lxdAgua', 'lxd.agua@enactus.co', 'Lxd123'],
    ['est1', 'estudiante1@uniandes.edu.co', 'Est123'], // crs_ia_1, lab_ia
    ['est2', 'estudiante2@uniandes.edu.co', 'Est123'], // otro laboratorio
    ['est3', 'estudiante3@unal.edu.co', 'Est123'], // sin crs_ia_1
    ['mentor', 'mentor.ia@enactus.co', 'Mentor123'],
  ] as const) {
    tok[clave] = (await login(t.app, correo, clave2)).accessToken;
  }

  // Una capacitación que crea el LXD de la empresa, asignada a Ana.
  cursoAndino = await crear('/courses', { name: 'Riesgo bancario', isOpenLearning: true },
    tok.lxdAndino);
  await sql`update courses set status = 'published' where id = ${cursoAndino}`;
  const asignar = await pedir(`/users/${ana}/courses`, 'PUT', tok.admin, { ids: [cursoAndino] });
  expect(asignar.status, await asignar.clone().text()).toBe(200);
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('un evento de un curso', () => {
  it('lo ve todo el que cursa el curso, y nadie más', async () => {
    const res = await agendar('lxdIa', 'Sesión IA', { type: 'open_learning_sync', courseId: CURSO_IA });
    expect(res.status, await res.clone().text()).toBe(201);
    expect(await titulosDe('est1')).toContain('Sesión IA');
    expect(await titulosDe('est3')).not.toContain('Sesión IA');
    expect(await titulosDe('lxdIa')).toContain('Sesión IA');
  });

  it('también en un curso de laboratorio, no solo de Open Learning', async () => {
    // crs_ia_1 es de un laboratorio: antes la pantalla ni lo ofrecía.
    const [curso] = await sql<{ laboratory_id: string | null }[]>`
      select laboratory_id from courses where id = ${CURSO_IA}`;
    expect(curso!.laboratory_id).toBe(LAB_IA);
  });

  it('un LXD solo agenda en los cursos que creó', async () => {
    const res = await agendar('lxdAgua', 'Intruso', { type: 'open_learning_sync', courseId: CURSO_IA });
    expect(res.status).toBe(403);
    expect(await res.text()).toContain('cursos que usted creó');
  });

  it('en una empresa, lo ven sus empleados del curso y su supervisor', async () => {
    const res = await agendar('lxdAndino', 'Taller de riesgo', {
      type: 'open_learning_sync', courseId: cursoAndino,
    });
    expect(res.status, await res.clone().text()).toBe(201);
    expect(await titulosDe('ana')).toContain('Taller de riesgo');
    expect(await titulosDe('jefa')).toContain('Taller de riesgo');
    expect(await titulosDe('luis')).not.toContain('Taller de riesgo');
  });

  it('sin curso: 400', async () => {
    expect((await agendar('lxdIa', 'Sin curso', { type: 'open_learning_sync' })).status).toBe(400);
  });
});

describe('un evento de un laboratorio', () => {
  it('el LXD lo agenda en el laboratorio de sus cursos; lo ven sus estudiantes', async () => {
    const res = await agendar('lxdIa', 'Jornada del lab IA', { type: 'laboratorio', laboratoryId: LAB_IA });
    expect(res.status, await res.clone().text()).toBe(201);
    expect(await titulosDe('est1')).toContain('Jornada del lab IA');
    expect(await titulosDe('est2')).not.toContain('Jornada del lab IA');
    expect(await titulosDe('mentor')).toContain('Jornada del lab IA');
  });

  it('pero no en un laboratorio donde no tiene cursos', async () => {
    const res = await agendar('lxdIa', 'Ajeno', { type: 'laboratorio', laboratoryId: LAB_AGUA });
    expect(res.status).toBe(403);
    expect(await res.text()).toContain('laboratorios de sus cursos');
  });

  it('el admin, en cualquiera', async () => {
    const res = await agendar('admin', 'Feria del agua', { type: 'laboratorio', laboratoryId: LAB_AGUA });
    expect(res.status).toBe(201);
    expect(await titulosDe('est3')).toContain('Feria del agua');
  });
});

describe('un evento de toda la organización', () => {
  it('el LXD de una empresa lo agenda para su empresa: lo ve toda su gente', async () => {
    const res = await agendar('lxdAndino', 'Asamblea Andino', { type: 'organizacion', clientId: andino });
    expect(res.status, await res.clone().text()).toBe(201);
    expect(await titulosDe('ana')).toContain('Asamblea Andino');
    expect(await titulosDe('jefa')).toContain('Asamblea Andino');
    expect(await titulosDe('luis')).not.toContain('Asamblea Andino');
    expect(await titulosDe('est1')).not.toContain('Asamblea Andino');
  });

  it('pero no para otra empresa', async () => {
    const res = await agendar('lxdAndino', 'Para Norte', { type: 'organizacion', clientId: norte });
    expect(res.status).toBe(403);
    expect(await res.text()).toContain('su propia organización');
  });

  it('el LXD del equipo de eduXaction (sin cliente), para toda Enactus', async () => {
    const res = await agendar('lxdIa', 'Día Enactus', { type: 'organizacion', clientId: enactus });
    expect(res.status, await res.clone().text()).toBe(201);
    expect(await titulosDe('est1')).toContain('Día Enactus');
    expect(await titulosDe('ana')).not.toContain('Día Enactus');
  });

  it('el admin, para la organización que elija', async () => {
    const res = await agendar('admin', 'Inducción Norte', { type: 'organizacion', clientId: norte });
    expect(res.status).toBe(201);
    expect(await titulosDe('luis')).toContain('Inducción Norte');
    expect(await titulosDe('ana')).not.toContain('Inducción Norte');
  });

  it('sin organización: 400; una que no existe: 404', async () => {
    expect((await agendar('admin', 'X', { type: 'organizacion' })).status).toBe(400);
    expect((await agendar('admin', 'X', {
      type: 'organizacion', clientId: '00000000-0000-4000-8000-000000000000',
    })).status).toBe(404);
  });
});

describe('a qué organizaciones puede agendar', () => {
  const nombres = async (quien: string) => {
    const res = await pedir('/calendar-events/organizaciones', 'GET', tok[quien]!);
    expect(res.status).toBe(200);
    return ((await res.json()) as { data: { name: string }[] }).data.map((o) => o.name);
  };

  it('el de una empresa, solo la suya; el admin y el equipo de eduXaction, todas', async () => {
    expect(await nombres('lxdAndino')).toEqual(['Banco Andino']);
    expect(await nombres('admin')).toEqual(expect.arrayContaining(['Banco Andino', 'Banco Norte', 'Enactus']));
    expect(await nombres('lxdIa')).toEqual(expect.arrayContaining(['Banco Norte', 'Enactus']));
  });

  it('un estudiante no pregunta', async () => {
    expect((await pedir('/calendar-events/organizaciones', 'GET', tok.est1!)).status).toBe(403);
  });
});

describe('editar', () => {
  it('pasarlo a un curso ajeno se revisa igual que crearlo', async () => {
    const res = await agendar('lxdIa', 'Para mover', { type: 'open_learning_sync', courseId: CURSO_IA });
    const { id } = (await res.json()) as { id: string };
    const mover = await pedir(`/calendar-events/${id}`, 'PATCH', tok.lxdIa!, { courseId: CURSO_AGUA });
    expect(mover.status).toBe(403);
  });

  it('cambiar de tipo deja solo el destino que el tipo lleva', async () => {
    const res = await agendar('lxdIa', 'Cambia', { type: 'open_learning_sync', courseId: CURSO_IA });
    const { id } = (await res.json()) as { id: string };
    const cambio = await pedir(`/calendar-events/${id}`, 'PATCH', tok.lxdIa!, {
      type: 'laboratorio', laboratoryId: LAB_IA,
    });
    expect(cambio.status, await cambio.clone().text()).toBe(200);
    const fila = (await cambio.json()) as { courseId: string | null; laboratoryId: string };
    expect(fila.courseId).toBeNull();
    expect(fila.laboratoryId).toBe(LAB_IA);
  });
});

describe('lo de antes sigue igual', () => {
  it('el mentor agenda la Ruta; un LXD no', async () => {
    expect((await agendar('mentor', 'Ruta', { type: 'ruta_impacto' })).status).toBe(201);
    expect((await agendar('lxdIa', 'Ruta', { type: 'ruta_impacto' })).status).toBe(403);
  });

  it('un estudiante no agenda nada', async () => {
    expect((await agendar('est1', 'Mío', { type: 'organizacion', clientId: enactus })).status)
      .toBe(403);
  });
});
