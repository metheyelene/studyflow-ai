CREATE TABLE "founding_member_counter" (
	"id" integer PRIMARY KEY NOT NULL,
	"claimed" integer DEFAULT 0 NOT NULL,
	"cap" integer DEFAULT 35 NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "founding_members" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"subscription_id" text NOT NULL,
	"status" text DEFAULT 'active' NOT NULL,
	"claimed_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "founding_members_user_id_unique" UNIQUE("user_id"),
	CONSTRAINT "founding_members_subscription_id_unique" UNIQUE("subscription_id")
);
--> statement-breakpoint
ALTER TABLE "founding_members" ADD CONSTRAINT "founding_members_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "founding_members" ADD CONSTRAINT "founding_members_subscription_id_subscriptions_id_fk" FOREIGN KEY ("subscription_id") REFERENCES "public"."subscriptions"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "founding_members_status_idx" ON "founding_members" USING btree ("status");