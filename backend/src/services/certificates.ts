import { randomInt } from 'node:crypto';
import { and, eq, isNull, sql } from 'drizzle-orm';

import type { Database } from '../db/client';
import { auditLog, certificates, laboratories, notifications, users } from '../db/schema';
import { conflict, notFound } from '../lib/errors';

/**
 * Emisión del certificado de Ruta de Impacto.
 *
 * Hoy `issueRutaCertificate` no comprueba su propio requisito: la pantalla
 * arma el desplegable solo con laboratorios completos y el método confía. Acá
 * se valida en el servidor y, además, lo hace cumplir un trigger de la base
 * (`certificates_require_complete_ruta`).
 */

export interface MissingRequirement {
  phaseId: string;
  phaseOrder: number;
  phaseTitle: string;
  modulesDone: number;
  modulesTotal: number;
  pendingModules: { moduleId: string; title: string }[];
}

export interface Eligibility {
  eligible: boolean;
  alreadyIssued: boolean;
  phasesDone: number;
  phasesTotal: number;
  missing: MissingRequirement[];
}

export async function rutaCertificateEligibility(
  db: Database,
  studentId: string,
  laboratoryId: string,
): Promise<Eligibility> {
  const [ruta] = await db.execute<{
    phases_done: number;
    phases_total: number;
    is_complete: boolean;
  }>(sql`
    select phases_done::int, phases_total::int, is_complete
      from ruta_completion
     where student_id = ${studentId} and laboratory_id = ${laboratoryId}
  `);

  if (!ruta) {
    // Sin fila en la vista, el estudiante no está asignado a ese laboratorio.
    throw notFound('El estudiante no está asignado a ese laboratorio.');
  }

  const [issued] = await db
    .select({ id: certificates.id })
    .from(certificates)
    .where(
      and(
        eq(certificates.studentId, studentId),
        eq(certificates.laboratoryId, laboratoryId),
      ),
    )
    .limit(1);

  const pendientes = await db.execute<{
    phase_id: string;
    phase_order: number;
    phase_title: string;
    modules_done: number;
    modules_total: number;
    module_id: string | null;
    module_title: string | null;
  }>(sql`
    select pc.phase_id, pc.order_index as phase_order, p.title as phase_title,
           pc.modules_done::int, pc.modules_total::int,
           rm.id as module_id, rm.title as module_title
      from phase_completion pc
      join phases p on p.id = pc.phase_id
      left join ruta_module_completion rmc
             on rmc.student_id = pc.student_id and rmc.is_complete = false
      left join ruta_modules rm
             on rm.id = rmc.ruta_module_id and rm.phase_id = pc.phase_id
     where pc.student_id = ${studentId}
       and pc.laboratory_id = ${laboratoryId}
       and pc.is_complete = false
     order by pc.order_index, rm.order_index
  `);

  const byPhase = new Map<string, MissingRequirement>();
  for (const row of pendientes) {
    const entry = byPhase.get(row.phase_id) ?? {
      phaseId: row.phase_id,
      phaseOrder: row.phase_order,
      phaseTitle: row.phase_title,
      modulesDone: row.modules_done,
      modulesTotal: row.modules_total,
      pendingModules: [],
    };
    if (row.module_id && row.module_title) {
      entry.pendingModules.push({ moduleId: row.module_id, title: row.module_title });
    }
    byPhase.set(row.phase_id, entry);
  }

  return {
    eligible: ruta.is_complete && !issued,
    alreadyIssued: Boolean(issued),
    phasesDone: ruta.phases_done,
    phasesTotal: ruta.phases_total,
    missing: [...byPhase.values()],
  };
}

/**
 * Horas del certificado: suma las horas de los cursos ÚNICOS asignados a los
 * módulos de las 3 fases (certificadas si el curso las tiene, si no las
 * estimadas). Misma regla que `DataProvider._rutaHours`.
 */
