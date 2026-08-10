// ─────────────────────────────────────────────────────────────────────
// Shared profile logic. Used by the settings server action and the
// mobile REST route (GET/PUT /api/profile) so both validate and persist
// exactly the same way.
// ─────────────────────────────────────────────────────────────────────
import { z } from "zod";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";

export const EDUCATION_LEVELS = [
  { value: "high-school", label: "High school" },
  { value: "undergraduate", label: "Undergraduate" },
  { value: "postgraduate", label: "Postgraduate" },
  { value: "professional", label: "Professional / working" },
  { value: "other", label: "Other" },
] as const;

export const profileSchema = z.object({
  name: z.string().trim().min(1, "Your name can't be empty.").max(100),
  educationLevel: z
    .enum(["high-school", "undergraduate", "postgraduate", "professional", "other"])
    .nullable()
    .optional(),
  course: z.string().trim().max(120).nullable().optional(),
  dailyStudyMinutes: z.coerce
    .number()
    .int()
    .min(5, "Minimum 5 minutes a day.")
    .max(480, "That's a lot — max 480 minutes."),
  timezone: z.string().trim().max(64).nullable().optional(),
  goal: z.string().trim().max(200).nullable().optional(),
});

export type ProfileResult = { error: string } | { ok: true };

/**
 * Update the display name (better-auth user) and profile preferences.
 * `requestHeaders` must carry the session cookie so better-auth can
 * verify the updateUser call. Idempotent profile upsert.
 */
export async function updateProfile(
  userId: string,
  requestHeaders: Headers,
  input: unknown,
): Promise<ProfileResult> {
  const parsed = profileSchema.safeParse(input);
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "Check your inputs." };
  }

  const db = getDb();
  try {
    await auth.api.updateUser({
      headers: requestHeaders,
      body: { name: parsed.data.name },
    });

    const values = {
      educationLevel: parsed.data.educationLevel ?? null,
      course: parsed.data.course ?? null,
      dailyStudyMinutes: parsed.data.dailyStudyMinutes,
      timezone: parsed.data.timezone ?? null,
      goal: parsed.data.goal ?? null,
    };

    await db
      .insert(schema.profiles)
      .values({ userId, ...values })
      .onConflictDoUpdate({
        target: schema.profiles.userId,
        set: values,
      });

    return { ok: true };
  } catch (err) {
    console.error("[profile] update failed:", err);
    return { error: "We couldn't save your profile. Please try again." };
  }
}
