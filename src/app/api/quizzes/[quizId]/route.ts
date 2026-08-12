import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";

export const runtime = "nodejs";

/** Ownership-checked quiz fetch. Returns null when missing or not owned. */
async function quizForUser(userId: string, quizId: string) {
  const db = getDb();
  return db.query.quizzes.findFirst({
    where: and(eq(schema.quizzes.id, quizId), eq(schema.quizzes.userId, userId)),
  });
}

/**
 * GET /api/quizzes/[quizId] — the quiz and its questions. This is a
 * self-study tool, not a proctored exam: questions include the correct
 * answer and explanation so the client can show immediate feedback.
 * Scoring is still recomputed server-side on submission (see /answers).
 */
export async function GET(_request: Request, { params }: { params: Promise<{ quizId: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { quizId } = await params;
  const quiz = await quizForUser(session.user.id, quizId);
  if (!quiz) return NextResponse.json({ error: "Quiz not found." }, { status: 404 });

  const questions = await getDb()
    .query.quizQuestions.findMany({
      where: eq(schema.quizQuestions.quizId, quizId),
      orderBy: (q, { asc }) => [asc(q.order), asc(q.id)],
    })
    .then((rows) =>
      rows.map((q) => ({
        id: q.id,
        question: q.question,
        options: q.options,
        correctIndex: q.correctIndex,
        explanation: q.explanation,
        order: q.order,
      })),
    );

  return NextResponse.json({
    quiz: {
      id: quiz.id,
      title: quiz.title,
      notebookId: quiz.notebookId,
      difficulty: quiz.difficulty,
      questionCount: questions.length,
      createdAt: quiz.createdAt.toISOString(),
    },
    questions,
  });
}

/** DELETE /api/quizzes/[quizId] — remove the quiz, questions, and attempts. */
export async function DELETE(_request: Request, { params }: { params: Promise<{ quizId: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { quizId } = await params;
  const quiz = await quizForUser(session.user.id, quizId);
  if (!quiz) return NextResponse.json({ error: "Quiz not found." }, { status: 404 });

  await getDb().delete(schema.quizzes).where(eq(schema.quizzes.id, quizId));
  return NextResponse.json({ ok: true });
}
