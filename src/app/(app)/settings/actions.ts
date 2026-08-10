"use server";

import { headers } from "next/headers";
import { eq } from "drizzle-orm";
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

const profileSchema = z.object({
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

export type ProfileFormState = {
  ok?: boolean;
  error?: string;
};

export async function updateProfileAction(
  _prev: ProfileFormState,
  formData: FormData,
): Promise<ProfileFormState> {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return { error: "Your session expired. Please log in again." };

  const parsed = profileSchema.safeParse({
    name: formData.get("name"),
    educationLevel: formData.get("educationLevel") || null,
    course: formData.get("course") || null,
    dailyStudyMinutes: formData.get("dailyStudyMinutes"),
    timezone: formData.get("timezone") || null,
    goal: formData.get("goal") || null,
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "Check your inputs." };
  }

  const db = getDb();
  try {
    await auth.api.updateUser({
      headers: await headers(),
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
      .values({ userId: session.user.id, ...values })
      .onConflictDoUpdate({
        target: schema.profiles.userId,
        set: values,
      });

    return { ok: true };
  } catch (err) {
    console.error("[settings] update profile failed:", err);
    return { error: "We couldn't save your profile. Please try again." };
  }
}

export async function exportDataAction(): Promise<{ ok?: boolean; error?: string; data?: unknown }> {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return { error: "Your session expired. Please log in again." };

  const db = getDb();
  try {
    const userId = session.user.id;
    const [profile, subjects, notes, documents, exams, decks, quizzes, attempts] =
      await Promise.all([
        db.query.profiles.findFirst({ where: eq(schema.profiles.userId, userId) }),
        db.query.subjects.findMany({ where: eq(schema.subjects.userId, userId) }),
        db.query.notes.findMany({ where: eq(schema.notes.userId, userId) }),
        db.query.documents.findMany({ where: eq(schema.documents.userId, userId) }),
        db.query.exams.findMany({ where: eq(schema.exams.userId, userId) }),
        db.query.flashcardDecks.findMany({ where: eq(schema.flashcardDecks.userId, userId) }),
        db.query.quizzes.findMany({ where: eq(schema.quizzes.userId, userId) }),
        db.query.quizAttempts.findMany({ where: eq(schema.quizAttempts.userId, userId) }),
      ]);

    return {
      ok: true,
      data: {
        exportedAt: new Date().toISOString(),
        account: { name: session.user.name, email: session.user.email },
        profile,
        subjects,
        notes,
        documents,
        exams,
        flashcardDecks: decks,
        quizzes,
        quizAttempts: attempts,
      },
    };
  } catch (err) {
    console.error("[settings] export failed:", err);
    return { error: "We couldn't export your data right now." };
  }
}
