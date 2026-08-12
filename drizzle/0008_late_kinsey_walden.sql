CREATE TYPE "public"."audio_episode_status" AS ENUM('processing', 'ready', 'failed');--> statement-breakpoint
CREATE TABLE "audio_episodes" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"notebook_id" text NOT NULL,
	"title" text NOT NULL,
	"style" text DEFAULT 'focused' NOT NULL,
	"length" text DEFAULT 'standard' NOT NULL,
	"status" "audio_episode_status" DEFAULT 'processing' NOT NULL,
	"pipeline_stage" text DEFAULT 'queued' NOT NULL,
	"error_message" text,
	"script" text,
	"transcript" jsonb,
	"audio_data" text,
	"mime_type" text DEFAULT 'audio/mpeg' NOT NULL,
	"duration_sec" integer,
	"word_count" integer,
	"playback_position_sec" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "audio_episodes" ADD CONSTRAINT "audio_episodes_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "audio_episodes" ADD CONSTRAINT "audio_episodes_notebook_id_notebooks_id_fk" FOREIGN KEY ("notebook_id") REFERENCES "public"."notebooks"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "audio_user_created_idx" ON "audio_episodes" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE INDEX "audio_notebook_idx" ON "audio_episodes" USING btree ("notebook_id");