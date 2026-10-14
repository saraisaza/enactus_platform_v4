import { readFileSync } from 'node:fs';

import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, login, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';

/**
 * Certificados de curso (etapa 6, parte 1).
 *
 * Al completar todas las lecciones de un curso que entrega certificado, la
 * persona lo recibe sola —sea porque completó la última lección o porque le
 * calificaron aprobada la última actividad—, una sola vez. Y cualquiera puede verificar
 * un certificado con el enlace de su QR, sin iniciar sesión.
 */

let t: ReturnType<typeof makeTestApp>;
let sql: Sql;
let admin = '';

const pedir = (ruta: string, metodo: string, token?: string, cuerpo?: unknown) =>
  t.app.request(ruta, {
    method: metodo,
    headers: { 'content-type': 'application/json', ...(token ? auth(token) : {}) },
    body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
  });

async function crear<T = { id: string }>(ruta: string, cuerpo: unknown, token = admin): Promise<T> {
  const res = await pedir(ruta, 'POST', token, cuerpo);
  expect(res.status, `${ruta}: ${await res.clone().text()}`).toBe(201);
  return (await res.json()) as T;
}

/** Un curso publicado con sus lecciones, asignado a una persona nueva. */
async function cursoConLecciones(
  nombre: string,
  tipos: string[],
  cuerpo: Record<string, unknown> = {},
) {
  const curso = await crear<{ id: string; generatesCertificate: boolean }>('/courses', {
    name: nombre, isOpenLearning: true, ...cuerpo,
  });
  const modulo = await crear(`/courses/${curso.id}/modules`, { title: 'Módulo 1' });
  const lecciones: string[] = [];
  for (const [i, type] of tipos.entries()) {
    lecciones.push((await crear(`/modules/${modulo.id}/lessons`, { title: `Lección ${i + 1}`, type })).id);
  }
  await sql`update courses set status = 'published' where id = ${curso.id}`;
  const correo = `${nombre.toLowerCase().replace(/\W+/g, '')}@prueba.co`;
  const persona = await crear('/users', {
    name: `Persona de ${nombre}`, email: correo, password: 'Clave123',
    role: 'student', studentType: 'open_learning',
  });
  expect((await pedir(`/users/${persona.id}/courses`, 'PUT', admin, { ids: [curso.id] })).status)
    .toBe(200);
  const token = (await login(t.app, correo, 'Clave123')).accessToken;
  return { curso, lecciones, persona, token };
}

const certificadosDe = (personaId: string, cursoId: string) => sql<{ id: string; code: string }[]>`
  select id, code from certificates where student_id = ${personaId} and course_id = ${cursoId}`;

