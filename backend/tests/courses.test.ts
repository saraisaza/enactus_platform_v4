import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { MAX_VIDEO_BYTES } from '../src/lib/s3';
import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Grupo 1 de la Fase 4: CRUD de cursos, módulos y lecciones.
 *
 * Todo va contra la base sembrada, a través de la aplicación completa.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

const LXD = ['lxd.ia@enactus.co', 'Lxd123'] as const;
const OTRO_LXD = ['lxd.agua@enactus.co', 'Lxd123'] as const;
const ADMIN = ['admin@enactus.co', 'Admin123'] as const;
const ESTUDIANTE = ['estudiante1@uniandes.edu.co', 'Est123'] as const;

let lxdToken = '';
let otroLxdToken = '';
let adminToken = '';
let estudianteToken = '';

const req = async (
  path: string,
  token: string,
  init: RequestInit = {},
): Promise<Response> =>
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

  lxdToken = (await login(app, ...LXD)).accessToken;
  otroLxdToken = (await login(app, ...OTRO_LXD)).accessToken;
  adminToken = (await login(app, ...ADMIN)).accessToken;
  estudianteToken = (await login(app, ...ESTUDIANTE)).accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

// ---------------------------------------------------------------------------

describe('permisos de creación', () => {
  it('un estudiante recibe 403 al crear un curso', async () => {
    const res = await req('/courses', estudianteToken, {
      ...json({ name: 'Curso pirata' }),
    });
    expect(res.status).toBe(403);
    const b = await body<{ error: { code: string } }>(res);
    expect(b.error.code).toBe('forbidden');
  });

  it('sin sesión recibe 401', async () => {
    const res = await app.request('/courses', json({ name: 'X' }));
    expect(res.status).toBe(401);
  });

  it('un LXD puede crear, y el curso nace en borrador', async () => {
    const res = await req('/courses', lxdToken, {
      ...json({ name: 'Curso nuevo de prueba', description: 'Creado en el test' }),
    });
    expect(res.status).toBe(201);
    const course = await body<{ id: string; status: string; creatorId: string }>(res);
    expect(course.status).toBe('draft');
    expect(course.creatorId).toBe(seedId('lxd1'));
  });
});

describe('ciclo completo de autoría: curso → módulo → lección → publicar', () => {
  let courseId = '';
  let moduleId = '';

  it('crea el curso', async () => {
    const res = await req('/courses', lxdToken, {
      ...json({ name: 'Curso ciclo completo', estimatedHours: 4 }),
    });
    expect(res.status).toBe(201);
    courseId = (await body<{ id: string }>(res)).id;
  });

  it('lo edita', async () => {
    const res = await req(`/courses/${courseId}`, lxdToken, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ subtitle: 'Con subtítulo' }),
    });
    expect(res.status).toBe(200);
    expect((await body<{ subtitle: string }>(res)).subtitle).toBe('Con subtítulo');
  });

  it('un LXD distinto NO puede editarlo', async () => {
    const res = await req(`/courses/${courseId}`, otroLxdToken, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ subtitle: 'Ajeno' }),
    });
    expect(res.status).toBe(403);
  });

  it('no se puede publicar sin lecciones', async () => {
    const res = await req(`/courses/${courseId}/publish`, lxdToken, {
      method: 'POST',
    });
    expect(res.status).toBe(409);
    const b = await body<{ error: { message: string } }>(res);
    expect(b.error.message).toContain('sin lecciones');
  });

  it('agrega un módulo', async () => {
    const res = await req(`/courses/${courseId}/modules`, lxdToken, {
      ...json({ title: 'Módulo 1' }),
    });
    expect(res.status).toBe(201);
    const mod = await body<{ id: string; orderIndex: number }>(res);
    expect(mod.orderIndex).toBe(1);
    moduleId = mod.id;
  });

  it('agrega una lección de video externo', async () => {
    const creada = await req(`/modules/${moduleId}/lessons`, lxdToken, {
      ...json({ title: 'Intro en YouTube', type: 'video' }),
    });
    expect(creada.status).toBe(201);
    const lesson = await body<{ id: string }>(creada);

    const res = await req(`/lessons/${lesson.id}/video-external`, lxdToken, {
      ...json({ url: 'https://www.youtube.com/watch?v=abc123' }),
    });
    expect(res.status).toBe(200);
    const actualizada = await body<{
      videoType: string;
      videoUrl: string;
      videoS3Key: string | null;
    }>(res);
    expect(actualizada.videoType).toBe('external');
    expect(actualizada.videoUrl).toContain('youtube.com');
    expect(actualizada.videoS3Key).toBeNull();
  });

  it('no se puede publicar con una lección de video sin origen', async () => {
    const creada = await req(`/modules/${moduleId}/lessons`, lxdToken, {
      ...json({ title: 'Video pendiente de subir', type: 'video' }),
    });
    const lesson = await body<{ id: string }>(creada);

    const res = await req(`/courses/${courseId}/publish`, lxdToken, {
      method: 'POST',
    });
    expect(res.status).toBe(409);
    const b = await body<{ error: { message: string; details: { lessons: unknown[] } } }>(res);
    expect(b.error.message).toContain('sin enlace ni archivo');
    expect(b.error.details.lessons).toHaveLength(1);

    // Se completa con un archivo propio y ya se puede publicar.
    await req(`/lessons/${lesson.id}/video`, lxdToken, {
      ...json({
        key: `lessons/${lesson.id}/archivo.mp4`,
        sizeBytes: 50 * 1024 * 1024,
        mimeType: 'video/mp4',
        durationSec: 600,
      }),
    });
  });

  it('publica el curso', async () => {
    const res = await req(`/courses/${courseId}/publish`, lxdToken, {
      method: 'POST',
    });
    expect(res.status).toBe(200);
    expect((await body<{ status: string }>(res)).status).toBe('published');
  });

  it('el curso publicado trae sus módulos y lecciones con include', async () => {
    const res = await req(
      `/courses/${courseId}?include=modules,lessons`,
      lxdToken,
    );
    expect(res.status).toBe(200);
    const course = await body<{
      modules: { title: string; lessons: { title: string }[] }[];
    }>(res);
    expect(course.modules).toHaveLength(1);
    expect(course.modules[0]?.lessons).toHaveLength(2);
  });
});

