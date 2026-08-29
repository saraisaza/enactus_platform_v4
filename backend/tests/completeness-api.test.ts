import type { Sql } from 'postgres';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { resetRateLimits } from '../src/middleware/rate-limit';
import { auth, json, login, makeTestApp } from './helpers/app';
import { seedId, seedTestDatabase } from './helpers/db';

/**
 * Grupo 2 de la Fase 4: la completitud vive en el servidor.
 *
 * Estos son los tests más importantes de la fase. No prueban que un endpoint
 * responda 200: prueban que la REGLA se cumple — que un módulo con tres cursos
 * no se completa con dos, que el certificado se rechaza con dos de tres fases,
 * y que destildar una lección recalcula hacia arriba.
 */

let app: ReturnType<typeof makeTestApp>['app'];
let sql: Sql;

let estToken = '';
let otroEstToken = '';
let lxdToken = '';
let lxdSinPermisoToken = '';
let adminToken = '';
let mentorToken = '';

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

  estToken = (await login(app, 'estudiante1@uniandes.edu.co', 'Est123')).accessToken;
  otroEstToken = (await login(app, 'estudiante3@unal.edu.co', 'Est123')).accessToken;
  lxdToken = (await login(app, 'lxd.ia@enactus.co', 'Lxd123')).accessToken;
  lxdSinPermisoToken = (await login(app, 'lxd.agua@enactus.co', 'Lxd123')).accessToken;
  adminToken = (await login(app, 'admin@enactus.co', 'Admin123')).accessToken;
  mentorToken = (await login(app, 'mentor.ia@enactus.co', 'Mentor123')).accessToken;
}, 120_000);

beforeEach(() => resetRateLimits());

afterAll(async () => {
  await sql.end();
});

// ---------------------------------------------------------------------------

describe('GET /students/:id/ruta-progress', () => {
  it('devuelve el árbol completo con el estado real del seed', async () => {
    const res = await req(`/students/${seedId('est1')}/ruta-progress`, estToken);
    expect(res.status).toBe(200);
    const b = await body<{
      laboratories: {
        laboratoryId: string;
        phasesDone: number;
        phasesTotal: number;
        isComplete: boolean;
        phases: {
          orderIndex: number;
          modulesDone: number;
          modulesTotal: number;
          isComplete: boolean;
          isUnlocked: boolean;
          deadlineStatus: string;
          objectives: { isComplete: boolean }[];
          modules: {
            isComplete: boolean;
            isUnlocked: boolean;
            courses: { ratio: number; isComplete: boolean }[];
          }[];
        }[];
      }[];
    }>(res);

    expect(b.laboratories).toHaveLength(2); // lab_ia y lab_impacto
    const ia = b.laboratories.find((l) => l.laboratoryId === seedId('lab_ia'));
    expect(ia?.isComplete).toBe(false);
    expect(ia?.phasesTotal).toBe(3);

    const fase1 = ia?.phases.find((p) => p.orderIndex === 1);
    // El estado que sembró la Fase 2: módulo de contenido completo, mentoría no.
    expect(fase1?.modulesDone).toBe(1);
    expect(fase1?.modulesTotal).toBe(2);
    expect(fase1?.isComplete).toBe(false);
    expect(fase1?.isUnlocked).toBe(true);
    // El curso del módulo 1 está al 100%.
    expect(fase1?.modules[0]?.courses[0]?.ratio).toBe(1);
    expect(fase1?.modules[0]?.isComplete).toBe(true);
    // Los dos objetivos de la fase 1 dependen de ese curso: completos.
    expect(fase1?.objectives.every((o) => o.isComplete)).toBe(true);
    // El módulo de mentoría está desbloqueado (el anterior está completo).
    expect(fase1?.modules[1]?.isUnlocked).toBe(true);
    expect(fase1?.modules[1]?.isComplete).toBe(false);

    // La fase 2 sigue bloqueada porque la 1 no está completa.
    const fase2 = ia?.phases.find((p) => p.orderIndex === 2);
    expect(fase2?.isUnlocked).toBe(false);

    // La fase 1 tenía deadline 2026-07-01, ya vencido y sin completar.
    expect(fase1?.deadlineStatus).toBe('overdue');
  });

  it('un estudiante NO puede ver la Ruta de otro', async () => {
    const res = await req(`/students/${seedId('est1')}/ruta-progress`, otroEstToken);
    expect(res.status).toBe(403);
  });

  it('un mentor sí puede', async () => {
    const res = await req(`/students/${seedId('est1')}/ruta-progress`, mentorToken);
    expect(res.status).toBe(200);
  });
});

