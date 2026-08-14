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
  bucketMonthly,
  collectPlayRevenue,
  collectStripeRevenue,
  fetchAllStripeInvoicePages,
  getFounderStats,
  mapWithConcurrency,
  mergeMonthly,
  monthKey,
  sumByCurrency,
  type StripeInvoicePage,
  type StripeInvoicePageFetcher,
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
      { amountPaid: 200, currency: "usd", created: 1_752_537_600 }, // 2025-07-15
      { amountPaid: 200, currency: "usd", created: 1_752_537_600 },
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
      monthly: [
        { month: "2025-07", amounts: [{ amountMinor: 400, currency: "usd" }] },
      ],
    });
  });

  it("sums real Play revenue from purchase prices", async () => {
    mockSubs = [
      {
        playPurchaseToken: "tok-1",
        playSubscriptionId: "founding_member_monthly",
        playPackageName: "ai.studyflow.studyflow_mobile",
        createdAt: new Date("2025-07-20T10:00:00Z"),
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
      monthly: [
        { month: "2025-07", amounts: [{ amountMinor: 16_500, currency: "inr" }] },
      ],
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
        createdAt: new Date("2025-07-20T10:00:00Z"),
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
    // Unavailable channels contribute no monthly data — never fabricated zeroes.
    expect(stats.revenue.monthly).toEqual([]);
  });

  it("merges provider revenue into a spanning monthly timeline", async () => {
    mockSubs = [
      {
        stripeSubscriptionId: "sub_1",
        stripeCustomerId: "cus_1",
      },
      {
        playPurchaseToken: "tok-1",
        playSubscriptionId: "founding_member_monthly",
        playPackageName: "ai.studyflow.studyflow_mobile",
        createdAt: new Date("2025-08-05T10:00:00Z"),
      },
    ];
    const listPaidInvoices = vi.fn(async () => [
      { amountPaid: 200, currency: "usd", created: 1_752_537_600 }, // 2025-07
      { amountPaid: 200, currency: "usd", created: 1_755_475_200 }, // 2025-08
    ]);
    const fetchPrice = vi.fn(async () => ({
      priceAmountMicros: 165_000_000,
      priceCurrencyCode: "INR",
    }));

    const stats = await getFounderStats({
      store: emptyStore(),
      listStripePaidInvoices: listPaidInvoices,
      fetchPlayPrice: fetchPrice,
    });

    expect(stats.revenue.monthly).toEqual([
      {
        month: "2025-07",
        stripe: [{ amountMinor: 200, currency: "usd" }],
      },
      {
        month: "2025-08",
        stripe: [{ amountMinor: 200, currency: "usd" }],
        play: [{ amountMinor: 16_500, currency: "inr" }],
      },
    ]);
  });

  it("has an empty monthly timeline when there are no purchases", async () => {
    const stats = await getFounderStats({ store: emptyStore() });
    expect(stats.revenue.monthly).toEqual([]);
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
      monthly: [],
    });
  });

  it("play: no play purchases → real zero, available", async () => {
    const revenue = await collectPlayRevenue(
      [
        {
          playPurchaseToken: null,
          playPackageName: null,
          playSubscriptionId: null,
        },
      ],
      vi.fn(),
    );
    expect(revenue).toEqual({
      amounts: [{ amountMinor: 0, currency: "inr" }],
      available: true,
      counts: 0,
      monthly: [],
    });
  });
});

