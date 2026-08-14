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

/** One calendar month's real revenue for a single provider, summed by
 *  currency. A provider invoices in one native currency, so in practice
 *  this is one amount — the array keeps the model honest for edge cases. */
export interface MonthlyChannelPoint {
  /** UTC calendar month, "YYYY-MM". */
  month: string;
  amounts: RevenueAmount[];
}

export type MonthlyChannel = MonthlyChannelPoint[];

/** A single month across providers, for the timeline chart. A provider key
 *  is absent when that provider had no revenue that month (available
 *  channels only — an unavailable channel contributes nothing at all). */
export interface MonthlyRevenuePoint {
  month: string;
  stripe?: RevenueAmount[];
  play?: RevenueAmount[];
}

export interface RevenueReport {
  /** Any subscription or founding claim exists → revenue is real, not zero-by-default. */
  hasPurchases: boolean;
  stripe: ChannelRevenue;
  play: ChannelRevenue;
  /** Monthly by provider, oldest month first, spanning every month from
   *  the first to the last real purchase. Real amounts, native currencies,
   *  never converted. Empty when there are no purchases. */
  monthly: MonthlyRevenuePoint[];
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
  now?: () => Date;/** Real paid-invoice amounts (minor units) + created (unix seconds).
 *  Default: Stripe API, paginated to completion. */
  listStripePaidInvoices?: () => Promise<
    { amountPaid: number; currency: string; created: number }[]
  >;
  /** Real price for one Play purchase. Default: Play Developer API. */
  fetchPlayPrice?: (
    input: PlayVerifyInput,
  ) => Promise<{ priceAmountMicros: number; priceCurrencyCode: string }>;
}

/** One page of paid invoices, as the Stripe client returns it. The page
 *  fetcher is injectable so the pagination loop is unit-tested without a
 *  real Stripe key. */
export interface StripeInvoicePage {
  data: {
    id: string;
    amount_paid?: number | null;
    currency?: string | null;
    created?: number | null;
  }[];
  has_more: boolean;
}

export type StripeInvoicePageFetcher = (params: {
  starting_after?: string;
}) => Promise<StripeInvoicePage>;

/** Walk every page of paid invoices (Stripe cursor pagination) and flatten
 *  them. Real amounts only; `created` (unix seconds) feeds the monthly
 *  revenue timeline. Guards against an infinite loop: if the API reports
 *  `has_more` but returns an empty page, stop rather than spin. */
export async function fetchAllStripeInvoicePages(
  fetchPage: StripeInvoicePageFetcher,
): Promise<{ amountPaid: number; currency: string; created: number }[]> {
  const out: { amountPaid: number; currency: string; created: number }[] = [];
  let startingAfter: string | undefined;
  for (;;) {
    const page = await fetchPage({ starting_after: startingAfter });
    for (const i of page.data) {
      out.push({
        amountPaid: i.amount_paid ?? 0,
        currency: i.currency ?? "usd",
        created: i.created ?? 0,
      });
    }
    if (!page.has_more || page.data.length === 0) break;
    startingAfter = page.data[page.data.length - 1].id;
  }
  return out;
}

async function defaultListStripePaidInvoices(): Promise<
  { amountPaid: number; currency: string; created: number }[]
> {
  const stripe = getStripe(); // throws BillingNotConfigured when unset
  return fetchAllStripeInvoicePages(({ starting_after }) =>
    stripe.invoices.list({
      status: "paid",
      limit: 100,
      ...(starting_after ? { starting_after } : {}),
    }),
  );
}

/** Run [fn] over [items] with at most [limit] concurrent in-flight calls.
 *  Order of results matches input order. Used to bound Google Play price
 *  lookups so a large subscriber base can't trip the API quota with an
 *  unbounded Promise.all. */
