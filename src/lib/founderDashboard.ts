// ─────────────────────────────────────────────────────────────────────
// Founder dashboard — REAL numbers only. Nothing here is fabricated:
//  - users / subscriptions / founding counts come from the database.
//  - revenue comes from the payment providers (Stripe invoices, Google
//    Play purchase prices). When a provider cannot be reached, that
//    channel reports `available: false` instead of inventing an amount.
//  - When there are no purchases at all, revenue is ₹0 — the UI shows
//    "₹0" rather than estimates.
//
// All provider + clock access is injectable so the unit tests exercise
// the exact same code paths the page uses.
// ─────────────────────────────────────────────────────────────────────
import { eq, gte, sql } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { getStripe } from "@/lib/billing";
import {
  FOUNDING_TERMS,
  postgresFoundingStore,
  type FoundingStatus,
  type FoundingStore,
} from "@/lib/founding";
import {
  GooglePlayVerifier,
  type PlayVerifyInput,
} from "@/lib/playBilling";

/** An amount in minor units of its currency (cents for USD, paise for INR). */
export interface RevenueAmount {
  amountMinor: number;
  currency: string;
}

export interface ChannelRevenue {
  /** Real provider amounts — one entry per currency (usually one). */
  amounts: RevenueAmount[];
  /** False when the provider could not be queried (no key / API error),
   *  and the dashboard must not invent a number. */
  available: boolean;
  /** How many real purchases contributed (paid invoices / fetched tokens). */
  counts: number;
}

export interface RevenueReport {
  /** Any subscription or founding claim exists → revenue is real, not zero-by-default. */
  hasPurchases: boolean;
  stripe: ChannelRevenue;
  play: ChannelRevenue;
}

export interface FounderStats {
  users: { total: number; onboarded: number; active30d: number };
  subscriptions: {
    active: number;
    activeFounding: number;
    activeRegular: number;
    canceled: number;
  };
  founding: FoundingStatus;
  revenue: RevenueReport;
}

export interface FounderDashboardDeps {
  store?: FoundingStore;
  /** Override "now" for the 30-day active window (tests). */
  now?: () => Date;
  /** Real paid-invoice amounts (minor units). Default: Stripe API. */
  listStripePaidInvoices?: () => Promise<
    { amountPaid: number; currency: string }[]
  >;
  /** Real price for one Play purchase. Default: Play Developer API. */
  fetchPlayPrice?: (
    input: PlayVerifyInput,
  ) => Promise<{ priceAmountMicros: number; priceCurrencyCode: string }>;
}

async function defaultListStripePaidInvoices(): Promise<
  { amountPaid: number; currency: string }[]
> {
  const stripe = getStripe(); // throws BillingNotConfigured when unset
  const invoices = await stripe.invoices.list({ status: "paid", limit: 100 });
  return invoices.data.map((i) => ({
    amountPaid: i.amount_paid ?? 0,
    currency: i.currency ?? "usd",
  }));
}

const _playVerifier = new GooglePlayVerifier();

async function defaultFetchPlayPrice(
  input: PlayVerifyInput,
): Promise<{ priceAmountMicros: number; priceCurrencyCode: string }> {
  const getter = _playVerifier.getSubscriptionPrice;
  if (!getter) throw new Error("Play price lookup unavailable");
  return getter.call(_playVerifier, input);
}

/** Sum amounts into one entry per currency (minor units preserved). */
export function sumByCurrency(
  amounts: { amountMinor: number; currency: string }[],
): RevenueAmount[] {
  const totals = new Map<string, number>();
  for (const a of amounts) {
    const key = a.currency.toLowerCase();
    totals.set(key, (totals.get(key) ?? 0) + a.amountMinor);
  }
  return [...totals.entries()].map(([currency, amountMinor]) => ({
    amountMinor,
    currency,
  }));
}

/** Real Stripe revenue. Zero channel purchases → real ₹0/USD 0 (available).
 *  Purchases exist but the provider is unreachable → unavailable, no number. */
export async function collectStripeRevenue(
  subscriptions: {
    stripeSubscriptionId: string | null;
    stripeCustomerId: string | null;
  }[],
  listPaidInvoices: () => Promise<
    { amountPaid: number; currency: string }[]
  >,
): Promise<ChannelRevenue> {
  const hasStripe = subscriptions.some(
    (s) => s.stripeSubscriptionId || s.stripeCustomerId,
  );
  if (!hasStripe) {
    // No Stripe purchases — revenue from Stripe is genuinely zero.
    return { amounts: [{ amountMinor: 0, currency: "usd" }], available: true, counts: 0 };
  }
  try {
    const invoices = await listPaidInvoices();
    return {
      amounts: sumByCurrency(
        invoices.map((i) => ({ amountMinor: i.amountPaid, currency: i.currency })),
      ),
      available: true,
      counts: invoices.length,
    };
  } catch (err) {
    console.error("[founder] Stripe revenue unavailable:", err);
    return { amounts: [], available: false, counts: 0 };
  }
}

