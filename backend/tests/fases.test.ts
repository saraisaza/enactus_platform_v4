import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';

/**
 * Agregar fases a la Ruta de un laboratorio.
 *
 * El sistema modelaba **tres** fases porque el comentario del esquema lo
 * decía, no porque el esquema lo exigiera: la única regla es
 * `order_index > 0` y que no se repita. La metodología real tiene cinco.
 *
 * Lo que estas pruebas fijan es lo que sí es cierto del dominio: el orden lo
 * calcula el servidor, y agregar una fase SUBE el listón del certificado.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;
let token = '';

beforeAll(async () => {
  const t = makeTestApp();
  app = t.app;
  sql = t.sql;
  await seedTestDatabase();
  const admin = await login(app, 'admin@enactus.co', 'Admin123');
  token = admin.accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

const cabeceras = () => ({
  ...(json({}).headers as Record<string, string>),
  ...auth(token),
});

async function unLaboratorio(): Promise<string> {
  const [fila] = await sql<{ id: string }[]>`
    select id from laboratories where deleted_at is null order by name limit 1`;
  return fila!.id;
}

describe('POST /laboratories/:id/phases', () => {
  it('la fase nueva va al final, con el orden que calcula el servidor', async () => {
    const labId = await unLaboratorio();
    const [antes] = await sql<{ n: number }[]>`
      select count(*)::int as n from phases where laboratory_id = ${labId}`;

    const res = await app.request(`/laboratories/${labId}/phases`, {
      ...json({ title: 'VALIDAR' }),
      headers: cabeceras(),
    });
    const texto = await res.text();
    expect(res.status, texto).toBe(201);

    const creada = JSON.parse(texto) as {
      orderIndex: number;
      title: string;
      phasesTotal: number;
    };
    expect(creada.title).toBe('VALIDAR');
    expect(creada.orderIndex).toBe(antes!.n + 1);
    expect(creada.phasesTotal).toBe(antes!.n + 1);
  });

  it('el orden NO se acepta del cliente', async () => {
    // Aceptarlo convierte una carrera entre dos administradores en un 500, por
    // el `unique(laboratory_id, order_index)`. Mandarlo se ignora, no se
    // obedece.
    const labId = await unLaboratorio();
    const res = await app.request(`/laboratories/${labId}/phases`, {
      ...json({ title: 'MOVILIZAR', orderIndex: 1 }),
      headers: cabeceras(),
    });
    expect(res.status).toBe(201);
    const creada = (await res.json()) as { orderIndex: number };
    expect(creada.orderIndex).toBeGreaterThan(1);
  });

  it('agregar una fase sube el listón del certificado', async () => {
    // `ruta_completion` exige TODAS las fases completas. No es un detalle de
    // implementación: es la consecuencia que alguien tiene que conocer antes
    // de agregar una fase a un laboratorio con gente avanzando.
    const labId = await unLaboratorio();
    const [antes] = await sql<{ total: number }[]>`
      select coalesce(max(phases_total), 0)::int as total
        from ruta_completion where laboratory_id = ${labId}`;

    await app.request(`/laboratories/${labId}/phases`, {
      ...json({ title: 'Una fase más' }),
      headers: cabeceras(),
    });

    const [despues] = await sql<{ total: number }[]>`
      select coalesce(max(phases_total), 0)::int as total
        from ruta_completion where laboratory_id = ${labId}`;
    // Solo si el laboratorio tiene estudiantes: sin ellos la vista no trae
    // filas y el `max` es 0 en los dos lados, que también es correcto.
    if (antes!.total > 0) {
      expect(despues!.total).toBe(antes!.total + 1);
    }
  });

  it('un laboratorio que no existe da 404', async () => {
    const res = await app.request(
      '/laboratories/00000000-0000-4000-8000-000000000000/phases',
      { ...json({ title: 'X' }), headers: cabeceras() },
    );
    expect(res.status).toBe(404);
  });

  it('sin título no se crea', async () => {
    const labId = await unLaboratorio();
    const res = await app.request(`/laboratories/${labId}/phases`, {
      ...json({ title: '   ' }),
      headers: cabeceras(),
    });
    expect(res.status).toBe(400);
  });
});