describe('visibilidad para estudiantes', () => {
  it('un curso NO publicado no aparece en el listado del estudiante', async () => {
    // El LXD crea un borrador en el laboratorio de la estudiante.
    const creado = await req('/courses', lxdToken, {
      ...json({ name: 'Borrador invisible', laboratoryId: seedId('lab_ia') }),
    });
    const draft = await body<{ id: string }>(creado);

    const listado = await req('/courses?pageSize=100', estudianteToken);
    const page = await body<{ data: { id: string }[] }>(listado);
    expect(page.data.map((c) => c.id)).not.toContain(draft.id);

    // Y pedirlo directo por id tampoco lo revela.
    const directo = await req(`/courses/${draft.id}`, estudianteToken);
    expect(directo.status).toBe(404);

    // Al LXD que lo creó sí le aparece: necesita ver sus borradores.
    const delLxd = await req('/courses?status=draft&pageSize=100', lxdToken);
    const pageLxd = await body<{ data: { id: string }[] }>(delLxd);
    expect(pageLxd.data.map((c) => c.id)).toContain(draft.id);
  });

  it('la estudiante ve los cursos publicados de sus laboratorios', async () => {
    const res = await req('/courses?pageSize=100', estudianteToken);
    expect(res.status).toBe(200);
    const page = await body<{ data: { id: string }[]; total: number }>(res);
    const ids = page.data.map((c) => c.id);
    expect(ids).toContain(seedId('crs_ia_1'));
    expect(ids).toContain(seedId('crs_impacto_1'));
    // Y no ve los de laboratorios ajenos.
    expect(ids).not.toContain(seedId('crs_agua_1'));
  });

  it('la estudiante de Open Learning solo ve su curso asignado', async () => {
    const { accessToken } = await login(app, 'camila.rivas@gmail.com', 'Est123');
    const res = await req('/courses?pageSize=100', accessToken);
    const page = await body<{ data: { id: string }[] }>(res);
    expect(page.data.map((c) => c.id)).toEqual([seedId('crs_ol_marketing')]);
  });

  it('el listado viene paginado', async () => {
    const res = await req('/courses?page=1&pageSize=2', adminToken);
    const page = await body<{
      data: unknown[];
      page: number;
      pageSize: number;
      total: number;
      totalPages: number;
    }>(res);
    expect(page.data).toHaveLength(2);
    expect(page.page).toBe(1);
    expect(page.total).toBeGreaterThan(2);
    expect(page.totalPages).toBe(Math.ceil(page.total / 2));
  });
});