/** Real Google Play revenue. Sums each attributed purchase's real price
 *  (Play reports micro-units; we convert to minor units of currency).
 *  Zero Play purchases → real ₹0. Provider unreachable → unavailable. */
export async function collectPlayRevenue(
  subscriptions: {
    playPurchaseToken: string | null;
    playPackageName: string | null;
    playSubscriptionId: string | null;
  }[],
  fetchPrice: (
    input: PlayVerifyInput,
  ) => Promise<{ priceAmountMicros: number; priceCurrencyCode: string }>,
): Promise<ChannelRevenue> {
  const tokens = subscriptions.filter((s) => s.playPurchaseToken);
  if (tokens.length === 0) {
    return { amounts: [{ amountMinor: 0, currency: "inr" }], available: true, counts: 0 };
  }
  try {
    const results = await Promise.all(
      tokens.map(async (s) => {
        try {
          const p = await fetchPrice({
            packageName: s.playPackageName ?? FOUNDING_TERMS.playPackageName,
            subscriptionId:
              s.playSubscriptionId ?? FOUNDING_TERMS.playProductId,
            purchaseToken: s.playPurchaseToken!,
          });
          // Micro-units → minor units: 1 unit = 1e6 micro; 1 minor = 1e-2 unit.
          return {
            amountMinor: Math.round(p.priceAmountMicros / 10_000),
            currency: p.priceCurrencyCode,
          };
        } catch {
          return null;
        }
      }),
    );
    const ok = results.filter(
      (r): r is { amountMinor: number; currency: string } => r !== null,
    );
    if (ok.length === 0) {
      return { amounts: [], available: false, counts: 0 };
    }
    return { amounts: sumByCurrency(ok), available: true, counts: ok.length };
  } catch (err) {
    console.error("[founder] Play revenue unavailable:", err);
    return { amounts: [], available: false, counts: 0 };
  }
}

/** Assemble the full founder dashboard. Never throws on provider errors —
 *  each revenue channel degrades to "unavailable" independently. */
export async function getFounderStats(
  deps: FounderDashboardDeps = {},
): Promise<FounderStats> {
  const db = getDb();
  const store = deps.store ?? postgresFoundingStore;
  const nowFn = deps.now ?? (() => new Date());
  const since = new Date(nowFn().getTime() - 30 * 86_400_000);

  const [totalUsers, onboardedUsers, activeUsers, activeRows, canceledRows, allSubs] =
    await Promise.all([
      db.select({ count: sql<number>`count(*)::int` }).from(schema.user),
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(schema.profiles)
        .where(eq(schema.profiles.onboardingCompleted, true)),
      db
        .select({ count: sql<number>`count(distinct ${schema.analyticsEvents.userId})::int` })
        .from(schema.analyticsEvents)
        .where(gte(schema.analyticsEvents.createdAt, since)),
      db
        .select({ plan: schema.subscriptions.plan })
        .from(schema.subscriptions)
        .where(eq(schema.subscriptions.status, "active")),
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(schema.subscriptions)
        .where(eq(schema.subscriptions.status, "canceled")),
      db.select().from(schema.subscriptions),
    ]);

  const active = activeRows.length;
  const activeFounding = activeRows.filter(
    (r) => r.plan === FOUNDING_TERMS.planStorage,
  ).length;

  const [founding, stripe, play] = await Promise.all([
    store.getStatus(),
    collectStripeRevenue(
      allSubs,
      deps.listStripePaidInvoices ?? defaultListStripePaidInvoices,
    ),
    collectPlayRevenue(allSubs, deps.fetchPlayPrice ?? defaultFetchPlayPrice),
  ]);

  return {
    users: {
      total: totalUsers[0]?.count ?? 0,
      onboarded: onboardedUsers[0]?.count ?? 0,
      active30d: activeUsers[0]?.count ?? 0,
    },
    subscriptions: {
      active,
      activeFounding,
      activeRegular: active - activeFounding,
      canceled: canceledRows[0]?.count ?? 0,
    },
    founding,
    revenue: {
      hasPurchases: allSubs.length > 0 || founding.claimed > 0,
      stripe,
      play,
    },
  };
}
