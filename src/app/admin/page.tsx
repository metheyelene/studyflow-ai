import { headers } from "next/headers";
import { notFound } from "next/navigation";

import { auth } from "@/lib/auth";
import {
  getFounderStats,
  type ChannelRevenue,
  type FounderStats,
} from "@/lib/founderDashboard";
import { postgresFoundingStore } from "@/lib/founding";
import { GlassCard } from "@/components/ui/glass";

/** Founder dashboard — server-side gated by ADMIN_EMAILS (comma-separated
 *  env). Never client-gated. When unset, the page does not exist for
 *  anyone. Every number is real: counts come from the database, revenue
 *  from the payment providers. No estimates, no fabricated data. */

// Auth-gated admin surface: never statically prerender. The gate reads
// the request headers and revenue must be fresh per request — a cached
// build-time 404 (or stale numbers) would be a release-blocking bug.
export const dynamic = "force-dynamic";

export default async function AdminPage() {
  const allowed = (process.env.ADMIN_EMAILS ?? "")
    .split(",")
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  if (allowed.length === 0) notFound();

  const session = await auth.api.getSession({ headers: await headers() });
  if (!session || !allowed.includes(session.user.email.toLowerCase())) {
    notFound();
  }

  const stats = await getFounderStats();
  const members = await postgresFoundingStore.listMembers();

  return (
    <div className="mx-auto max-w-4xl space-y-8">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">
          Founder Dashboard
        </h1>
        <p className="text-muted-foreground mt-1">
          Real numbers only — users, subscriptions, founding allocation, and
          revenue reported by the payment providers.
        </p>
      </div>

      <UsersCard stats={stats} />
      <PremiumCard stats={stats} />
      <FoundingCard stats={stats} />
      <RevenueCard stats={stats} />

      <GlassCard tone="primary" className="overflow-hidden p-0">
        <div className="border-b border-border/60 px-6 py-4">
          <h2 className="font-medium">Founding Members</h2>
        </div>
        {members.length === 0 ? (
          <p className="text-muted-foreground px-6 py-8 text-sm">
            No founding members yet.
          </p>
        ) : (
          <div className="divide-y divide-border/60">
            {members.map((m) => (
              <div
                key={m.userId}
                className="flex items-center justify-between px-6 py-3 text-sm"
              >
                <span className="font-mono text-xs">{m.userId}</span>
                <span className="flex items-center gap-3">
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                      m.status === "active"
                        ? "bg-emerald-500/15 text-emerald-600 dark:text-emerald-400"
                        : "bg-muted text-muted-foreground"
                    }`}
                  >
                    {m.status}
                  </span>
                  <span className="text-muted-foreground text-xs tabular-nums">
                    {m.claimedAt.toLocaleString()}
                  </span>
                </span>
              </div>
            ))}
          </div>
        )}
      </GlassCard>
    </div>
  );
}

function StatGrid({
  stats,
}: {
  stats: { label: string; value: string }[];
}) {
  return (
    <div className="grid grid-cols-2 gap-6 sm:grid-cols-4">
      {stats.map((s) => (
        <div key={s.label}>
          <p className="text-muted-foreground text-xs font-medium tracking-wider uppercase">
            {s.label}
          </p>
          <p className="mt-1 text-2xl font-semibold tabular-nums">{s.value}</p>
        </div>
      ))}
    </div>
  );
}

function UsersCard({ stats }: { stats: FounderStats }) {
  const { users } = stats;
  return (
    <GlassCard tone="floating" className="p-6">
      <h2 className="mb-4 font-medium">Users</h2>
      <StatGrid
        stats={[
          { label: "Total", value: String(users.total) },
          { label: "Onboarded", value: String(users.onboarded) },
          { label: "Active (30d)", value: String(users.active30d) },
          { label: "Conversion", value: formatPercent(users.total ? users.onboarded / users.total : 0) },
        ]}
      />
    </GlassCard>
  );
}

function PremiumCard({ stats }: { stats: FounderStats }) {
  const { subscriptions } = stats;
  return (
    <GlassCard tone="floating" className="p-6">
      <h2 className="mb-4 font-medium">Premium Subscribers</h2>
      <StatGrid
        stats={[
          { label: "Active", value: String(subscriptions.active) },
          { label: "Founding", value: String(subscriptions.activeFounding) },
          { label: "Regular", value: String(subscriptions.activeRegular) },
          { label: "Canceled", value: String(subscriptions.canceled) },
        ]}
      />
      <p className="text-muted-foreground mt-4 border-t border-border/60 pt-3 text-xs">
        Entitlement is derived from the subscriptions table server-side —
        never from a client-side flag.
      </p>
    </GlassCard>
  );
}

function FoundingCard({ stats }: { stats: FounderStats }) {
  const { founding } = stats;
  return (
    <GlassCard tone="floating" className="p-6">
      <h2 className="mb-4 font-medium">Founding Allocation</h2>
      <StatGrid
        stats={[
          { label: "Claimed", value: `${founding.claimed} / ${founding.cap}` },
          { label: "Remaining", value: String(founding.remaining) },
          { label: "Active", value: String(founding.activeCount) },
          { label: "Canceled", value: String(founding.canceledCount) },
        ]}
      />
      <p className="text-muted-foreground mt-4 border-t border-border/60 pt-3 text-xs">
        Source of truth: the database counter. Slots are permanently consumed
        once a subscription is confirmed (docs/founding-members.md §2).
      </p>
    </GlassCard>
  );
}

const moneySymbols: Record<string, string> = {
  usd: "$",
  inr: "₹",
  eur: "€",
  gbp: "£",
};

function formatMoney(amountMinor: number, currency: string): string {
  const symbol =
    moneySymbols[currency.toLowerCase()] ?? `${currency.toUpperCase()} `;
  const value = (amountMinor / 100).toLocaleString("en-IN", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return `${symbol}${value}`;
}

function formatPercent(fraction: number): string {
  return `${Math.round(fraction * 100)}%`;
}

function RevenueChannel({
  label,
  channel,
  fallbackNote,
}: {
  label: string;
  channel: ChannelRevenue;
  fallbackNote: string;
}) {
  if (!channel.available) {
    return (
      <div className="flex items-center justify-between gap-4">
        <span className="text-sm">{label}</span>
        <span className="text-muted-foreground text-right text-xs">
          {fallbackNote}
        </span>
      </div>
    );
  }
  return (
    <div className="flex items-center justify-between gap-4">
      <span className="text-sm">
        {label}
        {channel.counts > 0 && (
          <span className="text-muted-foreground ml-2 text-xs">
            {channel.counts} {channel.counts === 1 ? "purchase" : "purchases"}
          </span>
        )}
      </span>
      <span className="font-semibold tabular-nums">
        {channel.amounts
          .map((a) => formatMoney(a.amountMinor, a.currency))
          .join(" + ")}
      </span>
    </div>
  );
}

function RevenueCard({ stats }: { stats: FounderStats }) {
  const { revenue } = stats;
  return (
    <GlassCard tone="primary" className="p-6">
      <h2 className="mb-4 font-medium">Revenue</h2>
      {!revenue.hasPurchases ? (
        <>
          <p className="text-3xl font-semibold tabular-nums">₹0</p>
          <p className="text-muted-foreground mt-1 text-xs">
            No purchases yet — revenue appears here from real Play/Stripe
            payments only. Never estimated.
          </p>
        </>
      ) : (
        <>
          <div className="space-y-3">
            <RevenueChannel
              label="Stripe"
              channel={revenue.stripe}
              fallbackNote="Unavailable — STRIPE_SECRET_KEY missing or API error."
            />
            <RevenueChannel
              label="Google Play"
              channel={revenue.play}
              fallbackNote="Unavailable — GOOGLE_PLAY_SERVICE_ACCOUNT_JSON missing or API error."
            />
          </div>
          <p className="text-muted-foreground mt-4 border-t border-border/60 pt-3 text-xs">
            Real amounts reported by each provider in its native currency
            (Stripe: USD · Google Play: INR).
          </p>
        </>
      )}
    </GlassCard>
  );
}