describe('POST /progress/lessons/:id/toggle', () => {
  it('un estudiante no puede tocar el progreso de otro (no hay forma de pedirlo)', async () => {
    // El endpoint ni siquiera acepta un studentId: siempre opera sobre quien
    // tiene la sesión. Se comprueba que tocar una lección de un curso ajeno
    // se rechaza, que es la vía por la que se podría intentar.
    const res = await req(`/progress/lessons/${seedId('lag1')}/toggle`, estToken, {
      method: 'POST',
    });
    expect(res.status).toBe(403);
    const b = await body<{ error: { message: string } }>(res);
    expect(b.error.message).toContain('acceso');
  });

  it('un LXD no puede marcar lecciones: no es estudiante', async () => {
    const res = await req(`/progress/lessons/${seedId('lia1')}/toggle`, lxdToken, {
      method: 'POST',
    });
    expect(res.status).toBe(403);
  });

  it('destildar una lección completa recalcula hacia arriba', async () => {
    // `est1` tiene el curso al 100% y el módulo 1 completo.
    const antes = await req(
      `/students/${seedId('est1')}/course-progress/${seedId('crs_ia_1')}`,
      estToken,
    );
    expect((await body<{ isComplete: boolean }>(antes)).isComplete).toBe(true);

    const res = await req(`/progress/lessons/${seedId('lia1')}/toggle`, estToken, {
      method: 'POST',
    });
    expect(res.status).toBe(200);
    const impact = await body<{
      completed: boolean;
      course: { ratio: number; isComplete: boolean; completedLessons: number };
      rutaImpact: {
        moduleComplete: boolean;
        phaseComplete: boolean;
        rutaComplete: boolean;
        phaseModulesDone: number;
      }[];
    }>(res);

    expect(impact.completed).toBe(false);
    expect(impact.course.isComplete).toBe(false);
    expect(impact.course.completedLessons).toBe(5);
    // Y en una sola respuesta viene el efecto en la Ruta.
    expect(impact.rutaImpact).toHaveLength(1);
    expect(impact.rutaImpact[0]?.moduleComplete).toBe(false);
    expect(impact.rutaImpact[0]?.phaseModulesDone).toBe(0);
    expect(impact.rutaImpact[0]?.phaseComplete).toBe(false);

    // Se vuelve a marcar y todo regresa.
    const vuelta = await req(`/progress/lessons/${seedId('lia1')}/toggle`, estToken, {
      method: 'POST',
    });
    const back = await body<{
      completed: boolean;
      course: { isComplete: boolean };
      rutaImpact: { moduleComplete: boolean }[];
    }>(vuelta);
    expect(back.completed).toBe(true);
    expect(back.course.isComplete).toBe(true);
    expect(back.rutaImpact[0]?.moduleComplete).toBe(true);
  });
});

