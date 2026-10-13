-- Reverso de 0018_cliente_nelson_electric.
--
-- Se borra solo el que creó esta migración (el de su logo), y solo si nadie
-- lo usa todavía: si ya tiene cuentas o cursos, se queda.
DELETE FROM "clients" c
 WHERE lower(c."name") = 'nelson electric'
   AND c."logo_s3_key" = 'client-logos/nelson-electric.png'
   AND NOT EXISTS (SELECT 1 FROM "users" u WHERE u."client_id" = c."id")
   AND NOT EXISTS (SELECT 1 FROM "courses" co WHERE co."client_id" = c."id");
