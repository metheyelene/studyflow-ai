CREATE TYPE "public"."notebook_source_status" AS ENUM('processing', 'ready', 'failed');--> statement-breakpoint
CREATE TYPE "public"."notebook_source_type" AS ENUM('pasted', 'uploaded', 'url', 'transcript');--> statement-breakpoint
CREATE TABLE "ai_cache" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"notebook_id" text NOT NULL,
	"key" text NOT NULL,
	"payload" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ai_cache_key_unique" UNIQUE("key")
);
--> statement-breakpoint
CREATE TABLE "notebook_sources" (
	"id" text PRIMARY KEY NOT NULL,
	"notebook_id" text NOT NULL,
	"user_id" text NOT NULL,
	"title" text NOT NULL,
	"source_type" "notebook_source_type" DEFAULT 'pasted' NOT NULL,
	"content" text DEFAULT '' NOT NULL,
	"status" "notebook_source_status" DEFAULT 'processing' NOT NULL,
	"error_message" text,
	"word_count" integer,
	"page_count" integer,
	"meta" jsonb,
	"version" integer DEFAULT 1 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "notebooks" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"subject_id" text,
	"title" text NOT NULL,
	"description" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "source_chunks" (
	"id" text PRIMARY KEY NOT NULL,
	"source_id" text NOT NULL,
	"notebook_id" text NOT NULL,
	"user_id" text NOT NULL,
	"content" text NOT NULL,
	"chunk_index" integer DEFAULT 0 NOT NULL,
	"char_start" integer DEFAULT 0 NOT NULL,
	"char_end" integer DEFAULT 0 NOT NULL,
	"page" integer,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "ai_cache" ADD CONSTRAINT "ai_cache_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ai_cache" ADD CONSTRAINT "ai_cache_notebook_id_notebooks_id_fk" FOREIGN KEY ("notebook_id") REFERENCES "public"."notebooks"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notebook_sources" ADD CONSTRAINT "notebook_sources_notebook_id_notebooks_id_fk" FOREIGN KEY ("notebook_id") REFERENCES "public"."notebooks"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notebook_sources" ADD CONSTRAINT "notebook_sources_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notebooks" ADD CONSTRAINT "notebooks_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notebooks" ADD CONSTRAINT "notebooks_subject_id_subjects_id_fk" FOREIGN KEY ("subject_id") REFERENCES "public"."subjects"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "source_chunks" ADD CONSTRAINT "source_chunks_source_id_notebook_sources_id_fk" FOREIGN KEY ("source_id") REFERENCES "public"."notebook_sources"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "source_chunks" ADD CONSTRAINT "source_chunks_notebook_id_notebooks_id_fk" FOREIGN KEY ("notebook_id") REFERENCES "public"."notebooks"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "source_chunks" ADD CONSTRAINT "source_chunks_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "ai_cache_user_time_idx" ON "ai_cache" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE INDEX "sources_notebook_idx" ON "notebook_sources" USING btree ("notebook_id");--> statement-breakpoint
CREATE INDEX "sources_user_idx" ON "notebook_sources" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "notebooks_user_updated_idx" ON "notebooks" USING btree ("user_id","updated_at");--> statement-breakpoint
CREATE INDEX "chunks_source_idx" ON "source_chunks" USING btree ("source_id");--> statement-breakpoint
CREATE INDEX "chunks_notebook_idx" ON "source_chunks" USING btree ("notebook_id");