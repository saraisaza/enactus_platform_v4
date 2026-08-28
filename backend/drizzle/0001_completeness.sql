-- Completitud de la Ruta de Impacto, como vistas de PostgreSQL.
--
-- Hoy toda esta lógica vive en el navegador (`data_provider.dart`, líneas
-- 178-311) y se recalcula en cada `build()`. Acá se traduce una por una,
-- conservando las reglas exactas — incluidos los tres detalles que NO son
-- obvios y que la auditoría dejó anotados:
--
--   1. Un módulo sin nada configurado NUNCA cuenta como completo (evita que
--      un módulo vacío se vea "listo" antes de que el Admin lo configure).
--   2. Un objetivo sin cursos vinculados NUNCA se completa: no se puede
--      marcar a mano.
--   3. La completitud se DERIVA, no se guarda. Si un LXD agrega un curso a un
--      módulo, el módulo deja de estar completo solo. Ninguna columna
--      `is_complete` que se pueda desincronizar.

-- ---------------------------------------------------------------------------
-- Acceso a cursos: la regla `DataProvider.studentHasCourse`
-- ---------------------------------------------------------------------------
-- Enactus: automático, todo curso de un laboratorio asignado (sin asignar el
-- curso aparte). Open Learning: SOLO los asignados directamente. Son
-- excluyentes, igual que hoy: a un Enactus no se le miran sus `courseIds`.
CREATE VIEW student_course_access AS
  SELECT u.id AS student_id, c.id AS course_id
    FROM users u
    JOIN student_laboratories sl ON sl.student_id = u.id
    JOIN courses c ON c.laboratory_id = sl.laboratory_id
   WHERE u.student_type = 'enactus'
     AND u.deleted_at IS NULL
     AND c.deleted_at IS NULL
  UNION
  SELECT u.id AS student_id, c.id AS course_id
    FROM users u
    JOIN student_courses sc ON sc.student_id = u.id
    JOIN courses c ON c.id = sc.course_id
   WHERE u.student_type = 'open_learning'
     AND u.deleted_at IS NULL
     AND c.deleted_at IS NULL;
--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- Curso completo → TODAS sus lecciones completas para ese estudiante
-- ---------------------------------------------------------------------------
-- Diferencia deliberada con Flutter: allá el avance es
-- `completedLessonIds.length / lessonCount` y no comprueba que los ids
-- guardados sigan correspondiendo a lecciones existentes; si el LXD borra una
-- lección ya completada, el avance puede pasar de 100%. Acá se cuentan solo
-- lecciones que existen hoy.
CREATE VIEW course_progress AS
  SELECT a.student_id,
         a.course_id,
         count(l.id)                    AS total_lessons,
         count(pl.lesson_id)            AS completed_lessons,
         CASE WHEN count(l.id) = 0 THEN 0::numeric
              ELSE round(count(pl.lesson_id)::numeric / count(l.id), 4)
         END                            AS ratio,
         (count(l.id) > 0 AND count(pl.lesson_id) = count(l.id)) AS is_complete
    FROM student_course_access a
    LEFT JOIN course_modules cm ON cm.course_id = a.course_id
    LEFT JOIN lessons l ON l.course_module_id = cm.id
    LEFT JOIN progress p
           ON p.student_id = a.student_id AND p.course_id = a.course_id
    LEFT JOIN progress_lessons pl
           ON pl.progress_id = p.id AND pl.lesson_id = l.id
   GROUP BY a.student_id, a.course_id;
--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- Objetivo completo → TODOS sus cursos vinculados al 100%
-- ---------------------------------------------------------------------------
-- Un curso al que el estudiante no tiene acceso no aparece en
-- `course_progress`, así que el LEFT JOIN lo deja en NULL y el objetivo queda
-- incompleto — el mismo resultado que hoy da `courseProgress` devolviendo 0.
CREATE VIEW objective_completion AS
  SELECT o.id AS objective_id,
         sl.student_id,
         count(oc.course_id)                              AS courses_total,
         count(*) FILTER (WHERE cp.is_complete)           AS courses_done,
         (count(oc.course_id) > 0
          AND count(oc.course_id) = count(*) FILTER (WHERE cp.is_complete))
                                                          AS is_complete
    FROM objectives o
    JOIN phases ph ON ph.id = o.phase_id
    JOIN student_laboratories sl ON sl.laboratory_id = ph.laboratory_id
    LEFT JOIN objective_courses oc ON oc.objective_id = o.id
    LEFT JOIN course_progress cp
           ON cp.course_id = oc.course_id AND cp.student_id = sl.student_id
   GROUP BY o.id, sl.student_id;
