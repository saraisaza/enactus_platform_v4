import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/** Grupo 4 de la Fase 4: el resto de las entidades. */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

const T: Record<string, string> = {};

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

  const creds: [string, string, string][] = [
    ['admin', 'admin@enactus.co', 'Admin123'],
    ['superadmin', 'superadmin1@enactus.co', 'Super123'],
    ['advisor', 'asesor@uniandes.edu.co', 'Asesor123'],
    ['lxd', 'lxd.ia@enactus.co', 'Lxd123'],
    ['lxdSinPermiso', 'lxd.agua@enactus.co', 'Lxd123'],
    ['mentor', 'mentor.ia@enactus.co', 'Mentor123'],
    ['donor', 'donante@gmail.com', 'Donante123'],
    ['company', 'empresa@bancolombia.com', 'Empresa123'],
    ['student', 'estudiante1@uniandes.edu.co', 'Est123'],
    ['otroStudent', 'estudiante3@unal.edu.co', 'Est123'],
  ];
  for (const [key, email, password] of creds) {
    T[key] = (await login(app, email, password)).accessToken;
  }
}, 120_000);

beforeEach(() => resetRateLimits());
afterAll(async () => { await sql.end(); });

describe('/projects', () => {
  it('el admin crea, el asesor edita, el estudiante no puede ninguna', async () => {
    const creado = await req('/projects', T.admin!, {
      ...json({ name: 'Proyecto nuevo', stage: 'ideation', ods: ['ods_1'] }),
    });
    expect(creado.status).toBe(201);
    const { id } = await body<{ id: string }>(creado);

    const editado = await req(`/projects/${id}`, T.advisor!, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ stage: 'pilot' }),
    });
    expect(editado.status).toBe(200);
    expect((await body<{ stage: string }>(editado)).stage).toBe('pilot');

    // El asesor NO crea (decisión C.4).
    const creaAsesor = await req('/projects', T.advisor!, {
      ...json({ name: 'Del asesor' }),
    });
    expect(creaAsesor.status).toBe(403);

    const editaEstudiante = await req(`/projects/${id}`, T.student!, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ stage: 'scaling' }),
    });
    expect(editaEstudiante.status).toBe(403);
  });

  it('el detalle trae el equipo con el rol de cada integrante', async () => {
    const res = await req(`/projects/${seedId('prj1')}`, T.student!);
    expect(res.status).toBe(200);
    const p = await body<{
      ods: string[];
      team: { name: string; role_in_project: string }[];
    }>(res);
    expect(p.ods).toContain('ods_6');
    expect(p.team).toHaveLength(3);
    expect(p.team.map((m) => m.role_in_project)).toContain('leader');
  });
});

describe('/groups', () => {
  it('reemplaza los integrantes con su rol en una sola llamada', async () => {
    const res = await req(`/groups/${seedId('grp2')}/members`, T.admin!, {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        members: [
          { userId: seedId('est3'), roleInProject: 'communications' },
          { userId: seedId('est4'), roleInProject: 'leader' },
        ],
      }),
    });
    expect(res.status).toBe(200);

    const detalle = await req(`/groups/${seedId('grp2')}`, T.admin!);
    const g = await body<{ members: { user_id: string; role_in_project: string }[] }>(detalle);
    const est3 = g.members.find((m) => m.user_id === seedId('est3'));
    expect(est3?.role_in_project).toBe('communications');
  });

  it('un estudiante no puede cambiar los integrantes', async () => {
    const res = await req(`/groups/${seedId('grp1')}/members`, T.student!, {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ members: [] }),
    });
    expect(res.status).toBe(403);
  });
});

