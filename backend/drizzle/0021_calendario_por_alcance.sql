-- Eventos del calendario por alcance (pedido de Sara, 2026-10-17).
--
-- El LXD y el admin agendan para un curso, para un laboratorio o para toda
-- una organización (su empresa, o Enactus).
--
-- 1. `calendar_event_type` suma 'laboratorio' (lo ven los estudiantes, los
--    mentores y los asesores del laboratorio) y 'organizacion' (lo ve toda
--    la gente de un cliente). IF NOT EXISTS: el reverso no puede quitar un
--    valor de un tipo, así que volver a migrar lo encuentra puesto.
-- 2. `client_id`: el cliente de un evento de organización.
-- 3. La regla de qué lleva cada tipo compara `type::text`: los valores nuevos
--    no se pueden usar como tipo en la misma transacción en que se agregan, y
--    la migración entera va en una.
--
-- Los eventos que ya existen no cambian.
ALTER TYPE "public"."calendar_event_type" ADD VALUE IF NOT EXISTS 'laboratorio';--> statement-breakpoint
ALTER TYPE "public"."calendar_event_type" ADD VALUE IF NOT EXISTS 'organizacion';--> statement-breakpoint
ALTER TABLE "calendar_events" DROP CONSTRAINT "calendar_events_target_matches_type";--> statement-breakpoint
ALTER TABLE "calendar_events" ADD COLUMN "client_id" uuid;--> statement-breakpoint
ALTER TABLE "calendar_events" ADD CONSTRAINT "calendar_events_client_id_clients_id_fk" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "calendar_events_client_id_idx" ON "calendar_events" USING btree ("client_id");--> statement-breakpoint
ALTER TABLE "calendar_events" ADD CONSTRAINT "calendar_events_target_matches_type" CHECK (("calendar_events"."type"::text = 'open_learning_sync' and "calendar_events"."course_id" is not null and "calendar_events"."laboratory_id" is null and "calendar_events"."client_id" is null)
       or ("calendar_events"."type"::text in ('ruta_impacto','mentoria') and "calendar_events"."course_id" is null and "calendar_events"."client_id" is null)
       or ("calendar_events"."type"::text = 'laboratorio' and "calendar_events"."laboratory_id" is not null and "calendar_events"."course_id" is null and "calendar_events"."client_id" is null)
       or ("calendar_events"."type"::text = 'organizacion' and "calendar_events"."client_id" is not null and "calendar_events"."course_id" is null and "calendar_events"."laboratory_id" is null));