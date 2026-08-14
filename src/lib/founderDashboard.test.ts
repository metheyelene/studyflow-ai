import { beforeEach, describe, expect, it, vi } from "vitest";

// DB is not exercised as SQL — the mock below returns positional results
// that mirror the ORDER of the queries inside getFounderStats():
//   1. users count            2. onboarded count
//   3. active-30d count       4. active subscription plans
//   5. canceled count         6. full subscription rows (for revenue)
let mockUsers = 0;
let mockOnboarded = 0;
let mockActive30d = 0;
let mockActivePlans: string[] = [];
let mockCanceled = 0;
let mockSubs: Array<Record<string, unknown>> = [];
let queryCall = 0;

const dbMock = {
  select: vi.fn(() => ({
    from: vi.fn(() => {
      queryCall += 1;
      switch (queryCall) {
        // 1: total users (no where) — 6: full subscription rows (no where)
        case 1:
          return Promise.resolve([{ count: mockUsers }]);
        case 6:
          return Promise.resolve(mockSubs.map((s) => ({ ...s })));
        // 2-5: count / plan queries all chain .where()
        case 2:
          return { where: vi.fn(async () => [{ count: mockOnboarded }]) };
        case 3:
          return { where: vi.fn(async () => [{ count: mockActive30d }]) };
        case 4:
          return {
            where: vi.fn(async () =>
              mockActivePlans.map((plan) => ({ plan })),
            ),
          };
        default:
          return { where: vi.fn(async () => [{ count: mockCanceled }]) };
      }
    }),
  })),
};

vi.mock("@/db", () => ({
  getDb: () => dbMock,
  schema: {
    user: { id: "id", createdAt: "created_at" },
    profiles: {
      userId: "user_id",
      onboardingCompleted: "onboarding_completed",
    },
    analyticsEvents: { userId: "user_id", createdAt: "created_at" },
    subscriptions: {
      id: "id",
      userId: "user_id",
      stripeCustomerId: "stripe_customer_id",
      stripeSubscriptionId: "stripe_subscription_id",
      playPackageName: "play_package_name",
      playSubscriptionId: "play_subscription_id",
      playPurchaseToken: "play_purchase_token",
      status: "status",
      plan: "plan",
    },
  },
}));

import {
  collectPlayRevenue,
  collectStripeRevenue,
  getFounderStats,
  sumByCurrency,
} from "@/lib/founderDashboard";
import { inMemoryFoundingStore } from "@/lib/founding";

const emptyStore = () => inMemoryFoundingStore(35);

beforeEach(() => {
  mockUsers = 0;
  mockOnboarded = 0;
  mockActive30d = 0;
  mockActivePlans = [];
  mockCanceled = 0;
  mockSubs = [];
  queryCall = 0;
  vi.clearAllMocks();
});

