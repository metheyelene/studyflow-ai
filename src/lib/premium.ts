// ─────────────────────────────────────────────────────────────────────
// Server-side plan resolution. Premium ⇔ an active (or trialing)
// subscription — NEVER a client-supplied flag. All feature gating reads
// through these helpers so the rule lives in one place.
// ─────────────────────────────────────────────────────────────────────
import { headers } from "next/headers";
import { and, eq, inArray } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";
import type { Plan } from "@/lib/plans";

const ACTIVE_STATUSES = ["active", "trialing"] as const;

/** Pure plan resolution from the stored subscription plan. Founding
 *  members are premium for limits purposes — they get full Premium
 *  features at the founding price. */
export function planFromSubscription(plan: string | null): Plan {
  return plan ? "premium" : "free";
}

export interface PlanContext {
  userId: string;
  plan: Plan;
  /** Stored subscription plan ("premium" | "founding_member") or null. */
  subscriptionPlan: string | null;
}

/**
 * Resolves { userId, plan } for the current request, or null when logged
 * out. Reads the subscription row from Postgres — until the Stripe phase
 * lands, every user resolves to "free" (correct, just not yet upgradeable).
 */
export async function getPlanForSession(): Promise<PlanContext | null> {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return null;

  const db = getDb();
  const sub = await db.query.subscriptions.findFirst({
    where: and(
      eq(schema.subscriptions.userId, session.user.id),
      inArray(schema.subscriptions.status, [...ACTIVE_STATUSES]),
    ),
  });

  return {
    userId: session.user.id,
    plan: planFromSubscription(sub?.plan ?? null),
    subscriptionPlan: sub ? sub.plan : null,
  };
}

/** Convenience for server components: is this request premium? */
export async function isPremiumSession(): Promise<boolean> {
  return (await getPlanForSession())?.plan === "premium";
}
