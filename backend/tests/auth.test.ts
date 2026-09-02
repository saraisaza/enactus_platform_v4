import { Hono } from 'hono';
import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { signAccessTokenWithExpiry } from '../src/lib/jwt';
import {
  assertCanGrade,
  assertSelfOr,
  currentUser,
  requireAuth,
  requireCanGrade,
  requireEnactus,
  requireRole,
} from '../src/middleware/auth';
import type { AppEnv } from '../src/middleware/context';
import { onError } from '../src/middleware/error';
import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Fase 3: autenticación y autorización.
 *
 * Se ejercita la aplicación completa con `app.request()` — el mismo pipeline
 * que en producción (CORS, cabeceras, middlewares, manejo de errores), sin
 * abrir un puerto.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

const CREDS = {
  admin: ['admin@enactus.co', 'Admin123'] as const,
  superadmin: ['superadmin1@enactus.co', 'Super123'] as const,
  lxdPuede: ['lxd.ia@enactus.co', 'Lxd123'] as const,
  lxdNoPuede: ['lxd.agua@enactus.co', 'Lxd123'] as const,
  mentor: ['mentor.ia@enactus.co', 'Mentor123'] as const,
  advisor: ['asesor@uniandes.edu.co', 'Asesor123'] as const,
  company: ['empresa@bancolombia.com', 'Empresa123'] as const,
  donor: ['donante@gmail.com', 'Donante123'] as const,
  enactus: ['estudiante1@uniandes.edu.co', 'Est123'] as const,
  otroEnactus: ['estudiante3@unal.edu.co', 'Est123'] as const,
  openLearning: ['camila.rivas@gmail.com', 'Est123'] as const,
  alumni: ['alumni1@uniandes.edu.co', 'Alumni123'] as const,
};

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;
}, 120_000);

beforeEach(() => {
  // El límite de intentos es por proceso: sin esto, los tests de login se
  // acumularían y el último daría 429 sin que haya nada roto.
  resetRateLimits();
});

afterAll(async () => {
  await sql.end();
});

