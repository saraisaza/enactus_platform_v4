-- Reverso de 0001_completeness.sql
--
-- Orden inverso al de creación: primero el trigger y sus funciones, después
-- las vistas de arriba hacia abajo (cada una depende de la anterior).

DROP TRIGGER IF EXISTS certificates_require_complete_ruta ON certificates;
DROP FUNCTION IF EXISTS enforce_ruta_certificate_requirements();
DROP FUNCTION IF EXISTS can_issue_ruta_certificate(uuid, uuid);

DROP VIEW IF EXISTS phase_unlocked;
DROP VIEW IF EXISTS ruta_completion;
DROP VIEW IF EXISTS phase_completion;
DROP VIEW IF EXISTS ruta_module_completion;
DROP VIEW IF EXISTS objective_completion;
DROP VIEW IF EXISTS course_progress;
DROP VIEW IF EXISTS student_course_access;
