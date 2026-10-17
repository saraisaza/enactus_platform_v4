-- Reverso de 0021: los eventos de laboratorio y de organización se borran
-- (no hay a qué tipo viejo pasarlos sin que los vea gente que no debía), y
-- vuelve la regla anterior. Los valores del tipo quedan: Postgres no los
-- quita.
DELETE FROM "calendar_events" WHERE "type"::text IN ('laboratorio', 'organizacion');
ALTER TABLE "calendar_events" DROP CONSTRAINT "calendar_events_target_matches_type";
DROP INDEX IF EXISTS "calendar_events_client_id_idx";
ALTER TABLE "calendar_events" DROP CONSTRAINT IF EXISTS "calendar_events_client_id_clients_id_fk";
ALTER TABLE "calendar_events" DROP COLUMN IF EXISTS "client_id";
ALTER TABLE "calendar_events" ADD CONSTRAINT "calendar_events_target_matches_type" CHECK (("calendar_events"."type" = 'open_learning_sync' and "calendar_events"."course_id" is not null and "calendar_events"."laboratory_id" is null)
       or ("calendar_events"."type" in ('ruta_impacto','mentoria') and "calendar_events"."course_id" is null));
