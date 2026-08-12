// ─────────────────────────────────────────────────────────────────────
// Adaptive daily study planner (deterministic — no AI calls, so the
// planner itself costs nothing).
//
// Given an exam date, builds a day-by-day task plan between today and
// the exam. Cadence adapts to how much time is left:
//   ≤ 1 day   → a focused revision session for the day
//   ≤ 3 days  → revision cycle (core → practice → mock → mistakes)
//   ≤ 14 days → foundation days, then a 3-day revision sprint
//   > 14 days → a long-form rotation with a final revision week
//
// Regeneration is adaptive: when a plan is generated again (the user
// fell behind, or wants a fresh schedule), already-completed tasks are
// preserved by (date, title), the rest are rebuilt from today, and the
// plan version increments.
// ─────────────────────────────────────────────────────────────────────
export type PlanTaskStatus = "pending" | "done" | "skipped";

export interface PlanTask {
  /** Stable within a generation — used by PATCH to flip status. */
  id: string;
  /** yyyy-MM-dd (UTC) — which day this task belongs to. */
  date: string;
  title: string;
  detail: string;
  durationMin: number;
  status: PlanTaskStatus;
}

export interface StudyPlanJson {
  version: number;
  /** yyyy-MM-dd of the day the plan was (re)generated. */
  generatedForDate: string;
  /**
   * yyyy-MM-dd exam date this plan was generated against. Present on
   * plans written after this field was added; legacy plans omit it.
   * When it differs from the exam's current date, the exam moved and
   * the plan is stale.
   */
  examDate?: string;
  tasks: PlanTask[];
}

export const TASK_STATUSES: PlanTaskStatus[] = ["pending", "done", "skipped"];

interface TaskTemplate {
  title: string;
  detail: string;
  durationMin: number;
}

/** Foundation rotation for longer horizons (honest, syllabus-agnostic). */
const FOCUS_TASKS: TaskTemplate[] = [
  {
    title: "Review core concepts",
    detail: "Work through your notes, summary, or study guide for this unit's main ideas.",
    durationMin: 45,
  },
  {
    title: "Practice problems",
    detail: "Solve problems from your material and check each answer against the source.",
    durationMin: 40,
  },
  {
    title: "Active recall session",
    detail: "Close your notes and recall definitions, formulas, and key facts — then check what you missed.",
    durationMin: 25,
  },
  {
    title: "Quiz yourself",
    detail: "Generate flashcards or take a quiz from this unit, and review what you get wrong.",
    durationMin: 30,
  },
  {
    title: "Summarize the unit",
    detail: "Write a short summary of what you learned and note anything still unclear.",
    durationMin: 20,
  },
];

/** Revision sprint for the final stretch. */
const REVISION_TASKS: TaskTemplate[] = [
  {
    title: "Final revision of key concepts",
    detail: "Rapidly review the most important ideas and definitions from the whole subject.",
    durationMin: 40,
  },
  {
    title: "Practice questions",
    detail: "Work through exam-style questions under light time pressure.",
    durationMin: 30,
  },
  {
    title: "Mock exam (timed)",
    detail: "Attempt a full set of questions under exam conditions — no notes.",
    durationMin: 50,
  },
  {
    title: "Review mistakes",
    detail: "Re-read your quiz and practice mistakes; redo the ones you got wrong.",
    durationMin: 25,
  },
];

