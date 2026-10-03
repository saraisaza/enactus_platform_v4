-- Video subido como archivo: portada, nombre original y fecha de subida, y la
-- cola de archivos de S3 que ya nadie referencia.
--
-- Puramente aditivo: tres columnas anulables, una tabla y un trigger que solo
-- ESCRIBE en esa tabla nueva. El código anterior corre contra este esquema sin
-- enterarse — no lee las columnas y el trigger no le cambia ninguna escritura.
--
-- El trigger va a mano (drizzle-kit no los genera). Es la única forma de ver
-- las lecciones que se van en cascada al borrar un módulo: esas filas nunca
-- pasan por el código. Solo anota keys de `lessons/`, las que genera la
-- subida; las del seed no, porque staging y producción comparten el bucket.
-- Borrar de S3 lo hace la API después del commit (`services/storage-cleanup.ts`),
-- y antes comprueba que la key no haya vuelto a quedar referenciada.
CREATE TABLE "storage_pending_deletes" (
	"key" text PRIMARY KEY NOT NULL,
	"reason" text NOT NULL,
	"attempts" integer DEFAULT 0 NOT NULL,
	"last_error" text,
	"last_attempt_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "lessons" ADD COLUMN "video_thumbnail_s3_key" text;--> statement-breakpoint
ALTER TABLE "lessons" ADD COLUMN "video_original_name" text;--> statement-breakpoint
ALTER TABLE "lessons" ADD COLUMN "video_uploaded_at" timestamp with time zone;--> statement-breakpoint
CREATE INDEX "storage_pending_deletes_created_at_idx" ON "storage_pending_deletes" USING btree ("created_at");--> statement-breakpoint
CREATE OR REPLACE FUNCTION "public"."queue_lesson_files_for_deletion"() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    INSERT INTO "storage_pending_deletes" ("key", "reason")
    SELECT k, 'lesson_deleted'
      FROM unnest(ARRAY[OLD."video_s3_key", OLD."video_thumbnail_s3_key"]) AS k
     WHERE k LIKE 'lessons/%'
    ON CONFLICT ("key") DO NOTHING;
    RETURN OLD;
  END IF;

  IF OLD."video_s3_key" LIKE 'lessons/%'
     AND OLD."video_s3_key" IS DISTINCT FROM NEW."video_s3_key" THEN
    INSERT INTO "storage_pending_deletes" ("key", "reason")
    VALUES (OLD."video_s3_key", 'video_replaced')
    ON CONFLICT ("key") DO NOTHING;
  END IF;

  IF OLD."video_thumbnail_s3_key" LIKE 'lessons/%'
     AND OLD."video_thumbnail_s3_key" IS DISTINCT FROM NEW."video_thumbnail_s3_key" THEN
    INSERT INTO "storage_pending_deletes" ("key", "reason")
    VALUES (OLD."video_thumbnail_s3_key", 'thumbnail_replaced')
    ON CONFLICT ("key") DO NOTHING;
  END IF;

  RETURN NEW;
END
$$;--> statement-breakpoint
DROP TRIGGER IF EXISTS "lessons_queue_file_deletion" ON "lessons";--> statement-breakpoint
CREATE TRIGGER "lessons_queue_file_deletion"
  AFTER DELETE OR UPDATE OF "video_s3_key", "video_thumbnail_s3_key" ON "lessons"
  FOR EACH ROW EXECUTE FUNCTION "public"."queue_lesson_files_for_deletion"();
