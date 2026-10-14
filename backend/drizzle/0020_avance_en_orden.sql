-- Avance en orden y sin marcar a mano (pedido de Sara, 2026-10-14).
--
-- Una estudiante de la prueba beta marcaba lecciones como completas tocando
-- el círculo, sin ver el video ni leer el material. Desde ahora cada lección
-- se completa con su prueba (`services/avance-de-leccion.ts`), y la de un
-- video es haberlo VISTO: los tramos reproducidos, no la posición a la que
-- se adelantó.
--
-- Los avances que ya existen empiezan sin tramos vistos: lo que se guardó
-- antes no distingue ver de adelantar. Las lecciones ya completadas siguen
-- completadas; un video a medias se vuelve a ver para completarlo.
ALTER TABLE "lesson_video_progress" ADD COLUMN "watched_segments" jsonb DEFAULT '[]'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "lesson_video_progress" ADD COLUMN "watched_sec" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "lesson_video_progress" ADD CONSTRAINT "lesson_video_progress_watched_valid" CHECK ("lesson_video_progress"."watched_sec" >= 0);