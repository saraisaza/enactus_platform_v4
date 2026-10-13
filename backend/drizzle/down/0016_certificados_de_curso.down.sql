-- Reverso de 0016_certificados_de_curso.
--
-- Se borran los certificados de CURSO (el código anterior no los conoce) y el
-- candado vuelve a exigir solo la Ruta. Los cursos que pasaron a entregar
-- certificado quedan así: es un dato que el código anterior ya entendía.
DELETE FROM "certificates" WHERE "course_id" IS NOT NULL;
ALTER TABLE "certificates" DROP CONSTRAINT IF EXISTS "certificates_con_su_nombre";
ALTER TABLE "certificates" DROP CONSTRAINT IF EXISTS "certificates_de_lab_o_de_curso";
DROP INDEX IF EXISTS "certificates_course_id_idx";
DROP INDEX IF EXISTS "certificates_student_course_unique";
ALTER TABLE "certificates" DROP CONSTRAINT IF EXISTS "certificates_course_id_courses_id_fk";
ALTER TABLE "certificates" DROP COLUMN IF EXISTS "course_name_snapshot";
ALTER TABLE "certificates" DROP COLUMN IF EXISTS "course_id";
ALTER TABLE "certificates" ALTER COLUMN "laboratory_name_snapshot" SET NOT NULL;
ALTER TABLE "certificates" ALTER COLUMN "laboratory_id" SET NOT NULL;
CREATE OR REPLACE FUNCTION enforce_ruta_certificate_requirements()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT can_issue_ruta_certificate(NEW.student_id, NEW.laboratory_id) THEN
    RAISE EXCEPTION
      'No se puede emitir el certificado: la Ruta de Impacto del laboratorio % no está completa para el estudiante %',
      NEW.laboratory_id, NEW.student_id
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
