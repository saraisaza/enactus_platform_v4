-- Reverso de 0022: sin los triggers, sin la función y sin la papelera. Lo que
-- estaba en la papelera se pierde: es una copia, nada vivo depende de ella.
DROP TRIGGER IF EXISTS "lessons_a_papelera" ON "lessons";
DROP TRIGGER IF EXISTS "course_modules_a_papelera" ON "course_modules";
DROP TRIGGER IF EXISTS "ruta_modules_a_papelera" ON "ruta_modules";
DROP TRIGGER IF EXISTS "objectives_a_papelera" ON "objectives";
DROP TRIGGER IF EXISTS "glossary_terms_a_papelera" ON "glossary_terms";
DROP TRIGGER IF EXISTS "certificate_templates_a_papelera" ON "certificate_templates";
DROP FUNCTION IF EXISTS "public"."guardar_en_papelera"();
DROP TABLE IF EXISTS "papelera";
