import { and, asc, eq, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import {
  laboratories,
  laboratoryMentors,
  lessons,
  objectiveCourses,
  objectives,
  phases,
  rutaModuleCourses,
  rutaModules,
  studentLaboratories,
} from '../db/schema';
import { conflict, notFound } from '../lib/errors';
import { ADMIN_ROLES, requireAuth, requireRole } from '../middleware/auth';
import type { AppEnv } from '../middleware/context';

type Db = AppEnv['Variables']['db'];

/**
 * Autoría de laboratorios y de su Ruta de Impacto.
 *
 * Va aparte de `labs.ts` —que solo lee— por la misma razón que el seguimiento
 * de cursos vive fuera de `courses.ts`: son otro rol y otra clase de regla.
 * **Todo acá es de Admin**: quién puede leer un laboratorio es una pregunta de
 * ocho respuestas distintas; quién puede reescribir su Ruta, una sola.
 *
 * Dos invariantes del dominio se sostienen desde acá, no desde la base:
 *
 * 1. **Un laboratorio tiene siempre tres fases.** Se crean con él; no se
 *    agregan ni se borran, solo se les edita el contenido. Un laboratorio con
 *    dos fases no es un laboratorio a medias: es una Ruta que nadie puede
 *    completar.
 * 2. **El último módulo de cada fase es el de mentoría**, y el flag se
 *    recalcula después de cada cambio en vez de marcarlo a mano — así no queda
 *    a merced de que alguien se acuerde de moverlo.
 */
export const labAuthoringRoutes = new Hono<AppEnv>();
labAuthoringRoutes.use('*', requireAuth, requireRole(...ADMIN_ROLES));

// ---------------------------------------------------------------------------
// Validación
// ---------------------------------------------------------------------------

const labBody = z.object({
  name: z.string().trim().min(1, 'El laboratorio necesita un nombre.'),
  description: z.string().trim().default(''),
  objectives: z.string().trim().default(''),
  sponsorCompanyId: z.uuid().nullable().optional(),
});

const labUpdate = labBody.partial();

const phaseUpdate = z.object({
  title: z.string().trim().optional(),
  description: z.string().trim().optional(),
  deadline: z.iso.date('La fecha tiene que ser AAAA-MM-DD.').nullable().optional(),
});

const moduleBody = z.object({
  title: z.string().trim().min(1, 'El módulo necesita un título.'),
});

const objectiveBody = z.object({
  category: z.enum(['entrepreneurship', 'business']).default('entrepreneurship'),
  text: z.string().trim().min(1, 'El objetivo necesita su texto.'),
});

const objectiveUpdate = objectiveBody.partial();

const idsBody = z.object({
  ids: z.array(z.uuid()).default([]),
});

const reorderBody = z.object({
  orderedIds: z.array(z.uuid()).min(1, 'Hace falta al menos un id.'),
});

const ownLessonBody = z.object({
  title: z.string().trim().min(1, 'La lección necesita un título.'),
  type: z
    .enum(['video', 'pdf', 'resource', 'link', 'quiz', 'activity', 'survey'])
    .default('pdf'),
  description: z.string().trim().default(''),
  durationMin: z.number().int().min(0).default(0),
  externalUrl: z.url().nullable().optional(),
});

/** Títulos por defecto de las tres fases. */
const DEFAULT_PHASES = [
  'Fase 1 — Descubrimiento',
  'Fase 2 — Desarrollo',
  'Fase 3 — Impacto',
];

// ---------------------------------------------------------------------------
// Laboratorios
// ---------------------------------------------------------------------------

/**
 * Crea el laboratorio **con sus tres fases**.
 *
 * No es una comodidad: un laboratorio sin fases no tiene Ruta, y la vista
 * `phase_unlocked` —que decide qué ve cada estudiante— no tendría de dónde
 * partir. Crear las dos cosas por separado dejaría una ventana en la que el
 * laboratorio existe y no sirve.
 */
labAuthoringRoutes.post('/', async (c) => {
  const body = labBody.parse(await c.req.json());
  const db = c.get('db');

  await assertSponsorIsCompany(db, body.sponsorCompanyId);

  const lab = await db.transaction(async (tx) => {
    const [created] = await tx
      .insert(laboratories)
      .values({
        name: body.name,
        description: body.description,
        objectives: body.objectives,
        sponsorCompanyId: body.sponsorCompanyId ?? null,
      })
      .returning();

    await tx.insert(phases).values(
      DEFAULT_PHASES.map((title, i) => ({
        laboratoryId: created!.id,
        orderIndex: i + 1,
        title,
      })),
    );
    return created!;
  });

  return c.json(lab, 201);
});

labAuthoringRoutes.patch('/:id', async (c) => {
  const body = labUpdate.parse(await c.req.json());
  const db = c.get('db');
  const lab = await loadLab(db, c.req.param('id'));

  await assertSponsorIsCompany(db, body.sponsorCompanyId);

  const [updated] = await db
    .update(laboratories)
    .set({ ...body, updatedAt: new Date() })
    .where(eq(laboratories.id, lab.id))
    .returning();

  return c.json(updated);
});

/**
 * Borrado LÓGICO, y solo si no hay nadie adentro.
 *
 * Mismo criterio que el borrado de cursos: con estudiantes asignados o
 * certificados emitidos se responde 409 con el detalle. Borrarlo dejaría el
 * avance de esas personas apuntando a una Ruta que ya no existe, y sus
 * certificados sin el laboratorio que los respalda.
 */
labAuthoringRoutes.delete('/:id', async (c) => {
  const db = c.get('db');
  const lab = await loadLab(db, c.req.param('id'));

  // `certificates` no tiene borrado lógico —un certificado emitido no se
  // deshace— y su clave ajena al laboratorio es `restrict`, así que la base
  // por sí sola ya impediría un borrado físico. Acá se comprueba igual para
  // poder responder 409 con el detalle en vez de un error de base.
  const [blockers] = await db.execute<{
    students: number;
    certificates: number;
  }>(sql`
    select (select count(*) from student_laboratories
             where laboratory_id = ${lab.id})::int as students,
           (select count(*) from certificates
             where laboratory_id = ${lab.id})::int as certificates
  `);

  if ((blockers?.students ?? 0) > 0 || (blockers?.certificates ?? 0) > 0) {
    throw conflict(
      'Este laboratorio no se puede borrar porque tiene gente adentro. ' +
        'Quitá primero a sus estudiantes.',
      blockers,
    );
  }

  await db
    .update(laboratories)
    .set({ deletedAt: new Date(), updatedAt: new Date() })
    .where(eq(laboratories.id, lab.id));

  return c.body(null, 204);
});

/**
 * Reemplaza el conjunto de mentores del laboratorio.
 *
 * Reemplazo y no alta/baja de a uno: la pantalla edita la lista completa, y
 * dos llamadas (quitar a uno, agregar a otro) pueden quedar a la mitad.
 */
labAuthoringRoutes.put('/:id/mentors', async (c) => {
  const { ids } = idsBody.parse(await c.req.json());
  const db = c.get('db');
  const lab = await loadLab(db, c.req.param('id'));
  const mentorIds = [...new Set(ids)];

  await assertUsersHaveRole(db, mentorIds, 'mentor', 'mentores');

  await db.transaction(async (tx) => {
    await tx
      .delete(laboratoryMentors)
      .where(eq(laboratoryMentors.laboratoryId, lab.id));
    if (mentorIds.length > 0) {
      await tx.insert(laboratoryMentors).values(
        mentorIds.map((userId) => ({ laboratoryId: lab.id, userId })),
      );
    }
  });

  return c.json({ mentorIds });
});

/**
 * Reemplaza los estudiantes asignados.
 *
 * Ojo con lo que esto significa: `student_laboratories` es también lo que da
 * acceso a los CURSOS del laboratorio (regla `studentHasCourse` para Enactus).
 * Quitar a alguien de acá le quita el acceso a ese material — su avance no se
 * borra, pero deja de verlo.
 */
labAuthoringRoutes.put('/:id/students', async (c) => {
  const { ids } = idsBody.parse(await c.req.json());
  const db = c.get('db');
  const lab = await loadLab(db, c.req.param('id'));
  const studentIds = [...new Set(ids)];

  await assertEnactusStudents(db, studentIds);

  await db.transaction(async (tx) => {
    await tx
      .delete(studentLaboratories)
      .where(eq(studentLaboratories.laboratoryId, lab.id));
    if (studentIds.length > 0) {
      await tx.insert(studentLaboratories).values(
        studentIds.map((studentId) => ({ laboratoryId: lab.id, studentId })),
      );
    }
  });

  return c.json({ studentIds });
});

// ---------------------------------------------------------------------------
// Fases (se editan; no se crean ni se borran)
// ---------------------------------------------------------------------------

export const phaseRoutes = new Hono<AppEnv>();
phaseRoutes.use('*', requireAuth, requireRole(...ADMIN_ROLES));

phaseRoutes.patch('/:id', async (c) => {
  const body = phaseUpdate.parse(await c.req.json());
  const db = c.get('db');
  const phase = await loadPhase(db, c.req.param('id'));

  const [updated] = await db
    .update(phases)
    .set({ ...body, updatedAt: new Date() })
    .where(eq(phases.id, phase.id))
    .returning();

  return c.json(updated);
});

phaseRoutes.post('/:id/modules', async (c) => {
  const body = moduleBody.parse(await c.req.json());
  const db = c.get('db');
  const phase = await loadPhase(db, c.req.param('id'));

  const [{ next } = { next: 1 }] = await db.execute<{ next: number }>(sql`
    select coalesce(max(order_index), 0) + 1 as next
      from ruta_modules where phase_id = ${phase.id}
  `);

  const [created] = await db
    .insert(rutaModules)
    .values({ phaseId: phase.id, orderIndex: next, title: body.title })
    .returning();

  await afterStructuralChange(db, phase.id, phase.laboratoryId);
  return c.json(created, 201);
});

/** Mismo mecanismo de dos pasadas que el resto: hay un `unique(phase, order)`. */
phaseRoutes.put('/:id/modules/order', async (c) => {
  const { orderedIds } = reorderBody.parse(await c.req.json());
  const db = c.get('db');
  const phase = await loadPhase(db, c.req.param('id'));

  const existing = await db
    .select({ id: rutaModules.id })
    .from(rutaModules)
    .where(eq(rutaModules.phaseId, phase.id));

  const existingIds = new Set(existing.map((m) => m.id));
  const alien = orderedIds.filter((id) => !existingIds.has(id));
  const missing = existing.filter((m) => !orderedIds.includes(m.id));
  if (alien.length > 0 || missing.length > 0) {
    throw conflict(
      'La lista tiene que incluir exactamente los módulos de esta fase, una sola vez cada uno.',
      { alien, missing: missing.map((m) => m.id) },
    );
  }

  // Dos pasadas, como en el resto de los reordenamientos, pero **desplazando
  // hacia arriba en vez de a negativos**: `ruta_modules` tiene un CHECK
  // `order_index > 0` que `course_modules` no tiene, así que el truco de usar
  // índices negativos como zona de paso revienta acá. El desplazamiento parte
  // del máximo actual, con lo que no puede chocar con ninguna fila viva.
  const [{ max } = { max: 0 }] = await db.execute<{ max: number }>(sql`
    select coalesce(max(order_index), 0) as max
      from ruta_modules where phase_id = ${phase.id}
  `);
  const offset = max + 1;
  await db.transaction(async (tx) => {
    for (const [i, id] of orderedIds.entries()) {
      await tx
        .update(rutaModules)
        .set({ orderIndex: offset + i })
        .where(eq(rutaModules.id, id));
    }
    for (const [i, id] of orderedIds.entries()) {
      await tx
        .update(rutaModules)
        .set({ orderIndex: i + 1, updatedAt: new Date() })
        .where(eq(rutaModules.id, id));
    }
  });

  await afterStructuralChange(db, phase.id, phase.laboratoryId);

  const ordered = await db
    .select()
    .from(rutaModules)
    .where(eq(rutaModules.phaseId, phase.id))
    .orderBy(asc(rutaModules.orderIndex));
  return c.json(ordered);
});

phaseRoutes.post('/:id/objectives', async (c) => {
  const body = objectiveBody.parse(await c.req.json());
  const db = c.get('db');
  const phase = await loadPhase(db, c.req.param('id'));

  const [{ next } = { next: 1 }] = await db.execute<{ next: number }>(sql`
    select coalesce(max(order_index), 0) + 1 as next
      from objectives where phase_id = ${phase.id}
  `);

  const [created] = await db
    .insert(objectives)
    .values({
      phaseId: phase.id,
      category: body.category,
      text: body.text,
      orderIndex: next,
    })
    .returning();

  return c.json(created, 201);
});

// ---------------------------------------------------------------------------
// Módulos de la Ruta
// ---------------------------------------------------------------------------

export const rutaModuleRoutes = new Hono<AppEnv>();
rutaModuleRoutes.use('*', requireAuth, requireRole(...ADMIN_ROLES));

rutaModuleRoutes.patch('/:id', async (c) => {
  const body = moduleBody.partial().parse(await c.req.json());
  const db = c.get('db');
  const mod = await loadRutaModule(db, c.req.param('id'));

  const [updated] = await db
    .update(rutaModules)
    .set({ ...body, updatedAt: new Date() })
    .where(eq(rutaModules.id, mod.id))
    .returning();

  return c.json(updated);
});

rutaModuleRoutes.delete('/:id', async (c) => {
  const db = c.get('db');
  const mod = await loadRutaModule(db, c.req.param('id'));

  // Se borra de verdad: sus lecciones propias y sus vínculos a cursos caen por
  // CASCADE. Los cursos en sí no se tocan — viven fuera de la Ruta.
  await db.delete(rutaModules).where(eq(rutaModules.id, mod.id));
  await renumberModules(db, mod.phaseId);
  await afterStructuralChange(db, mod.phaseId, mod.laboratoryId);

  return c.body(null, 204);
});

/**
 * Vincula cursos completos al módulo.
 *
 * Un curso vive en UN solo módulo por laboratorio: si ya está en otro módulo
 * de la misma Ruta, se responde 409 en vez de dejarlo contado dos veces en el
 * avance.
 */
rutaModuleRoutes.put('/:id/courses', async (c) => {
  const { ids } = idsBody.parse(await c.req.json());
  const db = c.get('db');
  const mod = await loadRutaModule(db, c.req.param('id'));
  const courseIds = [...new Set(ids)];

  if (courseIds.length > 0) {
    const repetidos = await db.execute<{ courseId: string; moduleTitle: string }>(sql`
      select rmc.course_id as "courseId", rm.title as "moduleTitle"
        from ruta_module_courses rmc
        join ruta_modules rm on rm.id = rmc.ruta_module_id
        join phases p on p.id = rm.phase_id
       where p.laboratory_id = ${mod.laboratoryId}
         and rmc.ruta_module_id <> ${mod.id}
         and rmc.course_id in ${inList(courseIds)}
    `);
    if (repetidos.length > 0) {
      throw conflict(
        'Hay cursos que ya están en otro módulo de esta Ruta. Un curso cuenta ' +
          'para un solo módulo: si no, su avance se contaría dos veces.',
        { courses: repetidos },
      );
    }
  }

  await db.transaction(async (tx) => {
    await tx
      .delete(rutaModuleCourses)
      .where(eq(rutaModuleCourses.rutaModuleId, mod.id));
    if (courseIds.length > 0) {
      await tx.insert(rutaModuleCourses).values(
        courseIds.map((courseId) => ({ rutaModuleId: mod.id, courseId })),
      );
    }
  });

  await bumpContentVersion(db, mod.laboratoryId);
  return c.json({ courseIds });
});

/** Lección propia del módulo: la lectura o entrega que no viene de un curso. */
rutaModuleRoutes.post('/:id/lessons', async (c) => {
  const body = ownLessonBody.parse(await c.req.json());
  const db = c.get('db');
  const mod = await loadRutaModule(db, c.req.param('id'));

  if (body.type === 'link' && !body.externalUrl) {
    throw conflict('Una lección de tipo enlace necesita su URL.');
  }

  const [{ next } = { next: 1 }] = await db.execute<{ next: number }>(sql`
    select coalesce(max(order_index), 0) + 1 as next
      from lessons where ruta_module_id = ${mod.id}
  `);

  const [created] = await db
    .insert(lessons)
    .values({
      rutaModuleId: mod.id,
      title: body.title,
      type: body.type,
      description: body.description,
      durationMin: body.durationMin,
      externalUrl: body.externalUrl ?? null,
      orderIndex: next,
    })
    .returning();

  await bumpContentVersion(db, mod.laboratoryId);
  return c.json(created, 201);
});

// ---------------------------------------------------------------------------
// Objetivos de fase
// ---------------------------------------------------------------------------

export const objectiveRoutes = new Hono<AppEnv>();
objectiveRoutes.use('*', requireAuth, requireRole(...ADMIN_ROLES));

objectiveRoutes.patch('/:id', async (c) => {
  const body = objectiveUpdate.parse(await c.req.json());
  const db = c.get('db');
  const objective = await loadObjective(db, c.req.param('id'));

  const [updated] = await db
    .update(objectives)
    .set({ ...body, updatedAt: new Date() })
    .where(eq(objectives.id, objective.id))
    .returning();

  return c.json(updated);
});

objectiveRoutes.delete('/:id', async (c) => {
  const db = c.get('db');
  const objective = await loadObjective(db, c.req.param('id'));
  await db.delete(objectives).where(eq(objectives.id, objective.id));
  return c.body(null, 204);
});

/**
 * Los cursos que hacen falta para dar el objetivo por cumplido.
 *
 * Se completa cuando el estudiante terminó el 100% de TODOS. Un objetivo sin
 * cursos **nunca se completa** —no se puede marcar a mano— y eso bloquea la
 * fase entera, así que la respuesta lo avisa en vez de dejarlo pasar callado.
 */
objectiveRoutes.put('/:id/courses', async (c) => {
  const { ids } = idsBody.parse(await c.req.json());
  const db = c.get('db');
  const objective = await loadObjective(db, c.req.param('id'));
  const courseIds = [...new Set(ids)];

  if (courseIds.length > 0) {
    const alive = await db.execute<{ id: string }>(
      sql`select id from courses
           where id in ${inList(courseIds)} and deleted_at is null`,
    );
    const missing = courseIds.filter((id) => !alive.some((r) => r.id === id));
    if (missing.length > 0) {
      throw conflict('Hay cursos que ya no existen.', { courses: missing });
    }
  }

  await db.transaction(async (tx) => {
    await tx
      .delete(objectiveCourses)
      .where(eq(objectiveCourses.objectiveId, objective.id));
    if (courseIds.length > 0) {
      await tx.insert(objectiveCourses).values(
        courseIds.map((courseId) => ({ objectiveId: objective.id, courseId })),
      );
    }
  });

  await bumpContentVersion(db, objective.laboratoryId);

  return c.json({
    courseIds,
    // Sin cursos el objetivo no se puede completar nunca, y con él se queda
    // trabada la fase entera para todo el laboratorio.
    neverCompletable: courseIds.length === 0,
  });
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function loadLab(db: Db, id: string) {
  const [lab] = await db
    .select()
    .from(laboratories)
    .where(and(eq(laboratories.id, id), isNull(laboratories.deletedAt)))
    .limit(1);
  if (!lab) throw notFound('No se encontró el laboratorio.');
  return lab;
}

async function loadPhase(db: Db, id: string) {
  const [phase] = await db.select().from(phases).where(eq(phases.id, id)).limit(1);
  if (!phase) throw notFound('No se encontró la fase.');
  return phase;
}

async function loadRutaModule(db: Db, id: string) {
  const [row] = await db.execute<{
    id: string;
    phaseId: string;
    laboratoryId: string;
  }>(sql`
    select rm.id, rm.phase_id as "phaseId", p.laboratory_id as "laboratoryId"
      from ruta_modules rm
      join phases p on p.id = rm.phase_id
     where rm.id = ${id}
     limit 1
  `);
  if (!row) throw notFound('No se encontró el módulo.');
  return row;
}

async function loadObjective(db: Db, id: string) {
  const [row] = await db.execute<{
    id: string;
    phaseId: string;
    laboratoryId: string;
  }>(sql`
    select o.id, o.phase_id as "phaseId", p.laboratory_id as "laboratoryId"
      from objectives o
      join phases p on p.id = o.phase_id
     where o.id = ${id}
     limit 1
  `);
  if (!row) throw notFound('No se encontró el objetivo.');
  return row;
}

/**
 * Después de agregar, borrar o reordenar módulos: el ÚLTIMO de la fase es el
 * de mentoría y ninguno más.
 *
 * Se recalcula en vez de confiar en que quien mueve un módulo se acuerde de
 * mover también el flag. Y sube `content_version`, contra la que los
 * certificados quedan anclados: agregar contenido después no invalida los ya
 * emitidos.
 */
async function afterStructuralChange(
  db: Db,
  phaseId: string,
  laboratoryId: string,
): Promise<void> {
  await db.execute(sql`
    update ruta_modules rm
       set is_mentorship_module = (rm.order_index = (
             select max(order_index) from ruta_modules where phase_id = ${phaseId}))
     where rm.phase_id = ${phaseId}
  `);
  await bumpContentVersion(db, laboratoryId);
}

async function bumpContentVersion(db: Db, laboratoryId: string): Promise<void> {
  await db
    .update(laboratories)
    .set({
      contentVersion: sql`${laboratories.contentVersion} + 1`,
      updatedAt: new Date(),
    })
    .where(eq(laboratories.id, laboratoryId));
}

/**
 * Deja los índices consecutivos (1..n) después de borrar un módulo.
 *
 * Igual que el reordenamiento, la zona de paso va HACIA ARRIBA: el CHECK
 * `ruta_modules_order_positive` prohíbe los negativos que sí usa el
 * renumerado de módulos de curso.
 */
async function renumberModules(db: Db, phaseId: string): Promise<void> {
  await db.execute(sql`
    with ordenados as (
      select id, row_number() over (order by order_index) as nuevo,
             (select coalesce(max(order_index), 0)
                from ruta_modules where phase_id = ${phaseId}) as tope
        from ruta_modules where phase_id = ${phaseId}
    )
    update ruta_modules rm set order_index = o.tope + o.nuevo
      from ordenados o where o.id = rm.id
  `);
  await db.execute(sql`
    with ordenados as (
      select id, row_number() over (order by order_index) as nuevo
        from ruta_modules where phase_id = ${phaseId}
    )
    update ruta_modules rm set order_index = o.nuevo
      from ordenados o where o.id = rm.id
  `);
}

async function assertSponsorIsCompany(
  db: Db,
  sponsorCompanyId: string | null | undefined,
): Promise<void> {
  if (!sponsorCompanyId) return;
  const [row] = await db.execute<{ role: string }>(sql`
    select role from users
     where id = ${sponsorCompanyId} and deleted_at is null limit 1
  `);
  if (!row || row.role !== 'company') {
    throw conflict('El patrocinador tiene que ser una cuenta de empresa.', {
      sponsorCompanyId,
    });
  }
}

/** Que cada id exista, esté vivo y tenga el rol que corresponde. */
async function assertUsersHaveRole(
  db: Db,
  ids: string[],
  role: string,
  plural: string,
): Promise<void> {
  if (ids.length === 0) return;
  const rows = await db.execute<{ id: string; role: string }>(
    sql`select id, role from users
         where id in ${inList(ids)} and deleted_at is null`,
  );
  const wrong = ids.filter((id) => {
    const found = rows.find((r) => r.id === id);
    return !found || found.role !== role;
  });
  if (wrong.length > 0) {
    throw conflict(`Hay cuentas que no son ${plural}.`, { users: wrong });
  }
}

/**
 * Los laboratorios son de estudiantes Enactus (y sus egresados).
 *
 * Un Open Learning en `student_laboratories` recibiría acceso a los cursos del
 * laboratorio sin haber pasado por Enactus, que es exactamente el aislamiento
 * que la API sostiene en todas las demás lecturas.
 */
async function assertEnactusStudents(db: Db, ids: string[]): Promise<void> {
  if (ids.length === 0) return;
  const rows = await db.execute<{
    id: string;
    role: string;
    studentType: string | null;
  }>(sql`
    select id, role, student_type as "studentType" from users
     where id in ${inList(ids)} and deleted_at is null
  `);
  const wrong = ids.filter((id) => {
    const found = rows.find((r) => r.id === id);
    if (!found) return true;
    const isStudent = found.role === 'student' || found.role === 'alumni';
    return !isStudent || found.studentType !== 'enactus';
  });
  if (wrong.length > 0) {
    throw conflict(
      'Un laboratorio es para estudiantes Enactus: hay cuentas que no lo son.',
      { users: wrong },
    );
  }
}

/** `in (…)` con parámetros, sin interpolar valores en el SQL. */
const inList = (values: string[]) =>
  sql`(${sql.join(
    values.map((v) => sql`${v}`),
    sql`, `,
  )})`;
