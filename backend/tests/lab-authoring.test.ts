import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Autoría de laboratorios y de su Ruta de Impacto.
 *
 * Es la parte de la API donde una escritura mal hecha no da error: deja la
 * Ruta trabada. Un objetivo sin cursos no se completa nunca; un curso contado
 * en dos módulos infla el avance; un módulo de mentoría que dejó de ser el
 * último desordena la fase. Por eso lo que más se prueba acá es que esas
 * invariantes sobrevivan a cada cambio, no el camino feliz.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

let adminToken = '';
let lxdToken = '';
let mentorToken = '';
let est1Token = '';

/** El laboratorio que crea esta suite; se borra al final. */
let labId = '';
let faseIds: string[] = [];

const req = (path: string, token: string, init: RequestInit = {}) =>
  app.request(path, {
    ...init,
    headers: { ...(init.headers ?? {}), ...auth(token) },
  });

const put = (path: string, token: string, payload: unknown) =>
  req(path, token, { ...json(payload), method: 'PUT' });

const patch = (path: string, token: string, payload: unknown) =>
  req(path, token, { ...json(payload), method: 'PATCH' });

const del = (path: string, token: string) =>
  req(path, token, { method: 'DELETE' });

const body = async <T>(res: Response): Promise<T> => (await res.json()) as T;

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;

  adminToken = (await login(app, 'admin@enactus.co', 'Admin123')).accessToken;
  lxdToken = (await login(app, 'lxd.ia@enactus.co', 'Lxd123')).accessToken;
  mentorToken = (await login(app, 'mentor.ia@enactus.co', 'Mentor123')).accessToken;
  est1Token = (await login(app, 'estudiante1@uniandes.edu.co', 'Est123')).accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('POST /laboratories', () => {
  it('crea el laboratorio CON sus tres fases', async () => {
    // Un laboratorio sin fases no tiene Ruta, y `phase_unlocked` —la vista que
    // decide qué ve cada estudiante— no tendría de dónde partir.
    const res = await req(
      '/laboratories',
      adminToken,
      json({ name: 'Laboratorio de prueba', description: 'Para las pruebas' }),
    );
    expect(res.status).toBe(201);
    const lab = await body<{ id: string; contentVersion: number }>(res);
    labId = lab.id;
    expect(lab.contentVersion).toBe(1);

    const fases = await sql<{ id: string; order_index: number }[]>`
      select id, order_index from phases
       where laboratory_id = ${labId} order by order_index
    `;
    expect(fases).toHaveLength(3);
    expect(fases.map((f) => f.order_index)).toEqual([1, 2, 3]);
    faseIds = fases.map((f) => f.id);
  });

  it('un patrocinador que no es empresa se rechaza', async () => {
    const res = await req(
      '/laboratories',
      adminToken,
      json({ name: 'Otro', sponsorCompanyId: seedId('est1') }),
    );
    expect(res.status).toBe(409);
  });

  it('un LXD no crea laboratorios', async () => {
    const res = await req('/laboratories', lxdToken, json({ name: 'Suyo' }));
    expect(res.status).toBe(403);
  });

  it('un mentor tampoco', async () => {
    const res = await req('/laboratories', mentorToken, json({ name: 'Suyo' }));
    expect(res.status).toBe(403);
  });
});

describe('PATCH /laboratories/:id', () => {
  it('edita nombre y descripción', async () => {
    const res = await patch(`/laboratories/${labId}`, adminToken, {
      name: 'Laboratorio de prueba (editado)',
      description: 'Otra descripción',
    });
    expect(res.status).toBe(200);
    const lab = await body<{ name: string }>(res);
    expect(lab.name).toContain('editado');
  });

  it('acepta una empresa real como patrocinador', async () => {
    const [empresa] = await sql<{ id: string }[]>`
      select id from users where role = 'company' and deleted_at is null limit 1
    `;
    const res = await patch(`/laboratories/${labId}`, adminToken, {
      sponsorCompanyId: empresa!.id,
    });
    expect(res.status).toBe(200);
  });

  it('un laboratorio inexistente es 404', async () => {
    const res = await patch(
      '/laboratories/11111111-1111-4111-8111-111111111111',
      adminToken,
      { name: 'x' },
    );
    expect(res.status).toBe(404);
  });
});