describe("stripe pagination", () => {
  it("walks every page, chaining starting_after, until has_more is false", async () => {
    const pages: StripeInvoicePage[] = [
      {
        data: [
          { id: "in_0", amount_paid: 200, currency: "usd", created: 1_752_537_600 },
          { id: "in_1", amount_paid: 300, currency: "usd", created: 1_752_537_600 },
        ],
        has_more: true,
      },
      {
        data: [{ id: "in_2", amount_paid: 400, currency: "usd", created: 1_755_475_200 }],
        has_more: false,
      },
    ];
    const requests: (string | undefined)[] = [];
    const fetcher: StripeInvoicePageFetcher = async ({ starting_after }) => {
      requests.push(starting_after);
      if (starting_after === undefined) return pages[0];
      // Cursor is the last invoice id of the previous page → next page.
      return pages[1];
    };

    const out = await fetchAllStripeInvoicePages(fetcher);

    expect(out).toEqual([
      { amountPaid: 200, currency: "usd", created: 1_752_537_600 },
      { amountPaid: 300, currency: "usd", created: 1_752_537_600 },
      { amountPaid: 400, currency: "usd", created: 1_755_475_200 },
    ]);
    expect(requests).toEqual([undefined, "in_1"]);
  });

  it("stops instead of spinning when has_more stays true on an empty page", async () => {
    const requests: string[] = [];
    const fetcher: StripeInvoicePageFetcher = async ({ starting_after }) => {
      requests.push(starting_after ?? "(none)");
      return { data: [], has_more: true }; // pathological API state
    };

    const out = await fetchAllStripeInvoicePages(fetcher);

    expect(out).toEqual([]);
    expect(requests.length).toBe(1); // no infinite loop
  });

  it("maps a single page when there is only one", async () => {
    const out = await fetchAllStripeInvoicePages(async () => ({
      data: [{ id: "in_0", amount_paid: 100, currency: "eur" }],
      has_more: false,
    }));
    expect(out).toEqual([{ amountPaid: 100, currency: "eur", created: 0 }]);
  });
});

describe("mapWithConcurrency", () => {
  it("caps concurrent work at the limit and preserves input order", async () => {
    let inFlight = 0;
    let maxInFlight = 0;
    const work = async (x: number) => {
      inFlight++;
      maxInFlight = Math.max(maxInFlight, inFlight);
      await new Promise((r) => setTimeout(r, 5));
      inFlight--;
      return x * 2;
    };

    const out = await mapWithConcurrency([1, 2, 3, 4, 5, 6, 7, 8], 3, work);

    expect(out).toEqual([2, 4, 6, 8, 10, 12, 14, 16]);
    expect(maxInFlight).toBeLessThanOrEqual(3);
  });
});

describe("monthly bucketing", () => {
  it("monthKey maps timestamps to UTC YYYY-MM", () => {
    expect(monthKey(new Date("2025-07-15T23:59:00Z"))).toBe("2025-07");
    expect(monthKey("2025-08-01T00:00:00Z")).toBe("2025-08");
    expect(monthKey(1_752_537_600)).toBe("2025-07");
  });

  it("bucketMonthly groups by month and currency, oldest first", () => {
    const out = bucketMonthly([
      { amountMinor: 100, currency: "usd", at: "2025-08-05T00:00:00Z" },
      { amountMinor: 50, currency: "usd", at: "2025-07-01T00:00:00Z" },
      { amountMinor: 30, currency: "usd", at: "2025-08-20T00:00:00Z" },
      { amountMinor: 99, currency: "inr", at: "2025-08-20T00:00:00Z" },
    ]);
    expect(out).toEqual([
      {
        month: "2025-07",
        amounts: [{ amountMinor: 50, currency: "usd" }],
      },
      {
        month: "2025-08",
        amounts: [
          { amountMinor: 130, currency: "usd" },
          { amountMinor: 99, currency: "inr" },
        ],
      },
    ]);
  });

  it("mergeMonthly spans the timeline, omitting empty provider months", () => {
    const merged = mergeMonthly(
      [{ month: "2025-07", amounts: [{ amountMinor: 100, currency: "usd" }] }],
      [
        {
          month: "2025-08",
          amounts: [{ amountMinor: 16_500, currency: "inr" }],
        },
      ],
    );
    expect(merged).toEqual([
      {
        month: "2025-07",
        stripe: [{ amountMinor: 100, currency: "usd" }],
      },
      {
        month: "2025-08",
        play: [{ amountMinor: 16_500, currency: "inr" }],
      },
    ]);
  });
});