describe('/evidences', () => {
  it('el donante ve SOLO las suyas, y no las de otro donante', async () => {
    const res = await req('/evidences?pageSize=50', T.donor!);
    expect(res.status).toBe(200);
    const page = await body<{ data: { donorId: string }[] }>(res);
    expect(page.data.length).toBeGreaterThan(0);
    expect(page.data.every((e) => e.donorId === seedId('don1'))).toBe(true);

    // Pedir explícitamente las de otro donante no cambia nada: el filtro es
    // del servidor, no del parámetro.
    const otro = await req(`/evidences?donorId=${seedId('adm1')}`, T.donor!);
    const pageOtro = await body<{ data: { donorId: string }[] }>(otro);
    expect(pageOtro.data.every((e) => e.donorId === seedId('don1'))).toBe(true);
  });

  it('trae el proyecto asociado (la columna que faltaba)', async () => {
    const res = await req(`/evidences?projectId=${seedId('prj1')}`, T.donor!);
    const page = await body<{ data: { projectId: string }[] }>(res);
    expect(page.data.length).toBe(2);
    expect(page.data.every((e) => e.projectId === seedId('prj1'))).toBe(true);
  });

  it('solo el admin las crea', async () => {
    const delDonante = await req('/evidences', T.donor!, {
      ...json({ donorId: seedId('don1'), type: 'photo', title: 'Mía' }),
    });
    expect(delDonante.status).toBe(403);

    const delAdmin = await req('/evidences', T.admin!, {
      ...json({
        donorId: seedId('don1'),
        projectId: seedId('prj2'),
        type: 'report',
        title: 'Reporte SolAndino',
      }),
    });
    expect(delAdmin.status).toBe(201);
  });
});

describe('/calendar-events', () => {
  it('cada rol crea solo los tipos que le corresponden', async () => {
    const lxdOk = await req('/calendar-events', T.lxd!, {
      ...json({
        title: 'Sesión Open Learning',
        startsAt: new Date().toISOString(),
        type: 'open_learning_sync',
        courseId: seedId('crs_ol_marketing'),
      }),
    });
    expect(lxdOk.status).toBe(201);

    const lxdMal = await req('/calendar-events', T.lxd!, {
      ...json({
        title: 'Mentoría',
        startsAt: new Date().toISOString(),
        type: 'mentoria',
        laboratoryId: seedId('lab_ia'),
      }),
    });
    expect(lxdMal.status).toBe(403);

    const mentorOk = await req('/calendar-events', T.mentor!, {
      ...json({
        title: 'Mentoría IA',
        startsAt: new Date().toISOString(),
        type: 'mentoria',
        laboratoryId: seedId('lab_ia'),
      }),
    });
    expect(mentorOk.status).toBe(201);
  });

  it('Empresa y Donante no tienen calendario', async () => {
    for (const token of [T.company!, T.donor!]) {
      const res = await req('/calendar-events', token);
      const page = await body<{ data: unknown[]; total: number }>(res);
      expect(page.total).toBe(0);
    }
  });
});

describe('/communication-resources', () => {
  it('el admin publica; asesor, mentor y LXD leen; el estudiante no', async () => {
    const creado = await req('/communication-resources', T.admin!, {
      ...json({ title: 'Plantilla de pitch', type: 'link', url: 'https://ejemplo.co/p' }),
    });
    expect(creado.status).toBe(201);

    for (const token of [T.advisor!, T.mentor!, T.lxd!]) {
      const res = await req('/communication-resources', token);
      const page = await body<{ total: number }>(res);
      expect(page.total).toBeGreaterThan(0);
    }

    const delEstudiante = await req('/communication-resources', T.student!);
    expect((await body<{ total: number }>(delEstudiante)).total).toBe(0);

    const creaMentor = await req('/communication-resources', T.mentor!, {
      ...json({ title: 'No permitido', type: 'link', url: 'https://x.co' }),
    });
    expect(creaMentor.status).toBe(403);
  });

  it('un recurso de archivo sin s3Key se rechaza', async () => {
    const res = await req('/communication-resources', T.admin!, {
      ...json({ title: 'Sin archivo', type: 'file' }),
    });
    expect(res.status).toBe(400);
  });
});

