import { afterEach, beforeEach, describe, expect, it } from "vitest";

import { checkRateLimit, resetRateLimits } from "@/lib/rateLimit";

describe("checkRateLimit", () => {
  beforeEach(() => resetRateLimits());
  afterEach(() => {
    delete process.env.AI_RATE_LIMIT_PER_MINUTE;
    resetRateLimits();
  });

  it("allows requests under the limit", () => {
    expect(checkRateLimit("u1", "ai:chat", 1_000).allowed).toBe(true);
    expect(checkRateLimit("u1", "ai:chat", 2_000).allowed).toBe(true);
  });

  it("blocks once the sliding minute-window is full", () => {
    process.env.AI_RATE_LIMIT_PER_MINUTE = "2";
    expect(checkRateLimit("u1", "ai:chat", 1_000).allowed).toBe(true);
    expect(checkRateLimit("u1", "ai:chat", 2_000).allowed).toBe(true);

    const blocked = checkRateLimit("u1", "ai:chat", 3_000);
    expect(blocked.allowed).toBe(false);
    // The caller can retry once the oldest hit ages out of the window.
    expect(blocked.retryAfterMs).toBeGreaterThan(0);
    expect(blocked.retryAfterMs).toBeLessThanOrEqual(60_000);
  });

  it("keeps buckets and users independent", () => {
    process.env.AI_RATE_LIMIT_PER_MINUTE = "1";
    expect(checkRateLimit("u1", "ai:chat", 1_000).allowed).toBe(true);
    // Same user, different bucket (assist vs chat) — still allowed.
    expect(checkRateLimit("u1", "ai:assist", 1_000).allowed).toBe(true);
    // Different user, same bucket — still allowed.
    expect(checkRateLimit("u2", "ai:chat", 1_000).allowed).toBe(true);
  });

  it("lets slots expire after the window elapses", () => {
    process.env.AI_RATE_LIMIT_PER_MINUTE = "1";
    expect(checkRateLimit("u1", "ai:chat", 1_000).allowed).toBe(true);
    expect(checkRateLimit("u1", "ai:chat", 2_000).allowed).toBe(false);
    // 61s later the only hit has aged out of the window.
    expect(checkRateLimit("u1", "ai:chat", 1_000 + 61_000).allowed).toBe(true);
  });

  it("defaults to the configured ceiling when the env is unset or invalid", () => {
    delete process.env.AI_RATE_LIMIT_PER_MINUTE;
    for (let i = 0; i < 30; i++) {
      expect(checkRateLimit("u1", "ai:chat", 1_000 + i).allowed).toBe(true);
    }
    expect(checkRateLimit("u1", "ai:chat", 1_000 + 30).allowed).toBe(false);

    process.env.AI_RATE_LIMIT_PER_MINUTE = "not-a-number";
    resetRateLimits();
    expect(checkRateLimit("u1", "ai:chat", 1).allowed).toBe(true);
  });
});
