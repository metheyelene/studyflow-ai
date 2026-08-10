import { headers } from "next/headers";
import { notFound } from "next/navigation";

import { auth } from "@/lib/auth";
import { getFoundingStatus, postgresFoundingStore } from "@/lib/founding";
import { GlassCard } from "@/components/ui/glass";

/** Admin — server-side gated by ADMIN_EMAILS (comma-separated env).
 *  Never client-gated. When unset, the page does not exist for anyone. */
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

  const status = await getFoundingStatus();
  const members = await postgresFoundingStore.listMembers();

  const stats = [
    { label: "Claimed", value: `${status.claimed} / ${status.cap}` },
    { label: "Remaining", value: String(status.remaining) },
    { label: "Active", value: String(status.activeCount) },
    { label: "Canceled", value: String(status.canceledCount) },
  ];

  return (
    <div className="mx-auto max-w-4xl space-y-8">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Admin</h1>
        <p className="text-muted-foreground mt-1">
          Founding-member allocation — source of truth: the database counter.
        </p>
      </div>

      <GlassCard tone="floating" className="p-6">
        <div className="grid grid-cols-2 gap-6 sm:grid-cols-4">
          {stats.map((s) => (
            <div key={s.label}>
              <p className="text-muted-foreground text-xs font-medium tracking-wider uppercase">
                {s.label}
              </p>
              <p className="mt-1 text-2xl font-semibold tabular-nums">
                {s.value}
              </p>
            </div>
          ))}
        </div>
        <p className="text-muted-foreground mt-4 border-t border-border/60 pt-3 text-xs">
          Slots are permanently consumed once a subscription is confirmed —
          cancelled members do not free a slot (docs/founding-members.md §2).
        </p>
      </GlassCard>

      <GlassCard tone="primary" className="overflow-hidden p-0">
        <div className="border-b border-border/60 px-6 py-4">
          <h2 className="font-medium">Members</h2>
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
