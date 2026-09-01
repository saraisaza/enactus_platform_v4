import { createVerify, generateKeyPairSync } from 'node:crypto';

import type { Sql } from 'postgres';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import {
  VIDEO_URL_TTL_SECONDS,
  cloudFrontConfig,
  signCloudFrontUrl,
} from '../src/lib/cloudfront';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Reproducción de video propio: `GET /lessons/:id/video-url` y
 * `GET /courses/:id/intro-video-url`.
 *
 * Un video subido NUNCA se sirve con URL firmada de S3 —lo impide
 * `assertNotVideo`, y `files.test.ts` lo comprueba— así que este es el único
 * camino para verlo. Se prueban las dos mitades por separado, porque fallan
 * por razones distintas:
 *
 * - **La firma** es código propio (canned policy + RSA-SHA1), no de la SDK de
 *   AWS. Por eso no alcanza con mirar la forma de la URL: se genera un par de
 *   llaves en la propia prueba y se VERIFICA la firma contra la pública. Si la
 *   política cambiara un espacio, CloudFront respondería 403 y acá se ve.
 *
 * - **La autorización** es lo que decide quién puede pedirla. Igual que en
 *   `files.test.ts`, el caso concedido acepta 200 o el 503 de un entorno sin
 *   CloudFront configurado (la suite tiene que correr sin infraestructura),
 *   pero los casos denegados son estrictos: nunca un 200 a quien no.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

let est1Token = ''; // lab_ia + lab_impacto
let est3Token = ''; // lab_agua + lab_agricultura
let olToken = ''; // Open Learning
let lxdToken = '';
let adminToken = '';

const req = (path: string, token: string) =>
  app.request(path, { headers: auth(token) });

const body = async <T>(res: Response): Promise<T> => (await res.json()) as T;

/**
 * El permiso se CONCEDIÓ: 200 con la URL, o el 503 de un entorno sin CDN.
 * Lo que nunca puede ser es 403 ni 404 — eso significaría que la autorización
 * falló, que es lo que se está probando.
 */
async function expectAutorizado(res: Response): Promise<void> {
  if (res.status === 503) {
    const b = await body<{ error: { code: string; message: string } }>(res);
    expect(b.error.code).toBe('cdn_not_configured');
    // El 503 tiene que decir QUÉ falta, no solo que no anda.
    expect(b.error.message).toMatch(/CLOUDFRONT_/);
    return;
  }
  expect(res.status).toBe(200);
  const b = await body<{ url: string; expiresInSeconds: number }>(res);
  expect(b.url).toContain('Signature=');
  expect(b.url).toContain('Key-Pair-Id=');
  expect(b.expiresInSeconds).toBe(VIDEO_URL_TTL_SECONDS);
}

beforeAll(async () => {
  const t = makeTestApp();
  app = t.app;
  sql = t.sql;
  await seedTestDatabase();

  est1Token = (await login(app, 'estudiante1@uniandes.edu.co', 'Est123'))
    .accessToken;
  est3Token = (await login(app, 'estudiante3@unal.edu.co', 'Est123'))
    .accessToken;
  olToken = (await login(app, 'camila.rivas@gmail.com', 'Est123')).accessToken;
  lxdToken = (await login(app, 'lxd.ia@enactus.co', 'Lxd123')).accessToken;
  adminToken = (await login(app, 'admin@enactus.co', 'Admin123')).accessToken;
});

afterAll(async () => {
  await sql.end();
});

// ---------------------------------------------------------------------------
// La firma, contra un par de llaves de verdad
// ---------------------------------------------------------------------------

