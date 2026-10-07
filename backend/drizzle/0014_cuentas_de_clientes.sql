-- Cada cuenta puede pertenecer a un cliente (una empresa, o Enactus).
--
-- El cliente decide con qué marca ve la plataforma quien inicia sesión, y si
-- puede entrar: un cliente desactivado deja afuera a sus cuentas. Nulo = de
-- eduXaction directamente (administración, LXD propios, Open Learning sin
-- empresa).
--
-- Agrega una columna anulable, su índice y una regla (administración no
-- lleva cliente). Después asigna a Enactus las cuentas que ya son suyas.
ALTER TABLE "users" ADD COLUMN "client_id" uuid;--> statement-breakpoint
ALTER TABLE "users" ADD CONSTRAINT "users_client_id_clients_id_fk" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "users_client_id_idx" ON "users" USING btree ("client_id");--> statement-breakpoint
ALTER TABLE "users" ADD CONSTRAINT "users_admins_sin_cliente" CHECK ("users"."role" not in ('admin', 'superadmin') or "users"."client_id" is null);--> statement-breakpoint
-- RELLENO. Las cuentas que hoy son de Enactus pasan a su cliente: los
-- estudiantes y alumni eduXaction, y las cuentas especiales de la red
-- (asesores, mentores de laboratorio, donantes y empresas aliadas). Los LXD
-- y Open Learning quedan sin cliente: son de eduXaction directamente.
-- Idempotente: solo toca las que todavía no tienen cliente.
UPDATE "users"
   SET "client_id" = (SELECT "id" FROM "clients" WHERE "has_laboratories")
 WHERE "client_id" IS NULL
   AND ("student_type" = 'enactus'
        OR "role" IN ('advisor', 'mentor', 'donor', 'company'));
