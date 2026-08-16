// ─────────────────────────────────────────────────────────────────────
// Adaptive provider health. When a provider fails repeatedly within a
// short window, the model router sinks it to the END of the failover
// chain so healthy providers are tried first; a successful call — or a
// quiet period with no new failures — restores its priority.
//
// In-memory per process. That is the right scope for a single-instance
// deployment (and always better than static ordering); multi-instance
// deployments can accept the per-instance view or swap the record store
// for something shared. No provider names ever leave this module.
// ─────────────────────────────────────────────────────────────────────
import type { AIProviderName } from "./orchestrator";

const FAILURES_TO_DEGRADE = 3;
const DEGRADE_WINDOW_MS = 5 * 60_000;
const RECOVER_AFTER_MS = 60_000;

interface ProviderRecord {
  /** Timestamps of failures inside the current degrade window. */
  failures: number[];
}

const records = new Map<AIProviderName, ProviderRecord>();

function recordFor(name: AIProviderName): ProviderRecord {
  let record = records.get(name);
  if (!record) {
    record = { failures: [] };
    records.set(name, record);
  }
  return record;
}

function prune(record: ProviderRecord, now: number): void {
  const cutoff = now - DEGRADE_WINDOW_MS;
  record.failures = record.failures.filter((t) => t > cutoff);
}

/** Record a failed generation for [name]. */
export function recordProviderFailure(name: AIProviderName, now = Date.now()): void {
  const record = recordFor(name);
  prune(record, now);
  record.failures.push(now);
}

/** Record a successful generation for [name] — immediately restores it. */
export function recordProviderSuccess(name: AIProviderName): void {
  recordFor(name).failures = [];
}

/**
 * A provider is degraded when it has failed >= FAILURES_TO_DEGRADE times
 * inside the degrade window and has not recovered — either via a success
 * (see [recordProviderSuccess]) or by going quiet: no new failure for
 * [RECOVER_AFTER_MS] means the outage is assumed over.
 */
export function isProviderDegraded(name: AIProviderName, now = Date.now()): boolean {
  const record = records.get(name);
  if (!record) return false;
  prune(record, now);
  if (record.failures.length < FAILURES_TO_DEGRADE) return false;
  const lastFailure = record.failures[record.failures.length - 1];
  if (now - lastFailure > RECOVER_AFTER_MS) {
    // Quiet recovery — the outage is assumed over.
    record.failures = [];
    return false;
  }
  return true;
}

/**
 * The failover order to try, given the configured order: healthy
 * providers first (in configured order), degraded providers sunk to the
 * end. Degraded providers stay usable as last-resort fallbacks — the
 * router never hard-drops a provider entirely.
 */
export function healthyProviderOrder(
  configured: AIProviderName[],
  now = Date.now(),
): AIProviderName[] {
  const healthy = configured.filter((p) => !isProviderDegraded(p, now));
  const degraded = configured.filter((p) => isProviderDegraded(p, now));
  return [...healthy, ...degraded];
}

/** Clear all health state (tests, and when provider config changes). */
export function resetProviderHealth(): void {
  records.clear();
}
