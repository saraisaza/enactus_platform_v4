import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * `POST /files/download-url`: quién puede leer qué archivo.
 *
 * Es el endpoint con más superficie de la API — firma un permiso de lectura
 * que después viaja suelto, sin sesión — así que se prueba por el lado que
 * importa: que NO firme lo que no corresponde.
 *
 * Lo que se verifica es la AUTORIZACIÓN, que es lo que decide este endpoint.
 * La firma en sí es de la SDK de AWS. Por eso `expectAuthorized` acepta tanto
 * el 200 con URL —cuando hay bucket y credenciales— como el 503
 * `storage_not_configured` de un entorno sin S3: la suite tiene que poder
 * correr sin credenciales de AWS, pero la parte estricta (que NUNCA responda
 * 403 ni 404 a quien sí tiene derecho, ni 200 a quien no) se comprueba igual
 * en los dos casos.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

let adminToken = '';
let est1Token = '';
let est2Token = '';
let olToken = '';
let donorToken = '';
let mentorToken = '';
let companyToken = '';
let advisorToken = '';

let est1Id = '';

const req = (path: string, token: string, init: RequestInit = {}) =>
  app.request(path, {
    ...init,
    headers: { ...(init.headers ?? {}), ...auth(token) },
  });

const askFor = (key: string, token: string) =>
  req('/files/download-url', token, json({ key }));

const body = async <T>(res: Response): Promise<T> => (await res.json()) as T;

/**
 * Afirma que el permiso se CONCEDIÓ.
 *
 * Con bucket configurado eso es un 200 con la URL firmada; sin él, el 503 de
 * almacenamiento no configurado. Lo que nunca puede ser es 400, 403 ni 404 —
 * esos significan que la autorización falló, que es lo que se está probando.
 */
async function expectAuthorized(res: Response): Promise<void> {
  if (res.status === 503) return; // entorno sin S3
  expect(res.status).toBe(200);
  const b = await body<{ url: string; expiresInSeconds: number }>(res);
  expect(b.url).toContain('X-Amz-Signature');
  expect(b.expiresInSeconds).toBe(3600);
}

