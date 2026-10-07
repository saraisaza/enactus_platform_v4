-- Reverso de 0014_cuentas_de_clientes: las cuentas dejan de tener cliente.
--
-- Se pierde a qué cliente pertenecía cada cuenta; las cuentas y los clientes
-- quedan. Volver a migrar reasigna a Enactus las suyas, pero no las de las
-- empresas: esas hay que volver a asignarlas a mano.
ALTER TABLE "users" DROP CONSTRAINT IF EXISTS "users_admins_sin_cliente";
DROP INDEX IF EXISTS "users_client_id_idx";
ALTER TABLE "users" DROP CONSTRAINT IF EXISTS "users_client_id_clients_id_fk";
ALTER TABLE "users" DROP COLUMN IF EXISTS "client_id";
