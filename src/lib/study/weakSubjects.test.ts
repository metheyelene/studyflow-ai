import { describe, expect, it } from "vitest";

import {
  MIN_QUESTIONS_FOR_SIGNAL,
  WEAK_ACCURACY_THRESHOLD,
  classifyWeakSubjects,
} from "@/lib/study/weakSubjects";

describe("classifyWeakSubjects", () => {
  it("flags subjects below the accuracy threshold", () => {
    const weak = classifyWeakSubjects([
      { subjectId: "s1", name: "Physics", correct: 3, total: 10 }, // 30%
      { subjectId: "s2", name: "Chemistry", correct: 8, total: 10 }, // 80%
    ]);
    expect(weak.map((w) => w.subjectId)).toEqual(["s1"]);
    expect(weak[0]).toMatchObject({ name: "Physics", accuracy: 30 });
  });

  it("does not judge subjects with too few recent questions", () => {
    const weak = classifyWeakSubjects([
      { subjectId: "s1", name: "Physics", correct: 1, total: 2 }, // 50% but only 2 questions
    ]);
    expect(weak).toEqual([]);
  });

  it("treats the exact threshold as not weak", () => {
    const total = 10;
    // 7/10 = 70% — at the threshold, not below it.
    const weak = classifyWeakSubjects([
      { subjectId: "s1", name: "Physics", correct: Math.round(WEAK_ACCURACY_THRESHOLD * total), total },
    ]);
    expect(weak).toEqual([]);
  });

  it("sorts weakest first, then by more questions", () => {
    const weak = classifyWeakSubjects([
      { subjectId: "s1", name: "Math", correct: 5, total: 10 }, // 50%
      { subjectId: "s2", name: "Physics", correct: 4, total: 10 }, // 40%
      { subjectId: "s3", name: "Chem", correct: 6, total: 20 }, // 30%
    ]);
    expect(weak.map((w) => w.subjectId)).toEqual(["s3", "s2", "s1"]);
  });

  it("rounds accuracy to whole percents and returns an empty array for no tallies", () => {
    expect(classifyWeakSubjects([])).toEqual([]);
    const weak = classifyWeakSubjects([
      { subjectId: "s1", name: "Physics", correct: 2, total: 7 }, // 28.57 → 29
    ]);
    expect(weak[0].accuracy).toBe(29);
  });

  it("requires at least MIN_QUESTIONS_FOR_SIGNAL questions", () => {
    const weak = classifyWeakSubjects([
      { subjectId: "s1", name: "Physics", correct: 0, total: MIN_QUESTIONS_FOR_SIGNAL - 1 },
    ]);
    expect(weak).toEqual([]);
  });
});