describe("getFounderStats", () => {
  it("reports ₹0 revenue and honest zero counts when there are no purchases", async () => {
    const stats = await getFounderStats({ store: emptyStore() });

    expect(stats.users).toEqual({ total: 0, onboarded: 0, active30d: 0 });
    expect(stats.subscriptions).toEqual({
      active: 0,
      activeFounding: 0,
      activeRegular: 0,
      canceled: 0,
    });
    expect(stats.founding).toMatchObject({
      claimed: 0,
      cap: 35,
      remaining: 35,
      full: false,
    });
    // No purchases → zero revenue, not estimates.
    expect(stats.revenue.hasPurchases).toBe(false);
    expect(stats.revenue.stripe.amounts).toEqual([
      { amountMinor: 0, currency: "usd" },
    ]);
    expect(stats.revenue.play.amounts).toEqual([
      { amountMinor: 0, currency: "inr" },
    ]);
    expect(stats.revenue.stripe.available).toBe(true);
    expect(stats.revenue.play.available).toBe(true);
  });

  it("counts users, onboarded profiles, and 30-day active users", async () => {
    mockUsers = 5;
    mockOnboarded = 4;
    mockActive30d = 2;

    const stats = await getFounderStats({ store: emptyStore() });

    expect(stats.users).toEqual({ total: 5, onboarded: 4, active30d: 2 });
  });

  it("splits active subscriptions into founding vs regular premium", async () => {
    mockActivePlans = ["founding_member", "premium", "premium"];
    mockCanceled = 2;

    const stats = await getFounderStats({ store: emptyStore() });

    expect(stats.subscriptions).toEqual({
      active: 3,
      activeFounding: 1,
      activeRegular: 2,
      canceled: 2,
    });
  });

  it("reports remaining founding slots from the atomic counter", async () => {
    const store = inMemoryFoundingStore(35);
    await store.claim("u1", "sub-1");
    await store.claim("u2", "sub-2");

    const stats = await getFounderStats({ store });

    expect(stats.founding).toMatchObject({
      claimed: 2,
      cap: 35,
      remaining: 33,
      activeCount: 2,
    });
  });

  it("treats a founding claim alone as a purchase (hasPurchases)", async () => {
    const store = inMemoryFoundingStore(35);
    await store.claim("u1", "sub-1");

    const stats = await getFounderStats({ store });

    expect(stats.revenue.hasPurchases).toBe(true);
  });

  it("sums real Stripe revenue from paid invoices", async () => {
    mockSubs = [
      { stripeSubscriptionId: "sub_1", stripeCustomerId: "cus_1" },
    ];
    const listPaidInvoices = vi.fn(async () => [
      { amountPaid: 200, currency: "usd" },
      { amountPaid: 200, currency: "usd" },
    ]);

    const stats = await getFounderStats({
      store: emptyStore(),
      listStripePaidInvoices: listPaidInvoices,
    });

    expect(stats.revenue.hasPurchases).toBe(true);
    expect(stats.revenue.stripe).toEqual({
      amounts: [{ amountMinor: 400, currency: "usd" }],
      available: true,
      counts: 2,
    });
  });

  it("sums real Play revenue from purchase prices", async () => {
    mockSubs = [
      {
        playPurchaseToken: "tok-1",
        playSubscriptionId: "founding_member_monthly",
        playPackageName: "ai.studyflow.studyflow_mobile",
      },
    ];
    const fetchPrice = vi.fn(async () => ({
      priceAmountMicros: 165_000_000, // ₹165.00
      priceCurrencyCode: "INR",
    }));

    const stats = await getFounderStats({
      store: emptyStore(),
      fetchPlayPrice: fetchPrice,
    });

    expect(stats.revenue.play).toEqual({
      amounts: [{ amountMinor: 16_500, currency: "inr" }], // paise
      available: true,
      counts: 1,
    });
  });

  it("marks a channel unavailable instead of fabricating when the provider fails", async () => {
    mockSubs = [
      {
        stripeSubscriptionId: "sub_1",
        stripeCustomerId: "cus_1",
        playPurchaseToken: "tok-1",
        playSubscriptionId: "founding_member_monthly",
        playPackageName: "ai.studyflow.studyflow_mobile",
      },
    ];
    const listPaidInvoices = vi.fn(async () => {
      throw new Error("Stripe API down");
    });
    const fetchPrice = vi.fn(async () => {
      throw new Error("Play API down");
    });

    const stats = await getFounderStats({
      store: emptyStore(),
      listStripePaidInvoices: listPaidInvoices,
      fetchPlayPrice: fetchPrice,
    });

    expect(stats.revenue.hasPurchases).toBe(true);
    expect(stats.revenue.stripe.available).toBe(false);
    expect(stats.revenue.stripe.amounts).toEqual([]);
    expect(stats.revenue.play.available).toBe(false);
    expect(stats.revenue.play.amounts).toEqual([]);
  });
});

describe("sumByCurrency", () => {
  it("groups amounts by currency", () => {
    expect(
      sumByCurrency([
        { amountMinor: 100, currency: "usd" },
        { amountMinor: 50, currency: "usd" },
        { amountMinor: 99, currency: "inr" },
      ]),
    ).toEqual([
      { amountMinor: 150, currency: "usd" },
      { amountMinor: 99, currency: "inr" },
    ]);
  });
});

describe("collectors", () => {
  it("stripe: no stripe purchases → real zero, available", async () => {
    const revenue = await collectStripeRevenue(
      [{ stripeSubscriptionId: null, stripeCustomerId: null }],
      vi.fn(),
    );
    expect(revenue).toEqual({
      amounts: [{ amountMinor: 0, currency: "usd" }],
      available: true,
      counts: 0,
    });
  });

  it("play: no play purchases → real zero, available", async () => {
    const revenue = await collectPlayRevenue(
      [{ playPurchaseToken: null, playPackageName: null, playSubscriptionId: null }],
      vi.fn(),
    );
    expect(revenue).toEqual({
      amounts: [{ amountMinor: 0, currency: "inr" }],
      available: true,
      counts: 0,
    });
  });
});
