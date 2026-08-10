import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";
import { getPlanForSession } from "@/lib/premium";
import { updateProfile } from "@/lib/profile";

/** GET /api/profile — user identity, profile preferences, and plan. */
export async function GET() {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const db = getDb();
  const [profile, plan] = await Promise.all([
    db.query.profiles.findFirst({
      where: eq(schema.profiles.userId, session.user.id),
    }),
    getPlanForSession(),
  ]);

  return NextResponse.json({
    user: { id: session.user.id, name: session.user.name, email: session.user.email },
    plan: plan?.plan ?? "free",
    profile: {
      course: profile?.course ?? null,
      educationLevel: profile?.educationLevel ?? null,
      goal: profile?.goal ?? null,
      dailyStudyMinutes: profile?.dailyStudyMinutes ?? 30,
      timezone: profile?.timezone ?? null,
      onboardingCompleted: profile?.onboardingCompleted ?? false,
      studyStreak: profile?.studyStreak ?? 0,
    },
  });
}

/** PUT /api/profile — update display name and study preferences. */
export async function PUT(request: Request) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const body = (await request.json().catch(() => null)) as unknown;
  const result = await updateProfile(session.user.id, request.headers, body);
  if ("error" in result) {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
  return NextResponse.json({ ok: true });
}
