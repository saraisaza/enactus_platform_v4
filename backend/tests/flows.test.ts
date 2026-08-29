import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Verificación final de la Fase 4: los cuatro flujos completos, de punta a
 * punta, contra la base sembrada.
 *
 * A diferencia de los otros archivos —que atacan una regla cada uno— estos
 * recorren el camino que hace una persona real, empezando por el login.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

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
}, 120_000);

beforeEach(() => resetRateLimits());
afterAll(async () => { await sql.end(); });

// ---------------------------------------------------------------------------

describe('Flujo 1 — estudiante Enactus, de login a certificado', () => {
  it('login → ruta → completar → ver subir el progreso → certificado', async () => {
    // 1. Login.
    const sesion = await login(app, 'estudiante1@uniandes.edu.co', 'Est123');
    const token = sesion.accessToken;

    const me = await req('/auth/me', token);
    expect((await body<{ role: string }>(me)).role).toBe('student');

    // 2. Ver su Ruta de Impacto.
    const ruta = await req(`/students/${sesion.userId}/ruta-progress`, token);
    expect(ruta.status).toBe(200);
    const inicial = await body<{
      laboratories: { laboratoryId: string; phasesDone: number; isComplete: boolean }[];
    }>(ruta);
    const ia = inicial.laboratories.find((l) => l.laboratoryId === seedId('lab_ia'));
    expect(ia?.isComplete).toBe(false);

    // 3. El certificado se rechaza mientras falten fases.
    const lxd = (await login(app, 'lxd.ia@enactus.co', 'Lxd123')).accessToken;
    const prematuro = await req('/certificates/ruta', lxd, {
      ...json({ studentId: sesion.userId, laboratoryId: seedId('lab_ia') }),
    });
    expect(prematuro.status).toBe(409);

    // 4. Completar TODO lo que falta del laboratorio.
    // Las fases 2 y 3 del seed están vacías: el Admin les publica contenido,
    // que es lo que haría en el editor de Ruta de Impacto.
    for (const fase of ['lab_ia_fase2', 'lab_ia_fase3']) {
      const [mod] = await sql<{ id: string }[]>`
        insert into ruta_modules (phase_id, order_index, title, is_mentorship_module)
        values (${seedId(fase)}, 1, 'Módulo de la fase', true) returning id
      `;
      await sql`
        insert into lessons (ruta_module_id, order_index, title, type)
        values (${mod!.id}, 1, 'Entrega de la fase', 'activity')
      `;
    }

    const pendientes = await sql<{ id: string }[]>`
      select l.id from lessons l
        join ruta_modules rm on rm.id = l.ruta_module_id
        join phases p on p.id = rm.phase_id
       where p.laboratory_id = ${seedId('lab_ia')}
         and l.id not in (select rpl.lesson_id from ruta_progress_lessons rpl
                            join ruta_progress rp on rp.id = rpl.ruta_progress_id
                           where rp.student_id = ${sesion.userId})
    `;

    let ultimoImpacto: { rutaComplete: boolean; certificateAvailable: boolean } | undefined;
    for (const l of pendientes) {
      const res = await req(`/progress/lessons/${l.id}/toggle`, token, { method: 'POST' });
      expect(res.status).toBe(200);
      const impacto = await body<{
        rutaImpact: { rutaComplete: boolean; certificateAvailable: boolean }[];
      }>(res);
      ultimoImpacto = impacto.rutaImpact.find((r) => r.rutaComplete) ?? ultimoImpacto;
    }

    // 5. El progreso subió y la propia respuesta del toggle avisa que ya se
    //    puede emitir el certificado — sin llamadas adicionales.
    expect(ultimoImpacto?.rutaComplete).toBe(true);
    expect(ultimoImpacto?.certificateAvailable).toBe(true);

    const rutaFinal = await req(`/students/${sesion.userId}/ruta-progress`, token);
    const final = await body<{
      laboratories: { laboratoryId: string; phasesDone: number; isComplete: boolean }[];
    }>(rutaFinal);
    const iaFinal = final.laboratories.find((l) => l.laboratoryId === seedId('lab_ia'));
    expect(iaFinal?.phasesDone).toBe(3);
    expect(iaFinal?.isComplete).toBe(true);

    // 6. Ahora sí se emite.
    const cert = await req('/certificates/ruta', lxd, {
      ...json({ studentId: sesion.userId, laboratoryId: seedId('lab_ia') }),
    });
    expect(cert.status).toBe(201);
    const emitido = await body<{ code: string; hours: number }>(cert);
    expect(emitido.code).toMatch(/^ENC-\d{4}-\d{5}$/);

    // 7. La estudiante lo ve en su listado.
    const mios = await req('/certificates', token);
    const page = await body<{ data: { code: string }[] }>(mios);
    expect(page.data.map((c) => c.code)).toContain(emitido.code);
  });
});

