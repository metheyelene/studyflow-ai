// ─────────────────────────────────────────────────────────────────────
// Weak-subject detection for the adaptive study planner.
//
// The planner weights tasks toward subjects where recent quiz accuracy is
// weakest. "Recent" means completed quiz attempts within the last
// RECENT_WINDOW_DAYS. A subject is only judged when it has enough recent
// questions to be a real signal (MIN_QUESTIONS_FOR_SIGNAL), and it counts
// as weak when accuracy is below WEAK_ACCURACY_THRESHOLD.
//
// The chain from an attempt to its subject is:
//   quizAttempts.quizId → quizzes.notebookId → notebooks.subjectId
// Attempts whose quiz or notebook no longer exists (or has no subject)
// are skipped — they carry no subject signal.
// ─────────────────────────────────────────────────────────────────────
import { and, eq, gte, inArray } from "drizzle-orm";

import { getDb, schema } from "@/db";

/** How far back completed quiz attempts are considered "recent". */
export const RECENT_WINDOW_DAYS = 30;
/** Minimum recent questions a subject needs before it can be judged. */
export const MIN_QUESTIONS_FOR_SIGNAL = 6;
/** Accuracy below this (as a fraction) marks a subject as weak. */
export const WEAK_ACCURACY_THRESHOLD = 0.7;

export interface SubjectTally {
  subjectId: string;
  name: string;
  /** Number of questions answered correctly across recent attempts. */
  correct: number;
  /** Total questions attempted across recent attempts. */
  total: number;
}

export interface SubjectAccuracy extends SubjectTally {
  /** 0–100, rounded to the nearest whole percent. */
  accuracy: number;
}

/**
 * Pure classification: which subjects are weak, given per-subject tallies
 * of recent quiz attempts. A subject with too few questions is not judged
 * (a single 1-question miss is noise, not a signal); the rest are weak
 * when accuracy is below the threshold. Results sort weakest-first so the
 * planner naturally prioritizes the biggest gaps.
 */
export function classifyWeakSubjects(tallies: SubjectTally[]): SubjectAccuracy[] {
  return tallies
    .map((t) => ({
      ...t,
      accuracy: t.total > 0 ? Math.round((t.correct / t.total) * 100) : 100,
    }))
    .filter(
      (t) => t.total >= MIN_QUESTIONS_FOR_SIGNAL && t.accuracy < WEAK_ACCURACY_THRESHOLD * 100,
    )
    .sort((a, b) => a.accuracy - b.accuracy || b.total - a.total);
}

/**
 * DB: aggregate the user's recent completed quiz attempts into per-subject
 * tallies, then classify which subjects are weak. Returns an empty array
 * when there is no attempt data (the planner then stays generic).
 */
export async function fetchRecentSubjectAccuracy(
  userId: string,
  now: Date = new Date(),
): Promise<SubjectAccuracy[]> {
  const db = getDb();
  const since = new Date(now.getTime() - RECENT_WINDOW_DAYS * 86_400_000);

  const attempts = await db.query.quizAttempts.findMany({
    where: and(
      eq(schema.quizAttempts.userId, userId),
      gte(schema.quizAttempts.completedAt, since),
    ),
    columns: { quizId: true, score: true, totalQuestions: true },
  });
  if (attempts.length === 0) return [];

  const quizIds = [...new Set(attempts.map((a) => a.quizId))];
  const quizzes = await db.query.quizzes.findMany({
    where: inArray(schema.quizzes.id, quizIds),
    columns: { id: true, notebookId: true },
  });

  const notebookIds = [
    ...new Set(quizzes.map((q) => q.notebookId).filter((x): x is string => Boolean(x))),
  ];
  let notebooks: { id: string; subjectId: string | null }[] = [];
  if (notebookIds.length > 0) {
    notebooks = await db.query.notebooks.findMany({
      where: inArray(schema.notebooks.id, notebookIds),
      columns: { id: true, subjectId: true },
    });
  }
  const subjectByNotebook = new Map(notebooks.map((n) => [n.id, n.subjectId]));
  const subjectByQuiz = new Map<string, string | null>();
  for (const q of quizzes) {
    subjectByQuiz.set(q.id, q.notebookId ? (subjectByNotebook.get(q.notebookId) ?? null) : null);
  }

  const tallyBySubject = new Map<string, { correct: number; total: number }>();
  for (const a of attempts) {
    const subjectId = subjectByQuiz.get(a.quizId);
    if (!subjectId) continue;
    const tally = tallyBySubject.get(subjectId) ?? { correct: 0, total: 0 };
    tally.correct += a.score;
    tally.total += a.totalQuestions;
    tallyBySubject.set(subjectId, tally);
  }
  if (tallyBySubject.size === 0) return [];

  const subjectIds = [...tallyBySubject.keys()];
  const subjects = await db.query.subjects.findMany({
    where: inArray(schema.subjects.id, subjectIds),
    columns: { id: true, name: true },
  });
  const nameById = new Map(subjects.map((s) => [s.id, s.name]));

  return classifyWeakSubjects(
    [...tallyBySubject.entries()].map(([id, t]) => ({
      subjectId: id,
      name: nameById.get(id) ?? "Subject",
      correct: t.correct,
      total: t.total,
    })),
  );
}