describe('Personal y estudiantes del laboratorio', () => {
  it('reemplaza el conjunto de mentores', async () => {
    const mentores = await sql<{ id: string }[]>`
      select id from users where role = 'mentor' and deleted_at is null limit 2
    `;
    const ids = mentores.map((m) => m.id);

    const res = await put(`/laboratories/${labId}/mentors`, adminToken, { ids });
    expect(res.status).toBe(200);

    const guardados = await sql<{ user_id: string }[]>`
      select user_id from laboratory_mentors where laboratory_id = ${labId}
    `;
    expect(guardados.map((r) => r.user_id).sort()).toEqual([...ids].sort());
  });

  it('reemplaza, no agrega', async () => {
    await put(`/laboratories/${labId}/mentors`, adminToken, { ids: [] });
    const [row] = await sql<{ n: string }[]>`
      select count(*) as n from laboratory_mentors where laboratory_id = ${labId}
    `;
    expect(Number(row!.n)).toBe(0);
  });

  it('una cuenta que no es mentor se rechaza', async () => {
    const res = await put(`/laboratories/${labId}/mentors`, adminToken, {
      ids: [seedId('est1')],
    });
    expect(res.status).toBe(409);
  });

  it('asigna estudiantes Enactus', async () => {
    const res = await put(`/laboratories/${labId}/students`, adminToken, {
      ids: [seedId('est1')],
    });
    expect(res.status).toBe(200);
  });

  it('un Open Learning NO entra a un laboratorio', async () => {
    // Estaría recibiendo acceso a los cursos del laboratorio sin haber pasado
    // por Enactus, que es justo el aislamiento que sostiene el resto de la API.
    const [ol] = await sql<{ id: string }[]>`
      select id from users where student_type = 'open_learning' limit 1
    `;
    const res = await put(`/laboratories/${labId}/students`, adminToken, {
      ids: [ol!.id],
    });
    expect(res.status).toBe(409);
  });

  it('un LXD no toca el personal de un laboratorio', async () => {
    const res = await put(`/laboratories/${labId}/mentors`, lxdToken, { ids: [] });
    expect(res.status).toBe(403);
  });
});

describe('Fases y módulos de la Ruta', () => {
  let moduloIds: string[] = [];

  it('edita el contenido de una fase', async () => {
    const res = await patch(`/phases/${faseIds[0]}`, adminToken, {
      title: 'Fase 1 — Descubrimiento del problema',
      description: 'Entender a fondo la comunidad.',
      deadline: '2026-10-15',
    });
    expect(res.status).toBe(200);
    const fase = await body<{ title: string; deadline: string }>(res);
    expect(fase.title).toContain('problema');
    expect(fase.deadline).toBe('2026-10-15');
  });

  it('agrega módulos y el ÚLTIMO queda como el de mentoría', async () => {
    for (const title of ['Diagnóstico', 'Investigación', 'Mentoría']) {
      const res = await req(
        `/phases/${faseIds[0]}/modules`,
        adminToken,
        json({ title }),
      );
      expect(res.status).toBe(201);
    }

    type ModRow = { id: string; title: string; is_mentorship_module: boolean };
    const mods = await sql<ModRow[]>`
      select id, title, is_mentorship_module from ruta_modules
       where phase_id = ${faseIds[0]!} order by order_index
    `;
    expect(mods).toHaveLength(3);
    expect(mods.map((m) => m.is_mentorship_module)).toEqual([false, false, true]);
    moduloIds = mods.map((m) => m.id);
  });

  it('reordenar mueve también el flag de mentoría', async () => {
    // El flag se recalcula, no lo mueve nadie a mano: si dependiera de que
    // alguien se acuerde, una fase reordenada quedaría con dos módulos de
    // mentoría o con ninguno.
    const invertido = [...moduloIds].reverse();
    const res = await put(`/phases/${faseIds[0]}/modules/order`, adminToken, {
      orderedIds: invertido,
    });
    expect(res.status).toBe(200);

    const mods = await sql<{ id: string; is_mentorship_module: boolean }[]>`
      select id, is_mentorship_module from ruta_modules
       where phase_id = ${faseIds[0]!} order by order_index
    `;
    expect(mods.map((m) => m.id)).toEqual(invertido);
    expect(mods.map((m) => m.is_mentorship_module)).toEqual([false, false, true]);
  });

  it('la lista de reordenamiento tiene que ser exacta', async () => {
    const res = await put(`/phases/${faseIds[0]}/modules/order`, adminToken, {
      orderedIds: [moduloIds[0]!],
    });
    expect(res.status).toBe(409);
  });

  it('borrar un módulo renumera el resto y recalcula la mentoría', async () => {
    const antes = await sql<{ id: string }[]>`
      select id from ruta_modules where phase_id = ${faseIds[0]!} order by order_index
    `;
    const res = await del(`/ruta-modules/${antes[0]!.id}`, adminToken);
    expect(res.status).toBe(204);

    type OrdenRow = { order_index: number; is_mentorship_module: boolean };
    const despues = await sql<OrdenRow[]>`
      select order_index, is_mentorship_module from ruta_modules
       where phase_id = ${faseIds[0]!} order by order_index
    `;
    expect(despues.map((m) => m.order_index)).toEqual([1, 2]);
    expect(despues.map((m) => m.is_mentorship_module)).toEqual([false, true]);
  });

  it('cada cambio estructural sube content_version', async () => {
    // Los certificados quedan anclados a una versión: agregar contenido
    // después no invalida los ya emitidos.
    const [antes] = await sql<{ content_version: number }[]>`
      select content_version from laboratories where id = ${labId}
    `;
    await req(`/phases/${faseIds[0]}/modules`, adminToken, json({ title: 'Otro' }));
    const [despues] = await sql<{ content_version: number }[]>`
      select content_version from laboratories where id = ${labId}
    `;
    expect(despues!.content_version).toBeGreaterThan(antes!.content_version);
  });
});

