-- Reverso de 0008_video_subido.
--
-- Las keys que quedaron en la cola sin borrar se pierden con la tabla: los
-- archivos siguen en S3 y no los referencia nadie. Se pueden encontrar después
-- comparando el bucket contra `lessons` (prefijo `lessons/`).
DROP TRIGGER IF EXISTS "lessons_queue_file_deletion" ON "lessons";--> statement-breakpoint
DROP FUNCTION IF EXISTS "public"."queue_lesson_files_for_deletion"();--> statement-breakpoint
DROP TABLE IF EXISTS "storage_pending_deletes";--> statement-breakpoint
ALTER TABLE "lessons" DROP COLUMN IF EXISTS "video_uploaded_at";--> statement-breakpoint
ALTER TABLE "lessons" DROP COLUMN IF EXISTS "video_original_name";--> statement-breakpoint
ALTER TABLE "lessons" DROP COLUMN IF EXISTS "video_thumbnail_s3_key";
