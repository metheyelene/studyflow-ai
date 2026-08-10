// ─────────────────────────────────────────────────────────────────────
// Privacy-conscious in-house analytics. Events go to the analytics_events
// table (no third-party scripts, no tracking pixels). Tracking must
// never break the user flow — failures are logged and swallowed.
//
// Event names are typed here so call sites stay consistent and the
// admin dashboard can rely on them.
// ─────────────────────────────────────────────────────────────────────
import { getDb, schema } from "@/db";

export const EVENTS = {
  SIGNUP: "signup",
  ONBOARDING_COMPLETED: "onboarding_completed",
  NOTE_CREATED: "note_created",
  DOCUMENT_UPLOADED: "document_uploaded",
  SUMMARY_GENERATED: "summary_generated",
  FLASHCARDS_GENERATED: "flashcards_generated",
  QUIZ_STARTED: "quiz_started",
  QUIZ_COMPLETED: "quiz_completed",

  // Monetization funnel (docs/premium-conversion.md §5)
  PREMIUM_FEATURE_VIEWED: "premium_feature_viewed",
  PREMIUM_PREVIEW_STARTED: "premium_preview_started",
  PAYWALL_VIEWED: "paywall_viewed",
  PRICING_VIEWED: "pricing_viewed",
  CHECKOUT_STARTED: "checkout_started",
  CHECKOUT_COMPLETED: "checkout_completed",
  SUBSCRIPTION_STARTED: "subscription_started",
  SUBSCRIPTION_CANCELLED: "subscription_cancelled",
  UPGRADE_DECLINED: "upgrade_declined",

  // Founding-member offer (docs/founding-members.md §analytics)
  FOUNDING_OFFER_VIEWED: "founding_offer_viewed",
  FOUNDING_CHECKOUT_STARTED: "founding_checkout_started",
  FOUNDING_SUBSCRIPTION_COMPLETED: "founding_subscription_completed",
  FOUNDING_SUBSCRIPTION_FAILED: "founding_subscription_failed",
  FOUNDING_MEMBERSHIP_CLAIMED: "founding_membership_claimed",
  FOUNDING_MEMBERSHIP_CANCELLED: "founding_membership_cancelled",
} as const;

export type EventName = (typeof EVENTS)[keyof typeof EVENTS];

/**
 * Record an event server-side. `userId` may be null for pre-auth events
 * (the column allows it). Never throws.
 */
export async function trackEvent(
  userId: string | null,
  eventName: EventName | string,
  properties?: Record<string, unknown>,
): Promise<void> {
  try {
    const db = getDb();
    await db.insert(schema.analyticsEvents).values({
      userId: userId ?? null,
      eventName,
      properties: properties ?? {},
    });
  } catch (err) {
    console.error(`[analytics] failed to track "${eventName}":`, err);
  }
}
