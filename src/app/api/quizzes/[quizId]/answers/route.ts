import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";

export const runtime = "nodejs";

interface AnswersBody {
  answers: number[];
}

/**
 * POST /api/quizzes/[quizId]/answers — score a completed attempt
 * server-side (the stored correctIndex is the source of truth), persist a
 * quiz_attempt row, and return per-question feedback for the review screen.
 */
export async function POST(request: Request, { params }: { params: Promise<{ quizId: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { quizId } = await params;
  const body = (await request.json().catch(() => null)) as AnswersBody | null;
  const answers = Array.isArray(body?.answers) ? body.answers : null;
  if (answers === null) {
    return NextResponse.json({ error: "Missing answers." }, { status: 400 });
  }

  const db = getDb();
  const quiz = await db.query.quizzes.findFirst({
    where: and(eq(schema.quizzes.id, quizId), eq(schema.quizzes.userId, session.user.id)),
  });
  if (!quiz) return NextResponse.json({ error: "Quiz not found." }, { status: 404 });

  const questions = await db.query.quizQuestions.findMany({
    where: eq(schema.quizQuestions.quizId, quizId),
    orderBy: (q, { asc }) => [asc(q.order), asc(q.id)],
  });

  if (answers.length !== questions.length) {
    return NextResponse.json(
      { error: `Answer all ${questions.length} questions before submitting.` },
      { status: 400 },
    );
  }
  for (const a of answers) {
    if (typeof a !== "number" || !Number.isInteger(a)) {
      return NextResponse.json({ error: "Invalid answer." }, { status: 400 });
    }
  }

  const perQuestion = questions.map((q, i) => {
    const selectedIndex = answers[i];
    const correct = selectedIndex === q.correctIndex;
    return {
      questionId: q.id,
      question: q.question,
      options: q.options,
      selectedIndex,
      correctIndex: q.correctIndex,
      correct,
      explanation: q.explanation,
    };
  });
  const score = perQuestion.filter((r) => r.correct).length;

  await db.insert(schema.quizAttempts).values({
    userId: session.user.id,
    quizId,
    score,
    totalQuestions: questions.length,
    answers,
    completedAt: new Date(),
  });

  return NextResponse.json({
    score,
    total: questions.length,
    percent: questions.length > 0 ? Math.round((score / questions.length) * 100) : 0,
    perQuestion,
  });
}
