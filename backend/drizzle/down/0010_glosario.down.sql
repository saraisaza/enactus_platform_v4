-- Reverso de 0010_glosario.
--
-- Quita las cuatro tablas y la restricción única de `course_modules`. SÍ se
-- pierden los términos del glosario y el repaso de cada estudiante: no hay
-- otro lugar donde guardarlos, y el código anterior no los conoce.
--
-- Primero las tablas que apuntan a `glossary_terms`, después esa, y al final
-- la restricción: mientras exista la clave foránea compuesta, PostgreSQL no
-- deja quitarla.

DROP TABLE IF EXISTS "glossary_reviews";--> statement-breakpoint
DROP TABLE IF EXISTS "glossary_term_related";--> statement-breakpoint
DROP TABLE IF EXISTS "glossary_term_lessons";--> statement-breakpoint
DROP TABLE IF EXISTS "glossary_terms";--> statement-breakpoint
ALTER TABLE "course_modules" DROP CONSTRAINT IF EXISTS "course_modules_id_course_unique";
