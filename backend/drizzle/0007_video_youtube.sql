-- Video de YouTube guardado como id, y hasta dónde lo vio cada estudiante.
--
-- Puramente aditivo, que es lo que lo hace seguro entre migrar y publicar:
-- un valor de enum, una columna anulable, una tabla nueva y un CHECK que
-- ACEPTA TODO LO QUE ACEPTABA ANTES (las tres ramas viejas quedan idénticas;
-- solo se suma la de `youtube`). El código anterior corre contra este esquema
-- sin enterarse.
--
-- `IF NOT EXISTS` no lo pone drizzle-kit, va a mano: PostgreSQL no sabe quitar
-- un valor de un enum, así que el reverso lo deja puesto, y sin esto volver a
-- aplicar 0007 después de un rollback fallaría con «already exists».
--
-- El CHECK de origen compara `video_type::text = 'youtube'` y no contra el
-- enum. Ver el comentario en `src/db/schema/courses.ts`: usar el enum acá
-- funciona contra una base vacía (CI) y FALLA al desplegar sobre una que ya
-- existe, porque el valor nuevo todavía no está confirmado.
ALTER TYPE "public"."video_type" ADD VALUE IF NOT EXISTS 'youtube';--> statement-breakpoint
CREATE TABLE "lesson_video_progress" (
	"student_id" uuid NOT NULL,
	"lesson_id" uuid NOT NULL,
	"position_sec" integer DEFAULT 0 NOT NULL,
	"furthest_sec" integer DEFAULT 0 NOT NULL,
	"duration_sec" integer,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "lesson_video_progress_student_id_lesson_id_pk" PRIMARY KEY("student_id","lesson_id"),
	CONSTRAINT "lesson_video_progress_positions_valid" CHECK ("lesson_video_progress"."position_sec" >= 0 and "lesson_video_progress"."furthest_sec" >= "lesson_video_progress"."position_sec"
          and ("lesson_video_progress"."duration_sec" is null or "lesson_video_progress"."duration_sec" > 0))
);
--> statement-breakpoint
ALTER TABLE "lessons" DROP CONSTRAINT "lessons_video_source";--> statement-breakpoint
ALTER TABLE "lessons" ADD COLUMN "video_youtube_id" text;--> statement-breakpoint
ALTER TABLE "lesson_video_progress" ADD CONSTRAINT "lesson_video_progress_student_id_users_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "lesson_video_progress" ADD CONSTRAINT "lesson_video_progress_lesson_id_lessons_id_fk" FOREIGN KEY ("lesson_id") REFERENCES "public"."lessons"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "lesson_video_progress_lesson_id_idx" ON "lesson_video_progress" USING btree ("lesson_id");--> statement-breakpoint
ALTER TABLE "lessons" ADD CONSTRAINT "lessons_video_youtube_id_format" CHECK ("lessons"."video_youtube_id" is null or "lessons"."video_youtube_id" ~ '^[A-Za-z0-9_-]{11}$');--> statement-breakpoint
ALTER TABLE "lessons" ADD CONSTRAINT "lessons_video_source" CHECK (("lessons"."video_type" is null and "lessons"."video_url" is null and "lessons"."video_s3_key" is null)
       or ("lessons"."video_type" = 'external' and "lessons"."video_url" is not null and "lessons"."video_s3_key" is null)
       or ("lessons"."video_type" = 'uploaded' and "lessons"."video_s3_key" is not null and "lessons"."video_url" is null)
       or ("lessons"."video_type"::text = 'youtube' and "lessons"."video_youtube_id" is not null and "lessons"."video_url" is null and "lessons"."video_s3_key" is null));
