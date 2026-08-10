import { describe, expect, it } from "vitest";

import { PLANS, PRICING, getLimits, getPlan } from "./plans";

// The pricing contract: premium must be strictly better on every metered
// dimension, generation caps must be sane, and the approved prices hold.
// If these numbers drift, the paywall and metering drift with them.

describe("plans", () => {
  it("premium strictly exceeds free on every metered dimension", () => {
    const free = PLANS.free;
    const premium = PLANS.premium;
    expect(premium.aiActionsPerMonth).toBeGreaterThan(free.aiActionsPerMonth);
    expect(premium.documentsLifetime).toBeGreaterThan(free.documentsLifetime);
    expect(premium.subjectsLifetime).toBeGreaterThan(free.subjectsLifetime);
    expect(premium.flashcardCardsPerMonth).toBeGreaterThan(
      free.flashcardCardsPerMonth,
    );
  });

  it("premium unlocks feature gates; free does not", () => {
    expect(PLANS.premium.aiPlanner).toBe(true);
    expect(PLANS.premium.premiumThemes).toBe(true);
    expect(PLANS.free.aiPlanner).toBe(false);
    expect(PLANS.free.premiumThemes).toBe(false);
  });

  it("free generation caps never exceed premium caps", () => {
    expect(PLANS.free.maxQuizQuestions).toBeLessThanOrEqual(
      PLANS.premium.maxQuizQuestions,
    );
    expect(PLANS.free.maxFlashcardsPerGeneration).toBeLessThanOrEqual(
      PLANS.premium.maxFlashcardsPerGeneration,
    );
    expect(PLANS.free.maxInputTokensPerGeneration).toBeLessThanOrEqual(
      PLANS.premium.maxInputTokensPerGeneration,
    );
  });

  it("pricing matches the approved numbers", () => {
    expect(PRICING.monthlyUsd).toBe(4.99);
    expect(PRICING.yearlyUsd).toBe(39.99);
    // Yearly must actually be cheaper than 12 × monthly.
    expect(PRICING.yearlyUsd).toBeLessThan(PRICING.monthlyUsd * 12);
  });

  it("maps subscription status to a plan", () => {
    expect(getPlan(true)).toBe("premium");
    expect(getPlan(false)).toBe("free");
    expect(getLimits("free")).toBe(PLANS.free);
    expect(getLimits("premium")).toBe(PLANS.premium);
  });
});