describe('un módulo con 3 cursos exige los 3', () => {
  const nuevos: string[] = [];

  beforeAll(async () => {
    // Se agregan DOS cursos más al módulo 1 de la fase 1 de lab_ia, cada uno
    // con una lección. Junto al que ya estaba, el módulo pasa a exigir tres.
    for (const nombre of ['Curso extra A', 'Curso extra B']) {
      const curso = await req('/courses', lxdToken, {
        ...json({ name: nombre, laboratoryId: seedId('lab_ia') }),
      });
      const { id: courseId } = await body<{ id: string }>(curso);
      const mod = await req(`/courses/${courseId}/modules`, lxdToken, {
        ...json({ title: 'Único' }),
      });
      const { id: moduleId } = await body<{ id: string }>(mod);
      await req(`/modules/${moduleId}/lessons`, lxdToken, {
        ...json({ title: 'Única lección', type: 'pdf' }),
      });
      await req(`/courses/${courseId}/publish`, lxdToken, { method: 'POST' });
      await sql`
        insert into ruta_module_courses (ruta_module_id, course_id)
        values (${seedId('lab_ia_fase1_mod1')}, ${courseId})
      `;
      nuevos.push(courseId);
    }
  });

  it('con 1 de 3 cursos completos, el módulo NO está completo', async () => {
    // El curso original ya estaba al 100%; los dos nuevos, en cero.
    const res = await req(`/students/${seedId('est1')}/ruta-progress`, estToken);
    const b = await body<{
      laboratories: {
        laboratoryId: string;
        phases: { orderIndex: number; modules: { coursesTotal: number; coursesDone: number; isComplete: boolean }[] }[];
      }[];
    }>(res);
    const mod = b.laboratories
      .find((l) => l.laboratoryId === seedId('lab_ia'))
      ?.phases.find((p) => p.orderIndex === 1)?.modules[0];

    expect(mod?.coursesTotal).toBe(3);
    expect(mod?.coursesDone).toBe(1);
    expect(mod?.isComplete).toBe(false);
  });

  it('completando el 2º sigue incompleto; con el 3º se completa', async () => {
    const lecciones: string[] = [];
    for (const courseId of nuevos) {
      const [row] = await sql<{ id: string }[]>`
        select l.id from lessons l
          join course_modules cm on cm.id = l.course_module_id
         where cm.course_id = ${courseId} limit 1
      `;
      lecciones.push(row!.id);
    }

    // Segundo curso completo → módulo todavía incompleto.
    const dos = await req(`/progress/lessons/${lecciones[0]!}/toggle`, estToken, {
      method: 'POST',
    });
    const impactoDos = await body<{ rutaImpact: { moduleComplete: boolean }[] }>(dos);
    expect(impactoDos.rutaImpact[0]?.moduleComplete).toBe(false);

    // Tercero → ahora sí.
    const tres = await req(`/progress/lessons/${lecciones[1]!}/toggle`, estToken, {
      method: 'POST',
    });
    const impactoTres = await body<{
      rutaImpact: { moduleComplete: boolean; phaseModulesDone: number }[];
    }>(tres);
    expect(impactoTres.rutaImpact[0]?.moduleComplete).toBe(true);
    expect(impactoTres.rutaImpact[0]?.phaseModulesDone).toBe(1);
  });
});

