-- Nelson Electric, el primer cliente empresa (pedido de Sara, 2026-10-13).
--
-- Se crea por migración —como Enactus en la 0013— para que llegue a staging y
-- a producción por el despliegue, con la aprobación de siempre. El logo ya
-- está en el almacenamiento (`client-logos/nelson-electric.png`, 1410×204 px,
-- preparado a partir del de su sitio web). Va con placa clara: su texto
-- pizarra no se lee sobre el encabezado oscuro. Colores: el naranja de su
-- ícono y el pizarra de su nombre.
--
-- Idempotente: si ya existe un cliente con ese nombre (creado a mano desde el
-- panel), no se toca.
INSERT INTO "clients" ("name", "logo_s3_key", "logo_width", "logo_height",
                       "logo_light_plate", "primary_color", "secondary_color")
SELECT 'Nelson Electric', 'client-logos/nelson-electric.png', 1410, 204, true,
       '#F8931B', '#465668'
 WHERE NOT EXISTS (SELECT 1 FROM "clients" WHERE lower("name") = 'nelson electric');
