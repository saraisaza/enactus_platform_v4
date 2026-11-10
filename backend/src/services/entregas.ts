import { sql } from 'drizzle-orm';

import type { Database } from '../db/client';
import { isStudentLike } from '../middleware/auth';
import type { AuthUser } from '../middleware/context';

/**
 * Una entrega con fecha: lo que el calendario recuerda y lo que el inicio
 * cuenta como «entregas de esta semana».
 *
 * - `course_activity`: una actividad de un curso, con la fecha límite que le
 *   puso el LXD.
 * - `lab_phase`: una fase de la Ruta de un laboratorio, con la fecha que le
 *   puso el Admin.
 * - `lab_activity`: una entrega propia de un módulo de la Ruta.
 */
export interface Entrega {
  kind: 'course_activity' | 'lab_phase' | 'lab_activity';
  /** El id de la lección (actividad) o de la fase. */
  id: string;
  title: string;
  /** `AAAA-MM-DD`: un día, sin hora. */
  dueDate: string;
  /** Ya la entregó (actividad) o ya completó la fase. */
  done: boolean;
  courseId: string | null;
  courseName: string | null;
  laboratoryId: string | null;
  laboratoryName: string | null;
  /** Solo en lo que es de un laboratorio: el número de la fase. */
  phaseOrder: number | null;
}

interface Fila extends Record<string, unknown> {
  kind: Entrega['kind'];
  id: string;
  title: string;
  due_date: string;
  done: boolean;
  course_id: string | null;
  course_name: string | null;
  laboratory_id: string | null;
  laboratory_name: string | null;
  phase_order: number | null;
}

/**
 * Las entregas con fecha de quien pregunta, en orden de fecha.
 *
 * Solo las tiene quien estudia (estudiante, alumni, empleado de una
 * empresa): los demás roles reciben una lista vacía, no un error, porque su
 * calendario pide lo mismo y no tiene nada que recordarles.
 *
 * El alcance es el de siempre y no uno nuevo: los cursos salen de
 * `student_course_access` —publicados y visibles, igual que en Mis Cursos— y
 * los laboratorios de `student_laboratories`. Una actividad cuenta como
 * entregada desde que se manda, aunque nadie la haya calificado todavía: lo
 * que se recuerda es entregar, no la nota.
 */
export async function entregasDe(db: Database, user: AuthUser): Promise<Entrega[]> {
  if (!isStudentLike(user.role)) return [];

  // Los laboratorios son del mundo Enactus: a un Open Learning o al empleado
  // de una empresa no se le miran, igual que en `/students/:id/ruta-progress`.
  const conLaboratorios = user.studentType === 'enactus';

  const filas = await db.execute<Fila>(sql`
    select 'course_activity' as kind, l.id, l.title, a.deadline::text as due_date,
           (exists (select 1 from submissions s
                     where s.student_id = ${user.id} and s.lesson_id = l.id
                       and s.deleted_at is null)
            or exists (select 1 from progress p
                         join progress_lessons pl on pl.progress_id = p.id
                        where p.student_id = ${user.id} and p.course_id = c.id
                          and pl.lesson_id = l.id)) as done,
           c.id as course_id, c.name as course_name,
           lab.id as laboratory_id, lab.name as laboratory_name,
           null::int as phase_order
      from student_course_access acc
      join courses c on c.id = acc.course_id
      join course_modules cm on cm.course_id = c.id
      join lessons l on l.course_module_id = cm.id and l.type = 'activity'
      join lesson_activities a on a.lesson_id = l.id and a.deadline is not null
      left join laboratories lab on lab.id = c.laboratory_id and lab.deleted_at is null
     where acc.student_id = ${user.id}
       and c.status = 'published' and c.visible and c.deleted_at is null

    union all

    select 'lab_phase' as kind, ph.id, ph.title, ph.deadline::text as due_date,
           pc.is_complete as done,
           null::uuid as course_id, null::text as course_name,
           lab.id as laboratory_id, lab.name as laboratory_name,
           ph.order_index as phase_order
      from phase_completion pc
      join phases ph on ph.id = pc.phase_id and ph.deadline is not null
      join laboratories lab on lab.id = ph.laboratory_id and lab.deleted_at is null
     where pc.student_id = ${user.id} and ${conLaboratorios}

    union all

    select 'lab_activity' as kind, l.id, l.title, a.deadline::text as due_date,
           (exists (select 1 from submissions s
                     where s.student_id = ${user.id} and s.lesson_id = l.id
                       and s.deleted_at is null)
            or exists (select 1 from ruta_progress rp
                         join ruta_progress_lessons rpl on rpl.ruta_progress_id = rp.id
                        where rp.student_id = ${user.id}
                          and rp.laboratory_id = ph.laboratory_id
                          and rpl.lesson_id = l.id)) as done,
           null::uuid as course_id, null::text as course_name,
           lab.id as laboratory_id, lab.name as laboratory_name,
           ph.order_index as phase_order
      from student_laboratories sl
      join phases ph on ph.laboratory_id = sl.laboratory_id
      join ruta_modules rm on rm.phase_id = ph.id
      join lessons l on l.ruta_module_id = rm.id and l.type = 'activity'
      join lesson_activities a on a.lesson_id = l.id and a.deadline is not null
      join laboratories lab on lab.id = ph.laboratory_id and lab.deleted_at is null
     where sl.student_id = ${user.id} and ${conLaboratorios}

     order by due_date, title, id
  `);

  return filas.map((f) => ({
    kind: f.kind,
    id: f.id,
    title: f.title,
    dueDate: f.due_date,
    done: f.done,
    courseId: f.course_id,
    courseName: f.course_name,
    laboratoryId: f.laboratory_id,
    laboratoryName: f.laboratory_name,
    phaseOrder: f.phase_order,
  }));
}
