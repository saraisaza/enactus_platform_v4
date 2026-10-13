-- Moldes de certificado (etapa 6, parte 2).
--
-- 1. `certificate_templates`: el molde de cada cliente (uno por cliente; el de
--    `client_id` nulo es el de eduXaction). Un fondo —PDF de una página o
--    imagen— y dónde va cada dato.
-- 2. `certificates.issuer_client_id`: el cliente que emitió cada certificado.
--    Decide el molde, y se guarda para que un certificado viejo no cambie de
--    molde si la persona cambia de empresa. Los que ya existen toman el
--    cliente actual de su persona.
CREATE TABLE "certificate_templates" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"client_id" uuid,
	"background_s3_key" text NOT NULL,
	"background_kind" text NOT NULL,
	"page_width" real NOT NULL,
	"page_height" real NOT NULL,
	"fields" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"signature_s3_key" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "certificate_templates_kind" CHECK ("certificate_templates"."background_kind" in ('pdf', 'png', 'jpeg')),
	CONSTRAINT "certificate_templates_keys_folder" CHECK ("certificate_templates"."background_s3_key" like 'certificate-templates/%'
          and ("certificate_templates"."signature_s3_key" is null or "certificate_templates"."signature_s3_key" like 'certificate-templates/%')),
	CONSTRAINT "certificate_templates_page_positive" CHECK ("certificate_templates"."page_width" > 0 and "certificate_templates"."page_height" > 0)
);
--> statement-breakpoint
ALTER TABLE "certificates" ADD COLUMN "issuer_client_id" uuid;--> statement-breakpoint
ALTER TABLE "certificate_templates" ADD CONSTRAINT "certificate_templates_client_id_clients_id_fk" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "certificate_templates_client_unique" ON "certificate_templates" USING btree ("client_id") WHERE "certificate_templates"."client_id" is not null;--> statement-breakpoint
CREATE UNIQUE INDEX "certificate_templates_eduxaction_unique" ON "certificate_templates" USING btree (("client_id" is null)) WHERE "certificate_templates"."client_id" is null;--> statement-breakpoint
ALTER TABLE "certificates" ADD CONSTRAINT "certificates_issuer_client_id_clients_id_fk" FOREIGN KEY ("issuer_client_id") REFERENCES "public"."clients"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "certificates_issuer_client_id_idx" ON "certificates" USING btree ("issuer_client_id");--> statement-breakpoint

UPDATE "certificates" c
   SET "issuer_client_id" = u."client_id"
  FROM "users" u
 WHERE u."id" = c."student_id" AND c."issuer_client_id" IS NULL;
