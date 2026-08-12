import { beforeEach, describe, expect, it, vi } from "vitest";

// ── module mocks ────────────────────────────────────────────────────
vi.mock("next/headers", () => ({
  headers: () => new Headers(),
}));

const dbMock = {
  query: {
    studyPlans: { findMany: vi.fn(), findFirst: vi.fn() },
    exams: { findMany: vi.fn(), findFirst: vi.fn() },
  },
  update: vi.fn(() => ({
    set: vi.fn(() => ({
      where: vi.fn(() => ({
        returning: vi.fn(async () => []),
      })),
    })),
  })),
  insert: vi.fn(() => ({
    values: vi.fn(() => ({
      returning: vi.fn(async () => []),
    })),
  })),
};

vi.mock("@/db", () => ({
  getDb: () => dbMock,
  schema: {
    studyPlans: { userId: "user_id", examId: "exam_id", id: "id", createdAt: "created_at" },
    exams: { id: "id", userId: "user_id", examDate: "exam_date" },
  },
}));

const authMock = vi.hoisted(() => {
  const session = { user: { id: "user_1" } };
  const getSession = vi.fn(async (): Promise<{ user: { id: string } } | null> => session);
  return { session, getSession };
});
vi.mock("@/lib/auth", () => ({
  auth: { api: { getSession: authMock.getSession } },
}));

const weakMock = vi.hoisted(() => ({
  fetchRecentSubjectAccuracy: vi.fn<() => Promise<unknown[]>>(async () => []),
}));
vi.mock("@/lib/study/weakSubjects", () => ({
  fetchRecentSubjectAccuracy: weakMock.fetchRecentSubjectAccuracy,
}));

// ── imports (after mocks) ───────────────────────────────────────────
import { GET, POST } from "@/app/api/study-plans/route";
import { PATCH } from "@/app/api/study-plans/[planId]/route";
import { dateKey, type StudyPlanJson } from "@/lib/study/planner";

const DAY = 86_400_000;
const futureDate = (daysAhead: number) => new Date(Date.now() + daysAhead * DAY);
const todayKey = () => dateKey(new Date());
const dayKeyAgo = (daysAgo: number) => dateKey(new Date(Date.now() - daysAgo * DAY));

const examRow = {
  id: "exam_1",
  userId: "user_1",
  subjectId: null,
  title: "Physics Midterm",
  examDate: futureDate(10),
  createdAt: new Date(),
};

function planRow(overrides: Record<string, unknown> = {}) {
  return {
    id: "plan_1",
    userId: "user_1",
    examId: "exam_1",
    planJson: {
      version: 1,
      generatedForDate: dayKeyAgo(1),
      examDate: dateKey(examRow.examDate),
      tasks: [
        { id: `${todayKey()}-0`, date: todayKey(), title: "Review core concepts", detail: "d", durationMin: 45, status: "pending" },
      ],
    },
    version: 1,
    createdAt: new Date(),
    ...overrides,
  };
}

