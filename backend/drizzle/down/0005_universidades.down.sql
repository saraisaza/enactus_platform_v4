-- Reverso de 0005_universidades.
--
-- Deja la base exactamente como estaba: `users.university` y
-- `groups.university` nunca se tocaron, así que el código anterior vuelve a
-- funcionar con solo quitar lo que se agregó. Ese es el punto de que R1 sea
-- puramente aditivo.
--
-- SÍ se pierde el trabajo del relleno —las universidades creadas y el mapeo—
-- y eso es correcto: el relleno es idempotente, así que volver a aplicar la
-- migración lo reconstruye desde el texto, que sigue ahí intacto.

DROP INDEX IF EXISTS "projects_university_id_idx";--> statement-breakpoint
DROP INDEX IF EXISTS "users_advisor_id_idx";--> statement-breakpoint
DROP INDEX IF EXISTS "users_university_id_idx";--> statement-breakpoint

ALTER TABLE "projects" DROP CONSTRAINT IF EXISTS "projects_university_id_universities_id_fk";--> statement-breakpoint
ALTER TABLE "users" DROP CONSTRAINT IF EXISTS "users_advisor_id_users_id_fk";--> statement-breakpoint
ALTER TABLE "users" DROP CONSTRAINT IF EXISTS "users_university_id_universities_id_fk";--> statement-breakpoint

ALTER TABLE "projects" DROP COLUMN IF EXISTS "university_id";--> statement-breakpoint
ALTER TABLE "users" DROP COLUMN IF EXISTS "advisor_id";--> statement-breakpoint
ALTER TABLE "users" DROP COLUMN IF EXISTS "university_id";--> statement-breakpoint

-- Las puente primero: tienen FK contra `universities`.
DROP TABLE IF EXISTS "university_advisors";--> statement-breakpoint
DROP TABLE IF EXISTS "laboratory_lxds";--> statement-breakpoint
DROP TABLE IF EXISTS "universities";--> statement-breakpoint

DROP FUNCTION IF EXISTS enactus_normalizar_universidad(text);
