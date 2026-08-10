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

export interface PlanContext {
  userId: string;
  plan: Plan;
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

  return { userId: session.user.id, plan: sub ? "premium" : "free" };
}

/** Convenience for server components: is this request premium? */
export async function isPremiumSession(): Promise<boolean> {
  return (await getPlanForSession())?.plan === "premium";
}
