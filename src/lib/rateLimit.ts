// ─────────────────────────────────────────────────────────────────────
// Short-window rate limiting — a safety valve on TOP of the monthly
// AI-action quota (lib/usage.ts). The quota stops a user from burning
// their allowance; this stops one account from hammering the expensive
// AI endpoints with thousands of requests per minute (abuse protection,
// docs: rate limiting / request quotas).
//
// Config (server-side env only, never user-facing):
//   AI_RATE_LIMIT_PER_MINUTE — max AI requests per minute per user
//     (default 30; the free monthly allowance is only 20 actions, so a
//     burst of 30 in a minute is far beyond legitimate use).
//
// In-memory per process, like provider health. Single-instance
// deployments get exact accounting; multi-instance deployments get a
// per-instance view (still blocks the worst abuse).
// ─────────────────────────────────────────────────────────────────────
const WINDOW_MS = 60_000;
const DEFAULT_LIMIT = 30;

function limitPerMinute(): number {
  const raw = Number(process.env.AI_RATE_LIMIT_PER_MINUTE);
  return Number.isFinite(raw) && raw > 0 ? Math.floor(raw) : DEFAULT_LIMIT;
}

export interface RateLimitResult {
  allowed: boolean;
  /** When blocked, milliseconds until the window clears enough. */
  retryAfterMs: number;
}

const buckets = new Map<string, number[]>();

/**
 * Check (and, when allowed, record) one request in [bucket] for
 * [userId]. Returns [allowed: false] with [retryAfterMs] once the
 * sliding minute-window is full.
 */
export function checkRateLimit(
  userId: string,
  bucket: string,
  now = Date.now(),
): RateLimitResult {
  const key = `${userId}:${bucket}`;
  const cutoff = now - WINDOW_MS;
  const hits = (buckets.get(key) ?? []).filter((t) => t > cutoff);
  const max = limitPerMinute();
  if (hits.length >= max) {
    // Keep only the timestamps inside the window; the caller can retry
    // when the oldest one ages out.
    buckets.set(key, hits);
    return { allowed: false, retryAfterMs: WINDOW_MS - (now - hits[0]) };
  }
  hits.push(now);
  buckets.set(key, hits);
  return { allowed: true, retryAfterMs: 0 };
}

/** Clear all rate-limit state (tests). */
export function resetRateLimits(): void {
  buckets.clear();
}