describe('Flujo 2 — Open Learning', () => {
  it('login → ver sus cursos → 403 en todo lo de Ruta de Impacto', async () => {
    const sesion = await login(app, 'camila.rivas@gmail.com', 'Est123');
    const token = sesion.accessToken;

    const cursos = await req('/courses?pageSize=50', token);
    expect(cursos.status).toBe(200);
    const page = await body<{ data: { id: string; isOpenLearning: boolean }[] }>(cursos);
    expect(page.data).toHaveLength(1);
    expect(page.data[0]?.isOpenLearning).toBe(true);

    // Puede avanzar en SU curso.
    const [leccion] = await sql<{ id: string }[]>`
      select l.id from lessons l
        join course_modules cm on cm.id = l.course_module_id
       where cm.course_id = ${seedId('crs_ol_marketing')} limit 1
    `;
    const toggle = await req(`/progress/lessons/${leccion!.id}/toggle`, token, {
      method: 'POST',
    });
    expect(toggle.status).toBe(200);
    const impacto = await body<{
      completed: boolean;
      course: { ratio: number };
      rutaImpact: unknown[];
    }>(toggle);
    expect(impacto.completed).toBe(true);
    expect(impacto.course.ratio).toBeGreaterThan(0);
    // No hay Ruta de Impacto que recalcular.
    expect(impacto.rutaImpact).toHaveLength(0);

    // Y todo lo de Ruta le está cerrado.
    for (const path of [
      '/laboratories',
      '/projects',
      '/groups',
      '/forum-posts',
      `/students/${sesion.userId}/ruta-progress`,
    ]) {
      const res = await req(path, token);
      expect(res.status).toBe(403);
    }
  });
});

describe('Flujo 3 — LXD construye un curso completo', () => {
  it('curso → módulo → video externo → video subido → publicar', async () => {
    const token = (await login(app, 'lxd.ia@enactus.co', 'Lxd123')).accessToken;

    const curso = await req('/courses', token, {
      ...json({
        name: 'Fundamentos de datos',
        description: 'Curso armado en el flujo de integración',
        laboratoryId: seedId('lab_ia'),
        estimatedHours: 5,
      }),
    });
    expect(curso.status).toBe(201);
    const { id: courseId, status } = await body<{ id: string; status: string }>(curso);
    expect(status).toBe('draft');

    const mod = await req(`/courses/${courseId}/modules`, token, {
      ...json({ title: 'Módulo 1: Introducción' }),
    });
    const { id: moduleId } = await body<{ id: string }>(mod);

    // Lección con video EXTERNO.
    const l1 = await req(`/modules/${moduleId}/lessons`, token, {
      ...json({ title: 'Video introductorio', type: 'video', durationMin: 12 }),
    });
    const { id: leccionExterna } = await body<{ id: string }>(l1);
    const externo = await req(`/lessons/${leccionExterna}/video-external`, token, {
      ...json({ url: 'https://www.youtube.com/watch?v=intro', durationSec: 720 }),
    });
    expect((await body<{ videoType: string }>(externo)).videoType).toBe('external');

    // Lección con video PROPIO: se pide la URL de subida y se confirma.
    const l2 = await req(`/modules/${moduleId}/lessons`, token, {
      ...json({ title: 'Clase grabada', type: 'video' }),
    });
    const { id: leccionPropia } = await body<{ id: string }>(l2);

    const urlSubida = await req(`/lessons/${leccionPropia}/video-upload-url`, token, {
      ...json({ contentType: 'video/mp4', sizeBytes: 180 * 1024 * 1024 }),
    });
    // Sin S3 configurado en local, la validación pasa y falla la firma.
    expect(urlSubida.status).toBe(503);

    // El navegador habría subido a S3; se confirma con la key de la lección.
    const confirmada = await req(`/lessons/${leccionPropia}/video`, token, {
      ...json({
        key: `lessons/${leccionPropia}/clase.mp4`,
        sizeBytes: 180 * 1024 * 1024,
        mimeType: 'video/mp4',
        durationSec: 2400,
      }),
    });
    expect(confirmada.status).toBe(200);
    const propia = await body<{ videoType: string; videoS3Key: string }>(confirmada);
    expect(propia.videoType).toBe('uploaded');

    // Publicar.
    const publicado = await req(`/courses/${courseId}/publish`, token, { method: 'POST' });
    expect(publicado.status).toBe(200);
    expect((await body<{ status: string }>(publicado)).status).toBe('published');

    // Y ahora la estudiante del laboratorio lo ve.
    const est = (await login(app, 'estudiante1@uniandes.edu.co', 'Est123')).accessToken;
    const listado = await req('/courses?pageSize=100', est);
    const page = await body<{ data: { id: string }[] }>(listado);
    expect(page.data.map((c) => c.id)).toContain(courseId);

    // El almacenamiento de video del admin refleja los 180 MB.
    const admin = (await login(app, 'admin@enactus.co', 'Admin123')).accessToken;
    const storage = await req('/admin/storage/video', admin);
    const s = await body<{ totalBytes: number }>(storage);
    expect(s.totalBytes).toBeGreaterThanOrEqual(180 * 1024 * 1024);
  });
});

