// ─────────────────────────────────────────────────────────────────────
// User AI preferences — response style, study level, and language.
//
// Stored server-side on the user's profile (never on the device) and
// injected into EVERY generation as a system-prompt directive, so the
// app's only AI surface is product-level preferences. There is no
// provider, key, model, or endpoint configuration anywhere near this.
//
// The directive is cached in-process (short TTL) so a per-call DB read
// never taxes a hot chat path; PUT invalidates the entry immediately.
// ─────────────────────────────────────────────────────────────────────
import { eq } from "drizzle-orm";

import { getDb, schema } from "@/db";

export const RESPONSE_STYLES = ["concise", "balanced", "detailed"] as const;
export const STUDY_LEVELS = ["school", "university", "professional"] as const;

export type AiResponseStyle = (typeof RESPONSE_STYLES)[number];
export type AiStudyLevel = (typeof STUDY_LEVELS)[number];

export interface AiPreferences {
  responseStyle: AiResponseStyle;
  studyLevel: AiStudyLevel;
  language: string;
}

export const DEFAULT_PREFERENCES: AiPreferences = {
  responseStyle: "balanced",
  studyLevel: "university",
  language: "English",
};

export function isResponseStyle(v: unknown): v is AiResponseStyle {
  return typeof v === "string" && (RESPONSE_STYLES as readonly string[]).includes(v);
}

export function isStudyLevel(v: unknown): v is AiStudyLevel {
  return typeof v === "string" && (STUDY_LEVELS as readonly string[]).includes(v);
}

// Map the onboarding education level onto the three study levels, used
// only as the DEFAULT when the user hasn't set an explicit AI level.
function defaultStudyLevel(educationLevel: string | null | undefined): AiStudyLevel {
  switch (educationLevel) {
    case "high-school":
      return "school";
    case "undergraduate":
    case "postgraduate":
      return "university";
    case "professional":
      return "professional";
    default:
      return "university";
  }
}

const CACHE_TTL_MS = 60_000;
const cache = new Map<string, { prefs: AiPreferences; expiresAt: number }>();

/** The user's AI preferences, with sensible defaults when unset. */
export async function loadAiPreferences(
  userId: string,
  now = Date.now(),
): Promise<AiPreferences> {
  const cached = cache.get(userId);
  if (cached && cached.expiresAt > now) return cached.prefs;

  // Preferences are an enhancement — a DB hiccup must never break a
  // generation, so any failure falls back to the defaults.
  let profile: (typeof schema.profiles.$inferSelect) | undefined;
  try {
    const db = getDb();
    profile = await db.query.profiles.findFirst({
      where: eq(schema.profiles.userId, userId),
    });
  } catch {
    profile = undefined;
  }

  const prefs: AiPreferences = {
    responseStyle: isResponseStyle(profile?.aiResponseStyle)
      ? profile!.aiResponseStyle
      : DEFAULT_PREFERENCES.responseStyle,
    studyLevel: isStudyLevel(profile?.aiStudyLevel)
      ? profile!.aiStudyLevel
      : defaultStudyLevel(profile?.educationLevel ?? null),
    language:
      profile?.aiLanguage && profile.aiLanguage.trim().length > 0
        ? profile.aiLanguage.trim()
        : DEFAULT_PREFERENCES.language,
  };
  cache.set(userId, { prefs, expiresAt: now + CACHE_TTL_MS });
  return prefs;
}

/** Persist the user's AI preferences and drop the stale cache entry. */
export async function saveAiPreferences(
  userId: string,
  prefs: AiPreferences,
): Promise<void> {
  const db = getDb();
  await db
    .insert(schema.profiles)
    .values({
      userId,
      aiResponseStyle: prefs.responseStyle,
      aiStudyLevel: prefs.studyLevel,
      aiLanguage: prefs.language,
    })
    .onConflictDoUpdate({
      target: schema.profiles.userId,
      set: {
        aiResponseStyle: prefs.responseStyle,
        aiStudyLevel: prefs.studyLevel,
        aiLanguage: prefs.language,
      },
    });
  cache.delete(userId);
}

/** Clear the per-user cache entry (tests, or after external updates). */
export function invalidateAiPreferencesCache(userId: string): void {
  cache.delete(userId);
}

export function resetAiPreferencesCache(): void {
  cache.clear();
}

const STYLE_DIRECTIVE: Record<AiResponseStyle, string> = {
  concise: "Be concise: short, tight answers that skip filler and keep every key point.",
  balanced: "Be balanced: clear and complete, without padding.",
  detailed: "Be detailed: thorough answers with examples, reasoning, and nuance.",
};

const LEVEL_DIRECTIVE: Record<AiStudyLevel, string> = {
  school: "Address a school student: plain language, build intuition first, avoid jargon.",
  university: "Address a university student: precise terminology and full technical depth.",
  professional: "Address a professional: assume working knowledge, focus on practice and edge cases.",
};

/**
 * The system-prompt directive that shapes every generation. Returns ""
 * when the user has the defaults, so default-generation prompts stay
 * byte-identical to before (cache keys and goldens don't shift).
 */
export function aiPreferenceDirective(prefs: AiPreferences): string {
  const style = STYLE_DIRECTIVE[prefs.responseStyle];
  const level = LEVEL_DIRECTIVE[prefs.studyLevel];
  if (
    prefs.responseStyle === DEFAULT_PREFERENCES.responseStyle &&
    prefs.studyLevel === DEFAULT_PREFERENCES.studyLevel &&
    prefs.language === DEFAULT_PREFERENCES.language
  ) {
    return "";
  }
  const parts = [style, level, `Respond in ${prefs.language}.`];
  return `User preferences:\n${parts.join("\n")}`;
}

/**
 * Append the preference directive to a system prompt. `userId` absent or
 * defaults → the prompt is returned unchanged.
 */
export async function systemWithPreferences(
  system: string | undefined,
  userId: string | undefined,
): Promise<string | undefined> {
  if (!userId) return system;
  const directive = aiPreferenceDirective(await loadAiPreferences(userId));
  if (directive.length === 0) return system;
  const base = system?.trim() ?? "";
  return base.length > 0 ? `${base}\n\n${directive}` : directive;
}

/**
 * A short fingerprint of the user's preferences for AI-response cache
 * keys: when preferences change, cached answers are bypassed so the new
 * style/level/language actually shapes the next generation.
 */
export async function preferenceCacheSalt(userId: string): Promise<string> {
  const prefs = await loadAiPreferences(userId);
  return `${prefs.responseStyle}|${prefs.studyLevel}|${prefs.language}`;
}