beforeAll(async () => {
  await seedTestDatabase();
  t = makeTestApp();
  sql = t.sql;
  admin = (await login(t.app, 'admin@enactus.co', 'Admin123')).accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('al terminar el curso', () => {
  it('un curso de Open Learning entrega certificado sin que nadie lo pida', async () => {
    const { curso } = await cursoConLecciones('Seguridad eléctrica', ['resource']);
    expect(curso.generatesCertificate).toBe(true);
  });

  it('la última lección marcada emite el certificado, una sola vez', async () => {
    const { curso, lecciones, persona, token } = await cursoConLecciones(
      'Tableros', ['resource', 'resource'], { certifiedHours: 12 },
    );
    await pedir(`/progress/lessons/${lecciones[0]}/complete`, 'POST', token);
    expect(await certificadosDe(persona.id, curso.id)).toHaveLength(0);

    await pedir(`/progress/lessons/${lecciones[1]}/complete`, 'POST', token);
    const [cert] = await certificadosDe(persona.id, curso.id);
    expect(cert, 'tiene que haberse emitido').toBeDefined();
    expect(cert!.code).toMatch(/^CUR-\d{4}-[0-9A-F]{8}$/);

    // Lo ve en su lista, con el nombre del curso y las horas certificadas.
    const lista = (await (await pedir('/certificates', 'GET', token)).json()) as {
      data: { courseId: string; courseNameSnapshot: string; hours: number; issuerNameSnapshot: string }[];
    };
    expect(lista.data).toEqual([
      expect.objectContaining({
        courseId: curso.id, courseNameSnapshot: 'Tableros', hours: 12,
        issuerNameSnapshot: 'eduXaction',
      }),
    ]);
    // Y un aviso que la app muestra en su idioma.
    const [aviso] = await sql<{ kind: string; params: { curso: string } }[]>`
      select kind, params from notifications where user_id = ${persona.id}
       order by created_at desc limit 1`;
    expect(aviso).toEqual({ kind: 'certificado_curso', params: { curso: 'Tableros' } });

    // Volver a completarla (repasar la lectura) no emite otro.
    await pedir(`/progress/lessons/${lecciones[1]}/complete`, 'POST', token);
    await pedir(`/progress/lessons/${lecciones[1]}/complete`, 'POST', token);
    expect(await certificadosDe(persona.id, curso.id)).toHaveLength(1);
  });

  it('calificar la última actividad también lo emite', async () => {
    const { curso, lecciones, persona, token } = await cursoConLecciones(
      'Normas RETIE', ['activity'],
    );
    const entrega = await crear('/submissions', {
      courseId: curso.id, lessonId: lecciones[0], taskName: 'Informe',
      comment: 'Adjunto el informe.',
    }, token);
    expect(await certificadosDe(persona.id, curso.id)).toHaveLength(0);

    const res = await pedir(`/submissions/${entrega.id}/grade`, 'POST', admin, {
      gradingMode: 'points100', grade: 90, feedback: 'Bien',
    });
    expect(res.status, await res.clone().text()).toBe(200);
    expect(await certificadosDe(persona.id, curso.id)).toHaveLength(1);
  });

  it('un curso que no entrega certificado no lo emite', async () => {
    const { curso, lecciones, persona, token } = await cursoConLecciones(
      'Inducción', ['resource'], { generatesCertificate: false },
    );
    await pedir(`/progress/lessons/${lecciones[0]}/complete`, 'POST', token);
    expect(await certificadosDe(persona.id, curso.id)).toHaveLength(0);
  });

  it('un curso de laboratorio no emite el suyo: sus horas van a la Ruta', async () => {
    // El sembrado: est1 tiene completo «Introducción a la IA», de laboratorio,
    // que «cuenta para certificado».
    const [curso] = await sql<{ id: string; cuenta: boolean }[]>`
      select id, generates_certificate as cuenta from courses
       where name = 'Introducción a la Inteligencia Artificial'`;
    expect(curso!.cuenta).toBe(true);
    const [est] = await sql<{ id: string }[]>`
      select id from users where email = 'estudiante1@uniandes.edu.co'`;
    const est1 = (await login(t.app, 'estudiante1@uniandes.edu.co', 'Est123')).accessToken;
    const [leccion] = await sql<{ id: string }[]>`
      select l.id from lessons l join course_modules m on m.id = l.course_module_id
       where m.course_id = ${curso!.id} limit 1`;
    // Volver a completar una lección del curso, ya completo, no lo emite.
    await pedir(`/progress/lessons/${leccion!.id}/complete`, 'POST', est1);
    expect(await certificadosDe(est!.id, curso!.id)).toHaveLength(0);
  });

  it('la base no deja emitir el de un curso sin terminar', async () => {
    const { curso, persona } = await cursoConLecciones('Pendiente', ['resource']);
    await expect(sql`
      insert into certificates (code, student_id, course_id, student_name_snapshot,
                                course_name_snapshot, issuer_name_snapshot,
                                requirements_snapshot)
      values ('CUR-X', ${persona.id}, ${curso.id}, 'N', 'C', 'E', '{}'::jsonb)`)
      .rejects.toThrow(/no está completo/);
  });

  it('quien ya lo había terminado lo recibe al migrar', async () => {
    // Lo que hace la migración 0016 con quien terminó antes de que existiera:
    // se borra el emitido y se corre el mismo INSERT de la migración.
    const { curso, lecciones, persona, token } = await cursoConLecciones('Antes', ['resource']);
    await pedir(`/progress/lessons/${lecciones[0]}/complete`, 'POST', token);
    await sql`delete from certificates where course_id = ${curso.id}`;

    const migracion = readFileSync('drizzle/0016_certificados_de_curso.sql', 'utf8');
    const relleno = migracion.slice(migracion.indexOf('INSERT INTO "certificates"'));
    await sql.unsafe(relleno);
    expect(await certificadosDe(persona.id, curso.id)).toHaveLength(1);
    // Y correrla otra vez no duplica.
    await sql.unsafe(relleno);
    expect(await certificadosDe(persona.id, curso.id)).toHaveLength(1);
  });
});

describe('verificar un certificado', () => {
  it('sin sesión, con el enlace del QR, dice lo que el certificado dice', async () => {
    const { curso, lecciones, persona, token } = await cursoConLecciones(
      'Puesta a tierra', ['resource'], { certifiedHours: 8 },
    );
    await pedir(`/progress/lessons/${lecciones[0]}/complete`, 'POST', token);
    const [cert] = await certificadosDe(persona.id, curso.id);

    const res = await pedir(`/certificate-verification/${cert!.id}`, 'GET');
    expect(res.status).toBe(200);
    const cuerpo = (await res.json()) as Record<string, unknown>;
    // Solo lo que el certificado dice impreso: ni ids, ni correo.
    expect(Object.keys(cuerpo).sort()).toEqual(
      ['code', 'hours', 'issuedAt', 'issuer', 'kind', 'studentName', 'title'],
    );
    expect(cuerpo).toMatchObject({
      code: cert!.code,
      studentName: 'Persona de Puesta a tierra',
      kind: 'course',
      title: 'Puesta a tierra',
      hours: 8,
      issuer: 'eduXaction',
    });
  });

  it('uno que no existe: 404', async () => {
    const res = await pedir('/certificate-verification/00000000-0000-4000-8000-000000000000', 'GET');
    expect(res.status).toBe(404);
  });
});
