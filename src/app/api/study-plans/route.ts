import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";
import {
  daysBetween,
  generateDailyPlan,
  isPlanStale,
  regeneratePlan,
  type StudyPlanJson,
} from "@/lib/study/planner";

export const runtime = "nodejs";

/** API shape: plan + the exam it belongs to. */
function planJson(
  plan: typeof schema.studyPlans.$inferSelect,
  exam: { id: string; title: string; examDate: Date } | null,
) {
  const body = plan.planJson as StudyPlanJson;
  return {
    id: plan.id,
    examId: plan.examId,
    examTitle: exam?.title ?? "Exam",
    examDate: exam ? exam.examDate.toISOString() : null,
    version: body.version,
    generatedForDate: body.generatedForDate,
    tasks: body.tasks,
    createdAt: plan.createdAt.toISOString(),
  };
}

/**
 * GET /api/study-plans — the user's plans, nearest exam first.
 *
 * Plans are lazily refreshed on read: when a plan is stale (generated on
 * an earlier day, or the exam date moved after generation), it is
 * regenerated from today — preserving already-completed tasks — before
 * being returned. This keeps the plan authoritative on every load (the
 * Study tab fetches here) without a separate cron. Plans for exams that
 * are today or already passed are left untouched: there is nothing left
 * to schedule honestly.
 */
export async function GET() {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  try {
    const db = getDb();
    const plans = await db.query.studyPlans.findMany({
      where: eq(schema.studyPlans.userId, session.user.id),
      orderBy: (p, { desc }) => [desc(p.createdAt)],
    });
    const exams = plans.length
      ? await db.query.exams.findMany({
          where: eq(schema.exams.userId, session.user.id),
        })
      : [];
    const examById = new Map(exams.map((e) => [e.id, e]));

    const now = new Date();
    const refreshed: Array<(typeof plans)[number]> = [];

    for (const plan of plans) {
      const exam = plan.examId ? (examById.get(plan.examId) ?? null) : null;
      let body = plan.planJson as StudyPlanJson;

      if (
        exam &&
        isPlanStale(body, exam.examDate, now) &&
        daysBetween(now, exam.examDate) > 0
      ) {
        try {
          const fresh = regeneratePlan(body, exam.examDate, now);
          const [updated] = await db
            .update(schema.studyPlans)
            .set({ planJson: fresh, version: fresh.version })
            .where(eq(schema.studyPlans.id, plan.id))
            .returning();
          if (updated) body = updated.planJson as StudyPlanJson;
        } catch (err) {
          // Keep the stored plan on any regeneration failure — the read
          // path must never error the whole list for one stale plan.
          console.warn("[study-plans:auto-regenerate]", err);
        }
      }
      refreshed.push({ ...plan, planJson: body });
    }

    return NextResponse.json({
      plans: refreshed.map((p) => planJson(p, p.examId ? (examById.get(p.examId) ?? null) : null)),
    });
  } catch (err) {
    console.error("[study-plans:list]", err);
    return NextResponse.json({ error: "Failed to load your study plans." }, { status: 500 });
  }
}

/**
 * POST /api/study-plans — generate (or adaptively regenerate) a daily
 * plan for an exam. Regenerating preserves already-completed tasks and
 * bumps the plan version.
 */
export async function POST(request: Request) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const body = (await request.json().catch(() => null)) as { examId?: string } | null;
  const examId = body?.examId;
  if (!examId || typeof examId !== "string") {
    return NextResponse.json({ error: "Pick an exam to plan." }, { status: 400 });
  }

  const db = getDb();
  const exam = await db.query.exams.findFirst({
    where: eq(schema.exams.id, examId),
  });
  if (!exam || exam.userId !== session.user.id) {
    return NextResponse.json({ error: "Exam not found." }, { status: 404 });
  }

  const existing = await db.query.studyPlans.findFirst({
    where: eq(schema.studyPlans.examId, examId),
  });

  let bodyJson: StudyPlanJson;
  try {
    bodyJson = existing
      ? regeneratePlan(existing.planJson as StudyPlanJson, exam.examDate)
      : generateDailyPlan(exam.examDate);
  } catch (err) {
    if (err instanceof Error && /today or already passed/i.test(err.message)) {
      return NextResponse.json({ error: err.message }, { status: 422 });
    }
    console.error("[study-plans:generate]", err);
    return NextResponse.json({ error: "Could not build that plan." }, { status: 500 });
  }

  let plan;
  if (existing) {
    [plan] = await db
      .update(schema.studyPlans)
      .set({ planJson: bodyJson })
      .where(eq(schema.studyPlans.id, existing.id))
      .returning();
  } else {
    [plan] = await db
      .insert(schema.studyPlans)
      .values({
        userId: session.user.id,
        examId,
        planJson: bodyJson,
        version: bodyJson.version,
      })
      .returning();
  }

  return NextResponse.json(
    { plan: planJson(plan, { id: exam.id, title: exam.title, examDate: exam.examDate }) },
    { status: 201 },
  );
}