describe('reordenamiento', () => {
  let courseId = '';
  let moduleIds: string[] = [];

  beforeAll(async () => {
    const creado = await req('/courses', lxdToken, {
      ...json({ name: 'Curso para reordenar' }),
    });
    courseId = (await body<{ id: string }>(creado)).id;

    moduleIds = [];
    for (const title of ['Primero', 'Segundo', 'Tercero']) {
      const res = await req(`/courses/${courseId}/modules`, lxdToken, {
        ...json({ title }),
      });
      moduleIds.push((await body<{ id: string }>(res)).id);
    }
  });

  it('el orden inicial es el de creación', async () => {
    const res = await req(`/courses/${courseId}?include=modules`, lxdToken);
    const course = await body<{ modules: { title: string }[] }>(res);
    expect(course.modules.map((m) => m.title)).toEqual([
      'Primero',
      'Segundo',
      'Tercero',
    ]);
  });

  it('el reordenamiento persiste', async () => {
    const invertido = [moduleIds[2]!, moduleIds[0]!, moduleIds[1]!];
    const res = await req(`/courses/${courseId}/modules/order`, lxdToken, {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ orderedIds: invertido }),
    });
    expect(res.status).toBe(200);

    // Se vuelve a pedir desde cero: el orden tiene que venir de la base, no
    // de la respuesta que acabamos de recibir.
    const relectura = await req(`/courses/${courseId}?include=modules`, lxdToken);
    const course = await body<{ modules: { id: string; title: string; orderIndex: number }[] }>(
      relectura,
    );
    expect(course.modules.map((m) => m.title)).toEqual([
      'Tercero',
      'Primero',
      'Segundo',
    ]);
    expect(course.modules.map((m) => m.orderIndex)).toEqual([1, 2, 3]);
  });

  it('rechaza una lista incompleta en vez de dejar el orden a medias', async () => {
    const res = await req(`/courses/${courseId}/modules/order`, lxdToken, {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ orderedIds: [moduleIds[0]!] }),
    });
    expect(res.status).toBe(409);
    const b = await body<{ error: { details: { missing: string[] } } }>(res);
    expect(b.error.details.missing).toHaveLength(2);
  });

  it('reordena lecciones dentro de un módulo', async () => {
    const modId = moduleIds[0]!;
    const ids: string[] = [];
    for (const title of ['Lección A', 'Lección B', 'Lección C']) {
      const res = await req(`/modules/${modId}/lessons`, lxdToken, {
        ...json({ title, type: 'pdf' }),
      });
      ids.push((await body<{ id: string }>(res)).id);
    }

    const res = await req(`/modules/${modId}/lessons/order`, lxdToken, {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ orderedIds: [ids[1]!, ids[2]!, ids[0]!] }),
    });
    expect(res.status).toBe(200);

    const relectura = await req(`/courses/${courseId}?include=modules,lessons`, lxdToken);
    const course = await body<{
      modules: { id: string; lessons: { title: string }[] }[];
    }>(relectura);
    const mod = course.modules.find((m) => m.id === modId);
    expect(mod?.lessons.map((l) => l.title)).toEqual([
      'Lección B',
      'Lección C',
      'Lección A',
    ]);
  });
});

