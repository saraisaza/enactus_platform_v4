-- Reverso de 0019_encuestas_de_verdad.
--
-- Las respuestas de encuestas se borran (el código anterior no las conoce).
-- Las preguntas de calificar pasan a comentario, sin sus etiquetas: el código
-- anterior no sabe dibujarlas. El valor 'scale' QUEDA en el tipo `quiz_kind`:
-- PostgreSQL no permite quitar un valor de un enum sin recrear el tipo.
DROP TABLE IF EXISTS "survey_responses";
DELETE FROM "quiz_question_options"
 WHERE "quiz_question_id" IN (SELECT "id" FROM "quiz_questions" WHERE "kind"::text = 'scale');
UPDATE "quiz_questions" SET "kind" = 'short' WHERE "kind"::text = 'scale';
