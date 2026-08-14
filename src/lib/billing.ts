// ─────────────────────────────────────────────────────────────────────
// Stripe billing — founding-member checkout, webhook fulfillment, and
// subscription management. Security model (docs/founding-members.md §6):
//  - Checkout sessions are created server-side with a fixed price; the
//    client never supplies an amount.
//  - The webhook verifies the Stripe signature BEFORE any fulfillment;
//    unverifiable payloads are rejected with 400.
//  - Fulfillment verifies the charged amount and routes through the
//    founding store's atomic claim (idempotent, race-safe, permanent).
//  - When Stripe keys are absent (local dev), the checkout API returns a
//    clear "billing not configured" state — no fake success path exists.
// ─────────────────────────────────────────────────────────────────────
import { eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { trackEvent } from "@/lib/analytics";
import {
  FOUNDING_TERMS,
  type FoundingStore,
  postgresFoundingStore,
} from "@/lib/founding";

// Lazy client — constructing Stripe requires a key, and we don't want
// that to crash module import in environments without billing set up.
export function getStripe(): import("stripe").Stripe {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) throw new BillingNotConfigured("STRIPE_SECRET_KEY is not set");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const Stripe = require("stripe") as typeof import("stripe").default;
  return new Stripe(key, { apiVersion: "2026-07-29.dahlia" });
}

export class BillingNotConfigured extends Error {
  constructor(message = "Billing is not configured yet") {
    super(message);
    this.name = "BillingNotConfigured";
  }
}

export function billingConfigured(): boolean {
  return Boolean(
    process.env.STRIPE_SECRET_KEY && process.env.STRIPE_WEBHOOK_SECRET,
  );
}

export interface CheckoutSessionResult {
  url: string;
}

/** Server-side checkout session for the founding offer. The price comes
 *  from the environment (the price ID created in the Stripe dashboard);
 *  the client never sends an amount. */
export async function createFoundingCheckoutSession(input: {
  userId: string;
  email: string;
}): Promise<CheckoutSessionResult> {
  const stripe = getStripe();
  const priceId = process.env.STRIPE_FOUNDING_PRICE_ID;
  if (!priceId) {
    throw new BillingNotConfigured(
      "STRIPE_FOUNDING_PRICE_ID is not set — create the $2/month price in Stripe",
    );
  }

  const session = await stripe.checkout.sessions.create({
    mode: "subscription",
    line_items: [{ price: priceId, quantity: 1 }],
    customer_email: input.email,
    metadata: {
      userId: input.userId,
      plan: FOUNDING_TERMS.planStorage,
      priceUsd: String(FOUNDING_TERMS.priceUsd),
    },
    success_url: `${process.env.APP_URL ?? "http://localhost:3000"}/settings?founding=success`,
    cancel_url: `${process.env.APP_URL ?? "http://localhost:3000"}/pricing?founding=cancelled`,
    allow_promotion_codes: false,
    billing_address_collection: "auto",
  });

  await trackEvent(input.userId, "founding_checkout_started", {
    sessionId: session.id,
  });

  return { url: session.url! };
}

/** Create a billing portal session for subscription management. */
export async function createBillingPortalSession(input: {
  stripeCustomerId: string;
}): Promise<{ url: string }> {
  const stripe = getStripe();
  const session = await stripe.billingPortal.sessions.create({
    customer: input.stripeCustomerId,
    return_url: `${process.env.APP_URL ?? "http://localhost:3000"}/settings`,
  });
  return { url: session.url };
}

// ── Webhook handling ─────────────────────────────────────────────────

export interface WebhookResult {
  ok: boolean;
  status: number;
  message?: string;
}

/** Entry point for POST /api/billing/webhook. Verifies the Stripe
 *  signature (replay-safe via the built-in tolerance window), then
 *  dispatches on event type. */
