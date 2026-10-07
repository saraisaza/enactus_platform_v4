import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';

/**
 * Las cuentas y su cliente (etapa 3).
 *
 * Lo que se fija acá:
 * - La migración 0014 deja en Enactus exactamente a sus cuentas, y a nadie más.
 * - Cada cuenta recibe al entrar la marca de SU cliente, leída de su fila.
 * - Las reglas de quién puede pertenecer a qué cliente.
 * - Un cliente desactivado deja afuera a sus cuentas por las TRES puertas:
 *   entrar, renovar la sesión y cualquier pedido con la sesión ya abierta.
 */

let t: ReturnType<typeof makeTestApp>;
let sql: Sql;
let admin = '';
let enactusId = '';
let empresaId = '';

const RELLENO = resolve(__dirname, '../drizzle/0014_cuentas_de_clientes.sql');

const pedir = (ruta: string, metodo: string, token: string, cuerpo?: unknown) =>
  t.app.request(ruta, {
    method: metodo,
    headers: { 'content-type': 'application/json', ...auth(token) },
    body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
  });

let siguiente = 0;
/** Crea una cuenta por la API y devuelve su id (o la respuesta, si falla). */
async function crearCuenta(campos: Record<string, unknown>) {
  siguiente++;
  return pedir('/users', 'POST', admin, {
    name: `Prueba ${siguiente}`,
    email: `cuenta${siguiente}@prueba.co`,
    password: 'Clave123',
    ...campos,
  });
}

async function clienteDe(id: string): Promise<string | null> {
  const [fila] = await sql<{ client_id: string | null }[]>`
    select client_id from users where id = ${id}`;
  return fila!.client_id;
}

