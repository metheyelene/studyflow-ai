import { describe, expect, it } from "vitest";

import {
  daysBetween,
  generateDailyPlan,
  isPlanStale,
  regeneratePlan,
  type PlanTask,
} from "@/lib/study/planner";

const now = new Date("2026-08-12T10:00:00Z");

function planTask(t: Partial<PlanTask>): PlanTask {
  return {
    id: "x",
    date: "2026-08-12",
    title: "t",
    detail: "d",
    durationMin: 30,
    status: "pending",
    ...t,
  };
}

describe("generateDailyPlan", () => {
  it("rejects an exam that is today or already passed", () => {
    expect(() => generateDailyPlan(new Date("2026-08-12T00:00:00Z"), now)).toThrow(
      /today or already passed/,
    );
    expect(() => generateDailyPlan(new Date("2026-08-10T00:00:00Z"), now)).toThrow(
      /today or already passed/,
    );
  });

  it("plans a single focused day when the exam is tomorrow", () => {
    const plan = generateDailyPlan(new Date("2026-08-13T00:00:00Z"), now);
    expect(plan.version).toBe(1);
    expect(plan.generatedForDate).toBe("2026-08-12");
    expect(plan.tasks).toHaveLength(3);
    expect(plan.tasks.every((t) => t.date === "2026-08-12")).toBe(true);
    expect(plan.tasks.every((t) => t.status === "pending")).toBe(true);
  });

  it("builds a revision sprint for a 3-day horizon", () => {
    const plan = generateDailyPlan(new Date("2026-08-15T00:00:00Z"), now);
    // 3 days × 2 tasks
    expect(plan.tasks).toHaveLength(6);
    const dates = new Set(plan.tasks.map((t) => t.date));
    expect(dates).toEqual(new Set(["2026-08-12", "2026-08-13", "2026-08-14"]));
  });

  it("builds foundation days plus a revision sprint for a 2-week horizon", () => {
    const plan = generateDailyPlan(new Date("2026-08-22T00:00:00Z"), now);
    // 10 days: 7 foundation (×2 tasks) + 3 sprint (×2 tasks) = 20
    expect(plan.tasks).toHaveLength(20);
    expect(plan.tasks.filter((t) => t.date === "2026-08-21")).toHaveLength(2);
  });

  it("builds a long rotation with a final revision week for a month horizon", () => {
    const plan = generateDailyPlan(new Date("2026-09-12T00:00:00Z"), now);
    expect(plan.tasks.length).toBeGreaterThan(30);
    const lastDay = plan.tasks.at(-1)!;
    expect(lastDay.date).toBe("2026-09-11");
    // Final week days carry revision tasks.
    const finalWeekTitles = plan.tasks
      .filter((t) => t.date >= "2026-09-05")
      .map((t) => t.title);
    expect(finalWeekTitles).toContain("Mock exam (timed)");
    expect(finalWeekTitles).toContain("Review mistakes");
  });

  it("never schedules a task after the exam", () => {
    const plan = generateDailyPlan(new Date("2026-08-20T00:00:00Z"), now);
    for (const t of plan.tasks) {
      expect(daysBetween(new Date(t.date + "T00:00:00Z"), new Date("2026-08-20T00:00:00Z"))).toBeGreaterThanOrEqual(0);
    }
  });
});

describe("regeneratePlan", () => {
  it("bumps the version and preserves completed tasks by date+title", () => {
    const first = generateDailyPlan(new Date("2026-08-22T00:00:00Z"), now);
    // Mark one task done.
    first.tasks[0].status = "done";
    const doneTask = first.tasks[0];

    const second = regeneratePlan(first, new Date("2026-08-22T00:00:00Z"), now);
    expect(second.version).toBe(2);

    // The completed task is still done; everything else is pending again.
    const carried = second.tasks.find((t) => t.date === doneTask.date && t.title === doneTask.title);
    expect(carried?.status).toBe("done");
    expect(second.tasks.filter((t) => t.status === "done")).toHaveLength(1);
  });

  it("resets skipped tasks to pending on regeneration", () => {
    const first = generateDailyPlan(new Date("2026-08-15T00:00:00Z"), now);
    first.tasks[0].status = "skipped";
    const second = regeneratePlan(first, new Date("2026-08-15T00:00:00Z"), now);
    expect(second.tasks[0].status).toBe("pending");
  });

  it("stamps the exam date a plan was generated against", () => {
    const plan = generateDailyPlan(new Date("2026-08-22T00:00:00Z"), now);
    expect(plan.examDate).toBe("2026-08-22");
    const regen = regeneratePlan(plan, new Date("2026-08-25T00:00:00Z"), now);
    expect(regen.examDate).toBe("2026-08-25");
  });
});

describe("isPlanStale", () => {
  it("is stale when generated before today", () => {
    const plan = generateDailyPlan(new Date("2026-08-22T00:00:00Z"), new Date("2026-08-11T00:00:00Z"));
    expect(isPlanStale(plan, new Date("2026-08-22T00:00:00Z"), now)).toBe(true);
  });

  it("is stale when the exam date moved after generation", () => {
    const plan = generateDailyPlan(new Date("2026-08-22T00:00:00Z"), now);
    expect(isPlanStale(plan, new Date("2026-08-28T00:00:00Z"), now)).toBe(true);
    // Moving it earlier is just as stale.
    expect(isPlanStale(plan, new Date("2026-08-19T00:00:00Z"), now)).toBe(true);
  });

  it("is not stale for a fresh plan with an unchanged exam date", () => {
    const plan = generateDailyPlan(new Date("2026-08-22T00:00:00Z"), now);
    expect(isPlanStale(plan, new Date("2026-08-22T00:00:00Z"), now)).toBe(false);
  });

  it("judges legacy plans without an examDate stamp by generation date only", () => {
    const plan = generateDailyPlan(new Date("2026-08-22T00:00:00Z"), now);
    delete plan.examDate;
    expect(isPlanStale(plan, new Date("2026-08-28T00:00:00Z"), now)).toBe(false);
  });
});