beforeAll(async () => {
  await seedTestDatabase();
  const made = makeTestApp();
  app = made.app;
  sql = made.sql;

  adminToken = (await login(app, 'admin@enactus.co', 'Admin123')).accessToken;
  const est1 = await login(app, 'estudiante1@uniandes.edu.co', 'Est123');
  est1Token = est1.accessToken;
  est1Id = est1.userId;
  est2Token = (await login(app, 'estudiante3@unal.edu.co', 'Est123')).accessToken;
  olToken = (await login(app, 'camila.rivas@gmail.com', 'Est123')).accessToken;
  donorToken = (await login(app, 'donante@gmail.com', 'Donante123')).accessToken;
  mentorToken = (await login(app, 'mentor.ia@enactus.co', 'Mentor123')).accessToken;
  companyToken = (await login(app, 'empresa@bancolombia.com', 'Empresa123'))
    .accessToken;
  advisorToken = (await login(app, 'asesor@uniandes.edu.co', 'Asesor123'))
    .accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

describe('keys que ninguna tabla referencia', () => {
  it('responde 404, no 403: un 403 confirmaría que el objeto existe', async () => {
    const res = await askFor('avatars/no-existe.png', adminToken);
    expect(res.status).toBe(404);
    const b = await body<{ error: { code: string } }>(res);
    expect(b.error.code).toBe('not_found');
  });

  it('ni siquiera un superadmin puede firmar una key suelta', async () => {
    const superToken = (await login(app, 'superadmin1@enactus.co', 'Super123'))
      .accessToken;
    const res = await askFor('submissions/inventada.pdf', superToken);
    expect(res.status).toBe(404);
  });

  it('sin sesión no se firma nada', async () => {
    const res = await app.request('/files/download-url', json({ key: 'x' }));
    expect(res.status).toBe(401);
  });
});

describe('video: nunca por S3 firmado', () => {
  it.each([
    ['lessons/abc/video.mp4'],
    ['course-intros/abc/intro.webm'],
  ])('rechaza %s con 400 y explica por qué', async (key) => {
    const res = await askFor(key, adminToken);
    expect(res.status).toBe(400);
    const b = await body<{ error: { message: string } }>(res);
    expect(b.error.message).toContain('CloudFront');
  });

  it('el rechazo ocurre antes de mirar la base', async () => {
    // Una key de video que ADEMÁS no existe sigue dando 400, no 404: la regla
    // de costo se aplica primero, sin consultar nada.
    const res = await askFor('lessons/n/a.mp4', olToken);
    expect(res.status).toBe(400);
  });
});

describe('avatares', () => {
  let avatarKey = '';

  beforeAll(async () => {
    avatarKey = `avatars/${crypto.randomUUID()}.png`;
    await sql`update users set avatar_s3_key = ${avatarKey} where id = ${est1Id}`;
  });

  it('cualquier cuenta con sesión puede pedirlo: ya se ven en el directorio', async () => {
    for (const token of [est2Token, donorToken, companyToken, olToken]) {
      await expectAuthorized(await askFor(avatarKey, token));
    }
  });
});

describe('adjuntos de entregas', () => {
  let attachmentKey = '';

  beforeAll(async () => {
    // Entrega real del estudiante 1, con un adjunto.
    const created = await req(
      '/submissions',
      est1Token,
      json({
        courseId: seedId('crs_ia_1'),
        taskName: 'Adjunto de prueba',
        files: [
          {
            s3Key: `submissions/${crypto.randomUUID()}.pdf`,
            fileName: 'entrega.pdf',
            contentType: 'application/pdf',
            sizeBytes: 1024,
          },
        ],
      }),
    );
    expect(created.status).toBe(201);
    const sub = await body<{ files: { s3Key: string }[] }>(created);
    attachmentKey = sub.files[0]!.s3Key;
  });

  it('quien la entregó puede abrirla', async () => {
    await expectAuthorized(await askFor(attachmentKey, est1Token));
  });

  it('OTRO estudiante recibe 404, no 403', async () => {
    // 404 a propósito: confirmar que el archivo existe ya sería filtrar que
    // esa persona hizo esa entrega.
    const res = await askFor(attachmentKey, est2Token);
    expect(res.status).toBe(404);
  });

  it('el admin puede abrirla', async () => {
    await expectAuthorized(await askFor(attachmentKey, adminToken));
  });

  it('el mentor del laboratorio puede abrirla', async () => {
    await expectAuthorized(await askFor(attachmentKey, mentorToken));
  });

  it('la empresa NO puede: no ve entregas en ningún listado', async () => {
    const res = await askFor(attachmentKey, companyToken);
    expect(res.status).toBe(403);
  });

  it('el donante tampoco', async () => {
    expect((await askFor(attachmentKey, donorToken)).status).toBe(403);
  });

  it('el asesor de la misma universidad sí', async () => {
    await expectAuthorized(await askFor(attachmentKey, advisorToken));
  });
});

describe('evidencias de impacto', () => {
  let evidenceKey = '';

  beforeAll(async () => {
    evidenceKey = `evidences/${crypto.randomUUID()}.jpg`;
    const created = await req(
      '/evidences',
      adminToken,
      json({
        donorId: seedId('don1'),
        type: 'photo',
        title: 'Foto de prueba',
        s3Key: evidenceKey,
      }),
    );
    expect(created.status).toBe(201);
  });

  it('el donante dueño puede abrirla', async () => {
    await expectAuthorized(await askFor(evidenceKey, donorToken));
  });

  it('el admin puede abrirla', async () => {
    await expectAuthorized(await askFor(evidenceKey, adminToken));
  });

  it('un estudiante no: las evidencias no están en su portal', async () => {
    expect((await askFor(evidenceKey, est1Token)).status).toBe(403);
  });
});

describe('recursos de comunicaciones', () => {
  let resourceKey = '';

  beforeAll(async () => {
    resourceKey = `communication-resources/${crypto.randomUUID()}.pdf`;
    const created = await req(
      '/communication-resources',
      adminToken,
      json({
        title: 'Plantilla de prueba',
        type: 'file',
        fileName: 'plantilla.pdf',
        s3Key: resourceKey,
        contentType: 'application/pdf',
      }),
    );
    expect(created.status).toBe(201);
  });

  it('el equipo docente puede abrirlos', async () => {
    for (const token of [adminToken, mentorToken, advisorToken]) {
      await expectAuthorized(await askFor(resourceKey, token));
    }
  });

  it('un estudiante no', async () => {
    expect((await askFor(resourceKey, est1Token)).status).toBe(403);
  });

  it('una empresa tampoco', async () => {
    expect((await askFor(resourceKey, companyToken)).status).toBe(403);
  });
});

describe('recursos de lección', () => {
  let lessonResourceKey = '';

  beforeAll(async () => {
    lessonResourceKey = `lesson-resources/${crypto.randomUUID()}.pdf`;
    // Se cuelga de una lección del curso de IA, al que el estudiante 1 tiene
    // acceso por su laboratorio y el estudiante 3 no.
    await sql`
      update lessons set resource_s3_key = ${lessonResourceKey},
                         resource_file_name = 'guia.pdf'
       where id = ${seedId('lia3')}
    `;
  });

  it('un estudiante con acceso al curso puede abrirlo', async () => {
    await expectAuthorized(await askFor(lessonResourceKey, est1Token));
  });

  it('un Open Learning sin ese curso recibe 404', async () => {
    expect((await askFor(lessonResourceKey, olToken)).status).toBe(404);
  });

  it('un donante no abre material de curso', async () => {
    expect((await askFor(lessonResourceKey, donorToken)).status).toBe(403);
  });
});

describe('PATCH /auth/me y la foto de perfil', () => {
  it('acepta una key de avatar', async () => {
    const key = `avatars/${crypto.randomUUID()}.png`;
    const res = await req('/auth/me', est1Token, {
      ...json({ avatarS3Key: key }),
      method: 'PATCH',
    });
    expect(res.status).toBe(200);
    const b = await body<{ avatarS3Key: string }>(res);
    expect(b.avatarS3Key).toBe(key);
  });

  it('RECHAZA apuntar la foto a una key que no es de avatar', async () => {
    // Sin esta regla se podría apuntar el avatar al adjunto de otra persona y
    // leerlo por el visor de avatares, que es abierto a toda la plataforma.
    const res = await req('/auth/me', est1Token, {
      ...json({ avatarS3Key: 'submissions/de-otra-persona.pdf' }),
      method: 'PATCH',
    });
    expect(res.status).toBe(400);
  });

  it('sigue sin aceptar el rol ni los permisos de calificar', async () => {
    const res = await req('/auth/me', est1Token, {
      ...json({ role: 'admin', canGradeEnactus: true }),
      method: 'PATCH',
    });
    // Zod ignora las claves de más; lo que importa es que NO cambien.
    expect(res.status).toBe(200);
    const b = await body<{ role: string; canGradeEnactus: boolean }>(res);
    expect(b.role).toBe('student');
    expect(b.canGradeEnactus).toBe(false);
  });

  it('devuelve el equipo y el patrocinador del estudiante', async () => {
    const res = await req('/auth/me', est1Token);
    expect(res.status).toBe(200);
    const b = await body<{
      team: { groupId: string; projectName: string } | null;
      sponsorName: string | null;
    }>(res);
    expect(b.team).not.toBeNull();
    expect(b.team!.projectName).toBeTruthy();
    expect(b).toHaveProperty('sponsorName');
  });

  it('LOGIN y REFRESH devuelven la misma forma que GET /auth/me', async () => {
    // Si el login devolviera `publicUser` a secas, recién entrada la persona
    // a su portal el perfil se vería sin equipo ni proyecto hasta que algo
    // volviera a pedir /auth/me. Lo detectó la prueba de punta a punta.
    const login = await app.request(
      '/auth/login',
      json({ email: 'estudiante1@uniandes.edu.co', password: 'Est123' }),
    );
    const sesion = await body<{
      refreshToken: string;
      user: { team: unknown; sponsorName: unknown };
    }>(login);
    expect(sesion.user.team).not.toBeNull();
    expect(sesion.user).toHaveProperty('sponsorName');

    const renovada = await app.request(
      '/auth/refresh',
      json({ refreshToken: sesion.refreshToken }),
    );
    const b = await body<{ user: { team: unknown } }>(renovada);
    expect(b.user.team).not.toBeNull();
  });

  it('PATCH devuelve la MISMA forma que GET, con equipo incluido', async () => {
    // Si PATCH devolviera solo el usuario base, guardar el teléfono borraría
    // el equipo del modelo en el cliente y el perfil se quedaría sin proyecto
    // hasta recargar la página.
    const res = await req('/auth/me', est1Token, {
      ...json({ phone: '3001234567' }),
      method: 'PATCH',
    });
    expect(res.status).toBe(200);
    const b = await body<{
      phone: string;
      team: { projectName: string } | null;
    }>(res);
    expect(b.phone).toBe('3001234567');
    expect(b.team).not.toBeNull();
  });

  it('a un rol sin equipo no le agrega campos que no le corresponden', async () => {
    const res = await req('/auth/me', mentorToken);
    const b = await body<Record<string, unknown>>(res);
    expect(b).not.toHaveProperty('team');
    expect(b).not.toHaveProperty('sponsorName');
  });
});
