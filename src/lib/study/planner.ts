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
  /**
   * Set when the exam's subject has weak recent quiz accuracy — the plan
   * then targets practice at that subject and the UI can explain why.
   */
  focus?: PlanFocus;
  tasks: PlanTask[];
}

/** Weak-subject signal the planner uses to weight tasks. */
export interface WeakSubjectInfo {
  subjectId: string;
  name: string;
  /** 0–100 accuracy across recent completed quiz attempts. */
  accuracy: number;
}

/** What the planner decided to focus on, stamped into the plan JSON. */
export interface PlanFocus {
  subjectId: string;
  subjectName: string;
  /** 0–100 recent quiz accuracy for that subject (weak, by definition). */
  accuracy: number;
}

export interface PlanOptions {
  /** Subjects with weak recent quiz accuracy (from quiz attempts). */
  weakSubjects?: WeakSubjectInfo[];
  /** The exam's subject id, when the exam is subject-linked. */
  subjectId?: string | null;
}

export const TASK_STATUSES: PlanTaskStatus[] = ["pending", "done", "skipped"];

interface TaskTemplate {
  title: string;
  detail: string;
  durationMin: number;
}

/** Foundation rotation used when the exam's subject has weak recent quiz
 *  accuracy — practice is aimed at the weak area instead of generic study.
 *  `{subject}` and `{accuracy}` are filled in at generation time. */
const WEAK_FOCUS_TASKS: TaskTemplate[] = [
  {
    title: "Practice {subject} problems",
    detail: "Your recent quiz accuracy in {subject} is {accuracy}% — work through extra problems and check every answer against the source.",
    durationMin: 45,
  },
  {
    title: "Review {subject} quiz mistakes",
    detail: "Re-read the explanations from your recent {subject} quizzes and redo the questions you got wrong.",
    durationMin: 30,
  },
  {
    title: "Active recall — {subject}",
    detail: "Close your notes and recall the {subject} definitions and formulas you have struggled with, then check what you missed.",
    durationMin: 25,
  },
  {
    title: "Summarize weak areas in {subject}",
    detail: "Write a short summary of the {subject} topics you keep missing in quizzes.",
    durationMin: 20,
  },
];

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

