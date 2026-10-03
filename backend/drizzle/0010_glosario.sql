-- Glosario de los cursos.
--
-- Cuatro tablas nuevas: los términos (uno por módulo, sin repetir dentro del
-- curso), las lecciones donde aparece cada uno, sus términos relacionados y
-- lo que cada estudiante marcó en el modo repaso.
--
-- Puramente aditiva salvo una restricción única sobre `course_modules`
-- (id, course_id), redundante con la clave primaria: no puede fallar con
-- datos existentes. El código anterior sigue funcionando sobre esta base, así
-- que se puede migrar ANTES de desplegar la API nueva.
--
-- La restricción va PRIMERO: la clave foránea compuesta de `glossary_terms`
-- apunta a esas dos columnas y PostgreSQL exige que el único exista antes.
-- drizzle-kit la generaba al final, y así la migración fallaba.

ALTER TABLE "course_modules" ADD CONSTRAINT "course_modules_id_course_unique" UNIQUE("id","course_id");--> statement-breakpoint
CREATE TABLE "glossary_reviews" (
	"student_id" uuid NOT NULL,
	"term_id" uuid NOT NULL,
	"status" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "glossary_reviews_student_id_term_id_pk" PRIMARY KEY("student_id","term_id"),
	CONSTRAINT "glossary_reviews_status_valid" CHECK ("glossary_reviews"."status" in ('known', 'review'))
);
--> statement-breakpoint
CREATE TABLE "glossary_term_lessons" (
	"term_id" uuid NOT NULL,
	"lesson_id" uuid NOT NULL,
	CONSTRAINT "glossary_term_lessons_term_id_lesson_id_pk" PRIMARY KEY("term_id","lesson_id")
);
--> statement-breakpoint
CREATE TABLE "glossary_term_related" (
	"term_id" uuid NOT NULL,
	"related_term_id" uuid NOT NULL,
	CONSTRAINT "glossary_term_related_term_id_related_term_id_pk" PRIMARY KEY("term_id","related_term_id"),
	CONSTRAINT "glossary_term_related_not_self" CHECK ("glossary_term_related"."term_id" <> "glossary_term_related"."related_term_id")
);
--> statement-breakpoint
CREATE TABLE "glossary_terms" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"course_id" uuid NOT NULL,
	"module_id" uuid NOT NULL,
	"order_index" integer NOT NULL,
	"word" text NOT NULL,
	"word_key" text GENERATED ALWAYS AS (lower(btrim(regexp_replace(translate("glossary_terms"."word", 'ÁÀÂÄÃáàâäãÉÈÊËéèêëÍÌÎÏíìîïÓÒÔÖÕóòôöõÚÙÛÜúùûüÑ', 'aaaaaaaaaaeeeeeeeeiiiiiiiioooooooooouuuuuuuuñ'), '\s+', ' ', 'g')) collate "C")) STORED,
	"short_definition" text NOT NULL,
	"explanation" text DEFAULT '' NOT NULL,
	"example" text DEFAULT '' NOT NULL,
	"image_s3_key" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "glossary_terms_course_word_unique" UNIQUE("course_id","word_key"),
	CONSTRAINT "glossary_terms_module_order_unique" UNIQUE("module_id","order_index"),
	CONSTRAINT "glossary_terms_word_not_blank" CHECK (btrim("glossary_terms"."word") <> ''),
	CONSTRAINT "glossary_terms_short_definition_not_blank" CHECK (btrim("glossary_terms"."short_definition") <> '')
);
--> statement-breakpoint
ALTER TABLE "glossary_reviews" ADD CONSTRAINT "glossary_reviews_student_id_users_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "glossary_reviews" ADD CONSTRAINT "glossary_reviews_term_id_glossary_terms_id_fk" FOREIGN KEY ("term_id") REFERENCES "public"."glossary_terms"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "glossary_term_lessons" ADD CONSTRAINT "glossary_term_lessons_term_id_glossary_terms_id_fk" FOREIGN KEY ("term_id") REFERENCES "public"."glossary_terms"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "glossary_term_lessons" ADD CONSTRAINT "glossary_term_lessons_lesson_id_lessons_id_fk" FOREIGN KEY ("lesson_id") REFERENCES "public"."lessons"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "glossary_term_related" ADD CONSTRAINT "glossary_term_related_term_id_glossary_terms_id_fk" FOREIGN KEY ("term_id") REFERENCES "public"."glossary_terms"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "glossary_term_related" ADD CONSTRAINT "glossary_term_related_related_term_id_glossary_terms_id_fk" FOREIGN KEY ("related_term_id") REFERENCES "public"."glossary_terms"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "glossary_terms" ADD CONSTRAINT "glossary_terms_course_id_courses_id_fk" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "glossary_terms" ADD CONSTRAINT "glossary_terms_module_course_fk" FOREIGN KEY ("module_id","course_id") REFERENCES "public"."course_modules"("id","course_id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "glossary_reviews_term_id_idx" ON "glossary_reviews" USING btree ("term_id");--> statement-breakpoint
CREATE INDEX "glossary_term_lessons_lesson_id_idx" ON "glossary_term_lessons" USING btree ("lesson_id");--> statement-breakpoint
CREATE INDEX "glossary_term_related_related_idx" ON "glossary_term_related" USING btree ("related_term_id");--> statement-breakpoint
CREATE INDEX "glossary_terms_course_id_idx" ON "glossary_terms" USING btree ("course_id");
