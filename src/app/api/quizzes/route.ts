import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";
import { AiNotConfiguredError, AiProviderError } from "@/lib/ai/orchestrator";
import { runAction, type ActionName } from "@/lib/ai/actions";
import { NotFoundError, getNotebookForUser } from "@/lib/ai/sources";
import { getPlanForSession } from "@/lib/premium";
import { consumeAiAction } from "@/lib/usage";

export const runtime = "nodejs";

const DIFFICULTIES = ["easy", "medium", "hard"] as const;
type Difficulty = (typeof DIFFICULTIES)[number];

interface GenerateBody {
  notebookId: string;
  title?: string;
  difficulty?: Difficulty;
  count?: number;
}

/** Serialize a quiz row + attempt stats into the API shape. */
function quizJson(
  quiz: typeof schema.quizzes.$inferSelect,
  stats: { attempts: number; bestScore: number | null; bestTotal: number | null },
) {
  return {
    id: quiz.id,
    title: quiz.title,
    notebookId: quiz.notebookId,
    difficulty: quiz.difficulty,
    questionCount: quiz.questionCount,
    attempts: stats.attempts,
    bestScore: stats.bestScore,
    bestTotal: stats.bestTotal,
    createdAt: quiz.createdAt.toISOString(),
  };
}

/** GET /api/quizzes — the signed-in user's quizzes, newest first, with
 *  attempt counts and best scores. */
export async function GET() {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  try {
    const db = getDb();
    const quizzes = await db.query.quizzes.findMany({
      where: eq(schema.quizzes.userId, session.user.id),
      orderBy: (q, { desc }) => [desc(q.createdAt)],
    });

    const attempts = await db.query.quizAttempts.findMany({
      where: eq(schema.quizAttempts.userId, session.user.id),
      columns: { quizId: true, score: true, totalQuestions: true },
    });

    const byQuiz = new Map<string, { attempts: number; bestScore: number | null; bestTotal: number | null }>();
    for (const a of attempts) {
      const s = byQuiz.get(a.quizId) ?? { attempts: 0, bestScore: null as number | null, bestTotal: null as number | null };
      s.attempts += 1;
      if (a.totalQuestions > 0 && (s.bestScore === null || a.score > s.bestScore)) {
        s.bestScore = a.score;
        s.bestTotal = a.totalQuestions;
      }
      byQuiz.set(a.quizId, s);
    }

    return NextResponse.json({
      quizzes: quizzes.map((q) => quizJson(q, byQuiz.get(q.id) ?? { attempts: 0, bestScore: null, bestTotal: null })),
    });
  } catch (err) {
    console.error("[quizzes:list]", err);
    return NextResponse.json({ error: "Failed to load your quizzes." }, { status: 500 });
  }
}

/**
 * POST /api/quizzes — generate a source-grounded quiz from a notebook and
 * persist it atomically (same validated AI pipeline + one AI-action quota
 * as flashcards). Question order, options, and correct answers are the AI's
 * validated output; structurally invalid questions are dropped upstream.
 */
export async function POST(request: Request) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const body = (await request.json().catch(() => null)) as GenerateBody | null;
  const notebookId = body?.notebookId;
  if (!notebookId || typeof notebookId !== "string") {
    return NextResponse.json({ error: "Pick a notebook to generate from." }, { status: 400 });
  }
  const difficulty: Difficulty =
    body?.difficulty && DIFFICULTIES.includes(body.difficulty) ? body.difficulty : "medium";
  const count = typeof body?.count === "number" && body.count >= 1 && body.count <= 20 ? body.count : undefined;

  let notebook;
  try {
    notebook = await getNotebookForUser(session.user.id, notebookId);
  } catch (err) {
    if (err instanceof NotFoundError) {
      return NextResponse.json({ error: "Notebook not found." }, { status: 404 });
    }
    console.error("[quizzes:owner]", err);
    return NextResponse.json({ error: "Failed to load that notebook." }, { status: 500 });
  }

  const planCtx = await getPlanForSession();
  const plan = planCtx?.plan ?? "free";
  const consumed = await consumeAiAction(session.user.id, plan);
  if (!consumed.allowed) {
    return NextResponse.json(
      {
        error:
          "You've used this month's free AI allowance. It resets at the start of next month — or upgrade for a much higher limit.",
      },
      { status: 429 },
    );
  }

  try {
    const result = await runAction(
      "quiz" as ActionName,
      { userId: session.user.id, notebookId },
      { count, difficulty },
    );
    const data = result.data as {
      title?: string;
      questions: { question: string; options: string[]; correctIndex: number; explanation: string }[];
    };
    const questions = Array.isArray(data.questions) ? data.questions : [];
    if (questions.length === 0) {
      return NextResponse.json(
        { error: "The AI couldn't build questions from this material. Add more sources and try again." },
        { status: 422 },
      );
    }

    const db = getDb();
    const title = body?.title?.trim() || data.title?.trim() || `${notebook.title} quiz`;
    const quiz = await db.transaction(async (tx) => {
      const [inserted] = await tx
        .insert(schema.quizzes)
        .values({
          userId: session.user.id,
          notebookId,
          title: title.slice(0, 100),
          difficulty,
          questionCount: questions.length,
        })
        .returning();
      if (questions.length > 0) {
        await tx.insert(schema.quizQuestions).values(
          questions.map((q, i) => ({
            quizId: inserted.id,
            question: q.question.slice(0, 2000),
            options: q.options.slice(0, 6).map((o) => o.slice(0, 500)),
            correctIndex: Math.min(Math.max(q.correctIndex, 0), q.options.length - 1),
            explanation: q.explanation?.slice(0, 2000) ?? null,
            order: i,
          })),
        );
      }
      return inserted;
    });

    return NextResponse.json({
      quiz: quizJson(quiz, { attempts: 0, bestScore: null, bestTotal: null }),
      questions: questions.map((q, i) => ({ ...q, order: i })),
    });
  } catch (err) {
    if (err instanceof AiNotConfiguredError) {
      return NextResponse.json({ error: err.message }, { status: 503 });
    }
    if (err instanceof AiProviderError) {
      return NextResponse.json(
        { error: "The AI service is temporarily unavailable. Please try again in a moment." },
        { status: 502 },
      );
    }
    if (err instanceof Error && /no ready sources|no relevant content/i.test(err.message)) {
      return NextResponse.json(
        { error: "This notebook has no indexed sources yet. Add a source first." },
        { status: 422 },
      );
    }
    console.error("[quizzes:generate]", err);
    return NextResponse.json({ error: "Failed to generate the quiz." }, { status: 500 });
  }
}
