-- Reverso de 0002_early_stellaris.sql
--
-- Restaura el CHECK. Si al momento de revertir hay lecciones de video sin
-- origen (creadas mientras el CHECK no existía), el ALTER falla — y está
-- bien que falle: revertir no puede fingir que esos datos son válidos.

ALTER TABLE "lessons" ADD CONSTRAINT "lessons_video_type_requires_source"
  CHECK ("type" <> 'video' OR video_type IS NOT NULL);