describe('firma de CloudFront (canned policy)', () => {
  // Generado en cada corrida: una llave de firma no se guarda en el repo ni
  // siquiera de ejemplo, y una generada acá prueba exactamente lo mismo.
  const { privateKey, publicKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
  });

  const config = {
    domain: 'videos.enactus.co',
    keyPairId: 'K2JEMPLO123',
    privateKey: privateKey.export({ type: 'pkcs1', format: 'pem' }).toString(),
  };

  const key = 'lessons/abc-123/video.mp4';
  const expires = 1893456000; // 2030-01-01, fijo para que la prueba no dependa del reloj

  it('arma la URL con los tres parámetros que CloudFront exige', () => {
    const url = signCloudFrontUrl(config, {
      key,
      expiresAtEpochSeconds: expires,
    });
    const parsed = new URL(url);

    expect(parsed.protocol).toBe('https:');
    expect(parsed.host).toBe('videos.enactus.co');
    expect(parsed.pathname).toBe('/lessons/abc-123/video.mp4');
    expect(parsed.searchParams.get('Expires')).toBe(String(expires));
    expect(parsed.searchParams.get('Key-Pair-Id')).toBe('K2JEMPLO123');
    expect(parsed.searchParams.get('Signature')).toBeTruthy();
  });

  it('la firma VERIFICA contra la llave pública', () => {
    const url = signCloudFrontUrl(config, {
      key,
      expiresAtEpochSeconds: expires,
    });
    const signature = new URL(url).searchParams.get('Signature')!;

    // Se reconstruye la política EXACTAMENTE como la firma CloudFront. Si el
    // servidor armara otra cadena —un espacio, otro orden— esto falla, que es
    // justo el fallo que en producción se ve como un 403 opaco del CDN.
    const resource = 'https://videos.enactus.co/lessons/abc-123/video.mp4';
    const policy =
      `{"Statement":[{"Resource":"${resource}",` +
      `"Condition":{"DateLessThan":{"AWS:EpochTime":${expires}}}}]}`;

    const crudo = Buffer.from(
      signature.replace(/-/g, '+').replace(/_/g, '=').replace(/~/g, '/'),
      'base64',
    );

    const ok = createVerify('RSA-SHA1').update(policy).verify(publicKey, crudo);
    expect(ok).toBe(true);
  });

  it('no altera la firma si la política cambia', () => {
    const url = signCloudFrontUrl(config, {
      key,
      expiresAtEpochSeconds: expires,
    });
    const otra = signCloudFrontUrl(config, {
      key,
      expiresAtEpochSeconds: expires + 1,
    });
    // Un segundo de diferencia cambia la política y por lo tanto la firma: si
    // fueran iguales, la firma no estaría cubriendo el vencimiento y una URL
    // vencida se podría reusar cambiando `Expires` a mano.
    expect(new URL(url).searchParams.get('Signature')).not.toBe(
      new URL(otra).searchParams.get('Signature'),
    );
  });

  it('usa el alfabeto base64 de CloudFront, no el estándar', () => {
    // CloudFront define su propio reemplazo (`+`→`-`, `=`→`_`, `/`→`~`). Con
    // el base64 estándar, los caracteres reservados de la query rompen la
    // firma al llegar al CDN.
    for (let i = 0; i < 20; i++) {
      const url = signCloudFrontUrl(config, {
        key,
        expiresAtEpochSeconds: expires + i,
      });
      const firma = new URL(url).searchParams.get('Signature')!;
      expect(firma).not.toMatch(/[+=/]/);
    }
  });

  it('codifica cada segmento de la key por separado', () => {
    const url = signCloudFrontUrl(config, {
      key: 'lessons/con espacio/año 1.mp4',
      expiresAtEpochSeconds: expires,
    });
    // Las barras siguen siendo separadores de ruta; lo demás va codificado.
    expect(new URL(url).pathname).toBe(
      '/lessons/con%20espacio/a%C3%B1o%201.mp4',
    );
  });

  it('la vigencia es corta', () => {
    // Una URL firmada es un permiso que viaja suelto, sin sesión. Cinco
    // minutos alcanzan: CloudFront valida al abrir la conexión, no durante la
    // reproducción.
    expect(VIDEO_URL_TTL_SECONDS).toBeLessThanOrEqual(300);
  });
});

// ---------------------------------------------------------------------------
// Quién puede pedirla
// ---------------------------------------------------------------------------

describe('GET /lessons/:id/video-url', () => {
  it('sin sesión no se firma nada', async () => {
    const res = await app.request(`/lessons/${seedId('lia1')}/video-url`);
    expect(res.status).toBe(401);
  });

  it('la estudiante del laboratorio sí puede ver su lección', async () => {
    const res = await req(`/lessons/${seedId('lia1')}/video-url`, est1Token);
    await expectAutorizado(res);
  });

  it('el LXD que creó el curso también', async () => {
    const res = await req(`/lessons/${seedId('lia1')}/video-url`, lxdToken);
    await expectAutorizado(res);
  });

  it('el admin también', async () => {
    const res = await req(`/lessons/${seedId('lia1')}/video-url`, adminToken);
    await expectAutorizado(res);
  });

  it('una estudiante de OTRO laboratorio recibe 404, no 403', async () => {
    // 404 y no 403 a propósito: un 403 confirmaría que esa lección existe.
    const res = await req(`/lessons/${seedId('lia1')}/video-url`, est3Token);
    expect(res.status).toBe(404);
  });

  it('la de Open Learning no llega al video de un laboratorio', async () => {
    const res = await req(`/lessons/${seedId('lia1')}/video-url`, olToken);
    expect(res.status).toBe(404);
  });

  it('y una Enactus no llega al de Open Learning', async () => {
    const res = await req(`/lessons/${seedId('lol1')}/video-url`, est1Token);
    expect(res.status).toBe(404);
  });

  it('la de Open Learning sí ve el suyo', async () => {
    const res = await req(`/lessons/${seedId('lol1')}/video-url`, olToken);
    await expectAutorizado(res);
  });

  it('una lección sin video responde 409, no una URL vacía', async () => {
    // `lol2` es un PDF. Devolver una URL igual dejaría al reproductor
    // cargando para siempre sin decir por qué.
    const res = await req(`/lessons/${seedId('lol2')}/video-url`, olToken);
    expect(res.status).toBe(409);
  });

  it('una lección inexistente da 404', async () => {
    const res = await req(
      '/lessons/00000000-0000-4000-8000-000000000000/video-url',
      adminToken,
    );
    expect(res.status).toBe(404);
  });

  it('un id MAL FORMADO da 404, no un 500', async () => {
    // Antes esto llegaba hasta PostgreSQL y volvía como «error inesperado»:
    // código equivocado y ruido en el log, que es donde se miran los
    // problemas de verdad. Vale para cualquier ruta con id, no solo esta.
    const res = await req('/lessons/no-es-un-uuid/video-url', adminToken);
    expect(res.status).toBe(404);
    const b = await body<{ error: { code: string } }>(res);
    expect(b.error.code).toBe('not_found');
  });

  it('un video EXTERNO responde 409 y explica que va por su propia URL', async () => {
    // Se construye por la API, como lo haría un LXD: el seed no trae ninguno.
    const curso = await body<{ id: string }>(
      await app.request('/courses', {
        ...json({
          name: 'Curso con video externo',
          description: 'Para probar la reproducción',
          level: 'basic',
          language: 'es',
        }),
        headers: { ...auth(lxdToken), 'content-type': 'application/json' },
      }),
    );
    const modulo = await body<{ id: string }>(
      await app.request(`/courses/${curso.id}/modules`, {
        ...json({ title: 'Módulo 1' }),
        headers: { ...auth(lxdToken), 'content-type': 'application/json' },
      }),
    );
    const leccion = await body<{ id: string }>(
      await app.request(`/modules/${modulo.id}/lessons`, {
        ...json({ title: 'Lección externa', type: 'video' }),
        headers: { ...auth(lxdToken), 'content-type': 'application/json' },
      }),
    );
    const externo = await app.request(`/lessons/${leccion.id}/video-external`, {
      ...json({ url: 'https://www.youtube.com/watch?v=ejemplo' }),
      headers: { ...auth(lxdToken), 'content-type': 'application/json' },
    });
    expect(externo.status).toBe(200);

    const res = await req(`/lessons/${leccion.id}/video-url`, lxdToken);
    expect(res.status).toBe(409);
    const b = await body<{ error: { message: string } }>(res);
    expect(b.error.message).toContain('externo');
  });
});

