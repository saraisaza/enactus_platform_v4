-- Reverso de 0015_supervisores_y_cursos_exclusivos.
--
-- Los cursos dejan de ser exclusivos (vuelven a poder asignarse a cualquiera).
-- Las cuentas de supervisor pasan a mentor, con el mismo cliente: el código
-- anterior no conoce el rol. El valor 'supervisor' QUEDA en el tipo
-- `user_role`, sin uso: PostgreSQL no permite quitar un valor de un enum sin
-- recrear el tipo y todas las columnas que lo usan.
ALTER TABLE "courses" DROP CONSTRAINT IF EXISTS "courses_exclusivo_sin_laboratorio";
ALTER TABLE "users" DROP CONSTRAINT IF EXISTS "users_supervisor_con_cliente";
UPDATE "users" SET "role" = 'mentor' WHERE "role"::text = 'supervisor';
DROP INDEX IF EXISTS "courses_client_id_idx";
ALTER TABLE "courses" DROP CONSTRAINT IF EXISTS "courses_client_id_clients_id_fk";
ALTER TABLE "courses" DROP COLUMN IF EXISTS "client_id";
