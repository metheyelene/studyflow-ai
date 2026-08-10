import { describe, expect, it } from "vitest";

import { cacheKey } from "./cache";

const BASE = {
  userId: "u1",
  notebookId: "nb1",
  sourceIds: ["s1", "s2"],
  sourceVersions: { s1: 1, s2: 1 },
  question: "What is photosynthesis?",
  mode: "sources",
  feature: "qa",
  model: "gpt-4o-mini",
};

describe("cacheKey", () => {
  it("is stable for identical inputs", () => {
    expect(cacheKey(BASE)).toBe(cacheKey(BASE));
  });

  it("changes when a source version changes (source replacement invalidates)", () => {
    expect(cacheKey({ ...BASE, sourceVersions: { s1: 2, s2: 1 } })).not.toBe(cacheKey(BASE));
  });

  it("changes when the question changes", () => {
    expect(cacheKey({ ...BASE, question: "Explain the Calvin cycle" })).not.toBe(cacheKey(BASE));
  });

  it("changes when the mode or model changes", () => {
    expect(cacheKey({ ...BASE, mode: "study" })).not.toBe(cacheKey(BASE));
    expect(cacheKey({ ...BASE, model: "gpt-4o" })).not.toBe(cacheKey(BASE));
  });

  it("is order-insensitive to sourceIds and versions", () => {
    const shuffled = cacheKey({
      ...BASE,
      sourceIds: ["s2", "s1"],
      sourceVersions: { s2: 1, s1: 1 },
    });
    expect(shuffled).toBe(cacheKey(BASE));
  });

  it("is case-insensitive to the question", () => {
    expect(cacheKey({ ...BASE, question: "what is PHOTOSYNTHESIS?" })).toBe(cacheKey(BASE));
  });
});
