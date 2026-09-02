import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';

/**
 * Respaldo y restauración, de ida y vuelta.
 *
 * Esta suite nace de un fallo que la revisión previa al lanzamiento encontró
 * ejecutando el flujo completo: **la restauración no había funcionado nunca.**
 *
 * El respaldo deja fuera `password_hash` a propósito y con razón — el archivo
 * termina en el portátil de alguien, y un hash bcrypt se rompe sin prisa y sin
 * conexión. Pero la columna es `not null`, así que el `insert` de `users`
 * fallaba siempre; y como todo va en una transacción, no se restauraba nada.
 * El botón "Restaurar desde archivo" estaba en la pantalla de Admin y
 * devolvía 500.
 *
 * Las pruebas que había miraban el respaldo (que se descargue, que no lleve
 * credenciales). Ninguna cerraba el círculo. Por eso lo que se prueba acá es
 * el ciclo entero: respaldar → destruir → restaurar → **y comprobar que la
 * gente puede entrar**, que es lo que uno necesita a las 2 de la mañana.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

const CONFIRM = 'REEMPLAZAR TODOS LOS DATOS';

beforeAll(async () => {
  await seedTestDatabase();
  const t = makeTestApp();
  app = t.app;
  sql = t.sql;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

const conteos = async () => {
  const [fila] = await sql`
    select (select count(*) from users)            as usuarios,
           (select count(*) from courses)          as cursos,
           (select count(*) from submissions)      as entregas,
           (select count(*) from progress_lessons) as lecciones,
           (select count(*) from forum_posts)      as foro`;
  return fila as Record<string, string>;
};

const respaldar = async (token: string) => {
  const res = await app.request('/admin/backup', { headers: auth(token) });
  expect(res.status).toBe(200);
  return (await res.json()) as { version: number; data: Record<string, unknown[]> };
};

describe('respaldo → destrucción → restauración', () => {
  it('el ciclo completo devuelve la base a como estaba', async () => {
    const { accessToken } = await login(app, 'superadmin1@enactus.co', 'Super123');

    const antes = await conteos();
    const respaldo = await respaldar(accessToken);

    // Se borra contenido de verdad, no una fila de adorno.
    await sql`delete from progress_lessons`;
    await sql`delete from submissions`;
    await sql`delete from forum_posts`;
    await sql`delete from courses`;

    const roto = await conteos();
    expect(Number(roto.cursos)).toBe(0);
    expect(Number(roto.entregas)).toBe(0);

    const res = await app.request('/admin/restore', {
      ...json({ version: respaldo.version, data: respaldo.data, confirm: CONFIRM }),
      headers: { 'content-type': 'application/json', ...auth(accessToken) },
    });
    expect(res.status, `la restauración falló: ${await res.clone().text()}`).toBe(200);

    expect(await conteos()).toEqual(antes);
  });

  it('después de restaurar, la gente puede ENTRAR', async () => {
    // El corazón del bug: las contraseñas no viajan en el archivo. Si la
    // restauración no las conserva, la base queda "restaurada" y nadie puede
    // usarla — que a efectos prácticos es no haber restaurado.
    for (const [email, password] of [
      ['superadmin1@enactus.co', 'Super123'],
      ['admin@enactus.co', 'Admin123'],
      ['estudiante1@uniandes.edu.co', 'Est123'],
      ['lxd.ia@enactus.co', 'Lxd123'],
    ] as const) {
      resetRateLimits();
      const res = await app.request('/auth/login', json({ email, password }));
      expect(res.status, `${email} no pudo entrar tras la restauración`).toBe(200);
    }
  });

  it('los campos jsonb sobreviven, no quedan como "[object Object]"', async () => {
    // El driver convierte un objeto de JavaScript con `String(...)` si no se
    // serializa antes: `profile` llegaba a PostgreSQL como el literal
    // `[object Object]` y el perfil del LXD quedaba en basura.
    const corruptos = await sql<{ total: number }[]>`
      select count(*)::int as total from users
       where profile::text like '%object Object%'`;
    expect(corruptos[0]?.total).toBe(0);

    const lxd = await sql<{ cargo: string }[]>`
      select profile->>'position' as cargo from users
       where email = 'lxd.ia@enactus.co'`;
    expect(lxd[0]?.cargo).toBe('Líder de Ciencia de Datos');
  });

  it('el archivo de respaldo NO lleva contraseñas ni sesiones', async () => {
    const { accessToken } = await login(app, 'superadmin1@enactus.co', 'Super123');
    const respaldo = await respaldar(accessToken);
    const texto = JSON.stringify(respaldo);

    expect(texto).not.toMatch(/\$2[aby]\$/);
    expect(texto).not.toContain('password_hash');
    expect(texto).not.toContain('refresh_token');
  });

  it('sin la frase de confirmación exacta no restaura', async () => {
    const { accessToken } = await login(app, 'superadmin1@enactus.co', 'Super123');
    const respaldo = await respaldar(accessToken);

    for (const confirm of ['', 'sí', 'reemplazar todos los datos']) {
      const res = await app.request('/admin/restore', {
        ...json({ version: respaldo.version, data: respaldo.data, confirm }),
        headers: { 'content-type': 'application/json', ...auth(accessToken) },
      });
      expect(res.status, `pasó con confirm="${confirm}"`).toBe(400);
    }
  });

  it('un admin que NO es superadmin no puede restaurar', async () => {
    const { accessToken } = await login(app, 'admin@enactus.co', 'Admin123');
    const res = await app.request('/admin/restore', {
      ...json({ version: 1, data: {}, confirm: CONFIRM }),
      headers: { 'content-type': 'application/json', ...auth(accessToken) },
    });
    expect(res.status).toBe(403);
  });
});
