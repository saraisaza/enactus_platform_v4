import { eq } from 'drizzle-orm';
import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { users } from '../src/db/schema';
import { hashPassword } from '../src/lib/password';
import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';

/**
 * Cambio obligatorio de contraseña al primer ingreso.
 *
 * Era la casilla abierta 2 de la revisión previa al lanzamiento: el plan de
 * go-live pedía "contraseñas iniciales entregadas de forma segura, con cambio
 * obligatorio en el primer ingreso" y no existía ni el campo que lo marcara ni
 * un endpoint con el que la persona pudiera cambiar la suya. La plataforma
 * sabía restablecer la contraseña de otro (solo administración), pero nadie
 * podía cambiar la propia — así que la instrucción era imposible de cumplir.
 *
 * Lo que se prueba acá, sobre todo, es que la obligación **sea real**. Un
 * cartel en la pantalla lo cierra cualquiera con la X y la API sigue
 * aceptando todo con la contraseña vieja; lo que vale es que el servidor no
 * deje hacer otra cosa.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let db: ReturnType<typeof makeTestApp>['db'];
let sql: Sql;

const CUENTA = 'lxd.agua@enactus.co';
const ACTUAL = 'Lxd123';
const NUEVA = 'UnaContrasenaNueva2026$';

beforeAll(async () => {
  await seedTestDatabase();
  const t = makeTestApp();
  app = t.app;
  db = t.db;
  sql = t.sql;
}, 120_000);

beforeEach(async () => {
  resetRateLimits();
  // Cada caso arranca del mismo punto: la contraseña del seed y sin
  // obligación pendiente.
  //
  // Se restaura escribiendo el hash, no llamando al endpoint: la contraseña
  // del seed tiene 6 caracteres y `change-password` exige 12 — con razón, así
  // que no hay forma de volver a ponerla por la API, ni debería haberla.
  await db
    .update(users)
    .set({ passwordHash: await hashPassword(ACTUAL), mustChangePassword: false })
    .where(eq(users.email, CUENTA));
});

afterAll(async () => {
  await sql.end();
});

const marcarPendiente = () =>
  db.update(users).set({ mustChangePassword: true }).where(eq(users.email, CUENTA));

const banderaDe = async (email: string) => {
  const [fila] = await db
    .select({ pendiente: users.mustChangePassword })
    .from(users)
    .where(eq(users.email, email));
  return fila!.pendiente;
};

describe('la obligación es del servidor, no de la pantalla', () => {
  it('con el cambio pendiente, el resto de la API responde 403', async () => {
    const { accessToken } = await login(app, CUENTA, ACTUAL);
    await marcarPendiente();

    // Rutas de tres routers distintos: la obligación vive en `requireAuth`,
    // así que no puede haber una que se escape por estar en otro archivo.
    for (const ruta of ['/users', '/courses', '/laboratories', '/notifications']) {
      const res = await app.request(ruta, { headers: auth(accessToken) });
      expect(res.status, `${ruta} dejó pasar con el cambio pendiente`).toBe(403);
      const body = (await res.json()) as { error: { code: string } };
      expect(body.error.code).toBe('password_change_required');
    }
  });

  it('el código lo distingue de un 403 cualquiera', async () => {
    // Sin un código propio, el cliente mandaría a la persona a "no tenés
    // permiso" en vez de a la pantalla de cambio.
    const { accessToken } = await login(app, CUENTA, ACTUAL);
    await marcarPendiente();

    const pendiente = await app.request('/courses', { headers: auth(accessToken) });
    const sinPermiso = await app.request('/admin/metrics', {
      headers: auth((await login(app, 'estudiante1@uniandes.edu.co', 'Est123')).accessToken),
    });

    expect(pendiente.status).toBe(403);
    expect(sinPermiso.status).toBe(403);
    const a = (await pendiente.json()) as { error: { code: string } };
    const b = (await sinPermiso.json()) as { error: { code: string } };
    expect(a.error.code).toBe('password_change_required');
    expect(b.error.code).toBe('forbidden');
  });

  it('deja pasar solo lo indispensable para cambiarla o salir', async () => {
    const { accessToken } = await login(app, CUENTA, ACTUAL);
    await marcarPendiente();

    // `/auth/me`: el cliente necesita saber quién es para dibujar la pantalla.
    const yo = await app.request('/auth/me', { headers: auth(accessToken) });
    expect(yo.status).toBe(200);
    const perfil = (await yo.json()) as { mustChangePassword: boolean };
    expect(perfil.mustChangePassword).toBe(true);

    // Editar el perfil NO es indispensable: no puede usarse para hacer
    // trabajo real esquivando la obligación.
    const editar = await app.request('/auth/me', {
      method: 'PATCH',
      headers: { 'content-type': 'application/json', ...auth(accessToken) },
      body: JSON.stringify({ city: 'Medellín' }),
    });
    expect(editar.status).toBe(403);
  });
});

describe('POST /auth/change-password', () => {
  it('cambia la contraseña y levanta la obligación', async () => {
    const { accessToken } = await login(app, CUENTA, ACTUAL);
    await marcarPendiente();

    const res = await app.request('/auth/change-password', {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...auth(accessToken) },
      body: JSON.stringify({ currentPassword: ACTUAL, newPassword: NUEVA }),
    });
    expect(res.status, await res.clone().text()).toBe(200);

    const body = (await res.json()) as {
      accessToken: string;
      user: { mustChangePassword: boolean };
    };
    expect(body.user.mustChangePassword).toBe(false);
    expect(await banderaDe(CUENTA)).toBe(false);

    // El token que devuelve sirve para trabajar de verdad.
    const ahora = await app.request('/courses', { headers: auth(body.accessToken) });
    expect(ahora.status).toBe(200);

    // La nueva entra y la vieja no.
    resetRateLimits();
    expect((await app.request('/auth/login', json({ email: CUENTA, password: NUEVA }))).status).toBe(200);
    expect((await app.request('/auth/login', json({ email: CUENTA, password: ACTUAL }))).status).toBe(401);

  });

  it('exige la contraseña actual: un token robado no basta', async () => {
    // Sin esto, quien consiguiera un access token —que dura 12 horas— podría
    // cambiar la contraseña y dejar afuera a su dueño.
    const { accessToken } = await login(app, CUENTA, ACTUAL);
    const res = await app.request('/auth/change-password', {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...auth(accessToken) },
      body: JSON.stringify({ currentPassword: 'no-es-la-mia', newPassword: NUEVA }),
    });
    expect(res.status).toBe(401);
  });

  it('no acepta repetir la misma', async () => {
    // Si no, la obligación se cumple escribiendo la que ya tenía y no sirve
    // para nada.
    const { accessToken } = await login(app, CUENTA, ACTUAL);
    await marcarPendiente();

    const res = await app.request('/auth/change-password', {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...auth(accessToken) },
      body: JSON.stringify({ currentPassword: ACTUAL, newPassword: ACTUAL }),
    });
    expect(res.status).toBe(400);
    expect(await banderaDe(CUENTA)).toBe(true);
  });

  it('exige al menos 12 caracteres', async () => {
    const { accessToken } = await login(app, CUENTA, ACTUAL);
    const res = await app.request('/auth/change-password', {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...auth(accessToken) },
      body: JSON.stringify({ currentPassword: ACTUAL, newPassword: 'corta1$' }),
    });
    expect(res.status).toBe(400);
  });

  it('sin sesión, 401', async () => {
    const res = await app.request('/auth/change-password', {
      ...json({ currentPassword: ACTUAL, newPassword: NUEVA }),
    });
    expect(res.status).toBe(401);
  });

  it('cierra las sesiones anteriores', async () => {
    // Cambiar la contraseña se hace, entre otras razones, porque alguien más
    // podría tenerla. Dejar viva su sesión haría el cambio decorativo.
    const vieja = await login(app, CUENTA, ACTUAL);
    const res = await app.request('/auth/change-password', {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...auth(vieja.accessToken) },
      body: JSON.stringify({ currentPassword: ACTUAL, newPassword: NUEVA }),
    });
    expect(res.status).toBe(200);

    const reusar = await app.request(
      '/auth/refresh',
      json({ refreshToken: vieja.refreshToken }),
    );
    expect(reusar.status).toBe(401);

  });

  it('el cambio queda en audit_log, sin la contraseña', async () => {
    const { accessToken } = await login(app, CUENTA, ACTUAL);
    await app.request('/auth/change-password', {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...auth(accessToken) },
      body: JSON.stringify({ currentPassword: ACTUAL, newPassword: NUEVA }),
    });

    const filas = await sql`
      select new_value::text as valor from audit_log
       where action = 'user.password.change' order by created_at desc limit 1`;
    expect(filas).toHaveLength(1);
    expect(filas[0]!.valor).not.toContain(NUEVA);
    expect(filas[0]!.valor).not.toContain(ACTUAL);

  });
});

describe('quién queda obligado', () => {
  it('un restablecimiento de administración obliga a la persona', async () => {
    const admin = await login(app, 'admin@enactus.co', 'Admin123');
    const [objetivo] = await db
      .select({ id: users.id })
      .from(users)
      .where(eq(users.email, 'mentor.ia@enactus.co'));

    const res = await app.request(`/users/${objetivo!.id}`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json', ...auth(admin.accessToken) },
      body: JSON.stringify({ password: 'RestablecidaPorAdmin2026$' }),
    });
    expect(res.status).toBe(200);
    expect(await banderaDe('mentor.ia@enactus.co')).toBe(true);
  });

  it('editar OTRO campo no obliga a nadie', async () => {
    // Cambiarle la ciudad a alguien no tiene por qué echarlo de la
    // plataforma hasta que cambie su contraseña.
    const admin = await login(app, 'admin@enactus.co', 'Admin123');
    const [objetivo] = await db
      .select({ id: users.id })
      .from(users)
      .where(eq(users.email, 'asesor@uniandes.edu.co'));

    await app.request(`/users/${objetivo!.id}`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json', ...auth(admin.accessToken) },
      body: JSON.stringify({ city: 'Cali' }),
    });
    expect(await banderaDe('asesor@uniandes.edu.co')).toBe(false);
  });

  it('la migración no obliga a las cuentas que ya existían', async () => {
    // `default false` no es un detalle: si fuera `true`, aplicar la migración
    // echaría de la plataforma a TODO el mundo hasta que cambiara su
    // contraseña — incluida gente que la eligió ella misma hace meses.
    //
    // Se mira el default de la columna y una cuenta que ningún caso de este
    // archivo toca; contar el total dependería del orden de ejecución.
    const columna = await sql`
      select column_default from information_schema.columns
       where table_name = 'users' and column_name = 'must_change_password'`;
    expect(columna[0]!.column_default).toBe('false');
    expect(await banderaDe('estudiante1@uniandes.edu.co')).toBe(false);
  });
});
