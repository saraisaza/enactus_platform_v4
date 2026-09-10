CREATE TABLE "universities" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"slug" text NOT NULL,
	"short_name" text DEFAULT '' NOT NULL,
	"city" text DEFAULT '' NOT NULL,
	"country" text DEFAULT 'Colombia' NOT NULL,
	"active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "laboratory_lxds" (
	"laboratory_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "laboratory_lxds_laboratory_id_user_id_pk" PRIMARY KEY("laboratory_id","user_id")
);
--> statement-breakpoint
CREATE TABLE "university_advisors" (
	"university_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "university_advisors_university_id_user_id_pk" PRIMARY KEY("university_id","user_id")
);
--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "university_id" uuid;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "advisor_id" uuid;--> statement-breakpoint
ALTER TABLE "projects" ADD COLUMN "university_id" uuid;--> statement-breakpoint
ALTER TABLE "laboratory_lxds" ADD CONSTRAINT "laboratory_lxds_laboratory_id_laboratories_id_fk" FOREIGN KEY ("laboratory_id") REFERENCES "public"."laboratories"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "laboratory_lxds" ADD CONSTRAINT "laboratory_lxds_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "university_advisors" ADD CONSTRAINT "university_advisors_university_id_universities_id_fk" FOREIGN KEY ("university_id") REFERENCES "public"."universities"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "university_advisors" ADD CONSTRAINT "university_advisors_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "universities_slug_unique" ON "universities" USING btree ("slug") WHERE "universities"."deleted_at" is null;--> statement-breakpoint
CREATE INDEX "universities_active_idx" ON "universities" USING btree ("active");--> statement-breakpoint
CREATE INDEX "universities_deleted_at_idx" ON "universities" USING btree ("deleted_at");--> statement-breakpoint
CREATE INDEX "laboratory_lxds_user_id_idx" ON "laboratory_lxds" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "university_advisors_user_id_idx" ON "university_advisors" USING btree ("user_id");--> statement-breakpoint
ALTER TABLE "users" ADD CONSTRAINT "users_university_id_universities_id_fk" FOREIGN KEY ("university_id") REFERENCES "public"."universities"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "users" ADD CONSTRAINT "users_advisor_id_users_id_fk" FOREIGN KEY ("advisor_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "projects" ADD CONSTRAINT "projects_university_id_universities_id_fk" FOREIGN KEY ("university_id") REFERENCES "public"."universities"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "users_university_id_idx" ON "users" USING btree ("university_id");--> statement-breakpoint
CREATE INDEX "users_advisor_id_idx" ON "users" USING btree ("advisor_id");--> statement-breakpoint
CREATE INDEX "projects_university_id_idx" ON "projects" USING btree ("university_id");--> statement-breakpoint
-- ===========================================================================
-- RELLENO. Idempotente: correrlo dos veces no duplica nada.
--
-- Todo lo de arriba es aditivo —tablas, columnas anulables, índices— así que
-- el código VIEJO sigue corriendo contra este esquema sin enterarse. Eso es
-- lo que hace que este despliegue sea reversible por sí solo: entre migrar y
-- publicar, el código anterior no ve ninguna diferencia.
--
-- Nada se descarta en silencio: lo que no se pueda mapear va a la universidad
-- marcadora «Sin asignar» y sale en el reporte de integridad.
-- ===========================================================================

-- La normalización, escrita a mano y no con `unaccent`.
--
-- `unaccent` es una EXTENSIÓN de Postgres y no está instalada en esta RDS.
-- Depender de ella convertiría una regla de integridad del dominio en un
-- requisito de infraestructura escondido: la migración funcionaría en la
-- máquina de quien la escribió y fallaría al desplegar. `translate` es SQL
-- estándar y viaja con la migración.
--
-- Ojo: las dos cadenas de `translate` tienen que medir lo mismo en
-- CARACTERES, no en bytes.
CREATE OR REPLACE FUNCTION enactus_normalizar_universidad(texto text)
RETURNS text
LANGUAGE sql IMMUTABLE
AS $$
  SELECT nullif(
    regexp_replace(
      lower(trim(translate(
        coalesce(texto, ''),
        'áàäâãéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ',
        'aaaaaeeeeiiiiooooouuuuncAAAAAEEEEIIIIOOOOOUUUUNC'
      ))),
      '\s+', ' ', 'g'
    ),
    ''
  );
$$;
--> statement-breakpoint

-- 1. Una universidad por variante normalizada.
--
-- El nombre canónico es la variante MÁS FRECUENTE; si empatan, la más larga
-- —«Universidad de los Andes» le gana a «U. de los Andes», que es lo que
-- alguien querría ver en una lista.
INSERT INTO universities (name, slug)
SELECT DISTINCT ON (slug) nombre, slug
FROM (
  SELECT
    enactus_normalizar_universidad(u.university) AS slug,
    trim(u.university)                            AS nombre,
    count(*)                                      AS veces
  FROM users u
  WHERE enactus_normalizar_universidad(u.university) IS NOT NULL
  GROUP BY 1, 2
  UNION ALL
  SELECT
    enactus_normalizar_universidad(g.university),
    trim(g.university),
    count(*)
  FROM groups g
  WHERE enactus_normalizar_universidad(g.university) IS NOT NULL
  GROUP BY 1, 2
) variantes
ORDER BY slug, veces DESC, length(nombre) DESC, nombre
ON CONFLICT DO NOTHING;
--> statement-breakpoint

-- 2. La marcadora, para lo que no se pueda mapear.
--
-- Existe para que un estudiante Enactus sin universidad legible NO quede con
-- el campo vacío: vacío es indistinguible de «Open Learning, que no lleva»,
-- y esa confusión es justo la que este trabajo viene a quitar. Sale en el
-- reporte de integridad hasta que alguien la resuelva a mano.
INSERT INTO universities (name, slug, active)
VALUES ('Sin asignar', 'sin asignar', false)
ON CONFLICT DO NOTHING;
--> statement-breakpoint

-- 3. Cada usuario a su universidad, por el nombre normalizado.
UPDATE users u
   SET university_id = un.id,
       updated_at    = now()
  FROM universities un
 WHERE u.university_id IS NULL
   AND un.slug = enactus_normalizar_universidad(u.university);
--> statement-breakpoint

-- 4. Los estudiantes Enactus que quedaron sin mapear, a la marcadora.
--
-- Solo Enactus: Open Learning no lleva universidad (INV-9) y quedarse en NULL
-- es su estado correcto, no un hueco que haya que tapar.
UPDATE users u
   SET university_id = (SELECT id FROM universities WHERE slug = 'sin asignar'),
       updated_at    = now()
 WHERE u.university_id IS NULL
   AND u.role IN ('student', 'alumni')
   AND u.student_type = 'enactus';
--> statement-breakpoint

-- 5. Los asesores, a la tabla puente.
--
-- Acá empieza a existir la visibilidad por id. Todavía no manda —las lecturas
-- siguen por texto hasta R3— pero ya se puede comparar una contra otra, que
-- es la condición para pasar a R3.
INSERT INTO university_advisors (university_id, user_id)
SELECT u.university_id, u.id
  FROM users u
 WHERE u.role = 'advisor'
   AND u.university_id IS NOT NULL
   AND u.deleted_at IS NULL
ON CONFLICT DO NOTHING;
--> statement-breakpoint

-- 6. La universidad del proyecto, que hoy vive del lado del equipo.
--
-- `DISTINCT ON` porque un proyecto puede tener más de un equipo: se toma el
-- primero con universidad legible. Si dos equipos del mismo proyecto
-- declararan universidades distintas, eso es una violación de INV-7 que el
-- reporte de integridad tiene que mostrar — no algo que la migración deba
-- resolver por su cuenta eligiendo una.
UPDATE projects p
   SET university_id = elegida.university_id,
       updated_at    = now()
  FROM (
    SELECT DISTINCT ON (g.project_id)
           g.project_id,
           un.id AS university_id
      FROM groups g
      JOIN universities un
        ON un.slug = enactus_normalizar_universidad(g.university)
     WHERE g.deleted_at IS NULL
     ORDER BY g.project_id, g.created_at
  ) elegida
 WHERE p.id = elegida.project_id
   AND p.university_id IS NULL;