describe('POST /auth/login', () => {
  it('con credenciales correctas devuelve tokens y el usuario', async () => {
    const res = await app.request(
      '/auth/login',
      json({ email: CREDS.admin[0], password: CREDS.admin[1] }),
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as Record<string, unknown>;
    expect(typeof body.accessToken).toBe('string');
    expect(typeof body.refreshToken).toBe('string');
    expect(body.expiresIn).toBe(12 * 60 * 60);
    const user = body.user as Record<string, unknown>;
    expect(user.email).toBe('admin@enactus.co');
    expect(user.role).toBe('admin');
  });

  it('nunca devuelve el hash de la contraseña', async () => {
    const res = await app.request(
      '/auth/login',
      json({ email: CREDS.admin[0], password: CREDS.admin[1] }),
    );
    const raw = await res.text();
    expect(raw).not.toContain('passwordHash');
    expect(raw).not.toContain('password_hash');
    expect(raw).not.toContain('$2b$');
  });

  it('acepta el correo sin importar mayúsculas', async () => {
    const res = await app.request(
      '/auth/login',
      json({ email: 'ADMIN@Enactus.CO', password: 'Admin123' }),
    );
    expect(res.status).toBe(200);
  });

  it('con contraseña incorrecta devuelve 401', async () => {
    const res = await app.request(
      '/auth/login',
      json({ email: CREDS.admin[0], password: 'incorrecta' }),
    );
    expect(res.status).toBe(401);
    const body = (await res.json()) as { error: { code: string; message: string } };
    expect(body.error.code).toBe('unauthorized');
    expect(body.error.message).toBe('Correo o contraseña incorrectos.');
  });

  it('con un correo inexistente devuelve el MISMO mensaje', async () => {
    // Si distinguiéramos "no existe" de "contraseña mala", estaríamos
    // regalando un enumerador de cuentas.
    const res = await app.request(
      '/auth/login',
      json({ email: 'nadie@enactus.co', password: 'loquesea' }),
    );
    expect(res.status).toBe(401);
    const body = (await res.json()) as { error: { message: string } };
    expect(body.error.message).toBe('Correo o contraseña incorrectos.');
  });

  it('sin cuerpo válido devuelve 400 con el detalle del campo', async () => {
    const res = await app.request('/auth/login', json({ email: '' }));
    expect(res.status).toBe(400);
    const body = (await res.json()) as {
      error: { code: string; details: { field: string }[] };
    };
    expect(body.error.code).toBe('validation_error');
    expect(body.error.details.map((d) => d.field)).toContain('password');
  });

  it('corta los intentos de fuerza bruta con 429', async () => {
    const attempt = () =>
      app.request(
        '/auth/login',
        json({ email: CREDS.admin[0], password: 'mala' }),
      );
    for (let i = 0; i < 10; i++) {
      expect((await attempt()).status).toBe(401);
    }
    const bloqueado = await attempt();
    expect(bloqueado.status).toBe(429);
    const body = (await bloqueado.json()) as {
      error: { code: string; details: { retryAfterSeconds: number } };
    };
    expect(body.error.code).toBe('too_many_requests');
    expect(body.error.details.retryAfterSeconds).toBeGreaterThan(0);
  });
});

describe('GET /auth/me', () => {
  it('sin token devuelve 401', async () => {
    const res = await app.request('/auth/me');
    expect(res.status).toBe(401);
  });

  it('con token válido devuelve el usuario de la sesión', async () => {
    const { accessToken } = await login(app, ...CREDS.enactus);
    const res = await app.request('/auth/me', { headers: auth(accessToken) });
    expect(res.status).toBe(200);
    const body = (await res.json()) as { email: string; studentType: string };
    expect(body.email).toBe('estudiante1@uniandes.edu.co');
    expect(body.studentType).toBe('enactus');
  });

  it('con un token expirado devuelve 401', async () => {
    const expirado = await signAccessTokenWithExpiry(
      { sub: seedId('est1'), role: 'student' },
      new Date(Date.now() - 60_000),
    );
    const res = await app.request('/auth/me', { headers: auth(expirado) });
    expect(res.status).toBe(401);
    const body = (await res.json()) as { error: { message: string } };
    expect(body.error.message).toContain('expiró');
  });

  it('con un token manipulado devuelve 401', async () => {
    const { accessToken } = await login(app, ...CREDS.admin);
    const manipulado = `${accessToken.slice(0, -4)}AAAA`;
    const res = await app.request('/auth/me', { headers: auth(manipulado) });
    expect(res.status).toBe(401);
  });
});

/**
 * El token NO es la fuente de verdad. El registro vivo, sí.
 *
 * Este bloque existe por un hueco que encontró la auditoría de pruebas
 * (BLOQUE 1, mutación M8): se le quitó a `requireAuth` el filtro
 * `isNull(users.deletedAt)` —o sea, una cuenta desactivada seguía entrando— y
 * **ninguna de las 502 pruebas se puso roja**. La regla estaba escrita en el
 * comentario del middleware y en ningún assert.
 *
 * Importa de verdad: el access token dura 12 horas. Sin esta verificación,
 * desactivar a alguien que se fue de la organización no lo saca hasta la
 * mañana siguiente, y quitarle `can_grade` a un LXD tampoco surte efecto —
 * justo los dos momentos en que se revoca un permiso son aquellos en los que
 * hay prisa por que surta efecto.
 */
describe('los permisos se leen del registro vivo, no del token', () => {
  it('desactivar la cuenta invalida el token YA emitido, sin esperar 12 h', async () => {
    const { accessToken } = await login(app, ...CREDS.otroEnactus);

    // Antes de tocar nada, el token sirve.
    expect(
      (await app.request('/auth/me', { headers: auth(accessToken) })).status,
    ).toBe(200);

    await sql`update users set deleted_at = now() where email = ${CREDS.otroEnactus[0]}`;
    try {
      const res = await app.request('/auth/me', { headers: auth(accessToken) });
      expect(res.status).toBe(401);
      const body = (await res.json()) as { error: { message: string } };
      expect(body.error.message).toContain('ya no existe');
    } finally {
      await sql`update users set deleted_at = null where email = ${CREDS.otroEnactus[0]}`;
    }
  });

  it('quitar can_grade surte efecto en la petición siguiente', async () => {
    const guard = guardApp(makeTestApp().db);
    const { accessToken } = await login(app, ...CREDS.lxdPuede);

    expect(
      (await guard.request('/calificar', { method: 'POST', headers: auth(accessToken) }))
        .status,
    ).toBe(200);

    await sql`update users
                 set can_grade_enactus = false, can_grade_open_learning = false
               where email = ${CREDS.lxdPuede[0]}`;
    try {
      // Mismo token, sin volver a entrar: el permiso se releyó de la base.
      const res = await guard.request('/calificar', {
        method: 'POST',
        headers: auth(accessToken),
      });
      expect(res.status).toBe(403);
    } finally {
      await sql`update users
                   set can_grade_enactus = true, can_grade_open_learning = true
                 where email = ${CREDS.lxdPuede[0]}`;
    }
  });

  it('cambiar el rol surte efecto aunque el token diga el rol viejo', async () => {
    // El claim `role` del token queda desactualizado a propósito: si la
    // autorización lo leyera a él en vez del registro, un rol degradado
    // seguiría entrando donde ya no debe.
    const guard = guardApp(makeTestApp().db);
    const { accessToken } = await login(app, ...CREDS.lxdPuede);

    expect(
      (await guard.request('/solo-contenido', { headers: auth(accessToken) })).status,
    ).toBe(200);

    await sql`update users set role = 'donor' where email = ${CREDS.lxdPuede[0]}`;
    try {
      const res = await guard.request('/solo-contenido', {
        headers: auth(accessToken),
      });
      expect(res.status).toBe(403);
    } finally {
      await sql`update users set role = 'lxd' where email = ${CREDS.lxdPuede[0]}`;
    }
  });
});

describe('POST /auth/refresh — rotación', () => {
  it('emite un par nuevo y revoca el anterior', async () => {
    const { refreshToken } = await login(app, ...CREDS.admin);

    const res = await app.request('/auth/refresh', json({ refreshToken }));
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      accessToken: string;
      refreshToken: string;
    };
    expect(body.refreshToken).not.toBe(refreshToken);

    // El nuevo access token funciona.
    const me = await app.request('/auth/me', { headers: auth(body.accessToken) });
    expect(me.status).toBe(200);

    // El anterior ya no sirve: fue rotado.
    const reuso = await app.request('/auth/refresh', json({ refreshToken }));
    expect(reuso.status).toBe(401);
  });

  it('reusar un refresh ya usado cierra TODAS las sesiones del usuario', async () => {
    const primera = await login(app, ...CREDS.mentor);
    const segunda = await login(app, ...CREDS.mentor);

    // Se rota el primero, quedando revocado.
    const rotado = await app.request(
      '/auth/refresh',
      json({ refreshToken: primera.refreshToken }),
    );
    expect(rotado.status).toBe(200);

    // Reusar el revocado: señal de token robado → se corta todo.
    const reuso = await app.request(
      '/auth/refresh',
      json({ refreshToken: primera.refreshToken }),
    );
    expect(reuso.status).toBe(401);

    // Y la OTRA sesión, que no tenía nada que ver, también quedó cerrada.
    const otra = await app.request(
      '/auth/refresh',
      json({ refreshToken: segunda.refreshToken }),
    );
    expect(otra.status).toBe(401);
  });

  it('el refresh token se guarda hasheado, nunca en claro', async () => {
    const { refreshToken } = await login(app, ...CREDS.donor);
    const [row] = await sql<{ count: string }[]>`
      select count(*)::text as count from refresh_tokens
       where token_hash = ${refreshToken}
    `;
    expect(row?.count).toBe('0');
  });

  it('con un token inventado devuelve 401', async () => {
    const res = await app.request(
      '/auth/refresh',
      json({ refreshToken: 'esto-no-existe' }),
    );
    expect(res.status).toBe(401);
  });
});

