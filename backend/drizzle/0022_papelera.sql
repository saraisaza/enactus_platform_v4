CREATE TABLE "papelera" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tabla" text NOT NULL,
	"fila_id" text NOT NULL,
	"datos" jsonb NOT NULL,
	"borrado_en" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE INDEX "papelera_tabla_fila_idx" ON "papelera" USING btree ("tabla","fila_id");--> statement-breakpoint
CREATE INDEX "papelera_borrado_en_idx" ON "papelera" USING btree ("borrado_en");--> statement-breakpoint
-- La copia se hace en la base, con un trigger BEFORE DELETE: atrapa los
-- borrados que hace la API, los que llegan en cascada (las lecciones de un
-- módulo borrado) y los que se hagan a mano. Puramente aditiva: el código que
-- borra sigue igual y la API anterior funciona sobre esta base.
CREATE OR REPLACE FUNCTION "public"."guardar_en_papelera"() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO "papelera" ("tabla", "fila_id", "datos")
  VALUES (TG_TABLE_NAME, OLD."id"::text, to_jsonb(OLD));
  RETURN OLD;
END
$$;--> statement-breakpoint
DROP TRIGGER IF EXISTS "lessons_a_papelera" ON "lessons";--> statement-breakpoint
CREATE TRIGGER "lessons_a_papelera" BEFORE DELETE ON "lessons"
  FOR EACH ROW EXECUTE FUNCTION "public"."guardar_en_papelera"();--> statement-breakpoint
DROP TRIGGER IF EXISTS "course_modules_a_papelera" ON "course_modules";--> statement-breakpoint
CREATE TRIGGER "course_modules_a_papelera" BEFORE DELETE ON "course_modules"
  FOR EACH ROW EXECUTE FUNCTION "public"."guardar_en_papelera"();--> statement-breakpoint
DROP TRIGGER IF EXISTS "ruta_modules_a_papelera" ON "ruta_modules";--> statement-breakpoint
CREATE TRIGGER "ruta_modules_a_papelera" BEFORE DELETE ON "ruta_modules"
  FOR EACH ROW EXECUTE FUNCTION "public"."guardar_en_papelera"();--> statement-breakpoint
DROP TRIGGER IF EXISTS "objectives_a_papelera" ON "objectives";--> statement-breakpoint
CREATE TRIGGER "objectives_a_papelera" BEFORE DELETE ON "objectives"
  FOR EACH ROW EXECUTE FUNCTION "public"."guardar_en_papelera"();--> statement-breakpoint
DROP TRIGGER IF EXISTS "glossary_terms_a_papelera" ON "glossary_terms";--> statement-breakpoint
CREATE TRIGGER "glossary_terms_a_papelera" BEFORE DELETE ON "glossary_terms"
  FOR EACH ROW EXECUTE FUNCTION "public"."guardar_en_papelera"();--> statement-breakpoint
DROP TRIGGER IF EXISTS "certificate_templates_a_papelera" ON "certificate_templates";--> statement-breakpoint
CREATE TRIGGER "certificate_templates_a_papelera" BEFORE DELETE ON "certificate_templates"
  FOR EACH ROW EXECUTE FUNCTION "public"."guardar_en_papelera"();
