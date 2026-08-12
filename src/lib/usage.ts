// ─────────────────────────────────────────────────────────────────────
// Server-side usage metering. NEVER enforce limits in the client —
// every AI generation must pass through consumeAiAction() first.
// The limits themselves come from src/lib/plans.ts (single source).
// ─────────────────────────────────────────────────────────────────────
import { and, eq, sql } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { getLimits, type Plan } from "@/lib/plans";

const AI_ACTIONS = "ai_actions";

/** "2026-08" — the monthly bucket used for all AI-action meters. */
export function periodKey(date: Date = new Date()): string {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
}

/** First instant of next month UTC — when the AI allowance resets. */
export function nextPeriodStart(date: Date = new Date()): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 1));
}

export function percentUsed(used: number, limit: number): number {
  if (limit <= 0) return 100;
  return Math.min(100, Math.round((used / limit) * 100));
}

export type UsageState = "ok" | "warning" | "critical" | "exhausted";

/**
 * Threshold states drive the usage-limit UX:
 *   0–69%  ok        (subtle, no messaging)
 *   70–89% warning   (subtle usage info)
 *   90–99% critical  (explain what remains + premium mention)
 *   100%   exhausted (explain reset, offer premium, never lock out cold)
 */
export function usageState(used: number, limit: number): UsageState {
  if (limit <= 0 || used >= limit) return "exhausted";
  const pct = (used / limit) * 100;
  if (pct >= 90) return "critical";
  if (pct >= 70) return "warning";
  return "ok";
}

export interface AiUsage {
  used: number;
  limit: number;
  remaining: number;
  percent: number;
  state: UsageState;
  /** ISO timestamp of the next period start (when the meter resets). */
  resetsAt: string;
}

export async function getAiUsage(userId: string, plan: Plan): Promise<AiUsage> {
  const db = getDb();
  const limit = getLimits(plan).aiActionsPerMonth;
  const key = periodKey();

  const row = await db.query.usage.findFirst({
    where: and(
      eq(schema.usage.userId, userId),
      eq(schema.usage.feature, AI_ACTIONS),
      eq(schema.usage.period, key),
    ),
  });

  const used = row?.count ?? 0;
  return {
    used,
    limit,
    remaining: Math.max(0, limit - used),
    percent: percentUsed(used, limit),
    state: usageState(used, limit),
    resetsAt: nextPeriodStart().toISOString(),
  };
}

/**
 * Atomically consume one unit of a lifetime bucket (notebooks, sources,
 * documents, subjects). Same race-safe pattern as consumeAiAction;
 * period is always "lifetime". Callers MUST check `allowed`.
 */
export async function consumeLifetime(
  userId: string,
  feature: string,
  limit: number,
): Promise<{ allowed: boolean; used: number }> {
  const db = getDb();
  const result = await db
    .insert(schema.usage)
    .values({
      userId,
      feature,
      period: "lifetime",
      count: 1,
      limit,
    })
    .onConflictDoUpdate({
      target: [schema.usage.userId, schema.usage.feature, schema.usage.period],
      set: {
        count: sql`${schema.usage.count} + 1`,
        limit,
      },
      setWhere: sql`${schema.usage.count} < ${limit}`,
    })
    .returning({ count: schema.usage.count });

  const used = result[0]?.count ?? limit;
  return { allowed: used <= limit, used };
}

/**
 * Atomically consume one unit of a monthly bucket (e.g. audio episodes).
 * Same race-safe pattern as consumeAiAction; the caller passes the
 * feature name and limit so it stays generic.
 */
export async function consumeMonthly(
  userId: string,
  feature: string,
  limit: number,
): Promise<{ allowed: boolean; used: number }> {
  const db = getDb();
  const key = periodKey();
  const result = await db
    .insert(schema.usage)
    .values({
      userId,
      feature,
      period: key,
      count: 1,
      limit,
    })
    .onConflictDoUpdate({
      target: [schema.usage.userId, schema.usage.feature, schema.usage.period],
      set: {
        count: sql`${schema.usage.count} + 1`,
        limit,
      },
      setWhere: sql`${schema.usage.count} < ${limit}`,
    })
    .returning({ count: schema.usage.count });

  const used = result[0]?.count ?? limit;
  return { allowed: used <= limit, used };
}

/**
 * Best-effort refund of one unit of a monthly bucket (used when a
 * generation job fails after reserving its slot, so a failed generation
 * doesn't silently eat the user's quota). The decrement can never go
 * below 0.
 */
export async function refundMonthly(userId: string, feature: string): Promise<void> {
  const db = getDb();
  await db
    .update(schema.usage)
    .set({ count: sql`greatest(${schema.usage.count} - 1, 0)` })
    .where(
      and(
        eq(schema.usage.userId, userId),
        eq(schema.usage.feature, feature),
        eq(schema.usage.period, periodKey()),
      ),
    );
}

/** Current count of a lifetime bucket (0 if never incremented). */
export async function getLifetimeCount(userId: string, feature: string): Promise<number> {
  const db = getDb();
  const row = await db.query.usage.findFirst({
    where: and(
      eq(schema.usage.userId, userId),
      eq(schema.usage.feature, feature),
      eq(schema.usage.period, "lifetime"),
    ),
  });
  return row?.count ?? 0;
}

/**
 * Atomically consume one AI action for a user. Race-safe: the
 * increment only happens when count < limit in the same statement, so
 * concurrent requests can't overspend (the double-spend guard from
 * docs/plans-and-limits.md).
 *
 * Callers MUST check `allowed` before running the generation.
 */
export async function consumeAiAction(
  userId: string,
  plan: Plan,
): Promise<{ allowed: boolean; usage: AiUsage }> {
  const db = getDb();
  const limit = getLimits(plan).aiActionsPerMonth;
  const key = periodKey();

  const result = await db
    .insert(schema.usage)
    .values({
      userId,
      feature: AI_ACTIONS,
      period: key,
      count: 1,
      limit,
    })
    .onConflictDoUpdate({
      target: [schema.usage.userId, schema.usage.feature, schema.usage.period],
      set: {
        count: sql`${schema.usage.count} + 1`,
        limit,
      },
      setWhere: sql`${schema.usage.count} < ${limit}`,
    })
    .returning({ count: schema.usage.count });

  // No row returned → the increment was rejected (limit reached).
  const used = result[0]?.count ?? limit;
  const allowed = used <= limit;

  return {
    allowed,
    usage: {
      used,
      limit,
      remaining: Math.max(0, limit - used),
      percent: percentUsed(used, limit),
      state: usageState(used, limit),
      resetsAt: nextPeriodStart().toISOString(),
    },
  };
}
