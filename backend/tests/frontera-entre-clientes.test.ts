import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, login, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';

/**
 * La frontera entre clientes (etapa 5).
 *
 * Una cuenta que pertenece a un cliente —Enactus o una empresa— solo alcanza a
 * personas de ESE cliente, por cualquier puerta: directorio, ficha, avance,
 * entregas (ver, comentar, calificar), archivos, certificados, seguimiento de
 * cursos y avisos. Y lo que es de Enactus —laboratorios, proyectos, equipos—
 * no lo ve una cuenta de empresa.
 *
 * Las cuentas sin cliente (administración y los LXD de eduXaction) no tienen
 * frontera: atienden a todos. Eso también se fija acá, para que cerrar la
 * frontera no deje a nadie sin lo suyo.
 *
 * El caso que motivó la prueba: el asesor de Enactus ve «a los de su
 * universidad», y una estudiante de una empresa puede estudiar en esa misma
 * universidad.
 */

let t: ReturnType<typeof makeTestApp>;
let sql: Sql;
const tok: Record<string, string> = {};
let ana = '';
let enactusEst = '';
let cursoAndino = '';
let entregaAna = '';
let entregaEnactus = '';

const pedir = (ruta: string, metodo: string, token: string, cuerpo?: unknown) =>
  t.app.request(ruta, {
    method: metodo,
    headers: { 'content-type': 'application/json', ...auth(token) },
    body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
  });

async function crear<T = { id: string }>(ruta: string, cuerpo: unknown, token = tok.admin!): Promise<T> {
  const res = await pedir(ruta, 'POST', token, cuerpo);
  expect(res.status, `${ruta}: ${await res.clone().text()}`).toBe(201);
  return (await res.json()) as T;
}

async function ids(ruta: string, token: string): Promise<string[]> {
  const res = await pedir(ruta, 'GET', token);
  expect(res.status, `${ruta}: ${await res.clone().text()}`).toBe(200);
  return ((await res.json()) as { data: { id: string }[] }).data.map((x) => x.id);
}

