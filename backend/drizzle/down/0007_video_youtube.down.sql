-- Reverso de 0007_video_youtube.
--
-- A diferencia del reverso de 0002, este NO falla a propósito cuando hay
-- datos que el esquema anterior no admite: las lecciones `youtube` se
-- convierten a `external` con el enlace reconstruido desde el id. La
-- conversión no pierde nada —el id es todo lo que había— y el código anterior
-- ya sabe reproducir un enlace de YouTube (lo embebe en un iframe). Exigirle a
-- alguien que lo haga a mano a las 2 de la mañana no protegería ningún dato.
--
-- LO QUE SÍ SE PIERDE: las posiciones de reproducción de `lesson_video_progress`.
-- Es correcto —es el dato que esta migración introdujo— y no toca la
-- completitud: las lecciones completadas viven en `progress_lessons`.
--
-- El valor `youtube` del enum QUEDA. PostgreSQL no permite quitar un valor
-- de un enum sin recrear el tipo y reescribir las columnas que lo usan, y
-- dejarlo es inofensivo: el CHECK restaurado no deja guardarlo. Por eso 0007
-- lo agrega con `IF NOT EXISTS`, para poder volver a aplicarse.

UPDATE "lessons"
   SET "video_type" = 'external',
       "video_url" = 'https://www.youtube.com/watch?v=' || "video_youtube_id",
       "video_youtube_id" = NULL
 WHERE "video_type"::text = 'youtube';--> statement-breakpoint

DROP TABLE IF EXISTS "lesson_video_progress";--> statement-breakpoint

ALTER TABLE "lessons" DROP CONSTRAINT IF EXISTS "lessons_video_source";--> statement-breakpoint
ALTER TABLE "lessons" DROP CONSTRAINT IF EXISTS "lessons_video_youtube_id_format";--> statement-breakpoint
ALTER TABLE "lessons" DROP COLUMN IF EXISTS "video_youtube_id";--> statement-breakpoint

ALTER TABLE "lessons" ADD CONSTRAINT "lessons_video_source" CHECK (("lessons"."video_type" is null and "lessons"."video_url" is null and "lessons"."video_s3_key" is null)
       or ("lessons"."video_type" = 'external' and "lessons"."video_url" is not null and "lessons"."video_s3_key" is null)
       or ("lessons"."video_type" = 'uploaded' and "lessons"."video_s3_key" is not null and "lessons"."video_url" is null));
