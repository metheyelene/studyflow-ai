import { beforeEach, describe, expect, it, vi } from "vitest";

const findFirst = vi.fn();
const onConflictDoUpdate = vi.fn();
const values = vi.fn(() => ({ onConflictDoUpdate }));
const insert = vi.fn(() => ({ values }));

vi.mock("@/db", () => ({
  getDb: () => ({ query: { profiles: { findFirst } }, insert }),
  schema: { profiles: { userId: "user_id" } },
}));

import {
  aiPreferenceDirective,
  loadAiPreferences,
  preferenceCacheSalt,
  resetAiPreferencesCache,
  saveAiPreferences,
} from "@/lib/ai/preferences";

describe("aiPreferenceDirective", () => {
  it("is empty for the defaults, so default generations stay byte-identical", () => {
    expect(
      aiPreferenceDirective({
        responseStyle: "balanced",
        studyLevel: "university",
        language: "English",
      }),
    ).toBe("");
  });

  it("states the style, level, and language when customized", () => {
    const directive = aiPreferenceDirective({
      responseStyle: "concise",
      studyLevel: "school",
      language: "Spanish",
    });
    expect(directive).toContain("concise");
    expect(directive).toContain("school");
    expect(directive).toContain("Respond in Spanish.");
  });
});

describe("loadAiPreferences", () => {
  beforeEach(() => {
    resetAiPreferencesCache();
    vi.clearAllMocks();
    findFirst.mockReset();
  });

  it("returns the defaults when no profile row exists", async () => {
    findFirst.mockResolvedValue(null);
    const prefs = await loadAiPreferences("u1", 1_000);
    expect(prefs).toEqual({
      responseStyle: "balanced",
      studyLevel: "university",
      language: "English",
    });
  });

  it("maps the onboarding education level onto the study-level default", async () => {
    findFirst.mockResolvedValue({
      aiResponseStyle: null,
      aiStudyLevel: null,
      aiLanguage: null,
      educationLevel: "high-school",
    });
    expect((await loadAiPreferences("u1", 1_000)).studyLevel).toBe("school");

    findFirst.mockResolvedValue({
      aiResponseStyle: null,
      aiStudyLevel: null,
      aiLanguage: null,
      educationLevel: "professional",
    });
    resetAiPreferencesCache();
    expect((await loadAiPreferences("u1", 1_000)).studyLevel).toBe("professional");
  });

  it("prefers an explicit AI level over the education level", async () => {
    findFirst.mockResolvedValue({
      aiResponseStyle: "detailed",
      aiStudyLevel: "school",
      aiLanguage: "Hindi",
      educationLevel: "professional",
    });
    const prefs = await loadAiPreferences("u1", 1_000);
    expect(prefs).toEqual({
      responseStyle: "detailed",
      studyLevel: "school",
      language: "Hindi",
    });
  });

  it("caches per user inside the TTL window", async () => {
    findFirst.mockResolvedValue({
      aiResponseStyle: null,
      aiStudyLevel: null,
      aiLanguage: null,
      educationLevel: null,
    });
    await loadAiPreferences("u1", 1_000);
    await loadAiPreferences("u1", 2_000);
    expect(findFirst).toHaveBeenCalledTimes(1);
  });

  it("save persists the preferences and invalidates the cache", async () => {
    findFirst.mockResolvedValue({
      aiResponseStyle: "balanced",
      aiStudyLevel: "university",
      aiLanguage: "English",
      educationLevel: null,
    });
    await loadAiPreferences("u1", 1_000);
    expect(findFirst).toHaveBeenCalledTimes(1);

    onConflictDoUpdate.mockResolvedValue(undefined);
    await saveAiPreferences("u1", {
      responseStyle: "concise",
      studyLevel: "professional",
      language: "French",
    });

    // Cache invalidated → the next load re-queries and sees the new row.
    findFirst.mockResolvedValue({
      aiResponseStyle: "concise",
      aiStudyLevel: "professional",
      aiLanguage: "French",
      educationLevel: null,
    });
    const prefs = await loadAiPreferences("u1", 1_000);
    expect(prefs).toEqual({
      responseStyle: "concise",
      studyLevel: "professional",
      language: "French",
    });
    expect(findFirst).toHaveBeenCalledTimes(2);
  });

  it("preferenceCacheSalt fingerprints the current preferences", async () => {
    findFirst.mockResolvedValue({
      aiResponseStyle: "concise",
      aiStudyLevel: "school",
      aiLanguage: "Hindi",
      educationLevel: null,
    });
    expect(await preferenceCacheSalt("u1")).toBe("concise|school|Hindi");
  });
});
