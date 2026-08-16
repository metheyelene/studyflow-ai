import { beforeEach, describe, expect, it } from "vitest";

import {
  healthyProviderOrder,
  isProviderDegraded,
  recordProviderFailure,
  recordProviderSuccess,
  resetProviderHealth,
} from "@/lib/ai/health";

describe("provider health", () => {
  beforeEach(() => resetProviderHealth());

  it("keeps the configured order while providers are healthy", () => {
    expect(healthyProviderOrder(["openai", "anthropic"], 1_000)).toEqual([
      "openai",
      "anthropic",
    ]);
  });

  it("does not degrade on a single transient failure", () => {
    recordProviderFailure("openai", 1_000);
    expect(isProviderDegraded("openai", 2_000)).toBe(false);
    expect(healthyProviderOrder(["openai", "anthropic"], 2_000)).toEqual([
      "openai",
      "anthropic",
    ]);
  });

  it("sinks a provider after repeated failures inside the window", () => {
    recordProviderFailure("openai", 1_000);
    recordProviderFailure("openai", 2_000);
    recordProviderFailure("openai", 3_000);
    expect(isProviderDegraded("openai", 3_000)).toBe(true);

    // Healthy providers first, degraded sunk to the end — still usable as
    // a last-resort fallback, never hard-dropped.
    expect(healthyProviderOrder(["openai", "anthropic"], 3_000)).toEqual([
      "anthropic",
      "openai",
    ]);
  });

  it("restores priority immediately on success", () => {
    recordProviderFailure("openai", 1_000);
    recordProviderFailure("openai", 2_000);
    recordProviderFailure("openai", 3_000);
    recordProviderSuccess("openai");
    expect(healthyProviderOrder(["openai", "anthropic"], 3_000)).toEqual([
      "openai",
      "anthropic",
    ]);
  });

  it("recovers quietly after a window with no new failures", () => {
    recordProviderFailure("openai", 1_000);
    recordProviderFailure("openai", 2_000);
    recordProviderFailure("openai", 3_000);
    // 61s after the last failure with no new ones: outage assumed over.
    expect(isProviderDegraded("openai", 3_000 + 61_000)).toBe(false);
  });

  it("only counts failures inside the degrade window", () => {
    recordProviderFailure("openai", 1_000);
    // The first failure has aged out by now; two fresh ones are not
    // enough to degrade.
    recordProviderFailure("openai", 1_000 + 5 * 60_000 + 1);
    recordProviderFailure("openai", 1_000 + 5 * 60_000 + 2);
    expect(isProviderDegraded("openai", 1_000 + 5 * 60_000 + 2)).toBe(false);
  });

  it("degrades each provider independently", () => {
    recordProviderFailure("anthropic", 1_000);
    recordProviderFailure("anthropic", 2_000);
    recordProviderFailure("anthropic", 3_000);
    expect(isProviderDegraded("anthropic", 3_000)).toBe(true);
    expect(isProviderDegraded("openai", 3_000)).toBe(false);
  });
});
