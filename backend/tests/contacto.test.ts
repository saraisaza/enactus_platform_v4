import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { json, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';

/**
 * El formulario «Hablemos» de la portada.
 *
 * Antes decía «¡Mensaje enviado!» y el mensaje no salía del navegador: nadie
 * se enteraba de quien escribía. Ahora le llega como aviso a cada
 * administrador.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

const escribir = (cuerpo: Record<string, unknown>) =>
  app.request('/contact', json(cuerpo));

const avisos = async () =>
  sql<{ user_id: string; body: string; params: Record<string, string> }[]>`
    select user_id, body, params from notifications where kind = 'contacto'`;

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;
}, 120_000);

beforeEach(async () => {
  resetRateLimits();
  await sql`delete from notifications where kind = 'contacto'`;
});

afterAll(async () => {
  await sql.end();
});

describe('POST /contact', () => {
  it('sin sesión, le llega a cada administrador con sus datos', async () => {
    const res = await escribir({
      name: 'Laura Gómez',
      email: 'laura@empresa.co',
      company: 'Empresa Andina',
      message: 'Queremos capacitar a 200 personas de ventas.',
    });
    expect(res.status).toBe(202);

    const lista = await avisos();
    const [admins] = await sql<{ n: number }[]>`
      select count(*)::int as n from users
       where role in ('admin', 'superadmin') and deleted_at is null`;
    expect(lista).toHaveLength(admins!.n);
    expect(lista[0]!.params).toEqual({
      nombre: 'Laura Gómez',
      correo: 'laura@empresa.co',
      empresa: 'Empresa Andina',
      mensaje: 'Queremos capacitar a 200 personas de ventas.',
    });
    expect(lista[0]!.body).toContain('laura@empresa.co');
  });

  it('la empresa es opcional', async () => {
    const res = await escribir({ name: 'Ana', email: 'ana@x.co', message: 'Hola' });
    expect(res.status).toBe(202);
    expect((await avisos())[0]!.params.empresa).toBe('');
  });

  it('sin nombre, correo válido o mensaje: 400, y no avisa', async () => {
    expect((await escribir({ email: 'a@b.co', message: 'Hola' })).status).toBe(400);
    expect((await escribir({ name: 'A', email: 'no-es-correo', message: 'Hola' })).status).toBe(400);
    expect((await escribir({ name: 'A', email: 'a@b.co', message: '  ' })).status).toBe(400);
    expect(await avisos()).toHaveLength(0);
  });

  it('un robot que llena el campo oculto no molesta a nadie', async () => {
    const res = await escribir({
      name: 'Bot', email: 'bot@spam.co', message: 'Compre ya', website: 'http://spam',
    });
    expect(res.status).toBe(202);
    expect(await avisos()).toHaveLength(0);
  });

  it('desde una misma IP, a lo sumo cinco mensajes cada diez minutos', async () => {
    const estados: number[] = [];
    for (let i = 0; i < 6; i++) {
      estados.push((await escribir({ name: 'A', email: 'a@b.co', message: `Hola ${i}` })).status);
    }
    expect(estados.slice(0, 5)).toEqual([202, 202, 202, 202, 202]);
    expect(estados[5]).toBe(429);
  });
});
