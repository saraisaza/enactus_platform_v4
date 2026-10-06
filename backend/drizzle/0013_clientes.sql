-- Clientes de la plataforma, con su marca.
--
-- Cada cliente —una empresa, o Enactus— puede tener logo y dos colores, y
-- quien inicia sesión verá la plataforma con la marca de su cliente. Esta
-- migración solo crea la tabla y el cliente Enactus: ninguna cuenta queda
-- asignada todavía, así que nadie ve ningún cambio.
--
-- Enactus es el cliente con laboratorios y Ruta de Impacto. Se crea acá para
-- que exista en todos los entornos sin alta manual, sin logo ni colores: así
-- se ve con la marca de eduXaction, como hoy.
--
-- Solo agrega: una tabla nueva y una fila. No toca ninguna tabla existente.
CREATE TABLE "clients" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"logo_s3_key" text,
	"logo_width" integer,
	"logo_height" integer,
	"logo_light_plate" boolean DEFAULT false NOT NULL,
	"primary_color" text,
	"secondary_color" text,
	"has_laboratories" boolean DEFAULT false NOT NULL,
	"active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "clients_name_not_blank" CHECK (length(trim("clients"."name")) > 0),
	CONSTRAINT "clients_primary_color_hex" CHECK ("clients"."primary_color" is null or "clients"."primary_color" ~ '^#[0-9A-F]{6}$'),
	CONSTRAINT "clients_secondary_color_hex" CHECK ("clients"."secondary_color" is null or "clients"."secondary_color" ~ '^#[0-9A-F]{6}$'),
	CONSTRAINT "clients_logo_complete" CHECK (("clients"."logo_s3_key" is null) = ("clients"."logo_width" is null)
          and ("clients"."logo_s3_key" is null) = ("clients"."logo_height" is null)),
	CONSTRAINT "clients_logo_key_folder" CHECK ("clients"."logo_s3_key" is null or "clients"."logo_s3_key" like 'client-logos/%'),
	CONSTRAINT "clients_logo_size_positive" CHECK ("clients"."logo_width" is null or ("clients"."logo_width" > 0 and "clients"."logo_height" > 0))
);
--> statement-breakpoint
CREATE UNIQUE INDEX "clients_name_lower_unique" ON "clients" USING btree (lower("name"));--> statement-breakpoint
CREATE UNIQUE INDEX "clients_one_with_laboratories" ON "clients" USING btree ("has_laboratories") WHERE "clients"."has_laboratories";--> statement-breakpoint
-- Idempotente: si la fila ya está (el índice de un solo cliente con
-- laboratorios), no hace nada.
INSERT INTO "clients" ("name", "has_laboratories") VALUES ('Enactus', true) ON CONFLICT DO NOTHING;