describe('/forum-posts', () => {
  it('publica, responde y apoya; el apoyo es uno por persona', async () => {
    const post = await req('/forum-posts', T.student!, {
      ...json({ body: '¿Alguien trabajó con sensores de agua?', category: 'question' }),
    });
    expect(post.status).toBe(201);
    const { id } = await body<{ id: string }>(post);

    const reply = await req(`/forum-posts/${id}/replies`, T.advisor!, {
      ...json({ body: 'Sí, el equipo AquaVida.' }),
    });
    expect(reply.status).toBe(201);

    const like1 = await req(`/forum-posts/${id}/like`, T.otroStudent!, { method: 'POST' });
    expect((await body<{ liked: boolean; likeCount: number }>(like1)).likeCount).toBe(1);
    const like2 = await req(`/forum-posts/${id}/like`, T.otroStudent!, { method: 'POST' });
    const b2 = await body<{ liked: boolean; likeCount: number }>(like2);
    expect(b2.liked).toBe(false);
    expect(b2.likeCount).toBe(0);
  });

  it('fijar es moderación de admin', async () => {
    const delEstudiante = await req(`/forum-posts/${seedId('post3')}/pin`, T.student!, {
      method: 'POST',
    });
    expect(delEstudiante.status).toBe(403);

    const delAdmin = await req(`/forum-posts/${seedId('post3')}/pin`, T.admin!, {
      method: 'POST',
    });
    expect(delAdmin.status).toBe(200);
  });

  it('el autor borra lo suyo; a lo ajeno, 403', async () => {
    const propio = await req('/forum-posts', T.student!, {
      ...json({ body: 'Se va a borrar' }),
    });
    const { id } = await body<{ id: string }>(propio);

    const ajeno = await req(`/forum-posts/${id}`, T.otroStudent!, { method: 'DELETE' });
    expect(ajeno.status).toBe(403);

    const suyo = await req(`/forum-posts/${id}`, T.student!, { method: 'DELETE' });
    expect(suyo.status).toBe(204);
  });

  it('LXD, Mentor, Empresa y Donante no tienen acceso al foro', async () => {
    for (const token of [T.lxd!, T.mentor!, T.company!, T.donor!]) {
      const res = await req('/forum-posts', token);
      expect(res.status).toBe(403);
    }
  });
});

describe('/notifications', () => {
  it('siempre devuelve las propias y permite marcarlas leídas', async () => {
    const res = await req('/notifications', T.student!);
    expect(res.status).toBe(200);
    const page = await body<{ data: { userId: string }[]; unread: number }>(res);
    expect(page.data.every((n) => n.userId === seedId('est1'))).toBe(true);
    expect(page.unread).toBeGreaterThan(0);

    const marcar = await req('/notifications/read', T.student!, { method: 'POST' });
    expect(marcar.status).toBe(204);

    const despues = await req('/notifications', T.student!);
    expect((await body<{ unread: number }>(despues)).unread).toBe(0);
  });
});

describe('PATCH /admin/users/:id/can-grade', () => {
  it('solo admin/superadmin, y queda en audit_log', async () => {
    const delLxd = await req(`/admin/users/${seedId('lxd2')}/can-grade`, T.lxd!, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ canGradeEnactus: true }),
    });
    expect(delLxd.status).toBe(403);

    const res = await req(`/admin/users/${seedId('lxd2')}/can-grade`, T.admin!, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ canGradeEnactus: true, canGradeOpenLearning: true }),
    });
    expect(res.status).toBe(200);
    const u = await body<{ canGradeEnactus: boolean }>(res);
    expect(u.canGradeEnactus).toBe(true);

    const [log] = await sql<{
      action: string;
      actor_id: string;
      old_value: { canGradeEnactus: boolean };
      new_value: { canGradeEnactus: boolean };
    }[]>`
      select action, actor_id, old_value, new_value from audit_log
       where action = 'user.can_grade.update' order by created_at desc limit 1
    `;
    expect(log?.actor_id).toBe(seedId('adm1'));
    expect(log?.old_value.canGradeEnactus).toBe(false);
    expect(log?.new_value.canGradeEnactus).toBe(true);
  });

  it('no aplica a roles que no son LXD', async () => {
    const res = await req(`/admin/users/${seedId('ment1')}/can-grade`, T.admin!, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ canGradeEnactus: true }),
    });
    expect(res.status).toBe(409);
  });
});