beforeEach(() => {
  vi.clearAllMocks();
  (dbMock.query.studyPlans.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([]);
  (dbMock.query.studyPlans.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(null);
  (dbMock.query.exams.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([examRow]);
  (dbMock.query.exams.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(examRow);
  weakMock.fetchRecentSubjectAccuracy.mockResolvedValue([]);
});

describe("GET /api/study-plans", () => {
  it("lists the user's plans with exam info", async () => {
    const plan = planRow({ planJson: { ...planRow().planJson, generatedForDate: todayKey() } });
    (dbMock.query.studyPlans.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([plan]);
    const res = await GET();
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.plans).toHaveLength(1);
    expect(body.plans[0]).toMatchObject({
      id: "plan_1",
      examId: "exam_1",
      examTitle: "Physics Midterm",
      version: 1,
    });
    expect(body.plans[0].tasks).toHaveLength(1);
  });

  it("returns an empty list when the user has no plans", async () => {
    const res = await GET();
    const body = await res.json();
    expect(body.plans).toEqual([]);
  });

  it("leaves a fresh plan untouched", async () => {
    const plan = planRow({
      planJson: {
        version: 2,
        generatedForDate: todayKey(),
        examDate: dateKey(examRow.examDate),
        tasks: [{ id: `${todayKey()}-0`, date: todayKey(), title: "Review core concepts", detail: "d", durationMin: 45, status: "done" }],
      },
    });
    (dbMock.query.studyPlans.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([plan]);
    const res = await GET();
    const body = await res.json();
    expect(dbMock.update).not.toHaveBeenCalled();
    expect(body.plans[0].version).toBe(2);
    expect(body.plans[0].tasks[0].status).toBe("done");
  });

  it("regenerates a plan generated on an earlier day, preserving done tasks", async () => {
    const doneTask = { id: `${todayKey()}-0`, date: todayKey(), title: "Review core concepts", detail: "d", durationMin: 45, status: "done" };
    const plan = planRow({ planJson: { version: 1, generatedForDate: dayKeyAgo(1), examDate: dateKey(examRow.examDate), tasks: [doneTask] } });
    (dbMock.query.studyPlans.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([plan]);
    // The regenerated plan bumps the version; the completed task survives.
    const updated = planRow({ planJson: { version: 2, generatedForDate: todayKey(), examDate: dateKey(examRow.examDate), tasks: [doneTask] } });
    (dbMock.update as ReturnType<typeof vi.fn>).mockImplementation(() => ({
      set: vi.fn(() => ({
        where: vi.fn(() => ({
          returning: vi.fn(async () => [updated]),
        })),
      })),
    }));
    const res = await GET();
    expect(dbMock.update).toHaveBeenCalledTimes(1);
    const body = await res.json();
    expect(body.plans[0].version).toBe(2);
    expect(body.plans[0].generatedForDate).toBe(todayKey());
    expect(body.plans[0].tasks[0].status).toBe("done");
  });

  it("regenerates a plan whose exam date moved", async () => {
    // Generated today against a date 20 days out; the exam now sits 10 days out.
    const plan = planRow({
      planJson: {
        version: 3,
        generatedForDate: todayKey(),
        examDate: dateKey(futureDate(20)),
        tasks: [{ id: `${todayKey()}-0`, date: todayKey(), title: "Review core concepts", detail: "d", durationMin: 45, status: "pending" }],
      },
    });
    (dbMock.query.studyPlans.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([plan]);
    (dbMock.update as ReturnType<typeof vi.fn>).mockImplementation(() => ({
      set: vi.fn(() => ({
        where: vi.fn(() => ({
          returning: vi.fn(async () => [planRow({ planJson: { version: 4, generatedForDate: todayKey(), examDate: dateKey(examRow.examDate), tasks: plan.planJson.tasks } })]),
        })),
      })),
    }));
    const res = await GET();
    expect(dbMock.update).toHaveBeenCalledTimes(1);
    const body = await res.json();
    expect(body.plans[0].version).toBe(4);
  });

  it("leaves a plan alone when the exam has already passed", async () => {
    const plan = planRow({
      planJson: {
        version: 1,
        generatedForDate: dayKeyAgo(3),
        examDate: dayKeyAgo(1),
        tasks: [{ id: "x-0", date: dayKeyAgo(3), title: "Final revision", detail: "d", durationMin: 40, status: "pending" }],
      },
    });
    (dbMock.query.studyPlans.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([plan]);
    (dbMock.query.exams.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([{ ...examRow, examDate: new Date(Date.now() - DAY) }]);
    const res = await GET();
    expect(dbMock.update).not.toHaveBeenCalled();
    const body = await res.json();
    expect(body.plans[0].version).toBe(1);
  });
});

describe("POST /api/study-plans", () => {
  it("generates a plan for an owned exam", async () => {
    const inserted = planRow({
      planJson: {
        version: 1,
        generatedForDate: "2026-08-12",
        tasks: [
          { id: "2026-08-12-0", date: "2026-08-12", title: "Review core concepts", detail: "d", durationMin: 45, status: "pending" },
        ],
      },
    });
    (dbMock.insert as ReturnType<typeof vi.fn>).mockImplementation(() => ({
      values: vi.fn(() => ({
        returning: vi.fn(async () => [inserted]),
      })),
    }));
    const res = await POST(
      new Request("http://x", { method: "POST", body: JSON.stringify({ examId: "exam_1" }) }),
    );
    expect(res.status).toBe(201);
    const body = await res.json();
    expect(body.plan.examTitle).toBe("Physics Midterm");
    expect(body.plan.tasks).toHaveLength(1);
  });

  it("rejects an exam the user does not own", async () => {
    (dbMock.query.exams.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue({ ...examRow, userId: "other" });
    const res = await POST(
      new Request("http://x", { method: "POST", body: JSON.stringify({ examId: "exam_1" }) }),
    );
    expect(res.status).toBe(404);
  });

  it("rejects an exam that has already passed", async () => {
    (dbMock.query.exams.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue({
      ...examRow,
      examDate: new Date("2026-01-01T00:00:00Z"),
    });
    const res = await POST(
      new Request("http://x", { method: "POST", body: JSON.stringify({ examId: "exam_1" }) }),
    );
    expect(res.status).toBe(422);
  });

  it("weights tasks toward the exam's weak subject and stamps focus", async () => {
    weakMock.fetchRecentSubjectAccuracy.mockResolvedValue([
      { subjectId: "subj_1", name: "Physics", correct: 3, total: 10, accuracy: 30 },
    ]);
    (dbMock.query.exams.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue({
      ...examRow,
      subjectId: "subj_1",
    });
    // The route runs the real planner; the insert mock just echoes the
    // values back so the response carries the generated plan.
    (dbMock.insert as ReturnType<typeof vi.fn>).mockImplementation(() => ({
      values: vi.fn((vals: { planJson: StudyPlanJson }) => ({
        returning: vi.fn(async () => [planRow({ planJson: vals.planJson, version: vals.planJson.version })]),
      })),
    }));
    const res = await POST(
      new Request("http://x", { method: "POST", body: JSON.stringify({ examId: "exam_1" }) }),
    );
    expect(res.status).toBe(201);
    const body = await res.json();
    expect(weakMock.fetchRecentSubjectAccuracy).toHaveBeenCalledTimes(1);
    expect(body.plan.focus).toMatchObject({ subjectId: "subj_1", subjectName: "Physics", accuracy: 30 });
    expect(body.plan.tasks.some((t: { title: string }) => t.title.includes("Physics"))).toBe(true);
    expect(body.plan.tasks.some((t: { title: string }) => t.title.includes("quiz mistakes"))).toBe(true);
  });

  it("keeps the plan generic when the exam's subject has no weak data", async () => {
    weakMock.fetchRecentSubjectAccuracy.mockResolvedValue([
      { subjectId: "subj_other", name: "Chemistry", correct: 9, total: 10, accuracy: 90 },
    ]);
    (dbMock.query.exams.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue({
      ...examRow,
      subjectId: "subj_1",
    });
    (dbMock.insert as ReturnType<typeof vi.fn>).mockImplementation(() => ({
      values: vi.fn((vals: { planJson: StudyPlanJson }) => ({
        returning: vi.fn(async () => [planRow({ planJson: vals.planJson, version: vals.planJson.version })]),
      })),
    }));
    const res = await POST(
      new Request("http://x", { method: "POST", body: JSON.stringify({ examId: "exam_1" }) }),
    );
    const body = await res.json();
    expect(body.plan.focus).toBeNull();
    expect(body.plan.tasks.some((t: { title: string }) => t.title.includes("Physics"))).toBe(false);
  });

  it("regenerates an existing plan, bumping the version", async () => {
    const existing = planRow({
      planJson: {
        version: 1,
        generatedForDate: "2026-08-11",
        tasks: [
          { id: "a", date: "2026-08-12", title: "Review core concepts", detail: "d", durationMin: 45, status: "done" },
        ],
      },
    });
    (dbMock.query.studyPlans.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(existing);
    // `.returning()` yields the UPDATED row (version bumped by the route).
    const updated = planRow({
      planJson: { ...(existing.planJson as object), version: 2 } as typeof existing.planJson,
    });
    (dbMock.update as ReturnType<typeof vi.fn>).mockImplementation(() => ({
      set: vi.fn(() => ({
        where: vi.fn(() => ({
          returning: vi.fn(async () => [updated]),
        })),
      })),
    }));
    const res = await POST(
      new Request("http://x", { method: "POST", body: JSON.stringify({ examId: "exam_1" }) }),
    );
    expect(res.status).toBe(201);
    const body = await res.json();
    expect(body.plan.version).toBe(2);
    // The completed task survives regeneration.
    const carried = body.plan.tasks.find((t: { title: string }) => t.title === "Review core concepts");
    expect(carried?.status).toBe("done");
  });
});

describe("PATCH /api/study-plans/[planId]", () => {
  it("updates a task status and returns the plan", async () => {
    const plan = planRow();
    (dbMock.query.studyPlans.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(plan);
    (dbMock.update as ReturnType<typeof vi.fn>).mockImplementation(() => ({
      set: vi.fn(() => ({
        where: vi.fn(() => ({
          returning: vi.fn(async () => [plan]),
        })),
      })),
    }));
    const res = await PATCH(
      new Request("http://x", { method: "PATCH", body: JSON.stringify({ taskId: "2026-08-12-0", status: "done" }) }),
      { params: Promise.resolve({ planId: "plan_1" }) },
    );
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.plan.tasks[0].status).toBe("done");
  });

  it("rejects an invalid status", async () => {
    (dbMock.query.studyPlans.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(planRow());
    const res = await PATCH(
      new Request("http://x", { method: "PATCH", body: JSON.stringify({ taskId: "t1", status: "banana" }) }),
      { params: Promise.resolve({ planId: "plan_1" }) },
    );
    expect(res.status).toBe(400);
  });

  it("returns 404 for a plan the user does not own", async () => {
    (dbMock.query.studyPlans.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(null);
    const res = await PATCH(
      new Request("http://x", { method: "PATCH", body: JSON.stringify({ taskId: "t1", status: "done" }) }),
      { params: Promise.resolve({ planId: "plan_x" }) },
    );
    expect(res.status).toBe(404);
  });
});
