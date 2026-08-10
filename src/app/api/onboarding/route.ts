import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";
import { completeOnboarding } from "@/lib/onboarding";

/** GET /api/onboarding — current onboarding state for session restore. */
export async function GET() {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const db = getDb();
  const userId = session.user.id;
  const [profile, subjects, exams] = await Promise.all([
    db.query.profiles.findFirst({ where: eq(schema.profiles.userId, userId) }),
    db.query.subjects.findMany({
      where: eq(schema.subjects.userId, userId),
      orderBy: (s, { asc }) => [asc(s.createdAt)],
    }),
    db.query.exams.findMany({
      where: eq(schema.exams.userId, userId),
      orderBy: (e, { asc }) => [asc(e.examDate)],
    }),
  ]);

  return NextResponse.json({
    onboardingCompleted: profile?.onboardingCompleted ?? false,
    profile: {
      course: profile?.course ?? null,
      educationLevel: profile?.educationLevel ?? null,
      goal: profile?.goal ?? null,
      dailyStudyMinutes: profile?.dailyStudyMinutes ?? 30,
      timezone: profile?.timezone ?? null,
    },
    subjects: subjects.map((s) => ({ id: s.id, name: s.name })),
    exams: exams.map((e) => ({
      id: e.id,
      title: e.title,
      date: e.examDate.toISOString(),
    })),
  });
}

/** POST /api/onboarding — complete onboarding (idempotent). */
export async function POST(request: Request) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const body = (await request.json().catch(() => null)) as unknown;
  const result = await completeOnboarding(session.user.id, body);
  if ("error" in result) {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
  return NextResponse.json({ ok: true }, { status: 200 });
}
