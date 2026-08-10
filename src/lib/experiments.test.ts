import { describe, expect, it } from "vitest";
import { getVariant, listExperiments } from "./experiments";

describe("experiments", () => {
  it("registers experiments with hypothesis, metric, and decision rule", () => {
    const experiments = listExperiments();
    expect(experiments.length).toBeGreaterThan(0);
    for (const e of experiments) {
      expect(e.hypothesis.length).toBeGreaterThan(0);
      expect(e.metric.length).toBeGreaterThan(0);
      expect(e.decisionRule.length).toBeGreaterThan(0);
      expect(e.variants.length).toBeGreaterThanOrEqual(2);
      // weights must be positive
      for (const v of e.variants) expect(v.weight).toBeGreaterThan(0);
    }
  });

  it("assigns the same variant deterministically for a user", () => {
    const userId = "user_123";
    const a = getVariant("pricing-headline", userId);
    const b = getVariant("pricing-headline", userId);
    expect(a).not.toBeNull();
    expect(a!.variant.id).toBe(b!.variant.id);
  });

  it("respects the env override for QA", () => {
    process.env["EXPERIMENT_pricing-headline"] = "hero-first";
    const v = getVariant("pricing-headline", "any_user");
    expect(v!.variant.id).toBe("hero-first");
    delete process.env["EXPERIMENT_pricing-headline"];
  });

  it("returns null for an unknown experiment", () => {
    expect(getVariant("does-not-exist", "user_1")).toBeNull();
  });
});