describe('GET /courses/:id/intro-video-url', () => {
  it('no lo captura la ruta de detalle del curso', async () => {
    // `GET /courses/:id` está registrado después a propósito: si estuviera
    // antes, `/:id` capturaría también este camino y el endpoint sería
    // inalcanzable sin que nada fallara.
    const res = await req(
      `/courses/${seedId('crs_ia_1')}/intro-video-url`,
      est1Token,
    );
    expect([200, 409, 503]).toContain(res.status);
  });

  it('una estudiante fuera del alcance recibe 404', async () => {
    const res = await req(
      `/courses/${seedId('crs_ia_1')}/intro-video-url`,
      est3Token,
    );
    expect(res.status).toBe(404);
  });
});

describe('coherencia con el resto de la API', () => {
  it('la misma key sigue rechazada por /files/download-url', async () => {
    // Las dos reglas tienen que apuntar al mismo lado: el video se sirve por
    // CloudFront y SOLO por CloudFront.
    //
    // Esta key NO empieza por `lessons/` —el seed usa
    // `lab_ia_tecnologia/curso_intro_ia/leccion_1.mp4`— así que el rechazo por
    // prefijo no la atrapa. Antes caía en 404 (por suerte: ninguna tabla la
    // referenciaba en la búsqueda de lecturas), no por la regla. Ahora la
    // regla se aplica mirando la fila, que es el criterio de todo este
    // archivo.
    const [fila] = await sql<{ key: string }[]>`
      select video_s3_key as key from lessons
       where id = ${seedId('lia1')}
    `;
    expect(fila!.key).toBeTruthy();
    expect(fila!.key.startsWith('lessons/')).toBe(false);

    const res = await app.request('/files/download-url', {
      ...json({ key: fila!.key }),
      headers: { ...auth(adminToken), 'content-type': 'application/json' },
    });
    expect(res.status).toBe(400);
    const b = await body<{ error: { message: string } }>(res);
    expect(b.error.message).toContain('CloudFront');
  });

  it('el video de intro de un curso también, con cualquier nombre de key', async () => {
    const [fila] = await sql<{ key: string | null }[]>`
      select intro_video_s3_key as key from courses
       where intro_video_s3_key is not null and deleted_at is null
       limit 1
    `;
    if (!fila?.key) return; // el seed puede no traer ninguno

    const res = await app.request('/files/download-url', {
      ...json({ key: fila.key }),
      headers: { ...auth(adminToken), 'content-type': 'application/json' },
    });
    expect(res.status).toBe(400);
  });

  it('sin configuración, `cloudFrontConfig()` no inventa una parcial', () => {
    // Con dominio pero sin llave no se puede firmar, y devolver una URL sin
    // firma da un 403 del CDN que en el cliente se ve como "no carga".
    const config = cloudFrontConfig();
    if (config !== null) {
      expect(config.domain).not.toBe('');
      expect(config.keyPairId).not.toBe('');
      expect(config.privateKey).not.toBe('');
    }
  });
});
