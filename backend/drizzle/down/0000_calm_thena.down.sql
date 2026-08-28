-- Reverso de 0000_calm_thena.sql
--
-- Escrito para que `npm run db:rollback` cumpla lo que promete:
-- revertir la migración sin errores y dejar la base como estaba.
-- Generado a partir del archivo de subida (mismos nombres, orden
-- inverso) y verificado con el ciclo migrate → rollback → migrate.

DROP TABLE IF EXISTS "staff_notes" CASCADE;
DROP TABLE IF EXISTS "site_gallery_images" CASCADE;
DROP TABLE IF EXISTS "site_content" CASCADE;
DROP TABLE IF EXISTS "notifications" CASCADE;
DROP TABLE IF EXISTS "forum_replies" CASCADE;
DROP TABLE IF EXISTS "forum_posts" CASCADE;
DROP TABLE IF EXISTS "forum_likes" CASCADE;
DROP TABLE IF EXISTS "expo_checklist_items" CASCADE;
DROP TABLE IF EXISTS "evidences" CASCADE;
DROP TABLE IF EXISTS "communication_resources" CASCADE;
DROP TABLE IF EXISTS "calendar_events" CASCADE;
DROP TABLE IF EXISTS "submissions" CASCADE;
DROP TABLE IF EXISTS "submission_files" CASCADE;
DROP TABLE IF EXISTS "quiz_attempts" CASCADE;
DROP TABLE IF EXISTS "certificates" CASCADE;
DROP TABLE IF EXISTS "ruta_progress_lessons" CASCADE;
DROP TABLE IF EXISTS "ruta_progress" CASCADE;
DROP TABLE IF EXISTS "progress_lessons" CASCADE;
DROP TABLE IF EXISTS "progress" CASCADE;
DROP TABLE IF EXISTS "student_laboratories" CASCADE;
DROP TABLE IF EXISTS "student_courses" CASCADE;
DROP TABLE IF EXISTS "ruta_module_courses" CASCADE;
DROP TABLE IF EXISTS "objective_courses" CASCADE;
DROP TABLE IF EXISTS "mentor_review_courses" CASCADE;
DROP TABLE IF EXISTS "quiz_questions" CASCADE;
DROP TABLE IF EXISTS "quiz_question_options" CASCADE;
DROP TABLE IF EXISTS "lessons" CASCADE;
DROP TABLE IF EXISTS "lesson_activities" CASCADE;
DROP TABLE IF EXISTS "courses" CASCADE;
DROP TABLE IF EXISTS "course_tags" CASCADE;
DROP TABLE IF EXISTS "course_prerequisites" CASCADE;
DROP TABLE IF EXISTS "course_ods" CASCADE;
DROP TABLE IF EXISTS "course_objectives" CASCADE;
DROP TABLE IF EXISTS "course_modules" CASCADE;
DROP TABLE IF EXISTS "course_learning_outcomes" CASCADE;
DROP TABLE IF EXISTS "course_competencies" CASCADE;
DROP TABLE IF EXISTS "activity_rubric_items" CASCADE;
DROP TABLE IF EXISTS "activity_allowed_types" CASCADE;
DROP TABLE IF EXISTS "ruta_modules" CASCADE;
DROP TABLE IF EXISTS "phases" CASCADE;
DROP TABLE IF EXISTS "objectives" CASCADE;
DROP TABLE IF EXISTS "laboratory_mentors" CASCADE;
DROP TABLE IF EXISTS "laboratories" CASCADE;
DROP TABLE IF EXISTS "projects" CASCADE;
DROP TABLE IF EXISTS "project_ods" CASCADE;
DROP TABLE IF EXISTS "groups" CASCADE;
DROP TABLE IF EXISTS "group_members" CASCADE;
DROP TABLE IF EXISTS "users" CASCADE;
DROP TABLE IF EXISTS "refresh_tokens" CASCADE;
DROP TABLE IF EXISTS "audit_log" CASCADE;
DROP TABLE IF EXISTS "ods_goals" CASCADE;
DROP TABLE IF EXISTS "competencies" CASCADE;

DROP TYPE IF EXISTS "public"."video_type" CASCADE;
DROP TYPE IF EXISTS "public"."user_role" CASCADE;
DROP TYPE IF EXISTS "public"."student_type" CASCADE;
DROP TYPE IF EXISTS "public"."quiz_kind" CASCADE;
DROP TYPE IF EXISTS "public"."project_stage" CASCADE;
DROP TYPE IF EXISTS "public"."project_member_role" CASCADE;
DROP TYPE IF EXISTS "public"."objective_category" CASCADE;
DROP TYPE IF EXISTS "public"."lesson_type" CASCADE;
DROP TYPE IF EXISTS "public"."grading_mode" CASCADE;
DROP TYPE IF EXISTS "public"."forum_category" CASCADE;
DROP TYPE IF EXISTS "public"."evidence_type" CASCADE;
DROP TYPE IF EXISTS "public"."deliverable_type" CASCADE;
DROP TYPE IF EXISTS "public"."course_status" CASCADE;
DROP TYPE IF EXISTS "public"."course_level" CASCADE;
DROP TYPE IF EXISTS "public"."comm_resource_type" CASCADE;
DROP TYPE IF EXISTS "public"."calendar_event_type" CASCADE;