describe('Cursos vinculados a un módulo', () => {
  let moduloA = '';
  let moduloB = '';

  it('vincula cursos al módulo', async () => {
    const mods = await sql<{ id: string }[]>`
      select id from ruta_modules where phase_id = ${faseIds[0]!} order by order_index
    `;
    moduloA = mods[0]!.id;
    moduloB = mods[1]!.id;

    const res = await put(`/ruta-modules/${moduloA}/courses`, adminToken, {
      ids: [seedId('crs_ia_1')],
    });
    expect(res.status).toBe(200);
  });

  it('el mismo curso en otro módulo de la MISMA Ruta se rechaza', async () => {
    // Si se dejara, su avance se contaría dos veces en la fase.
    const res = await put(`/ruta-modules/${moduloB}/courses`, adminToken, {
      ids: [seedId('crs_ia_1')],
    });
    expect(res.status).toBe(409);
    const b = await body<{ error: { details: { courses: unknown[] } } }>(res);
    expect(b.error.details.courses).toHaveLength(1);
  });

  it('volver a mandarlo al MISMO módulo no es conflicto', async () => {
    const res = await put(`/ruta-modules/${moduloA}/courses`, adminToken, {
      ids: [seedId('crs_ia_1')],
    });
    expect(res.status).toBe(200);
  });

  it('una lista vacía desvincula', async () => {
    const res = await put(`/ruta-modules/${moduloA}/courses`, adminToken, {
      ids: [],
    });
    expect(res.status).toBe(200);
    const [row] = await sql<{ n: string }[]>`
      select count(*) as n from ruta_module_courses where ruta_module_id = ${moduloA}
    `;
    expect(Number(row!.n)).toBe(0);
  });

  it('agrega una lección propia al módulo', async () => {
    const res = await req(
      `/ruta-modules/${moduloA}/lessons`,
      adminToken,
      json({ title: 'Lectura inicial', type: 'pdf' }),
    );
    expect(res.status).toBe(201);
    const leccion = await body<{ id: string; rutaModuleId: string }>(res);
    expect(leccion.rutaModuleId).toBe(moduloA);

    // Cuelga del módulo de Ruta, no de un módulo de curso: el CHECK
    // `lessons_exactly_one_parent` exige exactamente uno de los dos.
    const [row] = await sql<{ course_module_id: string | null }[]>`
      select course_module_id from lessons where id = ${leccion.id}
    `;
    expect(row!.course_module_id).toBeNull();
  });

  it('una lección de enlace sin URL se rechaza', async () => {
    const res = await req(
      `/ruta-modules/${moduloA}/lessons`,
      adminToken,
      json({ title: 'Enlace', type: 'link' }),
    );
    expect(res.status).toBe(409);
  });
});

