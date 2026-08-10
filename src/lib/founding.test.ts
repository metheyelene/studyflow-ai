import { beforeEach, describe, expect, it, vi } from "vitest";

// DB + analytics are not needed by the fulfillment logic under test —
// the founding store is injected, and analytics is best-effort.
vi.mock("@/db", () => ({
  getDb: () => ({
    insert: () => ({
      values: () => ({ onConflictDoUpdate: () => Promise.resolve({}) }),
    }),
    update: () => ({ set: () => ({ where: () => Promise.resolve({}) }) }),
    query: {
      foundingMembers: {
        findFirst: () => Promise.resolve(undefined),
        findMany: () => Promise.resolve([]),
      },
      foundingMemberCounter: {
        findFirst: () => Promise.resolve({ claimed: 0, cap: 35 }),
      },
    },
  }),
  schema: {
    // Only the field references used by billing.ts — never executed as SQL.
    subscriptions: { userId: "user_id", stripeSubscriptionId: "stripe_subscription_id" },
    foundingMembers: { subscriptionId: "subscription_id" },
  },
}));

vi.mock("@/lib/analytics", () => ({
  trackEvent: () => Promise.resolve(),
}));

import {
  fulfillFoundingSubscription,
  createFoundingCheckoutSession,
  BillingNotConfigured,
} from "@/lib/billing";
import {
  FOUNDING_TERMS,
  foundingOfferOpenFor,
  getFoundingStatus,
  inMemoryFoundingStore,
  type FoundingStore,
} from "@/lib/founding";
import { planFromSubscription } from "@/lib/premium";
import type Stripe from "stripe";

function fakeSession(overrides: Partial<Stripe.Checkout.Session> = {}): Stripe.Checkout.Session {
  return {
    id: "cs_test_1",
    object: "checkout.session",
    mode: "subscription",
    amount_total: 200,
    customer: "cus_1",
    subscription: "sub_1",
    metadata: { userId: "user_a", plan: FOUNDING_TERMS.planStorage },
    ...overrides,
  } as unknown as Stripe.Checkout.Session;
}