beforeAll(async () => {
  await seedTestDatabase();
  t = makeTestApp();
  sql = t.sql;
  admin = (await login(t.app, 'admin@enactus.co', 'Admin123')).accessToken;
  const [enactus] = await sql<{ id: string }[]>`select id from clients where has_laboratories`;
  enactusId = enactus!.id;
  const res = await pedir('/clients', 'POST', admin, {
    name: 'Banco Andino',
    primaryColor: '#1A73E8',
    secondaryColor: '#0B5394',
  });
  empresaId = ((await res.json()) as { id: string }).id;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('la asignación de Enactus', () => {
  it('quedan en Enactus sus estudiantes y su red; nadie más', async () => {
    const filas = await sql<{ role: string; student_type: string | null; client_id: string | null }[]>`
      select role, student_type, client_id from users where deleted_at is null`;
    for (const f of filas) {
      const deEnactus =
        f.student_type === 'enactus' || ['advisor', 'mentor', 'donor', 'company'].includes(f.role);
      expect(f.client_id, `${f.role}/${f.student_type}`).toBe(deEnactus ? enactusId : null);
    }
    expect(filas.some((f) => f.role === 'lxd')).toBe(true);
  });

  it('el relleno de la migración hace lo mismo sobre una base con gente, y es idempotente', async () => {
    const antes = await sql`select id, client_id from users order by id`;
    await sql`update users set client_id = null`;
    const texto = readFileSync(RELLENO, 'utf8');
    const relleno = texto.slice(texto.indexOf('-- RELLENO.'));
    await sql.unsafe(relleno);
    await sql.unsafe(relleno);
    expect(await sql`select id, client_id from users order by id`).toEqual(antes);
  });

  it('la base no deja a un admin con cliente', async () => {
    await expect(
      sql`update users set client_id = ${enactusId} where email = 'admin@enactus.co'`,
    ).rejects.toThrow(/users_admins_sin_cliente/);
  });
});

describe('la marca al entrar', () => {
  it('un estudiante de Enactus recibe su cliente, sin colores: se ve como eduXaction', async () => {
    const res = await t.app.request(
      '/auth/login',
      json({ email: 'estudiante1@uniandes.edu.co', password: 'Est123' }),
    );
    const { user } = (await res.json()) as { user: { client: Record<string, unknown> | null } };
    expect(user.client?.name).toBe('Enactus');
    expect(user.client?.primaryColor).toBeNull();
    expect(user.client?.hasLaboratories).toBe(true);
  });

  it('el personal de eduXaction no tiene cliente', async () => {
    for (const [email, clave] of [
      ['admin@enactus.co', 'Admin123'],
      ['lxd.ia@enactus.co', 'Lxd123'],
    ] as const) {
      resetRateLimits();
      const token = (await login(t.app, email, clave)).accessToken;
      const me = (await (await pedir('/auth/me', 'GET', token)).json()) as { client: unknown };
      expect(me.client, email).toBeNull();
    }
  });

  it('una cuenta de empresa recibe SU marca, y solo esa', async () => {
    const res = await crearCuenta({
      email: 'ana@bancoandino.co',
      role: 'student',
      studentType: 'open_learning',
      clientId: empresaId,
    });
    expect(res.status, await res.clone().text()).toBe(201);
    const token = (await login(t.app, 'ana@bancoandino.co', 'Clave123')).accessToken;
    const me = (await (await pedir('/auth/me', 'GET', token)).json()) as {
      clientId: string;
      client: Record<string, unknown>;
    };
    expect(me.clientId).toBe(empresaId);
    expect(me.client).toMatchObject({
      id: empresaId,
      name: 'Banco Andino',
      primaryColor: '#1A73E8',
      secondaryColor: '#0B5394',
      hasLaboratories: false,
    });
  });
});

describe('quién puede pertenecer a qué cliente', () => {
  it('sin mandarlo, cada cuenta queda con el que le toca', async () => {
    const enactus = (await (
      await crearCuenta({ role: 'student', studentType: 'enactus' })
    ).json()) as { id: string };
    expect(await clienteDe(enactus.id)).toBe(enactusId);
    const asesor = (await (await crearCuenta({ role: 'advisor' })).json()) as { id: string };
    expect(await clienteDe(asesor.id)).toBe(enactusId);
    const ol = (await (
      await crearCuenta({ role: 'student', studentType: 'open_learning' })
    ).json()) as { id: string };
    expect(await clienteDe(ol.id)).toBeNull();
    const lxd = (await (await crearCuenta({ role: 'lxd' })).json()) as { id: string };
    expect(await clienteDe(lxd.id)).toBeNull();
  });

  it('las combinaciones que no tienen sentido se rechazan', async () => {
    const casos: [string, Record<string, unknown>][] = [
      ['un estudiante eduXaction en una empresa', { role: 'student', studentType: 'enactus', clientId: empresaId }],
      ['uno de Open Learning en Enactus', { role: 'student', studentType: 'open_learning', clientId: enactusId }],
      ['un asesor en una empresa', { role: 'advisor', clientId: empresaId }],
      ['un admin con cliente', { role: 'admin', clientId: empresaId }],
      ['un estudiante eduXaction sin Enactus', { role: 'student', studentType: 'enactus', clientId: null }],
      ['un cliente que no existe', { role: 'lxd', clientId: '00000000-0000-4000-8000-000000000000' }],
    ];
    for (const [caso, campos] of casos) {
      const res = await crearCuenta(campos);
      expect(res.status, caso).toBe(409);
    }
  });

  it('un LXD puede ser de una empresa', async () => {
    const res = await crearCuenta({ role: 'lxd', clientId: empresaId });
    expect(res.status).toBe(201);
  });

  it('cambiar el tipo de estudiante mueve el cliente con él', async () => {
    const { id } = (await (
      await crearCuenta({ role: 'student', studentType: 'enactus' })
    ).json()) as { id: string };
    await pedir(`/users/${id}`, 'PATCH', admin, { studentType: 'open_learning' });
    expect(await clienteDe(id)).toBeNull();
    await pedir(`/users/${id}`, 'PATCH', admin, { studentType: 'enactus' });
    expect(await clienteDe(id)).toBe(enactusId);
  });

  it('una empresa aliada no elige el cliente de su equipo', async () => {
    const empresa = (await login(t.app, 'empresa@bancolombia.com', 'Empresa123')).accessToken;
    siguiente++;
    const res = await pedir('/users', 'POST', empresa, {
      name: 'Formadora',
      email: `formadora${siguiente}@prueba.co`,
      password: 'Clave123',
      role: 'lxd',
      clientId: empresaId,
    });
    expect(res.status, await res.clone().text()).toBe(201);
    expect(await clienteDe(((await res.json()) as { id: string }).id)).toBeNull();
  });

  it('el panel cuenta las cuentas de cada cliente, y la lista filtra por cliente', async () => {
    const { data } = (await (await pedir('/clients', 'GET', admin)).json()) as {
      data: { id: string; accountCount: number }[];
    };
    const [fila] = await sql<{ total: number }[]>`
      select count(*)::int as total from users where client_id = ${enactusId} and deleted_at is null`;
    expect(fila!.total).toBeGreaterThan(0);
    expect(data.find((c) => c.id === enactusId)?.accountCount).toBe(fila!.total);

    const lista = (await (
      await pedir(`/users?clientId=${empresaId}&pageSize=100`, 'GET', admin)
    ).json()) as { data: { clientId: string }[] };
    expect(lista.data.length).toBeGreaterThan(0);
    expect(lista.data.every((u) => u.clientId === empresaId)).toBe(true);
  });
});

describe('un cliente desactivado', () => {
  it('deja afuera a sus cuentas por las tres puertas, y vuelven al reactivarlo', async () => {
    await crearCuenta({
      email: 'luis@bancoandino.co',
      role: 'student',
      studentType: 'open_learning',
      clientId: empresaId,
    });
    const sesion = await login(t.app, 'luis@bancoandino.co', 'Clave123');

    const off = await pedir(`/clients/${empresaId}`, 'PATCH', admin, { active: false });
    expect(off.status).toBe(200);

    // 1. Entrar.
    resetRateLimits();
    const entrar = await t.app.request(
      '/auth/login',
      json({ email: 'luis@bancoandino.co', password: 'Clave123' }),
    );
    expect(entrar.status).toBe(403);
    expect(await entrar.text()).toMatch(/client_inactive/);

    // Con la contraseña equivocada sigue siendo 401: decir «su empresa está
    // desactivada» confirmaría la cuenta a quien no sabe la clave.
    resetRateLimits();
    const mala = await t.app.request(
      '/auth/login',
      json({ email: 'luis@bancoandino.co', password: 'Otra999' }),
    );
    expect(mala.status).toBe(401);

    // 2. La sesión que ya estaba abierta.
    expect((await pedir('/auth/me', 'GET', sesion.accessToken)).status).toBe(403);

    // 3. Renovar la sesión.
    const renovar = await t.app.request(
      '/auth/refresh',
      json({ refreshToken: sesion.refreshToken }),
    );
    expect(renovar.status).toBe(403);

    await pedir(`/clients/${empresaId}`, 'PATCH', admin, { active: true });
    resetRateLimits();
    expect(
      (await t.app.request('/auth/login', json({ email: 'luis@bancoandino.co', password: 'Clave123' })))
        .status,
    ).toBe(200);
  });

  it('no admite cuentas nuevas, pero editar una suya no la saca del cliente', async () => {
    const { id } = (await (
      await crearCuenta({ role: 'student', studentType: 'open_learning', clientId: empresaId })
    ).json()) as { id: string };
    await pedir(`/clients/${empresaId}`, 'PATCH', admin, { active: false });

    expect(
      (await crearCuenta({ role: 'student', studentType: 'open_learning', clientId: empresaId }))
        .status,
    ).toBe(409);
    const editar = await pedir(`/users/${id}`, 'PATCH', admin, { phone: '3001234567' });
    expect(editar.status, await editar.clone().text()).toBe(200);
    expect(await clienteDe(id)).toBe(empresaId);

    await pedir(`/clients/${empresaId}`, 'PATCH', admin, { active: true });
  });
});