beforeAll(async () => {
  await seedTestDatabase();
  t = makeTestApp();
  sql = t.sql;
  const entrar = async (rol: string, correo: string, clave: string) => {
    tok[rol] = (await login(t.app, correo, clave)).accessToken;
  };
  await entrar('admin', 'admin@enactus.co', 'Admin123');
  await entrar('asesor', 'asesor@uniandes.edu.co', 'Asesor123');
  await entrar('mentor', 'mentor.ia@enactus.co', 'Mentor123');
  await entrar('aliada', 'empresa@bancolombia.com', 'Empresa123');
  await entrar('donante', 'donante@gmail.com', 'Donante123');
  await entrar('lxdEdu', 'lxd.ia@enactus.co', 'Lxd123');
  await entrar('enactus', 'estudiante1@uniandes.edu.co', 'Est123');

  // La universidad del asesor, del catálogo: el alta escribe además el
  // nombre, que es con lo que el asesor compara («los de mi universidad»).
  const [asesor] = await sql<{ universityId: string }[]>`
    select un.id as "universityId" from universities un
      join users u on u.university = un.name
     where u.email = 'asesor@uniandes.edu.co'`;
  const [est] = await sql<{ id: string }[]>`
    select id from users where email = 'estudiante1@uniandes.edu.co'`;
  enactusEst = est!.id;

  const andino = (await crear('/clients', { name: 'Banco Andino' })).id;

  // Ana estudia en la MISMA universidad que el asesor de Enactus.
  ana = (await crear('/users', {
    name: 'Ana', email: 'ana@andino.co', password: 'Clave123', role: 'student',
    studentType: 'open_learning', clientId: andino, universityId: asesor!.universityId,
  })).id;
  await crear('/users', {
    name: 'Formador', email: 'formador@andino.co', password: 'Clave123', role: 'lxd',
    clientId: andino,
  });
  await crear('/users', {
    name: 'Jefa', email: 'jefa@andino.co', password: 'Clave123', role: 'supervisor',
    clientId: andino,
  });
  await entrar('lxdAndino', 'formador@andino.co', 'Clave123');
  await entrar('supAndino', 'jefa@andino.co', 'Clave123');
  await entrar('ana', 'ana@andino.co', 'Clave123');

  cursoAndino = (await crear('/courses', { name: 'Riesgo', isOpenLearning: true }, tok.lxdAndino)).id;
  await sql`update courses set status = 'published' where id = ${cursoAndino}`;
  expect((await pedir(`/users/${ana}/courses`, 'PUT', tok.admin!, { ids: [cursoAndino] })).status)
    .toBe(200);
  entregaAna = (await crear('/submissions', { courseId: cursoAndino, taskName: 'Ensayo' }, tok.ana)).id;

  // Una entrega de Enactus, del sembrado.
  const [deEnactus] = await sql<{ id: string }[]>`
    select id from submissions where student_id = ${enactusEst} and deleted_at is null limit 1`;
  entregaEnactus = deEnactus!.id;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('Enactus no alcanza a la gente de una empresa', () => {
  it('el asesor no la ve, aunque sea de su universidad', async () => {
    expect(await ids('/users?pageSize=100', tok.asesor!)).not.toContain(ana);
    expect((await pedir(`/users/${ana}`, 'GET', tok.asesor!)).status).toBe(404);
    expect(await ids('/submissions?pageSize=100', tok.asesor!)).not.toContain(entregaAna);
    expect((await pedir(`/students/${ana}/course-progress/${cursoAndino}`, 'GET', tok.asesor!))
      .status).toBe(404);
    expect((await pedir(`/certificates?studentId=${ana}`, 'GET', tok.asesor!)).status).toBe(404);
    // Ni el seguimiento del curso que ella cursa.
    expect((await pedir(`/courses/${cursoAndino}/students`, 'GET', tok.asesor!)).status).toBe(404);
    expect((await pedir('/notifications', 'POST', tok.asesor!, {
      userIds: [ana], title: 'Hola', body: 'Hola',
    })).status).toBe(403);
  });

  it('el mentor no comenta entregas fuera de sus cursos', async () => {
    const res = await pedir(`/submissions/${entregaAna}/review`, 'POST', tok.mentor!, {
      feedback: 'Comentario ajeno',
    });
    expect(res.status).toBe(404);
    const [fila] = await sql<{ feedback: string | null }[]>`
      select feedback from submissions where id = ${entregaAna}`;
    expect(fila!.feedback ?? '').not.toContain('Comentario ajeno');
  });

  it('el mentor, el asesor y el LXD de laboratorio no abren su avance por id', async () => {
    for (const rol of ['mentor', 'asesor']) {
      expect((await pedir(`/students/${ana}/course-progress/${cursoAndino}`, 'GET', tok[rol]!))
        .status, rol).toBe(404);
    }
  });
});

describe('una empresa no alcanza a Enactus', () => {
  it('el LXD de la empresa no ve a la gente de Enactus', async () => {
    const vistos = await ids('/users?pageSize=100', tok.lxdAndino!);
    expect(vistos).toContain(ana);
    expect(vistos).not.toContain(enactusEst);
    // Tampoco a las empresas aliadas de Enactus: son de otro cliente.
    const [aliada] = await sql<{ id: string }[]>`
      select id from users where email = 'empresa@bancolombia.com'`;
    expect(vistos).not.toContain(aliada!.id);
    expect((await pedir(`/users/${enactusEst}`, 'GET', tok.lxdAndino!)).status).toBe(404);
    expect((await pedir(`/certificates?studentId=${enactusEst}`, 'GET', tok.lxdAndino!)).status)
      .toBe(404);
  });

  it('ni sus entregas', async () => {
    expect(await ids('/submissions?pageSize=100', tok.lxdAndino!)).not.toContain(entregaEnactus);
    expect((await pedir(`/submissions/${entregaEnactus}/grade`, 'POST', tok.lxdAndino!, {
      gradingMode: 'points100', grade: 10, feedback: '',
    })).status).toBe(403);
  });

  it('laboratorios, proyectos y equipos son de Enactus', async () => {
    for (const rol of ['lxdAndino', 'supAndino']) {
      for (const ruta of ['/laboratories', '/projects', '/groups']) {
        expect((await pedir(ruta, 'GET', tok[rol]!)).status, `${rol} ${ruta}`).toBe(403);
      }
    }
  });
});

describe('cada uno conserva lo suyo', () => {
  it('el asesor sigue viendo a los de Enactus de su universidad', async () => {
    expect(await ids('/users?pageSize=100', tok.asesor!)).toContain(enactusEst);
    expect((await pedir(`/students/${enactusEst}/ruta-progress`, 'GET', tok.asesor!)).status)
      .toBe(200);
  });

  it('el LXD de la empresa califica a su gente', async () => {
    expect(await ids('/submissions?pageSize=100', tok.lxdAndino!)).toContain(entregaAna);
    expect((await pedir(`/submissions/${entregaAna}/grade`, 'POST', tok.lxdAndino!, {
      gradingMode: 'points100', grade: 95, feedback: 'Bien',
    })).status).toBe(200);
  });

  it('un LXD de eduXaction, sin cliente, sigue alcanzando a sus estudiantes', async () => {
    expect(await ids('/users?pageSize=100', tok.lxdEdu!)).toContain(enactusEst);
    expect((await pedir('/laboratories', 'GET', tok.lxdEdu!)).status).toBe(200);
  });

  it('la administración ve a todos', async () => {
    const vistos = await ids('/users?pageSize=100', tok.admin!);
    expect(vistos).toEqual(expect.arrayContaining([ana, enactusEst]));
  });

  it('la empresa aliada y el donante de Enactus siguen con su portal', async () => {
    expect((await pedir('/talent?pageSize=100', 'GET', tok.aliada!)).status).toBe(200);
    expect((await pedir('/talent?pageSize=100', 'GET', tok.donante!)).status).toBe(200);
  });
});
