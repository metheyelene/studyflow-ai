"use server";

import { headers } from "next/headers";
import { eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";
import {
  EDUCATION_LEVELS,
  updateProfile as updateProfileShared,
} from "@/lib/profile";

export { EDUCATION_LEVELS };

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

  const result = await updateProfileShared(session.user.id, await headers(), {
    name: formData.get("name"),
    educationLevel: formData.get("educationLevel") || null,
    course: formData.get("course") || null,
    dailyStudyMinutes: formData.get("dailyStudyMinutes"),
    timezone: formData.get("timezone") || null,
    goal: formData.get("goal") || null,
  });

  if ("error" in result) return { error: result.error };
  return { ok: true };
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