/** yyyy-MM-dd for a Date, using its UTC calendar day. */
export function dateKey(d: Date): string {
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}-${String(d.getUTCDate()).padStart(2, "0")}`;
}

export function parseDateKey(key: string): Date {
  const [y, m, d] = key.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d));
}

/** Whole days from `from` (UTC) to `to` (UTC): 0 if same day. */
export function daysBetween(from: Date, to: Date): number {
  const a = Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), from.getUTCDate());
  const b = Date.UTC(to.getUTCFullYear(), to.getUTCMonth(), to.getUTCDate());
  return Math.round((b - a) / 86_400_000);
}

function dayTasks(date: string, templates: TaskTemplate[], offset: number, count: number): PlanTask[] {
  const out: PlanTask[] = [];
  for (let i = 0; i < count; i++) {
    const t = templates[(offset + i) % templates.length];
    out.push({
      id: `${date}-${i}`,
      date,
      title: t.title,
      detail: t.detail,
      durationMin: t.durationMin,
      status: "pending",
    });
  }
  return out;
}

/**
 * Build the plan. Throws if the exam is today or already passed — there
 * is nothing left to schedule honestly.
 */
export function generateDailyPlan(examDate: Date, now: Date = new Date()): StudyPlanJson {
  const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const days = daysBetween(today, examDate);
  if (days <= 0) {
    throw new Error("This exam is today or already passed — nothing left to schedule.");
  }

  const todayKey = dateKey(today);
  const tasks: PlanTask[] = [];

  if (days === 1) {
    // One day left: a single focused revision session.
    tasks.push(
      { id: `${todayKey}-0`, date: todayKey, title: "Final revision of key concepts", detail: "Rapidly review the most important ideas and definitions.", durationMin: 40, status: "pending" },
      { id: `${todayKey}-1`, date: todayKey, title: "Practice questions", detail: "Work through exam-style questions under light time pressure.", durationMin: 30, status: "pending" },
      { id: `${todayKey}-2`, date: todayKey, title: "Review mistakes", detail: "Re-read your quiz and practice mistakes from this subject.", durationMin: 20, status: "pending" },
    );
    return { version: 1, generatedForDate: todayKey, examDate: dateKey(examDate), tasks };
  }

  if (days <= 3) {
    // Sprint: two revision tasks per day, rotating.
    for (let i = 0; i < days; i++) {
      const date = dateKey(new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() + i)));
      tasks.push(...dayTasks(date, REVISION_TASKS, i * 2, 2));
    }
    return { version: 1, generatedForDate: todayKey, examDate: dateKey(examDate), tasks };
  }

  if (days <= 14) {
    // Foundation days, then a 3-day revision sprint.
    const sprint = 3;
    const foundation = days - sprint;
    for (let i = 0; i < foundation; i++) {
      const date = dateKey(new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() + i)));
      // Two tasks per foundation day: one focus task + one practice/recall.
      const focus = FOCUS_TASKS[i % FOCUS_TASKS.length];
      const practice = FOCUS_TASKS[(i + 1) % FOCUS_TASKS.length];
      tasks.push(
        { id: `${date}-0`, date, title: focus.title, detail: focus.detail, durationMin: focus.durationMin, status: "pending" },
        { id: `${date}-1`, date, title: practice.title, detail: practice.detail, durationMin: practice.durationMin, status: "pending" },
      );
    }
    for (let i = 0; i < sprint; i++) {
      const date = dateKey(new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() + foundation + i)));
      tasks.push(...dayTasks(date, REVISION_TASKS, i * 2, 2));
    }
    return { version: 1, generatedForDate: todayKey, examDate: dateKey(examDate), tasks };
  }

  // Long horizon: rotation through the focus cycle, then a final week.
  const finalWeek = 7;
  const main = days - finalWeek;
  for (let i = 0; i < main; i++) {
    const date = dateKey(new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() + i)));
    const focus = FOCUS_TASKS[i % FOCUS_TASKS.length];
    const recall = FOCUS_TASKS[(i + 2) % FOCUS_TASKS.length];
    tasks.push(
      { id: `${date}-0`, date, title: focus.title, detail: focus.detail, durationMin: focus.durationMin, status: "pending" },
      { id: `${date}-1`, date, title: recall.title, detail: recall.detail, durationMin: recall.durationMin, status: "pending" },
    );
  }
  for (let i = 0; i < finalWeek; i++) {
    const date = dateKey(new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() + main + i)));
    const t = REVISION_TASKS[i % REVISION_TASKS.length];
    tasks.push(
      { id: `${date}-0`, date, title: t.title, detail: t.detail, durationMin: t.durationMin, status: "pending" },
    );
  }
  return { version: 1, generatedForDate: todayKey, examDate: dateKey(examDate), tasks };
}

/**
 * A plan is stale when it no longer covers the current window:
 *   - it was generated on an earlier day (today's tasks are missing), or
 *   - the exam date moved after the plan was generated (the stamped
 *     examDate differs from the exam's current date).
 * Plans without an examDate stamp (written before the field existed) are
 * judged only by the generation date; they get stamped on their next
 * regeneration.
 */
export function isPlanStale(plan: StudyPlanJson, examDate: Date, now: Date = new Date()): boolean {
  if (plan.generatedForDate < dateKey(now)) return true;
  if (plan.examDate && plan.examDate !== dateKey(examDate)) return true;
  return false;
}

/**
 * Adaptive regeneration: rebuild from today, but keep tasks the user
 * already completed (matched by date + title). Version increments so the
 * client can show "Plan v2" and stale screens can refresh.
 */
export function regeneratePlan(previous: StudyPlanJson, examDate: Date, now: Date = new Date()): StudyPlanJson {
  const fresh = generateDailyPlan(examDate, now);
  const done = new Set(
    previous.tasks.filter((t) => t.status === "done").map((t) => `${t.date}|${t.title}`),
  );
  if (done.size > 0) {
    for (const task of fresh.tasks) {
      if (done.has(`${task.date}|${task.title}`)) task.status = "done";
    }
  }
  return { ...fresh, version: previous.version + 1 };
}