async function rutaHours(db: Database, laboratoryId: string): Promise<number> {
  const [row] = await db.execute<{ hours: number }>(sql`
    select coalesce(sum(
             case when c.certified_hours > 0 then c.certified_hours
                  else c.estimated_hours end), 0)::int as hours
      from (select distinct rmc.course_id
              from ruta_module_courses rmc
              join ruta_modules rm on rm.id = rmc.ruta_module_id
              join phases p on p.id = rm.phase_id
             where p.laboratory_id = ${laboratoryId}) uniq
      join courses c on c.id = uniq.course_id
     where c.deleted_at is null
  `);
  return row?.hours ?? 0;
}

/** Snapshot de lo que se exigía al emitir. Ver decisión B.1. */
async function requirementsSnapshot(
  db: Database,
  laboratoryId: string,
): Promise<unknown> {
  const rows = await db.execute<{
    phase_id: string;
    order_index: number;
    modules: string[];
    courses: string[];
  }>(sql`
    select p.id as phase_id, p.order_index,
           coalesce(array_agg(distinct rm.id::text) filter (where rm.id is not null), '{}') as modules,
           coalesce(array_agg(distinct rmc.course_id::text) filter (where rmc.course_id is not null), '{}') as courses
      from phases p
      left join ruta_modules rm on rm.phase_id = p.id
      left join ruta_module_courses rmc on rmc.ruta_module_id = rm.id
     where p.laboratory_id = ${laboratoryId}
     group by p.id, p.order_index
     order by p.order_index
  `);
  return { phases: rows };
}

export async function issueRutaCertificate(
  db: Database,
  input: { studentId: string; laboratoryId: string; issuerId: string; ip: string },
): Promise<typeof certificates.$inferSelect> {
  const eligibility = await rutaCertificateEligibility(
    db,
    input.studentId,
    input.laboratoryId,
  );

  if (eligibility.alreadyIssued) {
    throw conflict('Ese estudiante ya tiene el certificado de este laboratorio.');
  }
  if (!eligibility.eligible) {
    throw conflict(
      `La Ruta de Impacto no está completa: ${eligibility.phasesDone} de ${eligibility.phasesTotal} fases.`,
      {
        phasesDone: eligibility.phasesDone,
        phasesTotal: eligibility.phasesTotal,
        missing: eligibility.missing,
      },
    );
  }

  const [student] = await db
    .select()
    .from(users)
    .where(and(eq(users.id, input.studentId), isNull(users.deletedAt)))
    .limit(1);
  if (!student) throw notFound('No se encontró el estudiante.');

  const [lab] = await db
    .select()
    .from(laboratories)
    .where(eq(laboratories.id, input.laboratoryId))
    .limit(1);
  if (!lab) throw notFound('No se encontró el laboratorio.');

  const [issuer] = await db
    .select({ name: users.name })
    .from(users)
    .where(eq(users.id, input.issuerId))
    .limit(1);

  const [created] = await db
    .insert(certificates)
    .values({
      code: `ENC-${new Date().getFullYear()}-${randomInt(10000, 99999)}`,
      studentId: student.id,
      laboratoryId: lab.id,
      issuerId: input.issuerId,
      studentNameSnapshot: student.name,
      laboratoryNameSnapshot: lab.name,
      issuerNameSnapshot: issuer?.name ?? '',
      hours: await rutaHours(db, lab.id),
      labContentVersion: lab.contentVersion,
      requirementsSnapshot: await requirementsSnapshot(db, lab.id),
    })
    .returning();

  await db.insert(notifications).values({
    userId: student.id,
    title: 'Nuevo certificado',
    body: `Recibiste el certificado por completar la Ruta de Impacto de ${lab.name}.`,
  });

  await db.insert(auditLog).values({
    actorId: input.issuerId,
    action: 'certificate.issue',
    entityType: 'certificate',
    entityId: created!.id,
    newValue: {
      studentId: student.id,
      laboratoryId: lab.id,
      code: created!.code,
      hours: created!.hours,
    },
    ip: input.ip,
  });

  return created!;
}