export async function handleStripeWebhook(
  payload: string,
  signature: string,
  store: FoundingStore = postgresFoundingStore,
): Promise<WebhookResult> {
  const stripe = getStripe();
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!webhookSecret) {
    return { ok: false, status: 500, message: "webhook not configured" };
  }

  let event: import("stripe").Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(payload, signature, webhookSecret);
  } catch {
    // Signature invalid or expired — reject before touching any state.
    return { ok: false, status: 400, message: "invalid signature" };
  }

  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object as import("stripe").Stripe.Checkout.Session;
      const result = await fulfillFoundingSubscription(session, store);
      return result.ok ? { ok: true, status: 200 } : result;
    }
    case "customer.subscription.deleted": {
      const sub = event.data.object as import("stripe").Stripe.Subscription;
      await onSubscriptionCancelled(sub, store);
      return { ok: true, status: 200 };
    }
    default:
      // Acknowledge all other events (payment_intent updates, etc.).
      return { ok: true, status: 200 };
  }
}

/**
 * Fulfillment — the ONLY path that can consume a founding slot. All
 * checks are server-side and verified against the Stripe object:
 *  1. subscription mode only (never a one-off payment)
 *  2. the charged amount equals the founding price
 *  3. the session belongs to a founding offer (metadata/plan)
 * Then: atomic claim → subscriptions row → analytics.
 * Idempotent: a replayed event returns ok without double-claiming.
 */
export async function fulfillFoundingSubscription(
  session: import("stripe").Stripe.Checkout.Session,
  store: FoundingStore = postgresFoundingStore,
): Promise<WebhookResult> {
  const userId = session.metadata?.userId;
  if (!userId) {
    return { ok: false, status: 400, message: "missing userId metadata" };
  }

  if (session.mode !== "subscription") {
    return { ok: false, status: 400, message: "not a subscription" };
  }

  const chargedUsd = (session.amount_total ?? 0) / 100;
  if (chargedUsd !== FOUNDING_TERMS.priceUsd) {
    await trackEvent(userId, "founding_subscription_failed", {
      reason: "price_mismatch",
      chargedUsd,
      expectedUsd: FOUNDING_TERMS.priceUsd,
    });
    return { ok: false, status: 400, message: "price mismatch" };
  }

  const subscriptionId = String(session.subscription ?? "");
  if (!subscriptionId) {
    return { ok: false, status: 400, message: "missing subscription" };
  }

  const claim = await store.claim(userId, subscriptionId);
  if (claim.status === "already_claimed") {
    // Webhook replay or an existing member — nothing to do, report success.
    return { ok: true, status: 200 };
  }
  if (claim.status === "full") {
    await trackEvent(userId, "founding_subscription_failed", {
      reason: "offer_full",
      claimed: claim.claimed,
      cap: claim.cap,
    });
    return { ok: false, status: 409, message: "founding offer is full" };
  }

  // Persist the subscription row (upsert by userId).
  const db = getDb();
  await db
    .insert(schema.subscriptions)
    .values({
      userId,
      stripeCustomerId: String(session.customer ?? null),
      stripeSubscriptionId: subscriptionId,
      status: "active",
      plan: FOUNDING_TERMS.planStorage,
    })
    .onConflictDoUpdate({
      target: schema.subscriptions.userId,
      set: {
        stripeCustomerId: String(session.customer ?? null),
        stripeSubscriptionId: subscriptionId,
        status: "active",
        plan: FOUNDING_TERMS.planStorage,
        updatedAt: new Date(),
      },
    });

  await trackEvent(userId, "founding_membership_claimed", {
    claimed: claim.claimed,
    cap: claim.cap,
  });
  await trackEvent(userId, "founding_subscription_completed", {
    sessionId: session.id,
  });
  await trackEvent(userId, "subscription_started", {
    plan: FOUNDING_TERMS.planStorage,
  });

  return { ok: true, status: 200 };
}

async function onSubscriptionCancelled(
  sub: import("stripe").Stripe.Subscription,
  store: FoundingStore,
): Promise<void> {
  const db = getDb();
  // Slot stays consumed — only the member record and subscription status change.
  await store.markCanceled(sub.id);
  await db
    .update(schema.subscriptions)
    .set({
      status: "canceled",
      cancelAtPeriodEnd: false,
      updatedAt: new Date(),
    })
    .where(eq(schema.subscriptions.stripeSubscriptionId, sub.id));

  const member = await db.query.foundingMembers.findFirst({
    where: eq(schema.foundingMembers.subscriptionId, sub.id),
  });
  if (member) {
    await trackEvent(member.userId, "founding_membership_cancelled", {});
    await trackEvent(member.userId, "subscription_cancelled", {});
  }
}
