-- Reverso de 0017_moldes_de_certificado.
--
-- Los archivos de los moldes quedan en S3 sin referencia: los limpia la cola
-- de borrado solo si alguien los encola; acá no se tocan (un reverso no debería
-- borrar diseños que alguien subió).
DROP INDEX IF EXISTS "certificates_issuer_client_id_idx";
ALTER TABLE "certificates" DROP CONSTRAINT IF EXISTS "certificates_issuer_client_id_clients_id_fk";
ALTER TABLE "certificates" DROP COLUMN IF EXISTS "issuer_client_id";
DROP TABLE IF EXISTS "certificate_templates";