describe("founding-member allocation", () => {
  let store: FoundingStore;

  beforeEach(() => {
    store = inMemoryFoundingStore(35);
  });

  it("1. first customer successfully claims founding membership", async () => {
    const res = await fulfillFoundingSubscription(fakeSession(), store);
    expect(res.ok).toBe(true);
    const status = await store.getStatus();
    expect(status.claimed).toBe(1);
    expect(status.remaining).toBe(34);
  });

  it("2 + 3. the 34th and 35th customers claim successfully", async () => {
    for (let i = 0; i < 34; i++) {
      const res = await fulfillFoundingSubscription(
        fakeSession({ id: `cs_${i}`, metadata: { userId: `user_${i}` } }),
        store,
      );
      expect(res.ok).toBe(true);
    }
    const status = await store.getStatus();
    expect(status.claimed).toBe(34);
    expect(status.full).toBe(false);

    const last = await fulfillFoundingSubscription(
      fakeSession({ id: "cs_last", metadata: { userId: "user_34" } }),
      store,
    );
    expect(last.ok).toBe(true);
    expect((await store.getStatus()).claimed).toBe(35);
    expect((await store.getStatus()).full).toBe(true);
  });

  it("4. the 36th customer cannot receive the founding plan", async () => {
    for (let i = 0; i < 35; i++) {
      await fulfillFoundingSubscription(
        fakeSession({ id: `cs_${i}`, metadata: { userId: `user_${i}` } }),
        store,
      );
    }
    const res = await fulfillFoundingSubscription(
      fakeSession({ id: "cs_36", metadata: { userId: "user_36" } }),
      store,
    );
    expect(res.ok).toBe(false);
    expect(res.status).toBe(409);
    expect((await store.getStatus()).claimed).toBe(35);
  });

  it("5. two simultaneous attempts cannot exceed the cap", async () => {
    const cap = 5;
    const smallStore = inMemoryFoundingStore(cap);
    const attempts = Array.from({ length: 20 }, (_, i) =>
      fulfillFoundingSubscription(
        fakeSession({ id: `cs_${i}`, metadata: { userId: `user_${i}` } }),
        smallStore,
      ),
    );
    const results = await Promise.all(attempts);
    const succeeded = results.filter((r) => r.ok).length;
    const status = await smallStore.getStatus();
    expect(succeeded).toBe(cap);
    expect(status.claimed).toBe(cap);
    expect(status.full).toBe(true);
  });

  it("6. failed payments do not consume a slot", async () => {
    // A failed subscription: session completes with $0 (never charged).
    const res = await fulfillFoundingSubscription(
      fakeSession({ amount_total: 0 }),
      store,
    );
    expect(res.ok).toBe(false);
    expect((await store.getStatus()).claimed).toBe(0);

    // A non-subscription (one-off) payment is rejected too.
    const res2 = await fulfillFoundingSubscription(
      fakeSession({ mode: "payment" }),
      store,
    );
    expect(res2.ok).toBe(false);
    expect((await store.getStatus()).claimed).toBe(0);
  });

  it("7. abandoned checkouts do not consume a slot", async () => {
    // Abandoned = a session was created but no completion event arrived.
    // Nothing to fulfill; the counter must remain untouched.
    expect((await store.getStatus()).claimed).toBe(0);
    expect((await store.getStatus()).remaining).toBe(35);
  });

  it("8. existing founding members retain the premium plan", () => {
    expect(planFromSubscription("founding_member")).toBe("premium");
    expect(planFromSubscription("premium")).toBe("premium");
    expect(planFromSubscription(null)).toBe("free");
  });

  it("9. cancelled founding members do not reopen the slot", async () => {
    const cap1 = inMemoryFoundingStore(1);
    await fulfillFoundingSubscription(fakeSession(), cap1);
    await cap1.markCanceled("sub_1");
    const status = await cap1.getStatus();
    expect(status.claimed).toBe(1);
    expect(status.activeCount).toBe(0);
    expect(status.canceledCount).toBe(1);
    // The slot is gone even for a different user.
    const res = await fulfillFoundingSubscription(
      fakeSession({ id: "cs_2", metadata: { userId: "user_b" } }),
      cap1,
    );
    expect(res.ok).toBe(false);
    expect(res.status).toBe(409);
  });

  it("10. frontend cannot manipulate the price", async () => {
    // A session charged below/above the founding price is rejected.
    const cheap = await fulfillFoundingSubscription(
      fakeSession({ amount_total: 100 }),
      store,
    );
    expect(cheap.ok).toBe(false);
    expect((await store.getStatus()).claimed).toBe(0);

    // Checkout creation is server-side only and requires a key — the
    // amount is never accepted from the client.
    delete process.env.STRIPE_SECRET_KEY;
    await expect(
      createFoundingCheckoutSession({ userId: "u", email: "e@x.com" }),
    ).rejects.toBeInstanceOf(BillingNotConfigured);
  });

  it("11. frontend cannot manipulate the remaining-member count", async () => {
    // The count is read only from the store; offer-open checks respect it.
    expect(await getFoundingStatus(store)).toMatchObject({
      claimed: 0,
      cap: 35,
      remaining: 35,
      full: false,
    });
    expect(await foundingOfferOpenFor("user_a", store)).toBe(true);

    for (let i = 0; i < 35; i++) {
      await fulfillFoundingSubscription(
        fakeSession({ id: `cs_${i}`, metadata: { userId: `user_${i}` } }),
        store,
      );
    }
    expect(await foundingOfferOpenFor("user_new", store)).toBe(false);
  });

  it("12. webhook verification rejects invalid signatures", async () => {
    process.env.STRIPE_SECRET_KEY = "sk_test_dummy";
    process.env.STRIPE_WEBHOOK_SECRET = "whsec_dummy";
    const { handleStripeWebhook } = await import("@/lib/billing");
    const res = await handleStripeWebhook(
      JSON.stringify({ type: "checkout.session.completed" }),
      "bad_signature",
      store,
    );
    expect(res.ok).toBe(false);
    expect(res.status).toBe(400);
    expect((await store.getStatus()).claimed).toBe(0);
  });

  it("webhook replay is idempotent — one slot per user", async () => {
    const session = fakeSession();
    const first = await fulfillFoundingSubscription(session, store);
    const replay = await fulfillFoundingSubscription(session, store);
    expect(first.ok).toBe(true);
    expect(replay.ok).toBe(true); // acknowledged, not an error
    expect((await store.getStatus()).claimed).toBe(1);
  });

  it("slot is permanently consumed even after cancellation (permanence rule)", async () => {
    const cap1 = inMemoryFoundingStore(1);
    await fulfillFoundingSubscription(fakeSession(), cap1);
    await cap1.markCanceled("sub_1");
    // The same user cannot re-claim (already_claimed wins over full).
    const again = await cap1.claim("user_a", "sub_2");
    expect(again.status).toBe("already_claimed");
    expect((await cap1.getStatus()).claimed).toBe(1);
  });
});
