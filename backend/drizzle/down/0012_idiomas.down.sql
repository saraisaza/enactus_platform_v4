-- Reverso de 0012_idiomas: quita las columnas de idioma.
--
-- Se pierden los textos de la portada en inglés que se hayan escrito y el tipo
-- de los avisos; el aviso en sí queda, con su texto en español.
ALTER TABLE "site_content" DROP COLUMN IF EXISTS "about_text_en";
ALTER TABLE "site_content" DROP COLUMN IF EXISTS "banner_text_en";
ALTER TABLE "site_content" DROP COLUMN IF EXISTS "hero_subtitle_en";
ALTER TABLE "site_content" DROP COLUMN IF EXISTS "hero_title_en";
ALTER TABLE "notifications" DROP COLUMN IF EXISTS "params";
ALTER TABLE "notifications" DROP COLUMN IF EXISTS "kind";