describe('POST /auth/logout', () => {
  it('revoca el refresh token y responde 204', async () => {
    const { refreshToken } = await login(app, ...CREDS.advisor);
    const res = await app.request('/auth/logout', json({ refreshToken }));
    expect(res.status).toBe(204);

    const usar = await app.request('/auth/refresh', json({ refreshToken }));
    expect(usar.status).toBe(401);
  });
});

// ---------------------------------------------------------------------------
// Middlewares de autorización, montados en una app de prueba
// ---------------------------------------------------------------------------

/**
 * Rutas mínimas que solo existen para ejercitar los middlewares por HTTP.
 * Los endpoints reales llegan en la Fase 4; lo que se prueba acá es la
 * guardia, no el recurso.
 */
function guardApp(database: ReturnType<typeof makeTestApp>['db']) {
  const test = new Hono<AppEnv>();
  test.onError(onError);
  test.use('*', async (c, next) => {
    c.set('db', database);
    c.set('requestIp', '127.0.0.1');
    await next();
  });
  test.get('/solo-contenido', requireAuth, requireRole('lxd', 'admin', 'superadmin'), (c) =>
    c.json({ ok: true }),
  );
  test.post('/calificar', requireAuth, requireCanGrade, (c) => c.json({ ok: true }));
  test.get('/ruta', requireAuth, requireEnactus, (c) => c.json({ ok: true }));
  test.get('/estudiantes/:id', requireAuth, (c) => {
    assertSelfOr(currentUser(c), c.req.param('id'), [
      'admin',
      'superadmin',
      'advisor',
      'mentor',
      'lxd',
    ]);
    return c.json({ ok: true });
  });
  return test;
}

