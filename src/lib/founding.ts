// ─────────────────────────────────────────────────────────────────────
// Founding Member offer — server-side allocation (docs/founding-members.md).
//
// Rules enforced here:
//  - A slot is claimed ONLY after the payment webhook confirms a
//    successful subscription (billing.ts calls claimFoundingMembership).
//  - The cap lives in the `founding_member_counter` row (source of truth).
//  - Allocation is an atomic conditional UPDATE — Postgres row-locks the
//    counter, so concurrent claims can never exceed `cap`.
//  - Slots are PERMANENT: cancellation marks the member canceled but
//    never frees the slot.
//  - Claiming is idempotent per user (unique constraint + pre-check).
//
// The `FoundingStore` interface lets tests exercise the full contract
// against an in-memory store that serializes claims exactly like the
// atomic counter does.
// ─────────────────────────────────────────────────────────────────────
import { eq, sql } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { FOUNDING_TERMS } from "@/lib/founding-constants";

export { FOUNDING_TERMS };

export const COUNTER_ID = 1;

export type ClaimResult =
  | { status: "claimed"; claimed: number; cap: number }
  | { status: "already_claimed" }
  | { status: "full"; claimed: number; cap: number };

export interface FoundingStatus {
  claimed: number;
  cap: number;
  remaining: number;
  full: boolean;
  activeCount: number;
  canceledCount: number;
  /** False when the counter could not be read (DB unavailable) — UI must
   *  not display a count it cannot source from the backend. */
  available: boolean;
}

export interface FoundingMemberRecord {
  userId: string;
  status: "active" | "canceled";
  claimedAt: Date;
}

/** The atomic claim contract. The Postgres implementation uses a
 *  conditional UPDATE inside a transaction; the test implementation
 *  serializes claims with a mutex so both uphold the same invariants:
 *  cap never exceeded, idempotent per user, slots permanent. */
export interface FoundingStore {
  /** Atomically claim one slot for a user. Never throws on business
   *  rules — returns the outcome. */
  claim(userId: string, subscriptionId: string): Promise<ClaimResult>;
  getStatus(): Promise<FoundingStatus>;
  listMembers(): Promise<FoundingMemberRecord[]>;
  /** Marks a member canceled after subscription cancellation. Slot
   *  stays consumed. No-op when the member is unknown. */
  markCanceled(subscriptionId: string): Promise<void>;
}

// ── Postgres implementation ──────────────────────────────────────────

export const postgresFoundingStore: FoundingStore = {
  async claim(userId, subscriptionId) {
    const db = getDb();
    return db.transaction(async (tx) => {
      // Idempotency: a user who already claimed (webhook replay, or a
      // second successful subscription) must not consume another slot.
      const existing = await tx.query.foundingMembers.findFirst({
        where: eq(schema.foundingMembers.userId, userId),
      });
      if (existing) return { status: "already_claimed" } as ClaimResult;

      // Atomic allocation — the entire race safety lives in this UPDATE.
      const rows = await tx.execute<{ claimed: number; cap: number }>(
        sql`UPDATE ${schema.foundingMemberCounter}
            SET claimed = claimed + 1
            WHERE id = ${COUNTER_ID} AND claimed < cap
            RETURNING claimed, cap`,
      );
      if (rows.length === 0) {
        // Cap reached — read current values for a helpful message.
        const counter = await tx.query.foundingMemberCounter.findFirst({
          where: eq(schema.foundingMemberCounter.id, COUNTER_ID),
        });
        return {
          status: "full",
          claimed: counter?.claimed ?? 0,
          cap: counter?.cap ?? 35,
        } as ClaimResult;
      }

      // Persist the permanent claim record. Unique(userId) protects
      // against a double-claim racing between the check and the insert.
      await tx.insert(schema.foundingMembers).values({
        userId,
        subscriptionId,
        status: "active",
      });

      return {
        status: "claimed",
        claimed: rows[0]!.claimed,
        cap: rows[0]!.cap,
      } as ClaimResult;
    });
  },

  async getStatus() {
    const db = getDb();
    const counter = await db.query.foundingMemberCounter.findFirst({
      where: eq(schema.foundingMemberCounter.id, COUNTER_ID),
    });
    const claimed = counter?.claimed ?? 0;
    const cap = counter?.cap ?? 35;

    const active = await db.query.foundingMembers.findMany({
      where: eq(schema.foundingMembers.status, "active"),
      columns: { id: true },
    });
    const canceled = await db.query.foundingMembers.findMany({
      where: eq(schema.foundingMembers.status, "canceled"),
      columns: { id: true },
    });

    return {
      claimed,
      cap,
      remaining: Math.max(0, cap - claimed),
      full: claimed >= cap,
      activeCount: active.length,
      canceledCount: canceled.length,
      available: true,
    };
  },

  async listMembers() {
    const db = getDb();
    const rows = await db.query.foundingMembers.findMany({
      orderBy: (m, { asc }) => [asc(m.claimedAt)],
    });
    return rows.map((r) => ({
      userId: r.userId,
      status: r.status as "active" | "canceled",
      claimedAt: r.claimedAt,
    }));
  },

  async markCanceled(subscriptionId) {
    const db = getDb();
    await db
      .update(schema.foundingMembers)
      .set({ status: "canceled" })
      .where(eq(schema.foundingMembers.subscriptionId, subscriptionId));
  },
};