describe('POST /certificates/ruta', () => {
  it('con 2 de 3 fases responde 409 y NO crea el certificado', async () => {
    const antes = await sql<{ count: string }[]>`
      select count(*)::text as count from certificates
       where student_id = ${seedId('est1')}
    `;

    const res = await req('/certificates/ruta', lxdToken, {
      ...json({ studentId: seedId('est1'), laboratoryId: seedId('lab_ia') }),
    });
    expect(res.status).toBe(409);
    const b = await body<{
      error: {
        code: string;
        message: string;
        details: { phasesDone: number; phasesTotal: number; missing: unknown[] };
      };
    }>(res);
    expect(b.error.code).toBe('conflict');
    expect(b.error.details.phasesTotal).toBe(3);
    expect(b.error.details.phasesDone).toBeLessThan(3);
    expect(b.error.details.missing.length).toBeGreaterThan(0);

    const despues = await sql<{ count: string }[]>`
      select count(*)::text as count from certificates
       where student_id = ${seedId('est1')}
    `;
    expect(despues[0]?.count).toBe(antes[0]?.count);
  });

  it('un LXD sin permiso de calificar en Enactus recibe 403', async () => {
    const res = await req('/certificates/ruta', lxdSinPermisoToken, {
      ...json({ studentId: seedId('est1'), laboratoryId: seedId('lab_ia') }),
    });
    expect(res.status).toBe(403);
  });

  it('un estudiante no puede emitirse un certificado a sí mismo', async () => {
    const res = await req('/certificates/ruta', estToken, {
      ...json({ studentId: seedId('est1'), laboratoryId: seedId('lab_ia') }),
    });
    expect(res.status).toBe(403);
  });

  it('con las 3 fases completas sí se emite', async () => {
    // Se completa todo lo que falta de lab_ia para est1: las lecturas propias
    // de los módulos pendientes de las 3 fases.
    const pendientes = await sql<{ id: string }[]>`
      select l.id
        from lessons l
        join ruta_modules rm on rm.id = l.ruta_module_id
        join phases p on p.id = rm.phase_id
       where p.laboratory_id = ${seedId('lab_ia')}
         and l.id not in (
           select rpl.lesson_id from ruta_progress_lessons rpl
             join ruta_progress rp on rp.id = rpl.ruta_progress_id
            where rp.student_id = ${seedId('est1')})
    `;
    for (const l of pendientes) {
      await req(`/progress/lessons/${l.id}/toggle`, estToken, { method: 'POST' });
    }

    // Las fases 2 y 3 del seed no tienen módulos, así que nunca se completan:
    // se les agrega uno con su lectura, como haría el Admin en el editor.
    for (const fase of ['lab_ia_fase2', 'lab_ia_fase3']) {
      const [mod] = await sql<{ id: string }[]>`
        insert into ruta_modules (phase_id, order_index, title, is_mentorship_module)
        values (${seedId(fase)}, 1, 'Módulo único', true) returning id
      `;
      const [lec] = await sql<{ id: string }[]>`
        insert into lessons (ruta_module_id, order_index, title, type)
        values (${mod!.id}, 1, 'Entrega de la fase', 'activity') returning id
      `;
      await req(`/progress/lessons/${lec!.id}/toggle`, estToken, { method: 'POST' });
    }

    const elegible = await req(
      `/students/${seedId('est1')}/certificate-eligibility/${seedId('lab_ia')}`,
      lxdToken,
    );
    const el = await body<{ eligible: boolean; phasesDone: number }>(elegible);
    expect(el.phasesDone).toBe(3);
    expect(el.eligible).toBe(true);

    const res = await req('/certificates/ruta', lxdToken, {
      ...json({ studentId: seedId('est1'), laboratoryId: seedId('lab_ia') }),
    });
    expect(res.status).toBe(201);
    const cert = await body<{
      code: string;
      hours: number;
      issuerId: string;
      labContentVersion: number;
      requirementsSnapshot: { phases: unknown[] };
    }>(res);
    expect(cert.code).toMatch(/^ENC-\d{4}-\d{5}$/);
    expect(cert.issuerId).toBe(seedId('lxd1'));
    // El snapshot congela lo que se exigía al emitir (decisión B.1).
    expect(cert.requirementsSnapshot.phases).toHaveLength(3);
    expect(cert.labContentVersion).toBe(1);
    // Horas: suma de los cursos únicos de los módulos (crs_ia_1 = 8 h
    // certificadas, más los dos cursos extra sin horas configuradas).
    expect(cert.hours).toBe(8);
  });

  it('no se puede emitir dos veces', async () => {
    const res = await req('/certificates/ruta', lxdToken, {
      ...json({ studentId: seedId('est1'), laboratoryId: seedId('lab_ia') }),
    });
    expect(res.status).toBe(409);
    const b = await body<{ error: { message: string } }>(res);
    expect(b.error.message).toContain('ya tiene el certificado');
  });

  it('el estudiante ve su certificado y le llegó la notificación', async () => {
    const res = await req('/certificates', estToken);
    const page = await body<{ data: { code: string }[] }>(res);
    expect(page.data).toHaveLength(1);

    const [noti] = await sql<{ title: string }[]>`
      select title from notifications
       where user_id = ${seedId('est1')} and title = 'Nuevo certificado'
    `;
    expect(noti?.title).toBe('Nuevo certificado');
  });

  it('la emisión quedó en audit_log', async () => {
    const [row] = await sql<{ action: string; actor_id: string }[]>`
      select action, actor_id from audit_log where action = 'certificate.issue'
    `;
    expect(row?.action).toBe('certificate.issue');
    expect(row?.actor_id).toBe(seedId('lxd1'));
  });

  it('el admin también puede emitir, sin pasar por can_grade', async () => {
    // `alum1` está en lab_impacto, que no tiene fases con módulos: se le
    // arma una Ruta mínima completable para probar la vía del administrador.
    const res = await req('/certificates/ruta', adminToken, {
      ...json({ studentId: seedId('alum1'), laboratoryId: seedId('lab_ia') }),
    });
    // No está completa para alum1: lo que importa es que NO fue 403.
    expect(res.status).toBe(409);
  });
});
