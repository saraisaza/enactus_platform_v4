-- Certificados de curso (etapa 6, parte 1).
--
-- 1. Un certificado es de la Ruta de un laboratorio O de un curso: el de curso
--    lo emite el servidor solo, cuando la persona completa todas las lecciones
--    de un curso que entrega certificado.
-- 2. El candado de la base ya exigía la Ruta completa para emitir; ahora exige,
--    para uno de curso, que el curso esté completo.
-- 3. Los cursos de Open Learning pasan a entregar certificado, y quien ya los
--    había terminado recibe el suyo. Los de laboratorio NO emiten certificado
--    propio: ahí «cuenta para certificado» quiere decir que sus horas suman al
--    de la Ruta, que se emite al completarla entera.
ALTER TABLE "certificates" ALTER COLUMN "laboratory_id" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "certificates" ALTER COLUMN "laboratory_name_snapshot" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "certificates" ADD COLUMN "course_id" uuid;--> statement-breakpoint
ALTER TABLE "certificates" ADD COLUMN "course_name_snapshot" text;--> statement-breakpoint
ALTER TABLE "certificates" ADD CONSTRAINT "certificates_course_id_courses_id_fk" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "certificates_student_course_unique" ON "certificates" USING btree ("student_id","course_id");--> statement-breakpoint
CREATE INDEX "certificates_course_id_idx" ON "certificates" USING btree ("course_id");--> statement-breakpoint
ALTER TABLE "certificates" ADD CONSTRAINT "certificates_de_lab_o_de_curso" CHECK (("certificates"."laboratory_id" is null) <> ("certificates"."course_id" is null));--> statement-breakpoint
ALTER TABLE "certificates" ADD CONSTRAINT "certificates_con_su_nombre" CHECK (("certificates"."laboratory_id" is null or "certificates"."laboratory_name_snapshot" is not null)
          and ("certificates"."course_id" is null or "certificates"."course_name_snapshot" is not null));--> statement-breakpoint

CREATE OR REPLACE FUNCTION enforce_ruta_certificate_requirements()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.laboratory_id IS NOT NULL
     AND NOT can_issue_ruta_certificate(NEW.student_id, NEW.laboratory_id) THEN
    RAISE EXCEPTION
      'No se puede emitir el certificado: la Ruta de Impacto del laboratorio % no está completa para el estudiante %',
      NEW.laboratory_id, NEW.student_id
      USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.course_id IS NOT NULL
     AND NOT coalesce((SELECT cp.is_complete FROM course_progress cp
                        WHERE cp.student_id = NEW.student_id
                          AND cp.course_id = NEW.course_id), false) THEN
    RAISE EXCEPTION
      'No se puede emitir el certificado: el curso % no está completo para el estudiante %',
      NEW.course_id, NEW.student_id
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
--> statement-breakpoint

UPDATE "courses"
   SET "generates_certificate" = true
 WHERE "is_open_learning" AND "deleted_at" IS NULL AND NOT "generates_certificate";
--> statement-breakpoint

-- Quien ya terminó un curso que entrega certificado, lo recibe. El emisor es el
-- cliente de la persona (su empresa, o Enactus); sin cliente, eduXaction.
INSERT INTO "certificates" (
  "code", "student_id", "course_id", "student_name_snapshot",
  "course_name_snapshot", "issuer_name_snapshot", "hours", "requirements_snapshot")
SELECT 'CUR-' || to_char(now(), 'YYYY') || '-'
         || upper(substr(md5(gen_random_uuid()::text), 1, 8)),
       cp.student_id, cp.course_id, u.name, c.name, coalesce(cl.name, 'eduXaction'),
       CASE WHEN c.certified_hours > 0 THEN c.certified_hours ELSE c.estimated_hours END,
       jsonb_build_object('lessons', cp.total_lessons)
  FROM course_progress cp
  JOIN courses c ON c.id = cp.course_id AND c.deleted_at IS NULL AND c.generates_certificate
                AND c.laboratory_id IS NULL
  JOIN users u ON u.id = cp.student_id AND u.deleted_at IS NULL
  LEFT JOIN clients cl ON cl.id = u.client_id
 WHERE cp.is_complete
ON CONFLICT DO NOTHING;
