import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedTestDatabase } from './helpers/db';

/**
 * Eliminar la propia cuenta: lo exigen App Store (guía 5.1.1(v)) y Google
 * Play para publicar la app.
 *
 * Lo que se mide no es que la ruta responda, sino lo que una persona y un
 * revisor de la tienda esperan: que la cuenta deje de funcionar EN EL ACTO,
 * que nadie quede con una sesión viva, que el equipo vea la solicitud, y que
 * al completarla no quede ningún dato personal.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

const DONANTE = { email: 'donante@gmail.com', password: 'Donante123' };
let adminToken = '';
let estudianteToken = '';

const req = (path: string, token: string, init: RequestInit = {}) =>
  app.request(path, {
    ...init,
    headers: { ...(init.headers ?? {}), ...auth(token) },
  });

const body = async <T>(res: Response): Promise<T> => (await res.json()) as T;

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;
  adminToken = (await login(app, 'admin@enactus.co', 'Admin123')).accessToken;
  estudianteToken = (await login(app, 'estudiante1@uniandes.edu.co', 'Est123'))
    .accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());
afterAll(async () => {
  await sql.end();
});

describe('eliminar la propia cuenta', () => {
  it('con la contraseña equivocada no pasa nada', async () => {
    const sesion = await login(app, DONANTE.email, DONANTE.password);
    const res = await req(
      '/auth/me/deletion-request',
      sesion.accessToken,
      json({ password: 'no-es-esta' }),
    );
    expect(res.status).toBe(403);
    // Sigue entrando con normalidad.
    expect((await req('/auth/me', sesion.accessToken)).status).toBe(200);
  });

  it('el estudiante no ve la cola de solicitudes del equipo', async () => {
    const res = await req('/users/deletion-requests', estudianteToken);
    expect(res.status).toBe(403);
  });

  it('no se pueden borrar los datos de una cuenta activa', async () => {
    const sesion = await login(app, DONANTE.email, DONANTE.password);
    const res = await req(
      `/users/${sesion.userId}/purge`,
      adminToken,
      { method: 'POST' },
    );
    expect(res.status).toBe(409);
  });

  it('con la contraseña correcta la cuenta deja de funcionar en el acto', async () => {
    const sesion = await login(app, DONANTE.email, DONANTE.password);
    const res = await req(
      '/auth/me/deletion-request',
      sesion.accessToken,
      json({ password: DONANTE.password }),
    );
    expect(res.status).toBe(202);
    const respuesta = await body<{ status: string; days: number }>(res);
    expect(respuesta).toEqual({ status: 'pending', days: 30 });

    // El token que ya tenía deja de servir desde la siguiente petición.
    expect((await req('/auth/me', sesion.accessToken)).status).toBe(401);
    // Su sesión no se puede renovar.
    const refresh = await app.request(
      '/auth/refresh',
      json({ refreshToken: sesion.refreshToken }),
    );
    expect(refresh.status).toBe(401);
    // Y ya no puede entrar.
    const otraVez = await app.request('/auth/login', json(DONANTE));
    expect(otraVez.status).toBe(401);
  });

  it('el equipo ve la solicitud pendiente, y al completarla no queda ningún dato personal', async () => {
    const pendientes = await req('/users/deletion-requests', adminToken);
    expect(pendientes.status).toBe(200);
    const { data } = await body<{
      data: { id: string; email: string; requestedAt: string }[];
    }>(pendientes);
    const solicitud = data.find((d) => d.email === DONANTE.email);
    expect(solicitud, 'La solicitud no aparece en la cola del equipo.').toBeDefined();
    const id = solicitud!.id;

    // Lo que la nombra o habla de ella fuera de `users`: su nombre en un
    // certificado, una nota del equipo, una notificación y un bloqueo.
    const [lab] = await sql<{ id: string }[]>`select id from laboratories limit 1`;
    const [curso] = await sql<{ id: string }[]>`select id from courses limit 1`;
    // La base no deja emitir un certificado sin la Ruta completa, y armar una
    // Ruta completa no es lo que se prueba acá. El guardia se apaga solo
    // dentro de esta transacción: ninguna otra conexión lo ve apagado.
    await sql.begin(async (tx) => {
      await tx`alter table certificates disable trigger certificates_require_complete_ruta`;
      await tx`insert into certificates (code, student_id, laboratory_id,
                 student_name_snapshot, laboratory_name_snapshot,
                 issuer_name_snapshot, requirements_snapshot)
               values ('PURGA-1', ${id}, ${lab!.id}, 'Nombre de la donante',
                       'Lab', 'Equipo', '{}'::jsonb)`;
      await tx`alter table certificates enable trigger certificates_require_complete_ruta`;
    });
    await sql`insert into staff_notes (student_id, course_id, note)
              values (${id}, ${curso!.id}, 'Nota personal sobre ella')`;
    await sql`insert into notifications (user_id, title) values (${id}, 'Aviso')`;
    const [otra] = await sql<{ id: string }[]>`
      select id from users where email = 'estudiante1@uniandes.edu.co'`;
    await sql`insert into user_blocks (blocker_id, blocked_id) values (${otra!.id}, ${id})`;

    const purga = await req(`/users/${solicitud!.id}/purge`, adminToken, {
      method: 'POST',
    });
    expect(purga.status).toBe(200);

    const [fila] = await sql<
      {
        name: string;
        email: string;
        phone: string;
        cedula: string;
        city: string;
        avatar_s3_key: string | null;
        profile: unknown;
      }[]
    >`select name, email, phone, cedula, city, avatar_s3_key, profile from users where id = ${solicitud!.id}`;
    expect(fila!.name).toBe('Cuenta eliminada');
    expect(fila!.email).not.toContain('donante');
    expect(fila!.email.endsWith('.invalid')).toBe(true);
    expect(fila!.phone).toBe('');
    expect(fila!.cedula).toBe('');
    expect(fila!.city).toBe('');
    expect(fila!.avatar_s3_key).toBeNull();
    expect(fila!.profile).toEqual({});

    const [restos] = await sql<
      { certificados: number; notas: number; avisos: number; bloqueos: number }[]
    >`select
        (select count(*)::int from certificates
          where student_id = ${id} and student_name_snapshot <> 'Cuenta eliminada') as certificados,
        (select count(*)::int from staff_notes where student_id = ${id}) as notas,
        (select count(*)::int from notifications where user_id = ${id}) as avisos,
        (select count(*)::int from user_blocks
          where blocker_id = ${id} or blocked_id = ${id}) as bloqueos`;
    expect(restos).toEqual({ certificados: 0, notas: 0, avisos: 0, bloqueos: 0 });

    // Y sale de la cola: ya no hay nada pendiente con esa persona.
    const despues = await body<{ data: { id: string }[] }>(
      await req('/users/deletion-requests', adminToken),
    );
    expect(despues.data.some((d) => d.id === solicitud!.id)).toBe(false);
  });
});