--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- Módulo completo → TODAS sus lecturas/entregas propias marcadas
--                   Y TODOS sus cursos asignados al 100%
-- ---------------------------------------------------------------------------
CREATE VIEW ruta_module_completion AS
  SELECT rm.id AS ruta_module_id,
         sl.student_id,
         own.total AS own_lessons_total,
         own.done  AS own_lessons_done,
         crs.total AS courses_total,
         crs.done  AS courses_done,
         -- Detalle 1: un módulo sin nada configurado no está completo.
         ((own.total + crs.total) > 0
          AND own.done = own.total
          AND crs.done = crs.total) AS is_complete
    FROM ruta_modules rm
    JOIN phases ph ON ph.id = rm.phase_id
    JOIN student_laboratories sl ON sl.laboratory_id = ph.laboratory_id
    CROSS JOIN LATERAL (
      SELECT count(l.id)          AS total,
             count(rpl.lesson_id) AS done
        FROM lessons l
        LEFT JOIN ruta_progress rp
               ON rp.student_id = sl.student_id
              AND rp.laboratory_id = ph.laboratory_id
        LEFT JOIN ruta_progress_lessons rpl
               ON rpl.ruta_progress_id = rp.id AND rpl.lesson_id = l.id
       WHERE l.ruta_module_id = rm.id
    ) own
    CROSS JOIN LATERAL (
      SELECT count(rmc.course_id)                    AS total,
             count(*) FILTER (WHERE cp.is_complete)  AS done
        FROM ruta_module_courses rmc
        LEFT JOIN course_progress cp
               ON cp.course_id = rmc.course_id AND cp.student_id = sl.student_id
       WHERE rmc.ruta_module_id = rm.id
    ) crs;
--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- Fase completa → al menos un módulo, y todos completos
-- ---------------------------------------------------------------------------
CREATE VIEW phase_completion AS
  SELECT ph.id AS phase_id,
         ph.laboratory_id,
         ph.order_index,
         sl.student_id,
         count(rm.id)                            AS modules_total,
         count(*) FILTER (WHERE rmc.is_complete) AS modules_done,
         (count(rm.id) > 0
          AND count(rm.id) = count(*) FILTER (WHERE rmc.is_complete))
                                                 AS is_complete
    FROM phases ph
    JOIN student_laboratories sl ON sl.laboratory_id = ph.laboratory_id
    LEFT JOIN ruta_modules rm ON rm.phase_id = ph.id
    LEFT JOIN ruta_module_completion rmc
           ON rmc.ruta_module_id = rm.id AND rmc.student_id = sl.student_id
   GROUP BY ph.id, ph.laboratory_id, ph.order_index, sl.student_id;
--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- Ruta completa → todas las fases del laboratorio completas
-- ---------------------------------------------------------------------------
CREATE VIEW ruta_completion AS
  SELECT lab.id AS laboratory_id,
         sl.student_id,
         count(ph.id)                           AS phases_total,
         count(*) FILTER (WHERE pc.is_complete) AS phases_done,
         (count(ph.id) > 0
          AND count(ph.id) = count(*) FILTER (WHERE pc.is_complete))
                                                AS is_complete
    FROM laboratories lab
    JOIN student_laboratories sl ON sl.laboratory_id = lab.id
    LEFT JOIN phases ph ON ph.laboratory_id = lab.id
    LEFT JOIN phase_completion pc
           ON pc.phase_id = ph.id AND pc.student_id = sl.student_id
   WHERE lab.deleted_at IS NULL
   GROUP BY lab.id, sl.student_id;
--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- Desbloqueo de fases: la 1 siempre; cada siguiente exige la anterior completa
-- ---------------------------------------------------------------------------
CREATE VIEW phase_unlocked AS
  SELECT pc.phase_id,
         pc.student_id,
         (pc.order_index = 1
          OR coalesce(prev.is_complete, false)) AS is_unlocked
    FROM phase_completion pc
    LEFT JOIN phases prev_ph
           ON prev_ph.laboratory_id = pc.laboratory_id
          AND prev_ph.order_index = pc.order_index - 1
    LEFT JOIN phase_completion prev
           ON prev.phase_id = prev_ph.id AND prev.student_id = pc.student_id;
--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- Guardia del certificado
-- ---------------------------------------------------------------------------
-- El endpoint valida esto antes de emitir, pero además lo hace cumplir la
-- base: hoy `issueRutaCertificate` no comprueba su propio requisito (lo hace
-- la pantalla al armar el desplegable), y esa es exactamente la clase de
-- garantía que no puede vivir en el cliente.
CREATE FUNCTION can_issue_ruta_certificate(p_student_id uuid, p_laboratory_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce(
    (SELECT rc.is_complete
       FROM ruta_completion rc
      WHERE rc.student_id = p_student_id
        AND rc.laboratory_id = p_laboratory_id),
    false);
$$;
--> statement-breakpoint

CREATE FUNCTION enforce_ruta_certificate_requirements()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT can_issue_ruta_certificate(NEW.student_id, NEW.laboratory_id) THEN
    RAISE EXCEPTION
      'No se puede emitir el certificado: la Ruta de Impacto del laboratorio % no está completa para el estudiante %',
      NEW.laboratory_id, NEW.student_id
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
--> statement-breakpoint

CREATE TRIGGER certificates_require_complete_ruta
  BEFORE INSERT ON certificates
  FOR EACH ROW
  EXECUTE FUNCTION enforce_ruta_certificate_requirements();
