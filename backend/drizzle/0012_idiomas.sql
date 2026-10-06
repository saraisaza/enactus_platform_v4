-- La plataforma en español e inglés.
--
-- 1. `notifications.kind` y `params`: qué aviso es y sus datos, para que la app
--    lo muestre en el idioma de quien lo LEE (un aviso lo genera el servidor o
--    otra persona, en otro idioma). `title` y `body` se siguen llenando en
--    español: una versión vieja de la app los muestra tal cual. Los avisos ya
--    guardados quedan con `kind` nulo y se ven como siempre.
-- 2. `site_content.*_en`: los textos de la portada en inglés. Los escribe el
--    equipo; vacíos, la portada en inglés muestra los de español.
--
-- Solo agrega columnas con valor por defecto: no reescribe filas ni bloquea
-- lecturas.
ALTER TABLE "notifications" ADD COLUMN "kind" text;--> statement-breakpoint
ALTER TABLE "notifications" ADD COLUMN "params" jsonb;--> statement-breakpoint
ALTER TABLE "site_content" ADD COLUMN "hero_title_en" text DEFAULT '' NOT NULL;--> statement-breakpoint
ALTER TABLE "site_content" ADD COLUMN "hero_subtitle_en" text DEFAULT '' NOT NULL;--> statement-breakpoint
ALTER TABLE "site_content" ADD COLUMN "banner_text_en" text DEFAULT '' NOT NULL;--> statement-breakpoint
ALTER TABLE "site_content" ADD COLUMN "about_text_en" text DEFAULT '' NOT NULL;