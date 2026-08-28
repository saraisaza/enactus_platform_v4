CREATE TYPE "public"."calendar_event_type" AS ENUM('open_learning_sync', 'ruta_impacto', 'mentoria');--> statement-breakpoint
CREATE TYPE "public"."comm_resource_type" AS ENUM('file', 'link');--> statement-breakpoint
CREATE TYPE "public"."course_level" AS ENUM('basic', 'intermediate', 'advanced');--> statement-breakpoint
CREATE TYPE "public"."course_status" AS ENUM('draft', 'published', 'archived');--> statement-breakpoint
CREATE TYPE "public"."deliverable_type" AS ENUM('pdf', 'video', 'document', 'image', 'zip');--> statement-breakpoint
CREATE TYPE "public"."evidence_type" AS ENUM('photo', 'video', 'testimonial', 'report', 'story');--> statement-breakpoint
CREATE TYPE "public"."forum_category" AS ENUM('question', 'progress', 'resource', 'announcement');--> statement-breakpoint
CREATE TYPE "public"."grading_mode" AS ENUM('points100', 'passfail', 'review', 'scale5');--> statement-breakpoint
CREATE TYPE "public"."lesson_type" AS ENUM('video', 'pdf', 'resource', 'link', 'quiz', 'activity', 'survey');--> statement-breakpoint
CREATE TYPE "public"."objective_category" AS ENUM('entrepreneurship', 'business');--> statement-breakpoint
CREATE TYPE "public"."project_member_role" AS ENUM('leader', 'research', 'finance', 'communications', 'design', 'operations', 'member');--> statement-breakpoint
CREATE TYPE "public"."project_stage" AS ENUM('ideation', 'validation', 'prototype', 'pilot', 'scaling', 'national_expo');--> statement-breakpoint
CREATE TYPE "public"."quiz_kind" AS ENUM('multiple', 'truefalse', 'short', 'fill', 'order');--> statement-breakpoint
CREATE TYPE "public"."student_type" AS ENUM('enactus', 'open_learning');--> statement-breakpoint
CREATE TYPE "public"."user_role" AS ENUM('superadmin', 'admin', 'advisor', 'donor', 'lxd', 'mentor', 'company', 'student', 'alumni');--> statement-breakpoint
CREATE TYPE "public"."video_type" AS ENUM('external', 'uploaded');--> statement-breakpoint
CREATE TABLE "competencies" (
	"code" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL
);
--> statement-breakpoint
CREATE TABLE "ods_goals" (
	"code" text PRIMARY KEY NOT NULL,
	"number" integer NOT NULL,
	"title" text NOT NULL
);
--> statement-breakpoint
CREATE TABLE "audit_log" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"actor_id" uuid,
	"action" text NOT NULL,
	"entity_type" text NOT NULL,
	"entity_id" uuid,
	"old_value" jsonb,
	"new_value" jsonb,
	"ip" text DEFAULT '' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "refresh_tokens" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"token_hash" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"revoked_at" timestamp with time zone,
	"replaced_by" uuid,
	"user_agent" text DEFAULT '' NOT NULL,
	"ip" text DEFAULT '' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"email" text NOT NULL,
	"password_hash" text NOT NULL,
	"role" "user_role" NOT NULL,
	"phone" text DEFAULT '' NOT NULL,
	"cedula" text DEFAULT '' NOT NULL,
	"city" text DEFAULT '' NOT NULL,
	"university" text DEFAULT '' NOT NULL,
	"career" text DEFAULT '' NOT NULL,
	"company_name" text DEFAULT '' NOT NULL,
	"impact_code" text,
	"student_type" "student_type",
	"can_grade_open_learning" boolean DEFAULT true NOT NULL,
	"can_grade_enactus" boolean DEFAULT false NOT NULL,
	"company_id" uuid,
	"donor_id" uuid,
	"avatar_s3_key" text,
	"joined_at" timestamp with time zone,
	"profile" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "users_student_type_matches_role" CHECK (("users"."role" in ('student','alumni')) = ("users"."student_type" is not null)),
	CONSTRAINT "users_impact_code_only_donor" CHECK ("users"."impact_code" is null or "users"."role" = 'donor')
);
--> statement-breakpoint
CREATE TABLE "group_members" (
	"group_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"role_in_project" "project_member_role" DEFAULT 'member' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "group_members_group_id_user_id_pk" PRIMARY KEY("group_id","user_id")
);
--> statement-breakpoint
CREATE TABLE "groups" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"project_id" uuid NOT NULL,
	"university" text DEFAULT '' NOT NULL,
	"advisor_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "project_ods" (
	"project_id" uuid NOT NULL,
	"ods_code" text NOT NULL,
	CONSTRAINT "project_ods_project_id_ods_code_pk" PRIMARY KEY("project_id","ods_code")
);
--> statement-breakpoint
CREATE TABLE "projects" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"description" text DEFAULT '' NOT NULL,
	"problem" text DEFAULT '' NOT NULL,
	"solution" text DEFAULT '' NOT NULL,
	"community" text DEFAULT '' NOT NULL,
	"stage" "project_stage" DEFAULT 'ideation' NOT NULL,
	"impact_indicators" text DEFAULT '' NOT NULL,
	"expo_enabled" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "laboratories" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"description" text DEFAULT '' NOT NULL,
	"objectives" text DEFAULT '' NOT NULL,
	"sponsor_company_id" uuid,
	"content_version" integer DEFAULT 1 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "laboratory_mentors" (
	"laboratory_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "laboratory_mentors_laboratory_id_user_id_pk" PRIMARY KEY("laboratory_id","user_id")
);
--> statement-breakpoint
CREATE TABLE "objectives" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"phase_id" uuid NOT NULL,
	"category" "objective_category" DEFAULT 'entrepreneurship' NOT NULL,
	"text" text DEFAULT '' NOT NULL,
	"order_index" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "phases" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"laboratory_id" uuid NOT NULL,
	"order_index" integer NOT NULL,
	"title" text DEFAULT '' NOT NULL,
	"description" text DEFAULT '' NOT NULL,
	"deadline" date,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "phases_lab_order_unique" UNIQUE("laboratory_id","order_index"),
	CONSTRAINT "phases_order_positive" CHECK ("phases"."order_index" > 0)
);
--> statement-breakpoint
CREATE TABLE "ruta_modules" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"phase_id" uuid NOT NULL,
	"order_index" integer NOT NULL,
	"title" text DEFAULT '' NOT NULL,
	"is_mentorship_module" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ruta_modules_phase_order_unique" UNIQUE("phase_id","order_index"),
	CONSTRAINT "ruta_modules_order_positive" CHECK ("ruta_modules"."order_index" > 0)
);
--> statement-breakpoint
CREATE TABLE "activity_allowed_types" (
	"lesson_id" uuid NOT NULL,
	"file_type" "deliverable_type" NOT NULL,
	CONSTRAINT "activity_allowed_types_lesson_id_file_type_pk" PRIMARY KEY("lesson_id","file_type")
);
--> statement-breakpoint
CREATE TABLE "activity_rubric_items" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"lesson_id" uuid NOT NULL,
	"order_index" integer DEFAULT 0 NOT NULL,
	"criterion" text NOT NULL,
	"points" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "activity_rubric_items_points_non_negative" CHECK ("activity_rubric_items"."points" >= 0)
);
--> statement-breakpoint
CREATE TABLE "course_competencies" (
	"course_id" uuid NOT NULL,
	"competency_code" text NOT NULL,
	CONSTRAINT "course_competencies_course_id_competency_code_pk" PRIMARY KEY("course_id","competency_code")
);
--> statement-breakpoint
CREATE TABLE "course_learning_outcomes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"course_id" uuid NOT NULL,
	"text" text NOT NULL,
	"order_index" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "course_modules" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"course_id" uuid NOT NULL,
	"order_index" integer NOT NULL,
	"title" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "course_modules_course_order_unique" UNIQUE("course_id","order_index")
);
--> statement-breakpoint
CREATE TABLE "course_objectives" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"course_id" uuid NOT NULL,
	"category" "objective_category",
	"text" text NOT NULL,
	"order_index" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "course_ods" (
	"course_id" uuid NOT NULL,
	"ods_code" text NOT NULL,
	CONSTRAINT "course_ods_course_id_ods_code_pk" PRIMARY KEY("course_id","ods_code")
);
--> statement-breakpoint
CREATE TABLE "course_prerequisites" (
	"course_id" uuid NOT NULL,
	"prerequisite_course_id" uuid NOT NULL,
	CONSTRAINT "course_prerequisites_course_id_prerequisite_course_id_pk" PRIMARY KEY("course_id","prerequisite_course_id"),
	CONSTRAINT "course_prerequisites_no_self" CHECK ("course_prerequisites"."course_id" <> "course_prerequisites"."prerequisite_course_id")
);
--> statement-breakpoint
CREATE TABLE "course_tags" (
	"course_id" uuid NOT NULL,
	"tag" text NOT NULL,
	CONSTRAINT "course_tags_course_id_tag_pk" PRIMARY KEY("course_id","tag")
);
--> statement-breakpoint
CREATE TABLE "courses" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"subtitle" text DEFAULT '' NOT NULL,
	"description" text DEFAULT '' NOT NULL,
	"full_description" text DEFAULT '' NOT NULL,
	"cover_s3_key" text,
	"intro_video_type" "video_type",
	"intro_video_url" text,
	"intro_video_s3_key" text,
	"intro_video_size_bytes" bigint,
	"intro_video_duration_sec" integer,
	"intro_video_mime_type" text,
	"laboratory_id" uuid,
	"creator_id" uuid,
	"is_open_learning" boolean DEFAULT false NOT NULL,
	"is_ruta_expo" boolean DEFAULT false NOT NULL,
	"legacy_project_id" uuid,
	"level" "course_level" DEFAULT 'basic' NOT NULL,
	"estimated_hours" integer DEFAULT 0 NOT NULL,
	"language" text DEFAULT 'es' NOT NULL,
	"status" "course_status" DEFAULT 'published' NOT NULL,
	"generates_certificate" boolean DEFAULT false NOT NULL,
	"certified_hours" integer DEFAULT 0 NOT NULL,
	"open_date" date,
	"close_date" date,
	"max_students" integer DEFAULT 0 NOT NULL,
	"visible" boolean DEFAULT true NOT NULL,
	"sponsor_company_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "courses_intro_video_source" CHECK (("courses"."intro_video_type" is null and "courses"."intro_video_url" is null and "courses"."intro_video_s3_key" is null)
       or ("courses"."intro_video_type" = 'external' and "courses"."intro_video_url" is not null and "courses"."intro_video_s3_key" is null)
       or ("courses"."intro_video_type" = 'uploaded' and "courses"."intro_video_s3_key" is not null and "courses"."intro_video_url" is null)),
	CONSTRAINT "courses_hours_non_negative" CHECK ("courses"."estimated_hours" >= 0 and "courses"."certified_hours" >= 0),
	CONSTRAINT "courses_max_students_non_negative" CHECK ("courses"."max_students" >= 0)
);
--> statement-breakpoint
CREATE TABLE "lesson_activities" (
	"lesson_id" uuid PRIMARY KEY NOT NULL,
	"description" text DEFAULT '' NOT NULL,
	"deadline" date,
	"requires_file" boolean DEFAULT false NOT NULL,
	"requires_text" boolean DEFAULT true NOT NULL,
	"max_files" integer DEFAULT 1 NOT NULL,
	"grading_mode" "grading_mode" DEFAULT 'points100' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "lesson_activities_max_files_positive" CHECK ("lesson_activities"."max_files" > 0)
);
--> statement-breakpoint
CREATE TABLE "lessons" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"course_module_id" uuid,
	"ruta_module_id" uuid,
	"order_index" integer DEFAULT 0 NOT NULL,
	"title" text NOT NULL,
	"type" "lesson_type" DEFAULT 'video' NOT NULL,
	"description" text DEFAULT '' NOT NULL,
	"duration_min" integer DEFAULT 0 NOT NULL,
	"resource_s3_key" text,
	"resource_file_name" text,
	"resource_content_type" text,
	"resource_size_bytes" bigint,
	"external_url" text,
	"video_type" "video_type",
	"video_url" text,
	"video_s3_key" text,
	"video_size_bytes" bigint,
	"video_duration_sec" integer,
	"video_mime_type" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "lessons_exactly_one_parent" CHECK (("lessons"."course_module_id" is not null) <> ("lessons"."ruta_module_id" is not null)),
	CONSTRAINT "lessons_video_source" CHECK (("lessons"."video_type" is null and "lessons"."video_url" is null and "lessons"."video_s3_key" is null)
       or ("lessons"."video_type" = 'external' and "lessons"."video_url" is not null and "lessons"."video_s3_key" is null)
       or ("lessons"."video_type" = 'uploaded' and "lessons"."video_s3_key" is not null and "lessons"."video_url" is null)),
	CONSTRAINT "lessons_video_type_requires_source" CHECK ("lessons"."type" <> 'video' or "lessons"."video_type" is not null),
	CONSTRAINT "lessons_link_requires_url" CHECK ("lessons"."type" <> 'link' or "lessons"."external_url" is not null)
);
--> statement-breakpoint
CREATE TABLE "quiz_question_options" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"quiz_question_id" uuid NOT NULL,
	"order_index" integer NOT NULL,
	"text" text NOT NULL,
	CONSTRAINT "quiz_question_options_order_unique" UNIQUE("quiz_question_id","order_index")
);
--> statement-breakpoint
CREATE TABLE "quiz_questions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"lesson_id" uuid NOT NULL,
	"order_index" integer DEFAULT 0 NOT NULL,
	"kind" "quiz_kind" DEFAULT 'multiple' NOT NULL,
	"question" text DEFAULT '' NOT NULL,
	"answer_index" integer,
	"answer_text" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "mentor_review_courses" (
	"mentor_id" uuid NOT NULL,
	"course_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "mentor_review_courses_mentor_id_course_id_pk" PRIMARY KEY("mentor_id","course_id")
);
--> statement-breakpoint
CREATE TABLE "objective_courses" (
	"objective_id" uuid NOT NULL,
	"course_id" uuid NOT NULL,
	CONSTRAINT "objective_courses_objective_id_course_id_pk" PRIMARY KEY("objective_id","course_id")
);
--> statement-breakpoint
CREATE TABLE "ruta_module_courses" (
	"ruta_module_id" uuid NOT NULL,
	"course_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ruta_module_courses_ruta_module_id_course_id_pk" PRIMARY KEY("ruta_module_id","course_id")
);
--> statement-breakpoint
CREATE TABLE "student_courses" (
	"student_id" uuid NOT NULL,
	"course_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "student_courses_student_id_course_id_pk" PRIMARY KEY("student_id","course_id")
);
--> statement-breakpoint
CREATE TABLE "student_laboratories" (
	"student_id" uuid NOT NULL,
	"laboratory_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "student_laboratories_student_id_laboratory_id_pk" PRIMARY KEY("student_id","laboratory_id")
);
--> statement-breakpoint
CREATE TABLE "progress" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"student_id" uuid NOT NULL,
	"course_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "progress_student_course_unique" UNIQUE("student_id","course_id")
);
--> statement-breakpoint
CREATE TABLE "progress_lessons" (
	"progress_id" uuid NOT NULL,
	"lesson_id" uuid NOT NULL,
	"completed_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "progress_lessons_progress_id_lesson_id_pk" PRIMARY KEY("progress_id","lesson_id")
);
--> statement-breakpoint
CREATE TABLE "ruta_progress" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"student_id" uuid NOT NULL,
	"laboratory_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ruta_progress_student_lab_unique" UNIQUE("student_id","laboratory_id")
);
--> statement-breakpoint
CREATE TABLE "ruta_progress_lessons" (
	"ruta_progress_id" uuid NOT NULL,
	"lesson_id" uuid NOT NULL,
	"completed_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ruta_progress_lessons_ruta_progress_id_lesson_id_pk" PRIMARY KEY("ruta_progress_id","lesson_id")
);
--> statement-breakpoint
CREATE TABLE "certificates" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"code" text NOT NULL,
	"student_id" uuid NOT NULL,
	"laboratory_id" uuid NOT NULL,
	"issuer_id" uuid,
	"student_name_snapshot" text NOT NULL,
	"laboratory_name_snapshot" text NOT NULL,
	"issuer_name_snapshot" text NOT NULL,
	"hours" integer DEFAULT 0 NOT NULL,
	"lab_content_version" integer DEFAULT 1 NOT NULL,
	"requirements_snapshot" jsonb NOT NULL,
	"issued_at" timestamp with time zone DEFAULT now() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "certificates_hours_non_negative" CHECK ("certificates"."hours" >= 0)
);
--> statement-breakpoint
CREATE TABLE "quiz_attempts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"lesson_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"answers" jsonb NOT NULL,
	"score" integer NOT NULL,
	"passed" boolean NOT NULL,
	"attempted_at" timestamp with time zone DEFAULT now() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "quiz_attempts_score_range" CHECK ("quiz_attempts"."score" between 0 and 100)
);
--> statement-breakpoint
CREATE TABLE "submission_files" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"submission_id" uuid NOT NULL,
	"s3_key" text NOT NULL,
	"file_name" text NOT NULL,
	"content_type" text NOT NULL,
	"size_bytes" bigint NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "submissions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"course_id" uuid,
	"ruta_module_id" uuid,
	"student_id" uuid,
	"group_id" uuid,
	"lesson_id" uuid,
	"task_name" text NOT NULL,
	"comment" text DEFAULT '' NOT NULL,
	"submitted_at" timestamp with time zone DEFAULT now() NOT NULL,
	"grade" numeric(5, 2),
	"grading_mode" "grading_mode",
	"graded_by" uuid,
	"graded_at" timestamp with time zone,
	"feedback" text DEFAULT '' NOT NULL,
	"reviewed_by" uuid,
	"reviewed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "submissions_exactly_one_context" CHECK (("submissions"."course_id" is not null) <> ("submissions"."ruta_module_id" is not null)),
	CONSTRAINT "submissions_exactly_one_author" CHECK (("submissions"."student_id" is not null) <> ("submissions"."group_id" is not null)),
	CONSTRAINT "submissions_grade_has_scale_and_author" CHECK ("submissions"."grade" is null or ("submissions"."grading_mode" is not null and "submissions"."graded_by" is not null and "submissions"."graded_at" is not null)),
	CONSTRAINT "submissions_review_mode_has_no_grade" CHECK ("submissions"."grading_mode" is distinct from 'review' or "submissions"."grade" is null)
);
--> statement-breakpoint
CREATE TABLE "calendar_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"title" text DEFAULT '' NOT NULL,
	"description" text DEFAULT '' NOT NULL,
	"starts_at" timestamp with time zone NOT NULL,
	"type" "calendar_event_type" DEFAULT 'ruta_impacto' NOT NULL,
	"meet_link" text DEFAULT '' NOT NULL,
	"guests" text DEFAULT '' NOT NULL,
	"course_id" uuid,
	"laboratory_id" uuid,
	"created_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "calendar_events_target_matches_type" CHECK (("calendar_events"."type" = 'open_learning_sync' and "calendar_events"."course_id" is not null and "calendar_events"."laboratory_id" is null)
       or ("calendar_events"."type" in ('ruta_impacto','mentoria') and "calendar_events"."course_id" is null))
);
--> statement-breakpoint
CREATE TABLE "communication_resources" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"title" text NOT NULL,
	"description" text DEFAULT '' NOT NULL,
	"type" "comm_resource_type" NOT NULL,
	"file_name" text,
	"s3_key" text,
	"content_type" text,
	"size_bytes" bigint,
	"url" text,
	"uploaded_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "communication_resources_source_matches_type" CHECK (("communication_resources"."type" = 'file' and "communication_resources"."s3_key" is not null and "communication_resources"."url" is null)
       or ("communication_resources"."type" = 'link' and "communication_resources"."url" is not null and "communication_resources"."s3_key" is null))
);
--> statement-breakpoint
CREATE TABLE "evidences" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"donor_id" uuid NOT NULL,
	"project_id" uuid,
	"type" "evidence_type" NOT NULL,
	"title" text NOT NULL,
	"description" text DEFAULT '' NOT NULL,
	"s3_key" text,
	"file_name" text,
	"content_type" text,
	"size_bytes" bigint,
	"evidence_date" timestamp with time zone DEFAULT now() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "expo_checklist_items" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"group_id" uuid NOT NULL,
	"order_index" integer DEFAULT 0 NOT NULL,
	"label" text NOT NULL,
	"done" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "forum_likes" (
	"post_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "forum_likes_post_id_user_id_pk" PRIMARY KEY("post_id","user_id")
);
--> statement-breakpoint
CREATE TABLE "forum_posts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"author_id" uuid NOT NULL,
	"body" text NOT NULL,
	"category" "forum_category" DEFAULT 'question' NOT NULL,
	"pinned" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "forum_replies" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"post_id" uuid NOT NULL,
	"author_id" uuid NOT NULL,
	"body" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "notifications" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"title" text NOT NULL,
	"body" text DEFAULT '' NOT NULL,
	"read_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "site_content" (
	"id" integer PRIMARY KEY DEFAULT 1 NOT NULL,
	"hero_title" text DEFAULT '' NOT NULL,
	"hero_subtitle" text DEFAULT '' NOT NULL,
	"banner_text" text DEFAULT '' NOT NULL,
	"about_text" text DEFAULT '' NOT NULL,
	"meeting_link" text DEFAULT '' NOT NULL,
	"stat_students" integer DEFAULT 0 NOT NULL,
	"stat_projects" integer DEFAULT 0 NOT NULL,
	"stat_labs" integer DEFAULT 0 NOT NULL,
	"stat_universities" integer DEFAULT 0 NOT NULL,
	"updated_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "site_content_singleton" CHECK ("site_content"."id" = 1)
);
--> statement-breakpoint
CREATE TABLE "site_gallery_images" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"s3_key" text NOT NULL,
	"order_index" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "staff_notes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"student_id" uuid NOT NULL,
	"course_id" uuid NOT NULL,
	"author_id" uuid,
	"note" text DEFAULT '' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "staff_notes_student_course_unique" UNIQUE("student_id","course_id")
);
--> statement-breakpoint
ALTER TABLE "audit_log" ADD CONSTRAINT "audit_log_actor_id_users_id_fk" FOREIGN KEY ("actor_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_replaced_by_refresh_tokens_id_fk" FOREIGN KEY ("replaced_by") REFERENCES "public"."refresh_tokens"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "users" ADD CONSTRAINT "users_company_id_users_id_fk" FOREIGN KEY ("company_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "users" ADD CONSTRAINT "users_donor_id_users_id_fk" FOREIGN KEY ("donor_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "group_members" ADD CONSTRAINT "group_members_group_id_groups_id_fk" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "group_members" ADD CONSTRAINT "group_members_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "groups" ADD CONSTRAINT "groups_project_id_projects_id_fk" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "groups" ADD CONSTRAINT "groups_advisor_id_users_id_fk" FOREIGN KEY ("advisor_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "project_ods" ADD CONSTRAINT "project_ods_project_id_projects_id_fk" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "project_ods" ADD CONSTRAINT "project_ods_ods_code_ods_goals_code_fk" FOREIGN KEY ("ods_code") REFERENCES "public"."ods_goals"("code") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "laboratories" ADD CONSTRAINT "laboratories_sponsor_company_id_users_id_fk" FOREIGN KEY ("sponsor_company_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "laboratory_mentors" ADD CONSTRAINT "laboratory_mentors_laboratory_id_laboratories_id_fk" FOREIGN KEY ("laboratory_id") REFERENCES "public"."laboratories"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "laboratory_mentors" ADD CONSTRAINT "laboratory_mentors_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "objectives" ADD CONSTRAINT "objectives_phase_id_phases_id_fk" FOREIGN KEY ("phase_id") REFERENCES "public"."phases"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "phases" ADD CONSTRAINT "phases_laboratory_id_laboratories_id_fk" FOREIGN KEY ("laboratory_id") REFERENCES "public"."laboratories"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ruta_modules" ADD CONSTRAINT "ruta_modules_phase_id_phases_id_fk" FOREIGN KEY ("phase_id") REFERENCES "public"."phases"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "activity_allowed_types" ADD CONSTRAINT "activity_allowed_types_lesson_id_lesson_activities_lesson_id_fk" FOREIGN KEY ("lesson_id") REFERENCES "public"."lesson_activities"("lesson_id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "activity_rubric_items" ADD CONSTRAINT "activity_rubric_items_lesson_id_lesson_activities_lesson_id_fk" FOREIGN KEY ("lesson_id") REFERENCES "public"."lesson_activities"("lesson_id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "course_competencies" ADD CONSTRAINT "course_competencies_course_id_courses_id_fk" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "course_competencies" ADD CONSTRAINT "course_competencies_competency_code_competencies_code_fk" FOREIGN KEY ("competency_code") REFERENCES "public"."competencies"("code") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "course_learning_outcomes" ADD CONSTRAINT "course_learning_outcomes_course_id_courses_id_fk" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "course_modules" ADD CONSTRAINT "course_modules_course_id_courses_id_fk" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "course_objectives" ADD CONSTRAINT "course_objectives_course_id_courses_id_fk" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "course_ods" ADD CONSTRAINT "course_ods_course_id_courses_id_fk" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "course_ods" ADD CONSTRAINT "course_ods_ods_code_ods_goals_code_fk" FOREIGN KEY ("ods_code") REFERENCES "public"."ods_goals"("code") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "course_prerequisites" ADD CONSTRAINT "course_prerequisites_course_id_courses_id_fk" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "course_prerequisites" ADD CONSTRAINT "course_prerequisites_prerequisite_course_id_courses_id_fk" FOREIGN KEY ("prerequisite_course_id") REFERENCES "public"."courses"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "course_tags" ADD CONSTRAINT "course_tags_course_id_courses_id_fk" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "courses" ADD CONSTRAINT "courses_laboratory_id_laboratories_id_fk" FOREIGN KEY ("laboratory_id") REFERENCES "public"."laboratories"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "courses" ADD CONSTRAINT "courses_creator_id_users_id_fk" FOREIGN KEY ("creator_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "courses" ADD CONSTRAINT "courses_sponsor_company_id_users_id_fk" FOREIGN KEY ("sponsor_company_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "lesson_activities" ADD CONSTRAINT "lesson_activities_lesson_id_lessons_id_fk" FOREIGN KEY ("lesson_id") REFERENCES "public"."lessons"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "lessons" ADD CONSTRAINT "lessons_course_module_id_course_modules_id_fk" FOREIGN KEY ("course_module_id") REFERENCES "public"."course_modules"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "lessons" ADD CONSTRAINT "lessons_ruta_module_id_ruta_modules_id_fk" FOREIGN KEY ("ruta_module_id") REFERENCES "public"."ruta_modules"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "quiz_question_options" ADD CONSTRAINT "quiz_question_options_quiz_question_id_quiz_questions_id_fk" FOREIGN KEY ("quiz_question_id") REFERENCES "public"."quiz_questions"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "quiz_questions" ADD CONSTRAINT "quiz_questions_lesson_id_lessons_id_fk" FOREIGN KEY ("lesson_id") REFERENCES "public"."lessons"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "mentor_review_courses" ADD CONSTRAINT "mentor_review_courses_mentor_id_users_id_fk" FOREIGN KEY ("mentor_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "mentor_review_courses" ADD CONSTRAINT "mentor_review_courses_course_id_courses_id_fk" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "objective_courses" ADD CONSTRAINT "objective_courses_objective_id_objectives_id_fk" FOREIGN KEY ("objective_id") REFERENCES "public"."objectives"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "objective_courses" ADD CONSTRAINT "objective_courses_course_id_courses_id_fk" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ruta_module_courses" ADD CONSTRAINT "ruta_module_courses_ruta_module_id_ruta_modules_id_fk" FOREIGN KEY ("ruta_module_id") REFERENCES "public"."ruta_modules"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ruta_module_courses" ADD CONSTRAINT "ruta_module_courses_course_id_courses_id_fk" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_courses" ADD CONSTRAINT "student_courses_student_id_users_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_courses" ADD CONSTRAINT "student_courses_course_id_courses_id_fk" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_laboratories" ADD CONSTRAINT "student_laboratories_student_id_users_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_laboratories" ADD CONSTRAINT "student_laboratories_laboratory_id_laboratories_id_fk" FOREIGN KEY ("laboratory_id") REFERENCES "public"."laboratories"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "progress" ADD CONSTRAINT "progress_student_id_users_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "progress" ADD CONSTRAINT "progress_course_id_courses_id_fk" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "progress_lessons" ADD CONSTRAINT "progress_lessons_progress_id_progress_id_fk" FOREIGN KEY ("progress_id") REFERENCES "public"."progress"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "progress_lessons" ADD CONSTRAINT "progress_lessons_lesson_id_lessons_id_fk" FOREIGN KEY ("lesson_id") REFERENCES "public"."lessons"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ruta_progress" ADD CONSTRAINT "ruta_progress_student_id_users_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ruta_progress" ADD CONSTRAINT "ruta_progress_laboratory_id_laboratories_id_fk" FOREIGN KEY ("laboratory_id") REFERENCES "public"."laboratories"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ruta_progress_lessons" ADD CONSTRAINT "ruta_progress_lessons_ruta_progress_id_ruta_progress_id_fk" FOREIGN KEY ("ruta_progress_id") REFERENCES "public"."ruta_progress"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ruta_progress_lessons" ADD CONSTRAINT "ruta_progress_lessons_lesson_id_lessons_id_fk" FOREIGN KEY ("lesson_id") REFERENCES "public"."lessons"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "certificates" ADD CONSTRAINT "certificates_student_id_users_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "certificates" ADD CONSTRAINT "certificates_laboratory_id_laboratories_id_fk" FOREIGN KEY ("laboratory_id") REFERENCES "public"."laboratories"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "certificates" ADD CONSTRAINT "certificates_issuer_id_users_id_fk" FOREIGN KEY ("issuer_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "quiz_attempts" ADD CONSTRAINT "quiz_attempts_lesson_id_lessons_id_fk" FOREIGN KEY ("lesson_id") REFERENCES "public"."lessons"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "quiz_attempts" ADD CONSTRAINT "quiz_attempts_student_id_users_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "submission_files" ADD CONSTRAINT "submission_files_submission_id_submissions_id_fk" FOREIGN KEY ("submission_id") REFERENCES "public"."submissions"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "submissions" ADD CONSTRAINT "submissions_course_id_courses_id_fk" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "submissions" ADD CONSTRAINT "submissions_ruta_module_id_ruta_modules_id_fk" FOREIGN KEY ("ruta_module_id") REFERENCES "public"."ruta_modules"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "submissions" ADD CONSTRAINT "submissions_student_id_users_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "submissions" ADD CONSTRAINT "submissions_group_id_groups_id_fk" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "submissions" ADD CONSTRAINT "submissions_lesson_id_lessons_id_fk" FOREIGN KEY ("lesson_id") REFERENCES "public"."lessons"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "submissions" ADD CONSTRAINT "submissions_graded_by_users_id_fk" FOREIGN KEY ("graded_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "submissions" ADD CONSTRAINT "submissions_reviewed_by_users_id_fk" FOREIGN KEY ("reviewed_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "calendar_events" ADD CONSTRAINT "calendar_events_course_id_courses_id_fk" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "calendar_events" ADD CONSTRAINT "calendar_events_laboratory_id_laboratories_id_fk" FOREIGN KEY ("laboratory_id") REFERENCES "public"."laboratories"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "calendar_events" ADD CONSTRAINT "calendar_events_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "communication_resources" ADD CONSTRAINT "communication_resources_uploaded_by_users_id_fk" FOREIGN KEY ("uploaded_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "evidences" ADD CONSTRAINT "evidences_donor_id_users_id_fk" FOREIGN KEY ("donor_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "evidences" ADD CONSTRAINT "evidences_project_id_projects_id_fk" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "expo_checklist_items" ADD CONSTRAINT "expo_checklist_items_group_id_groups_id_fk" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "forum_likes" ADD CONSTRAINT "forum_likes_post_id_forum_posts_id_fk" FOREIGN KEY ("post_id") REFERENCES "public"."forum_posts"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "forum_likes" ADD CONSTRAINT "forum_likes_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "forum_posts" ADD CONSTRAINT "forum_posts_author_id_users_id_fk" FOREIGN KEY ("author_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "forum_replies" ADD CONSTRAINT "forum_replies_post_id_forum_posts_id_fk" FOREIGN KEY ("post_id") REFERENCES "public"."forum_posts"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "forum_replies" ADD CONSTRAINT "forum_replies_author_id_users_id_fk" FOREIGN KEY ("author_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "site_content" ADD CONSTRAINT "site_content_updated_by_users_id_fk" FOREIGN KEY ("updated_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_notes" ADD CONSTRAINT "staff_notes_student_id_users_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_notes" ADD CONSTRAINT "staff_notes_course_id_courses_id_fk" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_notes" ADD CONSTRAINT "staff_notes_author_id_users_id_fk" FOREIGN KEY ("author_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "audit_log_entity_idx" ON "audit_log" USING btree ("entity_type","entity_id");--> statement-breakpoint
CREATE INDEX "audit_log_actor_id_idx" ON "audit_log" USING btree ("actor_id");--> statement-breakpoint
CREATE INDEX "audit_log_created_at_idx" ON "audit_log" USING btree ("created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "refresh_tokens_hash_unique" ON "refresh_tokens" USING btree ("token_hash");--> statement-breakpoint
CREATE INDEX "refresh_tokens_user_id_idx" ON "refresh_tokens" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "refresh_tokens_expires_at_idx" ON "refresh_tokens" USING btree ("expires_at");--> statement-breakpoint
CREATE UNIQUE INDEX "users_email_lower_unique" ON "users" USING btree (lower("email"));--> statement-breakpoint
CREATE UNIQUE INDEX "users_impact_code_unique" ON "users" USING btree ("impact_code") WHERE "users"."impact_code" is not null;--> statement-breakpoint
CREATE INDEX "users_role_idx" ON "users" USING btree ("role");--> statement-breakpoint
CREATE INDEX "users_company_id_idx" ON "users" USING btree ("company_id");--> statement-breakpoint
CREATE INDEX "users_donor_id_idx" ON "users" USING btree ("donor_id");--> statement-breakpoint
CREATE INDEX "users_university_idx" ON "users" USING btree ("university");--> statement-breakpoint
CREATE INDEX "users_deleted_at_idx" ON "users" USING btree ("deleted_at");--> statement-breakpoint
CREATE INDEX "group_members_user_id_idx" ON "group_members" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "groups_project_id_idx" ON "groups" USING btree ("project_id");--> statement-breakpoint
CREATE INDEX "groups_advisor_id_idx" ON "groups" USING btree ("advisor_id");--> statement-breakpoint
CREATE INDEX "groups_deleted_at_idx" ON "groups" USING btree ("deleted_at");--> statement-breakpoint
CREATE INDEX "project_ods_ods_code_idx" ON "project_ods" USING btree ("ods_code");--> statement-breakpoint
CREATE INDEX "projects_stage_idx" ON "projects" USING btree ("stage");--> statement-breakpoint
CREATE INDEX "projects_deleted_at_idx" ON "projects" USING btree ("deleted_at");--> statement-breakpoint
CREATE INDEX "laboratories_sponsor_company_id_idx" ON "laboratories" USING btree ("sponsor_company_id");--> statement-breakpoint
CREATE INDEX "laboratories_deleted_at_idx" ON "laboratories" USING btree ("deleted_at");--> statement-breakpoint
CREATE INDEX "laboratory_mentors_user_id_idx" ON "laboratory_mentors" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "objectives_phase_id_idx" ON "objectives" USING btree ("phase_id");--> statement-breakpoint
CREATE INDEX "phases_laboratory_id_idx" ON "phases" USING btree ("laboratory_id");--> statement-breakpoint
CREATE INDEX "ruta_modules_phase_id_idx" ON "ruta_modules" USING btree ("phase_id");--> statement-breakpoint
CREATE INDEX "activity_rubric_items_lesson_id_idx" ON "activity_rubric_items" USING btree ("lesson_id");--> statement-breakpoint
CREATE INDEX "course_competencies_code_idx" ON "course_competencies" USING btree ("competency_code");--> statement-breakpoint
CREATE INDEX "course_learning_outcomes_course_id_idx" ON "course_learning_outcomes" USING btree ("course_id");--> statement-breakpoint
CREATE INDEX "course_modules_course_id_idx" ON "course_modules" USING btree ("course_id");--> statement-breakpoint
CREATE INDEX "course_objectives_course_id_idx" ON "course_objectives" USING btree ("course_id");--> statement-breakpoint
CREATE INDEX "course_ods_ods_code_idx" ON "course_ods" USING btree ("ods_code");--> statement-breakpoint
CREATE INDEX "course_prerequisites_prereq_idx" ON "course_prerequisites" USING btree ("prerequisite_course_id");--> statement-breakpoint
CREATE INDEX "course_tags_tag_idx" ON "course_tags" USING btree ("tag");--> statement-breakpoint
CREATE INDEX "courses_laboratory_id_idx" ON "courses" USING btree ("laboratory_id");--> statement-breakpoint
CREATE INDEX "courses_creator_id_idx" ON "courses" USING btree ("creator_id");--> statement-breakpoint
CREATE INDEX "courses_sponsor_company_id_idx" ON "courses" USING btree ("sponsor_company_id");--> statement-breakpoint
CREATE INDEX "courses_status_idx" ON "courses" USING btree ("status");--> statement-breakpoint
CREATE INDEX "courses_is_open_learning_idx" ON "courses" USING btree ("is_open_learning");--> statement-breakpoint
CREATE INDEX "courses_deleted_at_idx" ON "courses" USING btree ("deleted_at");--> statement-breakpoint
CREATE INDEX "lessons_course_module_id_idx" ON "lessons" USING btree ("course_module_id");--> statement-breakpoint
CREATE INDEX "lessons_ruta_module_id_idx" ON "lessons" USING btree ("ruta_module_id");--> statement-breakpoint
CREATE INDEX "lessons_type_idx" ON "lessons" USING btree ("type");--> statement-breakpoint
CREATE INDEX "quiz_question_options_question_id_idx" ON "quiz_question_options" USING btree ("quiz_question_id");--> statement-breakpoint
CREATE INDEX "quiz_questions_lesson_id_idx" ON "quiz_questions" USING btree ("lesson_id");--> statement-breakpoint
CREATE INDEX "mentor_review_courses_course_id_idx" ON "mentor_review_courses" USING btree ("course_id");--> statement-breakpoint
CREATE INDEX "objective_courses_course_id_idx" ON "objective_courses" USING btree ("course_id");--> statement-breakpoint
CREATE INDEX "ruta_module_courses_course_id_idx" ON "ruta_module_courses" USING btree ("course_id");--> statement-breakpoint
CREATE INDEX "student_courses_course_id_idx" ON "student_courses" USING btree ("course_id");--> statement-breakpoint
CREATE INDEX "student_laboratories_laboratory_id_idx" ON "student_laboratories" USING btree ("laboratory_id");--> statement-breakpoint
CREATE INDEX "progress_student_id_idx" ON "progress" USING btree ("student_id");--> statement-breakpoint
CREATE INDEX "progress_course_id_idx" ON "progress" USING btree ("course_id");--> statement-breakpoint
CREATE INDEX "progress_lessons_lesson_id_idx" ON "progress_lessons" USING btree ("lesson_id");--> statement-breakpoint
CREATE INDEX "ruta_progress_student_id_idx" ON "ruta_progress" USING btree ("student_id");--> statement-breakpoint
CREATE INDEX "ruta_progress_laboratory_id_idx" ON "ruta_progress" USING btree ("laboratory_id");--> statement-breakpoint
CREATE INDEX "ruta_progress_lessons_lesson_id_idx" ON "ruta_progress_lessons" USING btree ("lesson_id");--> statement-breakpoint
CREATE UNIQUE INDEX "certificates_code_unique" ON "certificates" USING btree ("code");--> statement-breakpoint
CREATE UNIQUE INDEX "certificates_student_lab_unique" ON "certificates" USING btree ("student_id","laboratory_id");--> statement-breakpoint
CREATE INDEX "certificates_student_id_idx" ON "certificates" USING btree ("student_id");--> statement-breakpoint
CREATE INDEX "certificates_laboratory_id_idx" ON "certificates" USING btree ("laboratory_id");--> statement-breakpoint
CREATE INDEX "certificates_issuer_id_idx" ON "certificates" USING btree ("issuer_id");--> statement-breakpoint
CREATE INDEX "quiz_attempts_lesson_student_idx" ON "quiz_attempts" USING btree ("lesson_id","student_id");--> statement-breakpoint
CREATE INDEX "submission_files_submission_id_idx" ON "submission_files" USING btree ("submission_id");--> statement-breakpoint
CREATE UNIQUE INDEX "submission_files_s3_key_unique" ON "submission_files" USING btree ("s3_key");--> statement-breakpoint
CREATE INDEX "submissions_course_id_idx" ON "submissions" USING btree ("course_id");--> statement-breakpoint
CREATE INDEX "submissions_ruta_module_id_idx" ON "submissions" USING btree ("ruta_module_id");--> statement-breakpoint
CREATE INDEX "submissions_student_id_idx" ON "submissions" USING btree ("student_id");--> statement-breakpoint
CREATE INDEX "submissions_group_id_idx" ON "submissions" USING btree ("group_id");--> statement-breakpoint
CREATE INDEX "submissions_lesson_id_idx" ON "submissions" USING btree ("lesson_id");--> statement-breakpoint
CREATE INDEX "submissions_graded_by_idx" ON "submissions" USING btree ("graded_by");--> statement-breakpoint
CREATE INDEX "submissions_deleted_at_idx" ON "submissions" USING btree ("deleted_at");--> statement-breakpoint
CREATE INDEX "calendar_events_starts_at_idx" ON "calendar_events" USING btree ("starts_at");--> statement-breakpoint
CREATE INDEX "calendar_events_course_id_idx" ON "calendar_events" USING btree ("course_id");--> statement-breakpoint
CREATE INDEX "calendar_events_laboratory_id_idx" ON "calendar_events" USING btree ("laboratory_id");--> statement-breakpoint
CREATE INDEX "calendar_events_type_idx" ON "calendar_events" USING btree ("type");--> statement-breakpoint
CREATE INDEX "communication_resources_uploaded_by_idx" ON "communication_resources" USING btree ("uploaded_by");--> statement-breakpoint
CREATE INDEX "communication_resources_deleted_at_idx" ON "communication_resources" USING btree ("deleted_at");--> statement-breakpoint
CREATE INDEX "evidences_donor_id_idx" ON "evidences" USING btree ("donor_id");--> statement-breakpoint
CREATE INDEX "evidences_project_id_idx" ON "evidences" USING btree ("project_id");--> statement-breakpoint
CREATE INDEX "evidences_deleted_at_idx" ON "evidences" USING btree ("deleted_at");--> statement-breakpoint
CREATE INDEX "expo_checklist_items_group_id_idx" ON "expo_checklist_items" USING btree ("group_id");--> statement-breakpoint
CREATE INDEX "forum_likes_user_id_idx" ON "forum_likes" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "forum_posts_author_id_idx" ON "forum_posts" USING btree ("author_id");--> statement-breakpoint
CREATE INDEX "forum_posts_created_at_idx" ON "forum_posts" USING btree ("created_at");--> statement-breakpoint
CREATE INDEX "forum_posts_pinned_idx" ON "forum_posts" USING btree ("pinned");--> statement-breakpoint
CREATE INDEX "forum_posts_deleted_at_idx" ON "forum_posts" USING btree ("deleted_at");--> statement-breakpoint
CREATE INDEX "forum_replies_post_id_idx" ON "forum_replies" USING btree ("post_id");--> statement-breakpoint
CREATE INDEX "forum_replies_author_id_idx" ON "forum_replies" USING btree ("author_id");--> statement-breakpoint
CREATE INDEX "notifications_user_created_idx" ON "notifications" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "site_gallery_images_s3_key_unique" ON "site_gallery_images" USING btree ("s3_key");--> statement-breakpoint
CREATE INDEX "staff_notes_course_id_idx" ON "staff_notes" USING btree ("course_id");