import { beforeEach, describe, expect, it, vi } from "vitest";

type InsertCall = {
  op: "upsert" | "insert";
  table: string;
  values: Record<string, unknown>;
};

const calls: InsertCall[] = [];
const db = {
  insert: (table: unknown) => ({
    values: (values: Record<string, unknown>) => {
      // Record every insert; an upsert chain upgrades the same record.
      const rec: InsertCall = { op: "insert", table: String(table), values };
      calls.push(rec);
      return {
        onConflictDoUpdate: async () => {
          rec.op = "upsert";
        },
        onConflictDoNothing: async () => {},
      };
    },
  }),
};

vi.mock("@/db", () => {
  // Name the mock tables so the test can tell which insert happened —
  // the real schema objects stringify to their table names.
  const tbl = (name: string) => ({
    [Symbol.toPrimitive]: () => name,
    toString: () => name,
  });
  return {
    getDb: () => db,
    schema: {
      profiles: tbl("profiles"),
      subjects: tbl("subjects"),
      exams: tbl("exams"),
      analyticsEvents: tbl("analyticsEvents"),
    },
  };
});

import { completeOnboarding } from "@/lib/onboarding";

const validInput = {
  course: "Computer Science",
  subjects: "VLSI, Algorithms,  Operating Systems ",
  exams: [
    { name: "VLSI Midterm", date: "2026-09-15" },
    { name: "", date: "2026-10-01" },
  ],
  dailyMinutes: 60,
  goals: ["summaries", "flashcards"],
};

beforeEach(() => {
  calls.length = 0;
});

describe("completeOnboarding", () => {
  it("persists the profile, trimmed subjects, exams, and an analytics event", async () => {
    const res = await completeOnboarding("user_1", validInput);
    expect(res).toEqual({ ok: true });

    const upserts = calls.filter((c) => c.op === "upsert");
    expect(upserts).toHaveLength(1);
    expect(upserts[0].values).toMatchObject({
      userId: "user_1",
      course: "Computer Science",
      goal: "summaries, flashcards",
      dailyStudyMinutes: 60,
      onboardingCompleted: true,
    });

    const subjectInserts = calls.filter(
      (c) => c.op === "insert" && String(c.table).includes("subjects"),
    );
    expect(subjectInserts.map((c) => c.values.name)).toEqual([
      "VLSI",
      "Algorithms",
      "Operating Systems",
    ]);

    const examInserts = calls.filter((c) => String(c.table).includes("exams"));
    expect(examInserts).toHaveLength(2);

    const events = calls.filter((c) => String(c.table).includes("analyticsEvents"));
    expect(events).toHaveLength(1);
    expect(events[0].values.eventName).toBe("onboarding_completed");
    expect(events[0].values.properties).toEqual({ goals: validInput.goals });
  });

  it("caps subjects at five and skips empty names", async () => {
    const res = await completeOnboarding("user_2", {
      ...validInput,
      subjects: "a, b, c, d, e, f, g,  , h",
    });
    expect(res).toEqual({ ok: true });
    const subjectInserts = calls.filter((c) => String(c.table).includes("subjects"));
    expect(subjectInserts.map((c) => c.values.name)).toEqual(["a", "b", "c", "d", "e"]);
  });

  it("rejects invalid input without writing anything", async () => {
    const res = await completeOnboarding("user_3", {
      ...validInput,
      course: "", // min 2
    });
    expect("error" in res).toBe(true);
    expect(calls).toHaveLength(0);
  });

  it("rejects malformed exam dates", async () => {
    const res = await completeOnboarding("user_4", {
      ...validInput,
      exams: [{ name: "Bad", date: "15/09/2026" }],
    });
    expect("error" in res).toBe(true);
    expect(calls).toHaveLength(0);
  });

  it("rejects empty goals", async () => {
    const res = await completeOnboarding("user_5", {
      ...validInput,
      goals: [],
    });
    expect("error" in res).toBe(true);
  });
});