// ── Service helpers (UI / checkout / webhook) ────────────────────────

export async function getFoundingStatus(
  store: FoundingStore = postgresFoundingStore,
): Promise<FoundingStatus> {
  return store.getStatus();
}

/** Public-page helper: never lets a DB outage take down the landing or
 *  pricing page. On failure, returns an unavailable status so the UI
 *  omits counts rather than inventing them. */
export async function getFoundingStatusSafe(): Promise<FoundingStatus> {
  try {
    return await getFoundingStatus();
  } catch {
    return {
      claimed: 0,
      cap: 35,
      remaining: 0,
      full: false,
      activeCount: 0,
      canceledCount: 0,
      available: false,
    };
  }
}

export async function isFoundingMember(
  userId: string,
  store: FoundingStore = postgresFoundingStore,
): Promise<boolean> {
  const members = await store.listMembers();
  return members.some((m) => m.userId === userId && m.status === "active");
}

/** Returns true when the user may still purchase the founding offer. */
export async function foundingOfferOpenFor(
  userId: string,
  store: FoundingStore = postgresFoundingStore,
): Promise<boolean> {
  const status = await store.getStatus();
  if (status.full) return false;
  const members = await store.listMembers();
  return !members.some((m) => m.userId === userId);
}

// ── Test in-memory store ─────────────────────────────────────────────

/** Serialized in-memory store implementing the exact same contract as
 *  the atomic counter: claims are applied one at a time and never exceed
 *  the cap. Used by unit tests (src/lib/founding.test.ts). */
export function inMemoryFoundingStore(cap: number): FoundingStore {
  let claimed = 0;
  const members = new Map<string, { subscriptionId: string; status: "active" | "canceled"; claimedAt: Date }>();
  let queue: Promise<void> = Promise.resolve();

  function serialize<T>(fn: () => Promise<T>): Promise<T> {
    const next = queue.then(fn);
    queue = next.then(
      () => undefined,
      () => undefined,
    );
    return next;
  }

  return {
    claim(userId, subscriptionId) {
      return serialize(async (): Promise<ClaimResult> => {
        if (members.has(userId)) return { status: "already_claimed" };
        if (claimed >= cap) return { status: "full", claimed, cap };
        claimed += 1;
        members.set(userId, { subscriptionId, status: "active", claimedAt: new Date() });
        return { status: "claimed", claimed, cap };
      });
    },
    async getStatus() {
      const list = [...members.values()];
      return {
        claimed,
        cap,
        remaining: Math.max(0, cap - claimed),
        full: claimed >= cap,
        activeCount: list.filter((m) => m.status === "active").length,
        canceledCount: list.filter((m) => m.status === "canceled").length,
        available: true,
      };
    },
    async listMembers() {
      return [...members.entries()].map(([userId, m]) => ({
        userId,
        status: m.status,
        claimedAt: m.claimedAt,
      }));
    },
    markCanceled(subscriptionId) {
      return serialize(async () => {
        for (const m of members.values()) {
          if (m.subscriptionId === subscriptionId) m.status = "canceled";
        }
      });
    },
  };
}

export function isFoundingPlan(plan: string | null | undefined): boolean {
  return plan === FOUNDING_TERMS.planStorage;
}