describe('URL de subida de video', () => {
  let lessonId = '';

  beforeAll(async () => {
    const curso = await req('/courses', lxdToken, {
      ...json({ name: 'Curso con video' }),
    });
    const courseId = (await body<{ id: string }>(curso)).id;
    const mod = await req(`/courses/${courseId}/modules`, lxdToken, {
      ...json({ title: 'Módulo' }),
    });
    const moduleId = (await body<{ id: string }>(mod)).id;
    const lesson = await req(`/modules/${moduleId}/lessons`, lxdToken, {
      ...json({ title: 'Video propio', type: 'video' }),
    });
    lessonId = (await body<{ id: string }>(lesson)).id;
  });

  it('rechaza un content-type no permitido con 400', async () => {
    const res = await req(`/lessons/${lessonId}/video-upload-url`, lxdToken, {
      ...json({ contentType: 'video/quicktime', sizeBytes: 1024 }),
    });
    expect(res.status).toBe(400);
    const b = await body<{ error: { code: string; message: string } }>(res);
    expect(b.error.code).toBe('bad_request');
    expect(b.error.message).toContain('video/mp4');
  });

  it('rechaza un archivo de más de 500 MB con 413', async () => {
    const res = await req(`/lessons/${lessonId}/video-upload-url`, lxdToken, {
      ...json({ contentType: 'video/mp4', sizeBytes: MAX_VIDEO_BYTES + 1 }),
    });
    expect(res.status).toBe(413);
    const b = await body<{ error: { code: string } }>(res);
    expect(b.error.code).toBe('payload_too_large');
  });

  it('un estudiante recibe 403 al pedir una URL de subida', async () => {
    const res = await req(`/lessons/${lessonId}/video-upload-url`, estudianteToken, {
      ...json({ contentType: 'video/mp4', sizeBytes: 1024 }),
    });
    expect(res.status).toBe(403);
  });

  it('con datos válidos llega hasta la firma (503 sin S3 configurado)', async () => {
    // En local no hay bucket. Lo que se comprueba acá es que la validación
    // pasó y el fallo es de CONFIGURACIÓN, no de datos — y que se dice qué
    // falta en vez de devolver una URL falsa.
    const res = await req(`/lessons/${lessonId}/video-upload-url`, lxdToken, {
      ...json({ contentType: 'video/mp4', sizeBytes: 10 * 1024 * 1024 }),
    });
    expect(res.status).toBe(503);
    const b = await body<{ error: { code: string; message: string } }>(res);
    expect(b.error.code).toBe('storage_not_configured');
    expect(b.error.message).toContain('S3_BUCKET');
  });

  it('la confirmación rechaza una key que no es de esta lección', async () => {
    const res = await req(`/lessons/${lessonId}/video`, lxdToken, {
      ...json({
        key: 'lessons/otra-leccion/archivo.mp4',
        sizeBytes: 1024,
        mimeType: 'video/mp4',
      }),
    });
    expect(res.status).toBe(409);
  });

  it('la confirmación válida deja la lección apuntando al archivo', async () => {
    const key = `lessons/${lessonId}/video.mp4`;
    const res = await req(`/lessons/${lessonId}/video`, lxdToken, {
      ...json({ key, sizeBytes: 104857600, mimeType: 'video/mp4', durationSec: 900 }),
    });
    expect(res.status).toBe(200);
    const lesson = await body<{
      videoType: string;
      videoS3Key: string;
      videoUrl: string | null;
      videoSizeBytes: number;
    }>(res);
    expect(lesson.videoType).toBe('uploaded');
    expect(lesson.videoS3Key).toBe(key);
    expect(lesson.videoUrl).toBeNull();
    expect(lesson.videoSizeBytes).toBe(104857600);
  });
});

describe('borrado con la regla de la decisión B.7', () => {
  it('un curso con progreso de estudiantes NO se borra: 409 y sugiere archivar', async () => {
    const res = await req(`/courses/${seedId('crs_ia_1')}`, adminToken, {
      method: 'DELETE',
    });
    expect(res.status).toBe(409);
    const b = await body<{
      error: {
        message: string;
        details: {
          rutaModules: number;
          objectives: number;
          studentsWithProgress: number;
          suggestedAction: string;
        };
      };
    }>(res);
    expect(b.error.details.studentsWithProgress).toBeGreaterThan(0);
    expect(b.error.details.rutaModules).toBeGreaterThan(0);
    expect(b.error.details.objectives).toBeGreaterThan(0);
    expect(b.error.details.suggestedAction).toContain('archive');

    // Y sigue existiendo.
    const sigue = await req(`/courses/${seedId('crs_ia_1')}`, adminToken);
    expect(sigue.status).toBe(200);
  });

  it('archivarlo sí funciona y lo saca del alcance del estudiante', async () => {
    const antes = await req('/courses?pageSize=100', estudianteToken);
    const idsAntes = (await body<{ data: { id: string }[] }>(antes)).data.map((c) => c.id);
    expect(idsAntes).toContain(seedId('crs_impacto_1'));

    const res = await req(`/courses/${seedId('crs_impacto_1')}/archive`, adminToken, {
      method: 'POST',
    });
    expect(res.status).toBe(200);
    expect((await body<{ status: string }>(res)).status).toBe('archived');

    const despues = await req('/courses?pageSize=100', estudianteToken);
    const idsDespues = (await body<{ data: { id: string }[] }>(despues)).data.map((c) => c.id);
    expect(idsDespues).not.toContain(seedId('crs_impacto_1'));
  });

  it('un curso sin nada colgando sí se borra, y el borrado es lógico', async () => {
    const creado = await req('/courses', lxdToken, {
      ...json({ name: 'Curso descartable' }),
    });
    const { id } = await body<{ id: string }>(creado);

    const res = await req(`/courses/${id}`, lxdToken, { method: 'DELETE' });
    expect(res.status).toBe(204);

    const despues = await req(`/courses/${id}`, lxdToken);
    expect(despues.status).toBe(404);

    // La fila sigue en la base con `deleted_at`, no se borró físicamente.
    const [row] = await sql<{ deleted_at: string | null }[]>`
      select deleted_at from courses where id = ${id}
    `;
    expect(row?.deleted_at).not.toBeNull();
  });
});
