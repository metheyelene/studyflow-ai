import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";
import { TASK_STATUSES, type PlanTaskStatus, type StudyPlanJson } from "@/lib/study/planner";

export const runtime = "nodejs";

/**
 * PATCH /api/study-plans/[planId] — set one task's status
 * (pending | done | skipped). The full updated plan is returned so the
 * client can reconcile in one round-trip.
 */
export async function PATCH(request: Request, { params }: { params: Promise<{ planId: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { planId } = await params;
  const db = getDb();
  const plan = await db.query.studyPlans.findFirst({
    where: and(eq(schema.studyPlans.id, planId), eq(schema.studyPlans.userId, session.user.id)),
  });
  if (!plan) return NextResponse.json({ error: "Plan not found." }, { status: 404 });

  const body = (await request.json().catch(() => null)) as { taskId?: string; status?: string } | null;
  const taskId = body?.taskId;
  const status = body?.status as PlanTaskStatus | undefined;
  if (!taskId || typeof taskId !== "string" || !status || !TASK_STATUSES.includes(status)) {
    return NextResponse.json({ error: "A valid task id and status are required." }, { status: 400 });
  }

  const planJson = plan.planJson as StudyPlanJson;
  const task = planJson.tasks.find((t) => t.id === taskId);
  if (!task) return NextResponse.json({ error: "Task not found in this plan." }, { status: 404 });

  task.status = status;
  const [updated] = await db
    .update(schema.studyPlans)
    .set({ planJson })
    .where(eq(schema.studyPlans.id, planId))
    .returning();

  return NextResponse.json({ plan: updated.planJson as StudyPlanJson });
}