describe('autorización por rol', () => {
  let guard: ReturnType<typeof guardApp>;

  beforeAll(() => {
    guard = guardApp(makeTestApp().db);
  });

  it('un estudiante recibe 403 en una ruta de creación de contenido', async () => {
    const { accessToken } = await login(app, ...CREDS.enactus);
    const res = await guard.request('/solo-contenido', {
      headers: auth(accessToken),
    });
    expect(res.status).toBe(403);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe('forbidden');
  });

  it.each([
    ['lxd', CREDS.lxdPuede],
    ['admin', CREDS.admin],
    ['superadmin', CREDS.superadmin],
  ] as const)('un %s sí entra', async (_role, creds) => {
    const { accessToken } = await login(app, creds[0], creds[1]);
    const res = await guard.request('/solo-contenido', {
      headers: auth(accessToken),
    });
    expect(res.status).toBe(200);
  });

  it.each([
    ['mentor', CREDS.mentor],
    ['advisor', CREDS.advisor],
    ['company', CREDS.company],
    ['donor', CREDS.donor],
    ['alumni', CREDS.alumni],
  ] as const)('un %s recibe 403', async (_role, creds) => {
    const { accessToken } = await login(app, creds[0], creds[1]);
    const res = await guard.request('/solo-contenido', {
      headers: auth(accessToken),
    });
    expect(res.status).toBe(403);
  });
});

