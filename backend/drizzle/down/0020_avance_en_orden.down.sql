-- Reverso de 0020_avance_en_orden.
--
-- Se pierden los tramos vistos: el código anterior no los conoce y completa
-- un video con la posición, como antes.
ALTER TABLE "lesson_video_progress" DROP CONSTRAINT IF EXISTS "lesson_video_progress_watched_valid";
ALTER TABLE "lesson_video_progress" DROP COLUMN IF EXISTS "watched_sec";
ALTER TABLE "lesson_video_progress" DROP COLUMN IF EXISTS "watched_segments";
