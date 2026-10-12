import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, login, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';

/**
 * El Manager / Supervisor de una empresa, y los cursos exclusivos (etapa 4).
 *
 * El supervisor ve a la gente de SU empresa —sus entregas, su avance, quién
 * se certificó— y puede calificarla. A la de otra empresa, o a la de Enactus,
 * no la ve por ninguna puerta: listado, detalle, entregas, archivos,
 * certificados, seguimiento de cursos.
 */

let t: ReturnType<typeof makeTestApp>;
let sql: Sql;
let admin = '';
let andino = '';
let norte = '';
let supAndino = '';
let anaAndino = '';
let luisNorte = '';
let cursoAndino = '';
let cursoGeneral = '';

const pedir = (ruta: string, metodo: string, token: string, cuerpo?: unknown) =>
  t.app.request(ruta, {
    method: metodo,
    headers: { 'content-type': 'application/json', ...auth(token) },
    body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
  });

async function crear<T = { id: string }>(ruta: string, cuerpo: unknown): Promise<T> {
  const res = await pedir(ruta, 'POST', admin, cuerpo);
  expect(res.status, `${ruta}: ${await res.clone().text()}`).toBe(201);
  return (await res.json()) as T;
}

beforeAll(async () => {
  await seedTestDatabase();
  t = makeTestApp();
  sql = t.sql;
  admin = (await login(t.app, 'admin@enactus.co', 'Admin123')).accessToken;

  andino = (await crear('/clients', { name: 'Banco Andino', primaryColor: '#1A73E8' })).id;
  norte = (await crear('/clients', { name: 'Banco Norte' })).id;

  const cuenta = (email: string, campos: Record<string, unknown>) =>
    crear('/users', { name: email.split('@')[0], email, password: 'Clave123', ...campos });
  anaAndino = (await cuenta('ana@andino.co', {
    role: 'student', studentType: 'open_learning', clientId: andino,
  })).id;
  luisNorte = (await cuenta('luis@norte.co', {
    role: 'student', studentType: 'open_learning', clientId: norte,
  })).id;
  await cuenta('jefa@andino.co', { role: 'supervisor', clientId: andino });
  supAndino = (await login(t.app, 'jefa@andino.co', 'Clave123')).accessToken;

  cursoAndino = (await crear('/courses', {
    name: 'Riesgo bancario', isOpenLearning: true, clientId: andino,
  })).id;
  cursoGeneral = (await crear('/courses', { name: 'Liderazgo', isOpenLearning: true })).id;
  await sql`update courses set status = 'published' where id in (${cursoAndino}, ${cursoGeneral})`;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('quién puede ser supervisor', () => {
  it('solo de una empresa cliente: ni sin cliente, ni de Enactus', async () => {
    const [enactus] = await sql<{ id: string }[]>`select id from clients where has_laboratories`;
    for (const [caso, campos] of [
      ['sin cliente', { role: 'supervisor' }],
      ['de Enactus', { role: 'supervisor', clientId: enactus!.id }],
    ] as const) {
      const res = await pedir('/users', 'POST', admin, {
        name: 'X', email: `sup-${caso.replace(' ', '')}@x.co`, password: 'Clave123', ...campos,
      });
      expect(res.status, caso).toBe(409);
    }
    await expect(
      sql`update users set client_id = null where email = 'jefa@andino.co'`,
    ).rejects.toThrow(/users_supervisor_con_cliente/);
  });
});

describe('los cursos exclusivos', () => {
  it('un curso de una empresa no se asigna a gente de otra', async () => {
    const ajeno = await pedir(`/users/${luisNorte}/courses`, 'PUT', admin, {
      ids: [cursoAndino],
    });
    expect(ajeno.status).toBe(409);
    expect(await ajeno.text()).toMatch(/Riesgo bancario/);

    const propio = await pedir(`/users/${anaAndino}/courses`, 'PUT', admin, {
      ids: [cursoAndino, cursoGeneral],
    });
    expect(propio.status, await propio.clone().text()).toBe(200);
    // Uno general sí va a cualquiera.
    expect(
      (await pedir(`/users/${luisNorte}/courses`, 'PUT', admin, { ids: [cursoGeneral] })).status,
    ).toBe(200);
  });

  it('un LXD de una empresa crea cursos para su empresa', async () => {
    await crear('/users', {
      name: 'Formador', email: 'formador@andino.co', password: 'Clave123',
      role: 'lxd', clientId: andino,
    });
    const lxd = (await login(t.app, 'formador@andino.co', 'Clave123')).accessToken;
    const res = await pedir('/courses', 'POST', lxd, {
      name: 'Crédito', isOpenLearning: true, clientId: norte,
    });
    expect(res.status).toBe(201);
    expect(((await res.json()) as { clientId: string }).clientId).toBe(andino);
  });

  it('un LXD de Enactus sigue creando cursos, sin marca de exclusivo', async () => {
    // Los de Enactus le llegan a su gente por laboratorio: marcarlos como
    // exclusivos de Enactus haría que la regla de exclusivos los rechazara.
    await crear('/users', {
      name: 'Diseñadora', email: 'lxd@enactus-red.co', password: 'Clave123', role: 'lxd',
    });
    await sql`update users set client_id = (select id from clients where has_laboratories)
               where email = 'lxd@enactus-red.co'`;
    const lxd = (await login(t.app, 'lxd@enactus-red.co', 'Clave123')).accessToken;
    const res = await pedir('/courses', 'POST', lxd, { name: 'Ruta de agua' });
    expect(res.status, await res.clone().text()).toBe(201);
    expect(((await res.json()) as { clientId: string | null }).clientId).toBeNull();
  });

  it('exclusivo es de Open Learning y fuera de los laboratorios', async () => {
    const res = await pedir('/courses', 'POST', admin, {
      name: 'Mal', isOpenLearning: false, clientId: andino,
    });
    expect(res.status).toBe(409);
  });
});

describe('lo que ve el supervisor', () => {
  it('a su gente, y solo a ella', async () => {
    const res = await pedir('/users?pageSize=100', 'GET', supAndino);
    const { data } = (await res.json()) as { data: { id: string; email?: string }[] };
    expect(data.map((u) => u.id)).toEqual([anaAndino]);
    // Sin datos de contacto: para acompañar el avance no hacen falta.
    expect(data[0]!.email).toBeUndefined();
  });

  it('el avance de su gente sí; el de otra empresa no', async () => {
    expect((await pedir(`/students/${anaAndino}/course-progress/${cursoAndino}`, 'GET', supAndino)).status)
      .not.toBe(403);
    expect((await pedir(`/students/${luisNorte}/course-progress/${cursoGeneral}`, 'GET', supAndino)).status)
      .toBe(403);
  });

  it('las entregas de su gente, y puede calificarlas; las de otros no', async () => {
    const ana = (await login(t.app, 'ana@andino.co', 'Clave123')).accessToken;
    const luis = (await login(t.app, 'luis@norte.co', 'Clave123')).accessToken;
    const deAna = (await (await pedir('/submissions', 'POST', ana, {
      courseId: cursoAndino, taskName: 'Ensayo',
    })).json()) as { id: string };
    const deLuis = (await (await pedir('/submissions', 'POST', luis, {
      courseId: cursoGeneral, taskName: 'Ensayo',
    })).json()) as { id: string };

    const lista = (await (await pedir('/submissions?pageSize=100', 'GET', supAndino)).json()) as {
      data: { id: string }[];
    };
    expect(lista.data.map((s) => s.id)).toEqual([deAna.id]);

    const nota = { gradingMode: 'points100', grade: 90, feedback: 'Muy bien' };
    expect((await pedir(`/submissions/${deAna.id}/grade`, 'POST', supAndino, nota)).status).toBe(200);
    expect((await pedir(`/submissions/${deLuis.id}/grade`, 'POST', supAndino, nota)).status).toBe(403);
  });

  it('sin permiso de calificar, no califica', async () => {
    await sql`update users set can_grade_open_learning = false where email = 'jefa@andino.co'`;
    const [entrega] = await sql<{ id: string }[]>`
      select id from submissions where student_id = ${anaAndino} limit 1`;
    const res = await pedir(`/submissions/${entrega!.id}/grade`, 'POST', supAndino, {
      gradingMode: 'points100', grade: 80, feedback: '',
    });
    expect(res.status).toBe(403);
    await sql`update users set can_grade_open_learning = true where email = 'jefa@andino.co'`;
  });

  it('quién se certificó: los certificados de su gente, y de nadie más', async () => {
    // Hoy los certificados guardados son los de la Ruta (por laboratorio); los
    // de curso llegan con la etapa 6. Lo que se fija acá es el ALCANCE: el
    // supervisor ve los de su gente y ningún otro, sean del tipo que sean.
    const [lab] = await sql<{ id: string }[]>`select id from laboratories limit 1`;
    const certificado = (studentId: string, codigo: string) => sql<{ id: string }[]>`
      insert into certificates (student_id, laboratory_id, code, student_name_snapshot,
                                laboratory_name_snapshot, issuer_name_snapshot,
                                requirements_snapshot)
      values (${studentId}, ${lab!.id}, ${codigo}, 'Nombre', 'Laboratorio', 'Emisor',
              '{}'::jsonb)
      returning id`;
    // La base exige la Ruta completa para emitir: se apaga esa regla solo
    // mientras se insertan, porque acá se prueba quién VE, no quién emite.
    await sql`alter table certificates disable trigger user`;
    const [filaAna] = await certificado(anaAndino, 'CERT-ANA');
    const certAna = filaAna!.id;
    await certificado(luisNorte, 'CERT-LUIS');
    await sql`alter table certificates enable trigger user`;
    const lista = (await (await pedir('/certificates', 'GET', supAndino)).json()) as {
      data: { id: string }[];
    };
    expect(lista.data.map((c) => c.id)).toEqual([certAna]);
    expect((await pedir(`/certificates?studentId=${luisNorte}`, 'GET', supAndino)).status).toBe(403);
  });

  it('en el seguimiento de un curso compartido, solo ve a su gente', async () => {
    await pedir(`/users/${anaAndino}/courses`, 'PUT', admin, { ids: [cursoAndino, cursoGeneral] });
    const res = await pedir(`/courses/${cursoGeneral}/students`, 'GET', supAndino);
    expect(res.status, await res.clone().text()).toBe(200);
    const { students } = (await res.json()) as { students: { id: string }[] };
    expect(students.map((s) => s.id)).toEqual([anaAndino]);
  });

  it('no escribe en el cuaderno del curso: eso es del equipo docente', async () => {
    const res = await pedir(`/courses/${cursoAndino}/students/${anaAndino}/note`, 'PUT', supAndino, {
      note: 'Hola',
    });
    expect(res.status).toBe(403);
  });
});
