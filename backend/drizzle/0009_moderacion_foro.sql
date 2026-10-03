-- Moderación del foro: reportes y bloqueos.
--
-- Lo exige App Store (guía 1.2) para publicar una app donde las personas
-- publican contenido: reportar lo ofensivo, bloquear a quien abusa, y que el
-- equipo atienda los reportes.
--
-- Puramente aditivo: dos tablas nuevas y nada más. El código anterior sigue
-- funcionando sobre esta base, así que se puede migrar ANTES de desplegar la
-- API nueva.

CREATE TABLE "forum_reports" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"post_id" uuid NOT NULL,
	"reply_id" uuid,
	"reporter_id" uuid NOT NULL,
	"reason" text DEFAULT '' NOT NULL,
	"resolution" text,
	"resolved_by" uuid,
	"resolved_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "forum_reports_resolution_valid" CHECK ("forum_reports"."resolution" is null or "forum_reports"."resolution" in ('removed', 'dismissed')),
	CONSTRAINT "forum_reports_resolved_consistent" CHECK (("forum_reports"."resolved_at" is null) = ("forum_reports"."resolution" is null))
);
--> statement-breakpoint
CREATE TABLE "user_blocks" (
	"blocker_id" uuid NOT NULL,
	"blocked_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "user_blocks_blocker_id_blocked_id_pk" PRIMARY KEY("blocker_id","blocked_id"),
	CONSTRAINT "user_blocks_not_self" CHECK ("user_blocks"."blocker_id" <> "user_blocks"."blocked_id")
);
--> statement-breakpoint
ALTER TABLE "forum_reports" ADD CONSTRAINT "forum_reports_post_id_forum_posts_id_fk" FOREIGN KEY ("post_id") REFERENCES "public"."forum_posts"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "forum_reports" ADD CONSTRAINT "forum_reports_reply_id_forum_replies_id_fk" FOREIGN KEY ("reply_id") REFERENCES "public"."forum_replies"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "forum_reports" ADD CONSTRAINT "forum_reports_reporter_id_users_id_fk" FOREIGN KEY ("reporter_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "forum_reports" ADD CONSTRAINT "forum_reports_resolved_by_users_id_fk" FOREIGN KEY ("resolved_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_blocks" ADD CONSTRAINT "user_blocks_blocker_id_users_id_fk" FOREIGN KEY ("blocker_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_blocks" ADD CONSTRAINT "user_blocks_blocked_id_users_id_fk" FOREIGN KEY ("blocked_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "forum_reports_post_id_idx" ON "forum_reports" USING btree ("post_id");--> statement-breakpoint
CREATE INDEX "forum_reports_reporter_id_idx" ON "forum_reports" USING btree ("reporter_id");--> statement-breakpoint
CREATE UNIQUE INDEX "forum_reports_pending_unique" ON "forum_reports" USING btree ("reporter_id","post_id",coalesce("reply_id", '00000000-0000-0000-0000-000000000000'::uuid)) WHERE "forum_reports"."resolved_at" is null;--> statement-breakpoint
CREATE INDEX "user_blocks_blocked_id_idx" ON "user_blocks" USING btree ("blocked_id");