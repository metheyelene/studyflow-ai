"use server";

import { headers } from "next/headers";
import { z } from "zod";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";

export const GOAL_OPTIONS = [
  { value: "summaries", label: "AI summaries" },
  { value: "flashcards", label: "Flashcards" },
  { value: "quizzes", label: "Quizzes" },
  { value: "study planning", label: "Study planning" },
  { value: "staying motivated", label: "Staying motivated" },
] as const;

const GOAL_VALUES = GOAL_OPTIONS.map((g) => g.value);

const onboardingSchema = z.object({
  course: z.string().trim().min(2).max(100),
  subjects: z.string().trim().min(1).max(200),
  exams: z
    .array(
      z.object({
        name: z.string().trim().max(100),
        date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      }),
    )
    .max(3),
  dailyMinutes: z.coerce.number().int().min(5).max(480),
  goals: z.array(z.enum(GOAL_VALUES)).min(1).max(5),
});

export type OnboardingResult = { error: string } | { ok: true };

export async function completeOnboarding(
  input: unknown,
): Promise<OnboardingResult> {
  try {
    const session = await auth.api.getSession({ headers: await headers() });
    if (!session) {
      return { error: "Your session expired. Please log in again." };
    }

    const parsed = onboardingSchema.safeParse(input);
    if (!parsed.success) {
      return { error: "Please fill in every field to continue." };
    }

    const { course, subjects, exams, dailyMinutes, goals } = parsed.data;
    const db = getDb();
    const userId = session.user.id;
    const goalText = goals.join(", ");

    // Profile (upsert — safe to run onboarding again).
    await db
      .insert(schema.profiles)
      .values({
        userId,
        course,
        goal: goalText,
        dailyStudyMinutes: dailyMinutes,
        onboardingCompleted: true,
      })
      .onConflictDoUpdate({
        target: schema.profiles.userId,
        set: {
          course,
          goal: goalText,
          dailyStudyMinutes: dailyMinutes,
          onboardingCompleted: true,
        },
      });

    // Subjects from the comma-separated input (up to 5).
    const subjectNames = subjects
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean)
      .slice(0, 5);
    for (const name of subjectNames) {
      await db
        .insert(schema.subjects)
        .values({ userId, name })
        .onConflictDoNothing();
    }

    // Exams (up to 3).
    for (const exam of exams) {
      if (!exam.date) continue;
      await db.insert(schema.exams).values({
        userId,
        title: exam.name.trim() || course || "Exam",
        examDate: new Date(`${exam.date}T00:00:00Z`),
      });
    }

    // Analytics — privacy-conscious: event + goal tags, nothing more.
    await db.insert(schema.analyticsEvents).values({
      userId,
      eventName: "onboarding_completed",
      properties: { goals },
    });

    return { ok: true };
  } catch {
    return {
      error: "Something went wrong saving your details. Please try again.",
    };
  }
}
