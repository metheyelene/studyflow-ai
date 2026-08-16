// ─────────────────────────────────────────────────────────────────────
// AI response cache. Key = hash(notebookId, sourceIds sorted, source
// versions, question, mode, feature, model). Because the key includes
// source VERSIONS, replacing a source automatically invalidates every
// cached answer that depended on it — no explicit invalidation needed.
// ─────────────────────────────────────────────────────────────────────
import { and, eq, lt } from "drizzle-orm";
import { createHash } from "node:crypto";

import { getDb, schema } from "@/db";

export const CACHE_TTL_DAYS = 30;

export interface CacheKeyInput {
  userId: string;
  notebookId: string;
  sourceIds: string[];
  /** sourceId → version — the invalidation signal. */
  sourceVersions: Record<string, number>;
  question: string;
  mode: string;
  feature: string;
  model: string;
  /** AI-preference fingerprint — changing preferences bypasses cached answers. */
  preferences?: string;
}

export function cacheKey(input: CacheKeyInput): string {
  const canonical = JSON.stringify({
    notebookId: input.notebookId,
    sourceIds: [...input.sourceIds].sort(),
    versions: Object.fromEntries(
      Object.entries(input.sourceVersions).sort(([a], [b]) => a.localeCompare(b)),
    ),
    question: input.question.trim().toLowerCase(),
    mode: input.mode,
    feature: input.feature,
    model: input.model,
    preferences: input.preferences ?? "",
  });
  return createHash("sha256").update(canonical).digest("hex");
}

export async function getCached<T>(userId: string, notebookId: string, key: string): Promise<T | null> {
  const db = getDb();
  const row = await db.query.aiCache.findFirst({
    where: and(eq(schema.aiCache.userId, userId), eq(schema.aiCache.key, key)),
  });
  if (!row) return null;
  const cutoff = Date.now() - CACHE_TTL_DAYS * 86_400_000;
  if (new Date(row.createdAt).getTime() < cutoff) {
    await db.delete(schema.aiCache).where(eq(schema.aiCache.key, key)).catch(() => {});
    return null;
  }
  return row.payload as T;
}

export async function putCached<T>(userId: string, notebookId: string, key: string, payload: T): Promise<void> {
  try {
    const db = getDb();
    await db
      .insert(schema.aiCache)
      .values({ userId, notebookId, key, payload })
      .onConflictDoUpdate({
        target: schema.aiCache.key,
        set: { payload, userId, notebookId },
      });
  } catch {
    // Cache writes are best-effort; never fail a generation on them.
  }
}

/** Delete every cached entry for a notebook (used on notebook delete). */
export async function invalidateNotebook(notebookId: string): Promise<void> {
  try {
    const db = getDb();
    await db.delete(schema.aiCache).where(eq(schema.aiCache.notebookId, notebookId));
  } catch {
    // best-effort
  }
}

export async function cleanupExpiredCache(): Promise<number> {
  const db = getDb();
  const cutoff = new Date(Date.now() - CACHE_TTL_DAYS * 86_400_000);
  const deleted = await db
    .delete(schema.aiCache)
    .where(lt(schema.aiCache.createdAt, cutoff))
    .returning({ id: schema.aiCache.id });
  return deleted.length;
}