describe('permiso de calificar', () => {
  let guard: ReturnType<typeof guardApp>;

  beforeAll(() => {
    guard = guardApp(makeTestApp().db);
  });

  it('el LXD con permiso puede', async () => {
    const { accessToken } = await login(app, ...CREDS.lxdPuede);
    const res = await guard.request('/calificar', {
      method: 'POST',
      headers: auth(accessToken),
    });
    expect(res.status).toBe(200);
  });

  it('el LXD SIN permiso recibe 403', async () => {
    const { accessToken } = await login(app, ...CREDS.lxdNoPuede);
    const res = await guard.request('/calificar', {
      method: 'POST',
      headers: auth(accessToken),
    });
    expect(res.status).toBe(403);
    const body = (await res.json()) as { error: { message: string } };
    expect(body.error.message).toContain('permiso de calificar');
  });

  it('el Mentor no califica: comenta, pero no pone nota', async () => {
    const { accessToken } = await login(app, ...CREDS.mentor);
    const res = await guard.request('/calificar', {
      method: 'POST',
      headers: auth(accessToken),
    });
    expect(res.status).toBe(403);
  });

  it('assertCanGrade distingue los dos contextos', async () => {
    const [lxd] = await sql<
      { role: string; can_grade_open_learning: boolean; can_grade_enactus: boolean }[]
    >`select role, can_grade_open_learning, can_grade_enactus
        from users where email = 'lxd.impacto@enactus.co'`;
    const user = {
      role: lxd!.role,
      canGradeOpenLearning: lxd!.can_grade_open_learning,
      canGradeEnactus: lxd!.can_grade_enactus,
    } as Parameters<typeof assertCanGrade>[0];

    // lxd3 tiene los defaults: Open Learning sí, Enactus no.
    expect(() => assertCanGrade(user, true)).not.toThrow();
    expect(() => assertCanGrade(user, false)).toThrow(/eduXaction/);
  });
});

describe('aislamiento entre estudiantes', () => {
  let guard: ReturnType<typeof guardApp>;

  beforeAll(() => {
    guard = guardApp(makeTestApp().db);
  });

  it('un estudiante ve lo suyo', async () => {
    const { accessToken, userId } = await login(app, ...CREDS.enactus);
    const res = await guard.request(`/estudiantes/${userId}`, {
      headers: auth(accessToken),
    });
    expect(res.status).toBe(200);
  });

  it('un estudiante NO puede leer los datos de otro', async () => {
    const { accessToken } = await login(app, ...CREDS.enactus);
    const otro = await login(app, ...CREDS.otroEnactus);
    const res = await guard.request(`/estudiantes/${otro.userId}`, {
      headers: auth(accessToken),
    });
    expect(res.status).toBe(403);
  });

  it('un mentor sí puede leer los datos de un estudiante', async () => {
    const { accessToken } = await login(app, ...CREDS.mentor);
    const res = await guard.request(`/estudiantes/${seedId('est1')}`, {
      headers: auth(accessToken),
    });
    expect(res.status).toBe(200);
  });
});

describe('Open Learning no entra a lo de Enactus', () => {
  let guard: ReturnType<typeof guardApp>;

  beforeAll(() => {
    guard = guardApp(makeTestApp().db);
  });

  it('un Open Learning recibe 403, no una respuesta vacía', async () => {
    const { accessToken } = await login(app, ...CREDS.openLearning);
    const res = await guard.request('/ruta', { headers: auth(accessToken) });
    expect(res.status).toBe(403);
    const body = (await res.json()) as { error: { message: string } };
    expect(body.error.message).toContain('Open Learning');
  });

  it('un Enactus sí entra', async () => {
    const { accessToken } = await login(app, ...CREDS.enactus);
    const res = await guard.request('/ruta', { headers: auth(accessToken) });
    expect(res.status).toBe(200);
  });

  it('la alumni cuenta como Enactus', async () => {
    const { accessToken } = await login(app, ...CREDS.alumni);
    const res = await guard.request('/ruta', { headers: auth(accessToken) });
    expect(res.status).toBe(200);
  });
});

describe('GET /health', () => {
  it('responde sin sesión', async () => {
    const res = await app.request('/health');
    expect(res.status).toBe(200);
    const body = (await res.json()) as { status: string };
    expect(body.status).toBe('ok');
  });
});
