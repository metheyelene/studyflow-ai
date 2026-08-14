-- Google Play Billing support (docs/billing-decision.md §5–6):
--   * subscriptions gains Play purchase identifiers (one channel per
--     platform, same entitlement row).
--   * founding_members.subscription_id stores the PROVIDER id (Stripe
--     "sub_...", Play purchase token). Its old FK to subscriptions.id
--     could never be satisfied — webhooks only carry provider ids —
--     so it is dropped. The unique constraint stays (one member per
--     provider subscription).
ALTER TABLE "subscriptions" ADD COLUMN "play_package_name" text;--> statement-breakpoint
ALTER TABLE "subscriptions" ADD COLUMN "play_subscription_id" text;--> statement-breakpoint
ALTER TABLE "subscriptions" ADD COLUMN "play_purchase_token" text;--> statement-breakpoint
ALTER TABLE "subscriptions" ADD COLUMN "play_order_id" text;--> statement-breakpoint
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_play_subscription_id_unique" UNIQUE("play_subscription_id");--> statement-breakpoint
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_play_purchase_token_unique" UNIQUE("play_purchase_token");--> statement-breakpoint
ALTER TABLE "founding_members" DROP CONSTRAINT "founding_members_subscription_id_subscriptions_id_fk";--> statement-breakpoint
