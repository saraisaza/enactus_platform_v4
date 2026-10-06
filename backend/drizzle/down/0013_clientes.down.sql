-- Reverso de 0013_clientes: quita la tabla de clientes.
--
-- Se pierden los clientes creados, con sus colores y la referencia a su logo;
-- los archivos de los logos quedan en S3 (`client-logos/`) sin nadie que los
-- use. Ninguna otra tabla depende de esta todavía.
DROP TABLE IF EXISTS "clients";
