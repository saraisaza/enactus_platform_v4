-- El Manager / Supervisor de una empresa, y los cursos exclusivos.
--
-- 1. `user_role` suma 'supervisor': la cuenta de una empresa cliente que ve a
--    su gente, sus entregas, su avance y quién se certificó. Tiene que tener
--    cliente (la regla compara como texto: el valor nuevo no se puede usar
--    como enum en la misma transacción en que se agrega).
-- 2. `courses.client_id`: un curso exclusivo de una empresa solo se asigna a
--    cuentas de esa empresa. Un curso de laboratorio (Enactus) no puede serlo.
--
-- Solo agrega: un valor de enum, una columna anulable, su índice y dos
-- reglas que ninguna fila actual incumple.
-- IF NOT EXISTS: el reverso no puede quitar el valor del tipo, así que
-- volver a migrar después de revertir lo encuentra ya puesto.
ALTER TYPE "public"."user_role" ADD VALUE IF NOT EXISTS 'supervisor';--> statement-breakpoint
ALTER TABLE "courses" ADD COLUMN "client_id" uuid;--> statement-breakpoint
ALTER TABLE "courses" ADD CONSTRAINT "courses_client_id_clients_id_fk" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "courses_client_id_idx" ON "courses" USING btree ("client_id");--> statement-breakpoint
ALTER TABLE "users" ADD CONSTRAINT "users_supervisor_con_cliente" CHECK ("users"."role"::text <> 'supervisor' or "users"."client_id" is not null);--> statement-breakpoint
ALTER TABLE "courses" ADD CONSTRAINT "courses_exclusivo_sin_laboratorio" CHECK ("courses"."client_id" is null or "courses"."laboratory_id" is null);