ALTER TABLE "notes" ADD COLUMN "favorite" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "notes" ADD COLUMN "archived_at" timestamp with time zone;--> statement-breakpoint
CREATE INDEX "notes_user_archived_idx" ON "notes" USING btree ("user_id","archived_at");