-- Encuestas de verdad (pedido de Sara, 2026-10-14).
--
-- 1. `quiz_kind` suma 'scale': calificar de 1 a 5. Junto con 'multiple'
--    (elegir una opción, sin respuesta correcta) y 'short' (comentario), son
--    los tipos de pregunta de una encuesta.
-- 2. `survey_responses`: la respuesta de cada persona, por pregunta. Antes se
--    mandaba como una entrega y caía en la cola de calificación del LXD.
--
-- Las encuestas que ya existen tenían solo preguntas abiertas ('short'):
-- siguen funcionando, como preguntas de comentario.
-- IF NOT EXISTS: el reverso no puede quitar el valor del tipo, así que
-- volver a migrar después de revertir lo encuentra ya puesto.
ALTER TYPE "public"."quiz_kind" ADD VALUE IF NOT EXISTS 'scale';--> statement-breakpoint
CREATE TABLE "survey_responses" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"lesson_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"answers" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "survey_responses" ADD CONSTRAINT "survey_responses_lesson_id_lessons_id_fk" FOREIGN KEY ("lesson_id") REFERENCES "public"."lessons"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "survey_responses" ADD CONSTRAINT "survey_responses_student_id_users_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "survey_responses_lesson_student_unique" ON "survey_responses" USING btree ("lesson_id","student_id");--> statement-breakpoint
CREATE INDEX "survey_responses_lesson_id_idx" ON "survey_responses" USING btree ("lesson_id");