describe('/admin/backup y /admin/restore', () => {
  it('el respaldo NO incluye contraseñas ni sesiones', async () => {
    const res = await req('/admin/backup', T.admin!);
    expect(res.status).toBe(200);
    const raw = await res.text();

    // Lo que de verdad importa: que no viaje ningún hash de bcrypt. Hoy
    // `exportBackupJson()` vuelca la caja `users` entera, contraseñas en
    // texto plano incluidas, a un archivo que el Admin descarga.
    expect(raw).not.toContain('$2b$');
    expect(raw).not.toContain('$2a$');

    const b = JSON.parse(raw) as { data: Record<string, Record<string, unknown>[]> };
    expect(b.data.users?.length).toBe(16);
    expect(b.data.courses?.length).toBeGreaterThan(0);

    // Ninguna fila de usuario trae la columna, ni vacía.
    const claves = new Set(b.data.users?.flatMap((u) => Object.keys(u)) ?? []);
    expect(claves.has('password_hash')).toBe(false);
    expect(claves.has('passwordHash')).toBe(false);
    // Y las sesiones abiertas tampoco se respaldan.
    expect(Object.keys(b.data)).not.toContain('refresh_tokens');
  });

  it('restaurar está reservado al superadmin', async () => {
    const delAdmin = await req('/admin/restore', T.admin!, {
      ...json({ version: 1, data: {}, confirm: 'REEMPLAZAR TODOS LOS DATOS' }),
    });
    expect(delAdmin.status).toBe(403);
  });

  it('restaurar exige la confirmación explícita', async () => {
    const res = await req('/admin/restore', T.superadmin!, {
      ...json({ version: 1, data: {}, confirm: 'sí dale' }),
    });
    expect(res.status).toBe(400);
  });
});

describe('/admin/storage/video', () => {
  it('suma el almacenamiento de video del seed', async () => {
    const res = await req('/admin/storage/video', T.admin!);
    expect(res.status).toBe(200);
    const s = await body<{
      lessons: { count: number; bytes: number };
      totalBytes: number;
      totalGb: number;
    }>(res);
    expect(s.lessons.count).toBeGreaterThan(0);
    expect(s.totalGb).toBeGreaterThanOrEqual(0);
  });
});

describe('/files/upload-url', () => {
  it('valida el rol según el propósito', async () => {
    const estudianteSubeEvidencia = await req('/files/upload-url', T.student!, {
      ...json({
        purpose: 'evidence',
        fileName: 'foto.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 1024,
      }),
    });
    expect(estudianteSubeEvidencia.status).toBe(403);

    const estudianteSubeEntrega = await req('/files/upload-url', T.student!, {
      ...json({
        purpose: 'submission',
        fileName: 'ensayo.pdf',
        contentType: 'application/pdf',
        sizeBytes: 1024,
      }),
    });
    // Pasa la validación de rol y de archivo; falla por falta de bucket.
    expect(estudianteSubeEntrega.status).toBe(503);
  });

  it('rechaza un tipo de archivo no permitido', async () => {
    const res = await req('/files/upload-url', T.admin!, {
      ...json({
        purpose: 'evidence',
        fileName: 'raro.exe',
        contentType: 'application/x-msdownload',
        sizeBytes: 1024,
      }),
    });
    expect(res.status).toBe(400);
  });

  it('rechaza un archivo de más de 25 MB', async () => {
    const res = await req('/files/upload-url', T.admin!, {
      ...json({
        purpose: 'evidence',
        fileName: 'grande.pdf',
        contentType: 'application/pdf',
        sizeBytes: 30 * 1024 * 1024,
      }),
    });
    expect(res.status).toBe(413);
  });
});