export async function mapWithConcurrency<T, R>(
  items: readonly T[],
  limit: number,
  fn: (item: T) => Promise<R>,
): Promise<R[]> {
  const results = new Array<R>(items.length);
  let next = 0;
  async function worker() {
    for (;;) {
      const i = next++;
      if (i >= items.length) return;
      results[i] = await fn(items[i]);
    }
  }
  const workers = Array.from(
    { length: Math.min(limit, items.length) },
    () => worker(),
  );
  await Promise.all(workers);
  return results;
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

/** UTC calendar month key ("YYYY-MM") for a timestamp. All bucketing is UTC
 *  so months never shift with the viewer's timezone. */
export function monthKey(ts: number | string | Date): string {
  const d = typeof ts === "number" ? new Date(ts * 1000) : new Date(ts);
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}

/** Group amount records into months, oldest month first, summing by
 *  currency within each month. */
export function bucketMonthly(
  entries: { amountMinor: number; currency: string; at: number | string | Date }[],
): MonthlyChannel {
  const byMonth = new Map<string, Map<string, number>>();
  for (const e of entries) {
    const m = monthKey(e.at);
    const cur = e.currency.toLowerCase();
    const totals = byMonth.get(m) ?? new Map<string, number>();
    totals.set(cur, (totals.get(cur) ?? 0) + e.amountMinor);
    byMonth.set(m, totals);
  }
  return [...byMonth.entries()]
    .sort((a, b) => (a[0] < b[0] ? -1 : 1))
    .map(([month, totals]) => ({
      month,
      amounts: [...totals.entries()].map(([currency, amountMinor]) => ({
        amountMinor,
        currency,
      })),
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
    { amountPaid: number; currency: string; created: number }[]
  >,
): Promise<ChannelRevenue & { monthly: MonthlyChannel }> {
  const hasStripe = subscriptions.some(
    (s) => s.stripeSubscriptionId || s.stripeCustomerId,
  );
  if (!hasStripe) {
    // No Stripe purchases — revenue from Stripe is genuinely zero.
    return {
      amounts: [{ amountMinor: 0, currency: "usd" }],
      available: true,
      counts: 0,
      monthly: [],
    };
  }
  try {
    const invoices = await listPaidInvoices();
    return {
      amounts: sumByCurrency(
        invoices.map((i) => ({ amountMinor: i.amountPaid, currency: i.currency })),
      ),
      available: true,
      counts: invoices.length,
      monthly: bucketMonthly(
        invoices.map((i) => ({
          amountMinor: i.amountPaid,
          currency: i.currency,
          at: i.created,
        })),
      ),
    };
  } catch (err) {
    console.error("[founder] Stripe revenue unavailable:", err);
    return { amounts: [], available: false, counts: 0, monthly: [] };
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
    createdAt?: number | string | Date | null;
  }[],
  fetchPrice: (
    input: PlayVerifyInput,
  ) => Promise<{ priceAmountMicros: number; priceCurrencyCode: string }>,
): Promise<ChannelRevenue & { monthly: MonthlyChannel }> {
  const tokens = subscriptions.filter((s) => s.playPurchaseToken);
  if (tokens.length === 0) {
    return {
      amounts: [{ amountMinor: 0, currency: "inr" }],
      available: true,
      counts: 0,
      monthly: [],
    };
  }
  try {
    // Bounded concurrency: Play price lookups are one API call per token,
    // and an unbounded Promise.all would risk quota/rate-limit failures
    // as the subscriber base grows.
    const results = await mapWithConcurrency(tokens, 5, async (s) => {
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
          at: s.createdAt ?? 0,
        };
      } catch {
        return null;
      }
    });
    const ok = results.filter(
      (r): r is { amountMinor: number; currency: string; at: number | string | Date } =>
        r !== null,
    );
    if (ok.length === 0) {
      return { amounts: [], available: false, counts: 0, monthly: [] };
    }
    return {
      amounts: sumByCurrency(ok),
      available: true,
      counts: ok.length,
      monthly: bucketMonthly(ok),
    };
  } catch (err) {
    console.error("[founder] Play revenue unavailable:", err);
    return { amounts: [], available: false, counts: 0, monthly: [] };
  }
}

/** Merge two per-provider month series into one spanning timeline. Months
 *  with no revenue in a provider simply omit that provider's key. */
export function mergeMonthly(
  stripe: MonthlyChannel,
  play: MonthlyChannel,
): MonthlyRevenuePoint[] {
  const months = new Set<string>();
  for (const p of stripe) months.add(p.month);
  for (const p of play) months.add(p.month);
  return [...months]
    .sort()
    .map((month) => {
      const s = stripe.find((p) => p.month === month);
      const pl = play.find((p) => p.month === month);
      return {
        month,
        ...(s ? { stripe: s.amounts } : {}),
        ...(pl ? { play: pl.amounts } : {}),
      };
    });
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
      monthly: mergeMonthly(
        // Unavailable channels contribute nothing — never a fabricated zero.
        stripe.available ? stripe.monthly : [],
        play.available ? play.monthly : [],
      ),
    },
  };
}
