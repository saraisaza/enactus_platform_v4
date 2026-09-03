import { and, asc, eq, inArray, isNull, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';

import {
  auditLog,
  courses,
  laboratories,
  studentCourses,
  studentLaboratories,
  users,
} from '../db/schema';
import { conflict, notFound } from '../lib/errors';
import {
  ADMIN_ROLES,
  currentUser,
  isStudentLike,
  requireAuth,
  requireRole,
} from '../middleware/auth';
import type { AppEnv } from '../middleware/context';

type Db = AppEnv['Variables']['db'];

/**
 * Asignación de material a UN estudiante: sus laboratorios o sus cursos.
 *
 * Existía la mitad del camino y no se notaba. `PUT /laboratories/:id/students`
 * asigna desde el laboratorio hacia las personas —sirve para matricular a un
 * grupo entero de una vez— pero no había ninguna forma de pararse en un
 * estudiante y ver o cambiar lo suyo. Y `student_courses`, la única vía de
 * acceso de Open Learning, **no la escribía ningún endpoint**: la tabla y la
 * vista `student_course_access` existían desde la primera migración, pero solo
 * el sembrado ponía filas ahí. En producción una cuenta de Open Learning no
 * podía recibir un curso por ningún medio.
 *
 * Las dos vías son excluyentes por diseño, igual que en `student_course_access`:
 *
 * - **Enactus** recibe laboratorios. Los cursos le llegan solos, por ser del
 *   laboratorio; asignarle cursos sueltos no haría nada visible.
 * - **Open Learning** recibe cursos directos. No tiene laboratorios ni Ruta.
 *
 * Pedir la vía que no corresponde devuelve 409 con el motivo, no un 200 que no
 * cambia nada: una asignación que se guarda y no surte efecto es peor que un
 * error, porque nadie la vuelve a mirar.
 */
export const assignmentRoutes = new Hono<AppEnv>();
assignmentRoutes.use('*', requireAuth, requireRole(...ADMIN_ROLES));

const idsBody = z.object({
  ids: z.array(z.uuid()).default([]),
});

/** Carga al estudiante y confirma que lo es. */
async function loadStudent(db: Db, id: string) {
  const [row] = await db
    .select()
    .from(users)
    .where(and(eq(users.id, id), isNull(users.deletedAt)))
    .limit(1);
  if (!row || !isStudentLike(row.role)) {
    throw notFound('No se encontró el estudiante.');
  }
  return row;
}

/**
 * Exige que la cuenta sea del tipo que puede recibir esta clase de material.
 *
 * El mensaje dice qué hacer, no solo qué falló: el motivo real casi siempre es
 * que la cuenta se creó con el tipo equivocado, y eso se corrige en la ficha.
 */
function assertTipo(
  student: { studentType: string | null; name: string },
  esperado: 'enactus' | 'open_learning',
): void {
  if (student.studentType === esperado) return;

  const explicacion =
    esperado === 'enactus'
      ? `${student.name} es de Open Learning: no tiene laboratorios ni Ruta de Impacto. ` +
        'Asígnele cursos directamente, o cambie el tipo de cuenta en su ficha.'
      : `${student.name} es de eduXaction: sus cursos le llegan por el laboratorio, ` +
        'no de a uno. Asígnele el laboratorio que corresponda.';

  throw conflict(explicacion, {
    studentType: student.studentType,
    expected: esperado,
  });
}

/** Que cada id exista y siga vivo. */
async function assertExisten(
  db: Db,
  ids: string[],
  tabla: typeof laboratories | typeof courses,
  falta: string,
): Promise<void> {
  if (ids.length === 0) return;
  const rows = await db
    .select({ id: tabla.id })
    .from(tabla)
    .where(and(inArray(tabla.id, ids), isNull(tabla.deletedAt)));
  const encontrados = new Set(rows.map((r) => r.id));
  const faltantes = ids.filter((id) => !encontrados.has(id));
  if (faltantes.length > 0) {
    throw conflict(falta, { ids: faltantes });
  }
}

/**
 * Lo que este estudiante tiene asignado hoy.
 *
 * Devuelve las DOS listas siempre —no solo la que le corresponde por tipo— para
 * que la pantalla pueda mostrar el estado real. Si una cuenta cambió de tipo
 * después de recibir material, las filas viejas siguen en la base aunque la
 * vista de acceso ya no las mire: esconderlas acá dejaría al administrador sin
 * forma de enterarse de por qué alguien no ve lo que debería.
 */
assignmentRoutes.get('/:id/assignments', async (c) => {
  const db = c.get('db');
  const student = await loadStudent(db, c.req.param('id'));

  const [labs, cursos] = await Promise.all([
    db
      .select({ id: studentLaboratories.laboratoryId })
      .from(studentLaboratories)
      .innerJoin(
        laboratories,
        and(
          eq(laboratories.id, studentLaboratories.laboratoryId),
          isNull(laboratories.deletedAt),
        ),
      )
      .where(eq(studentLaboratories.studentId, student.id))
      .orderBy(asc(laboratories.name)),
    db
      .select({ id: studentCourses.courseId })
      .from(studentCourses)
      .innerJoin(
        courses,
        and(eq(courses.id, studentCourses.courseId), isNull(courses.deletedAt)),
      )
      .where(eq(studentCourses.studentId, student.id))
      .orderBy(asc(courses.name)),
  ]);

  return c.json({
    studentId: student.id,
    studentName: student.name,
    studentType: student.studentType,
    laboratoryIds: labs.map((l) => l.id),
    courseIds: cursos.map((x) => x.id),
  });
});

/**
 * Reemplaza los laboratorios de un estudiante Enactus.
 *
 * Reemplazo y no alta/baja de a uno, por el mismo motivo que en
 * `PUT /laboratories/:id/students`: la pantalla edita la lista completa, y dos
 * llamadas pueden quedar a la mitad.
 *
 * Quitar un laboratorio le quita el acceso a sus cursos. El avance no se borra
 * —las filas de `progress` siguen ahí— pero deja de verlo, y volverá a verlo
 * tal cual si se le reasigna.
 */
assignmentRoutes.put('/:id/laboratories', async (c) => {
  const { ids } = idsBody.parse(await c.req.json());
  const db = c.get('db');
  const admin = currentUser(c);
  const student = await loadStudent(db, c.req.param('id'));
  assertTipo(student, 'enactus');

  const laboratoryIds = [...new Set(ids)];
  await assertExisten(
    db,
    laboratoryIds,
    laboratories,
    'Hay laboratorios que ya no existen.',
  );

  const antes = await db
    .select({ id: studentLaboratories.laboratoryId })
    .from(studentLaboratories)
    .where(eq(studentLaboratories.studentId, student.id));

  await db.transaction(async (tx) => {
    await tx
      .delete(studentLaboratories)
      .where(eq(studentLaboratories.studentId, student.id));
    if (laboratoryIds.length > 0) {
      await tx.insert(studentLaboratories).values(
        laboratoryIds.map((laboratoryId) => ({
          studentId: student.id,
          laboratoryId,
        })),
      );
    }
  });

  await db.insert(auditLog).values({
    actorId: admin.id,
    action: 'student.laboratories',
    entityType: 'user',
    entityId: student.id,
    oldValue: { laboratoryIds: antes.map((r) => r.id) },
    newValue: { laboratoryIds },
    ip: c.get('requestIp'),
  });

  return c.json({ studentId: student.id, laboratoryIds });
});

/**
 * Reemplaza los cursos directos de un estudiante de Open Learning.
 *
 * Es la ÚNICA vía de acceso a material para esas cuentas: sin filas acá, un
 * estudiante de Open Learning entra a la plataforma y no tiene nada que hacer.
 *
 * Se permite asignar un curso que todavía está en borrador o no visible. No es
 * un descuido: deja preparar la matrícula antes de publicar. Lo que no se
 * permite es que pase inadvertido — la respuesta trae `notReady` con esos
 * cursos para que la pantalla lo diga, porque hasta que se publiquen el
 * estudiante no los va a ver aunque la asignación esté hecha.
 */
assignmentRoutes.put('/:id/courses', async (c) => {
  const { ids } = idsBody.parse(await c.req.json());
  const db = c.get('db');
  const admin = currentUser(c);
  const student = await loadStudent(db, c.req.param('id'));
  assertTipo(student, 'open_learning');

  const courseIds = [...new Set(ids)];
  await assertExisten(db, courseIds, courses, 'Hay cursos que ya no existen.');

  const antes = await db
    .select({ id: studentCourses.courseId })
    .from(studentCourses)
    .where(eq(studentCourses.studentId, student.id));

  await db.transaction(async (tx) => {
    await tx
      .delete(studentCourses)
      .where(eq(studentCourses.studentId, student.id));
    if (courseIds.length > 0) {
      await tx.insert(studentCourses).values(
        courseIds.map((courseId) => ({ studentId: student.id, courseId })),
      );
    }
  });

  // Cuáles de los asignados todavía no puede ver, y por qué.
  const notReady =
    courseIds.length === 0
      ? []
      : await db
          .select({ id: courses.id, name: courses.name })
          .from(courses)
          .where(
            and(
              inArray(courses.id, courseIds),
              sql`(${courses.status} <> 'published' or ${courses.visible} = false)`,
            ),
          );

  await db.insert(auditLog).values({
    actorId: admin.id,
    action: 'student.courses',
    entityType: 'user',
    entityId: student.id,
    oldValue: { courseIds: antes.map((r) => r.id) },
    newValue: { courseIds },
    ip: c.get('requestIp'),
  });

  return c.json({ studentId: student.id, courseIds, notReady });
});