/** Fill the `{subject}`/`{accuracy}` placeholders in a weak-task template. */
function fillTemplate(t: TaskTemplate, name: string, accuracy: number): TaskTemplate {
  const fill = (s: string) =>
    s.split("{subject}").join(name).split("{accuracy}").join(String(accuracy));
  return { title: fill(t.title), detail: fill(t.detail), durationMin: t.durationMin };
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
 *
 * When `opts.subjectId` matches a weak subject in `opts.weakSubjects`
 * (recent quiz accuracy below the threshold), the plan's foundation and
 * revision tasks are retargeted at that subject and `focus` is stamped so
 * the UI can explain why the plan is weighted there.
 */
export function generateDailyPlan(
  examDate: Date,
  now: Date = new Date(),
  opts: PlanOptions = {},
): StudyPlanJson {
  const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const days = daysBetween(today, examDate);
  if (days <= 0) {
    throw new Error("This exam is today or already passed — nothing left to schedule.");
  }

  const todayKey = dateKey(today);
  const weak = opts.subjectId
    ? (opts.weakSubjects?.find((w) => w.subjectId === opts.subjectId) ?? null)
    : null;
  const focus: PlanFocus | undefined = weak
    ? { subjectId: weak.subjectId, subjectName: weak.name, accuracy: weak.accuracy }
    : undefined;

  const foundationTemplates = weak
    ? WEAK_FOCUS_TASKS.map((t) => fillTemplate(t, weak.name, weak.accuracy))
    : FOCUS_TASKS;
  const revisionTemplates = weak
    ? REVISION_TASKS.map((t) =>
        t.title === "Review mistakes"
          ? fillTemplate(
              {
                ...t,
                title: "Review {subject} mistakes",
                detail: "Re-read your {subject} quiz mistakes and redo the ones you got wrong.",
              },
              weak.name,
              weak.accuracy,
            )
          : t,
      )
    : REVISION_TASKS;

  const stamp = (tasks: PlanTask[]): StudyPlanJson => ({
    version: 1,
    generatedForDate: todayKey,
    examDate: dateKey(examDate),
    ...(focus ? { focus } : {}),
    tasks,
  });

  const tasks: PlanTask[] = [];

  if (days === 1) {
    // One day left: a single focused revision session (subject-aware when weak).
    const [head, practice, mistakes] = [revisionTemplates[0], revisionTemplates[1], revisionTemplates[3]];
    tasks.push(
      { id: `${todayKey}-0`, date: todayKey, title: head.title, detail: head.detail, durationMin: head.durationMin, status: "pending" },
      { id: `${todayKey}-1`, date: todayKey, title: practice.title, detail: practice.detail, durationMin: practice.durationMin, status: "pending" },
      { id: `${todayKey}-2`, date: todayKey, title: mistakes.title, detail: mistakes.detail, durationMin: mistakes.durationMin, status: "pending" },
    );
    return stamp(tasks);
  }

  if (days <= 3) {
    // Sprint: two revision tasks per day, rotating.
    for (let i = 0; i < days; i++) {
      const date = dateKey(new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() + i)));
      tasks.push(...dayTasks(date, revisionTemplates, i * 2, 2));
    }
    return stamp(tasks);
  }

  if (days <= 14) {
    // Foundation days, then a 3-day revision sprint.
    const sprint = 3;
    const foundation = days - sprint;
    for (let i = 0; i < foundation; i++) {
      const date = dateKey(new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() + i)));
      // Two tasks per foundation day: one focus task + one practice/recall.
      const focus = foundationTemplates[i % foundationTemplates.length];
      const practice = foundationTemplates[(i + 1) % foundationTemplates.length];
      tasks.push(
        { id: `${date}-0`, date, title: focus.title, detail: focus.detail, durationMin: focus.durationMin, status: "pending" },
        { id: `${date}-1`, date, title: practice.title, detail: practice.detail, durationMin: practice.durationMin, status: "pending" },
      );
    }
    for (let i = 0; i < sprint; i++) {
      const date = dateKey(new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() + foundation + i)));
      tasks.push(...dayTasks(date, revisionTemplates, i * 2, 2));
    }
    return stamp(tasks);
  }

  // Long horizon: rotation through the focus cycle, then a final week.
  const finalWeek = 7;
  const main = days - finalWeek;
  for (let i = 0; i < main; i++) {
    const date = dateKey(new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() + i)));
    const focus = foundationTemplates[i % foundationTemplates.length];
    const recall = foundationTemplates[(i + 2) % foundationTemplates.length];
    tasks.push(
      { id: `${date}-0`, date, title: focus.title, detail: focus.detail, durationMin: focus.durationMin, status: "pending" },
      { id: `${date}-1`, date, title: recall.title, detail: recall.detail, durationMin: recall.durationMin, status: "pending" },
    );
  }
  for (let i = 0; i < finalWeek; i++) {
    const date = dateKey(new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() + main + i)));
    const t = revisionTemplates[i % revisionTemplates.length];
    tasks.push(
      { id: `${date}-0`, date, title: t.title, detail: t.detail, durationMin: t.durationMin, status: "pending" },
    );
  }
  return stamp(tasks);
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
 * client can show "Plan v2" and stale screens can refresh. Weak-subject
 * weighting is re-applied from `opts`, so the plan rebalances as quiz
 * accuracy improves (or the exam's subject changes).
 */
export function regeneratePlan(
  previous: StudyPlanJson,
  examDate: Date,
  now: Date = new Date(),
  opts: PlanOptions = {},
): StudyPlanJson {
  const fresh = generateDailyPlan(examDate, now, opts);
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