describe('Flujo 4 — calificación con can_grade en true y en false', () => {
  let submissionId = '';

  it('la estudiante hace una entrega', async () => {
    const token = (await login(app, 'estudiante1@uniandes.edu.co', 'Est123')).accessToken;
    const res = await req('/submissions', token, {
      ...json({
        courseId: seedId('crs_ia_1'),
        lessonId: seedId('lia5'),
        taskName: 'Proyecto: IA para mi comunidad',
        comment: 'Adjunto la propuesta.',
      }),
    });
    expect(res.status).toBe(201);
    submissionId = (await body<{ id: string }>(res)).id;
  });

  it('un LXD SIN permiso no puede calificarla', async () => {
    const token = (await login(app, 'lxd.agua@enactus.co', 'Lxd123')).accessToken;
    const res = await req(`/submissions/${submissionId}/grade`, token, {
      ...json({ grade: 90, gradingMode: 'points100', feedback: 'Bien' }),
    });
    expect(res.status).toBe(403);

    // Y la entrega sigue sin nota.
    const [row] = await sql<{ grade: string | null }[]>`
      select grade from submissions where id = ${submissionId}
    `;
    expect(row?.grade).toBeNull();
  });

  it('el Mentor comenta pero NO pone nota', async () => {
    const token = (await login(app, 'mentor.ia@enactus.co', 'Mentor123')).accessToken;

    const califica = await req(`/submissions/${submissionId}/grade`, token, {
      ...json({ grade: 80, gradingMode: 'points100' }),
    });
    expect(califica.status).toBe(403);

    const comenta = await req(`/submissions/${submissionId}/review`, token, {
      ...json({ feedback: 'Buen enfoque, profundizá en los datos.' }),
    });
    expect(comenta.status).toBe(200);
    const revisada = await body<{ feedback: string; grade: string | null }>(comenta);
    expect(revisada.feedback).toContain('Buen enfoque');
    expect(revisada.grade).toBeNull();
  });

  it('el LXD CON permiso califica, y eso completa la lección de la actividad', async () => {
    const token = (await login(app, 'lxd.ia@enactus.co', 'Lxd123')).accessToken;

    const fuera = await req(`/submissions/${submissionId}/grade`, token, {
      ...json({ grade: 130, gradingMode: 'points100' }),
    });
    expect(fuera.status).toBe(400);

    const res = await req(`/submissions/${submissionId}/grade`, token, {
      ...json({ grade: 92, gradingMode: 'points100', feedback: 'Excelente análisis.' }),
    });
    expect(res.status).toBe(200);
    const calificada = await body<{
      grade: string;
      gradingMode: string;
      gradedBy: string;
    }>(res);
    expect(Number(calificada.grade)).toBe(92);
    expect(calificada.gradingMode).toBe('points100');
    expect(calificada.gradedBy).toBe(seedId('lxd1'));

    // Calificar la actividad completa su lección — y nunca la des-completa.
    const [completa] = await sql<{ count: string }[]>`
      select count(*)::text as count from progress_lessons pl
        join progress p on p.id = pl.progress_id
       where p.student_id = ${seedId('est1')} and pl.lesson_id = ${seedId('lia5')}
    `;
    expect(completa?.count).toBe('1');

    // Quedó en audit_log.
    const [log] = await sql<{ action: string }[]>`
      select action from audit_log where action = 'submission.grade' limit 1
    `;
    expect(log?.action).toBe('submission.grade');
  });

  it('la estudiante ya no puede borrar una entrega calificada', async () => {
    const token = (await login(app, 'estudiante1@uniandes.edu.co', 'Est123')).accessToken;
    const res = await req(`/submissions/${submissionId}`, token, { method: 'DELETE' });
    expect(res.status).toBe(409);
  });

  it('un estudiante no ve las entregas de otro', async () => {
    const otro = (await login(app, 'estudiante3@unal.edu.co', 'Est123')).accessToken;
    const res = await req('/submissions?pageSize=100', otro);
    const page = await body<{ data: { studentId: string }[] }>(res);
    expect(page.data.every((s) => s.studentId === seedId('est3'))).toBe(true);
  });
});
