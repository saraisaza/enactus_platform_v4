-- Reverso de 0009_moderacion_foro.
--
-- Quita las dos tablas. SÍ se pierden los reportes y los bloqueos que se
-- hayan hecho mientras existieron: no hay otro lugar donde guardarlos, y el
-- código anterior no los conoce.

DROP TABLE IF EXISTS "user_blocks";--> statement-breakpoint
DROP TABLE IF EXISTS "forum_reports";