describe('Objetivos de fase', () => {
  let objetivoId = '';

  it('agrega un objetivo', async () => {
    const res = await req(
      `/phases/${faseIds[0]}/objectives`,
      adminToken,
      json({ category: 'entrepreneurship', text: 'Identificar el problema' }),
    );
    expect(res.status).toBe(201);
    const objetivo = await body<{ id: string; category: string }>(res);
    objetivoId = objetivo.id;
    expect(objetivo.category).toBe('entrepreneurship');
  });

  it('lo edita', async () => {
    const res = await patch(`/objectives/${objetivoId}`, adminToken, {
      text: 'Identificar el problema con la comunidad',
    });
    expect(res.status).toBe(200);
  });

  it('un objetivo SIN cursos avisa que nunca se va a completar', async () => {
    // No se puede marcar a mano: sin cursos traba la fase entera para todo el
    // laboratorio, y en silencio.
    const res = await put(`/objectives/${objetivoId}/courses`, adminToken, {
      ids: [],
    });
    expect(res.status).toBe(200);
    const b = await body<{ neverCompletable: boolean }>(res);
    expect(b.neverCompletable).toBe(true);
  });

  it('con cursos, no', async () => {
    const res = await put(`/objectives/${objetivoId}/courses`, adminToken, {
      ids: [seedId('crs_ia_1')],
    });
    const b = await body<{ neverCompletable: boolean; courseIds: string[] }>(res);
    expect(b.neverCompletable).toBe(false);
    expect(b.courseIds).toHaveLength(1);
  });

  it('un curso borrado no se puede exigir', async () => {
    const res = await put(`/objectives/${objetivoId}/courses`, adminToken, {
      ids: ['11111111-1111-4111-8111-111111111111'],
    });
    expect(res.status).toBe(409);
  });

  it('lo borra', async () => {
    const res = await del(`/objectives/${objetivoId}`, adminToken);
    expect(res.status).toBe(204);
  });

  it('un LXD no toca los objetivos de una fase', async () => {
    const res = await req(
      `/phases/${faseIds[0]}/objectives`,
      lxdToken,
      json({ text: 'Suyo' }),
    );
    expect(res.status).toBe(403);
  });

  it('un estudiante tampoco', async () => {
    const res = await req(
      `/phases/${faseIds[0]}/objectives`,
      est1Token,
      json({ text: 'Suyo' }),
    );
    expect(res.status).toBe(403);
  });
});

describe('DELETE /laboratories/:id', () => {
  it('con estudiantes adentro se bloquea y dice cuántos', async () => {
    const res = await del(`/laboratories/${labId}`, adminToken);
    expect(res.status).toBe(409);
    const b = await body<{ error: { details: { students: number } } }>(res);
    expect(b.error.details.students).toBeGreaterThan(0);
  });

  it('vacío, se borra lógicamente', async () => {
    await put(`/laboratories/${labId}/students`, adminToken, { ids: [] });
    const res = await del(`/laboratories/${labId}`, adminToken);
    expect(res.status).toBe(204);

    const [row] = await sql<{ deleted_at: string | null }[]>`
      select deleted_at from laboratories where id = ${labId}
    `;
    // Lógico, no físico: el avance histórico sigue apuntando a algo.
    expect(row!.deleted_at).not.toBeNull();
  });

  it('y deja de aparecer en el listado', async () => {
    const res = await req('/laboratories?pageSize=100', adminToken);
    const page = await body<{ data: { id: string }[] }>(res);
    expect(page.data.map((l) => l.id)).not.toContain(labId);
  });

  it('un laboratorio ya borrado responde 404', async () => {
    const res = await patch(`/laboratories/${labId}`, adminToken, { name: 'x' });
    expect(res.status).toBe(404);
  });
});
