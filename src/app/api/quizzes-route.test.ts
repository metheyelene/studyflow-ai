import { beforeEach, describe, expect, it, vi } from "vitest";

// ── module mocks ────────────────────────────────────────────────────
vi.mock("next/headers", () => ({
  headers: () => new Headers(),
}));

const dbMock = {
  query: {
    quizzes: { findMany: vi.fn(), findFirst: vi.fn() },
    quizQuestions: { findMany: vi.fn() },
    quizAttempts: { findMany: vi.fn() },
  },
  insert: vi.fn(() => ({
    values: vi.fn(async () => ({})),
  })),
  delete: vi.fn(() => ({ where: vi.fn(async () => {}) })),
  transaction: vi.fn(async (fn: (tx: unknown) => unknown) => fn(dbMock)),
};

vi.mock("@/db", () => ({
  getDb: () => dbMock,
  schema: {
    quizzes: { userId: "user_id", id: "id", createdAt: "created_at" },
    quizQuestions: { quizId: "quiz_id", id: "id", order: "order" },
    quizAttempts: { userId: "user_id", quizId: "quiz_id", score: "score", totalQuestions: "total_questions" },
  },
}));

const session = { user: { id: "user_1" } };
vi.mock("@/lib/auth", () => ({
  auth: { api: { getSession: vi.fn(async () => session) } },
}));

vi.mock("@/lib/ai/actions", () => ({
  runAction: vi.fn(),
}));

vi.mock("@/lib/ai/orchestrator", () => ({
  AiNotConfiguredError: class AiNotConfiguredError extends Error {},
  AiProviderError: class AiProviderError extends Error {},
}));

vi.mock("@/lib/ai/sources", () => ({
  NotFoundError: class NotFoundError extends Error {},
  getNotebookForUser: vi.fn(),
}));

vi.mock("@/lib/premium", () => ({
  getPlanForSession: vi.fn(async () => ({ plan: "free" })),
}));

vi.mock("@/lib/usage", () => ({
  consumeAiAction: vi.fn(async () => ({ allowed: true })),
}));

// ── imports (after mocks) ───────────────────────────────────────────
import { runAction } from "@/lib/ai/actions";
import { getNotebookForUser, NotFoundError } from "@/lib/ai/sources";
import { consumeAiAction } from "@/lib/usage";
import { GET, POST } from "@/app/api/quizzes/route";
import { DELETE as quizDELETE, GET as quizGET } from "@/app/api/quizzes/[quizId]/route";
import { POST as answersPOST } from "@/app/api/quizzes/[quizId]/answers/route";

const quizRow = {
  id: "quiz_1",
  userId: "user_1",
  notebookId: "nb_1",
  noteId: null,
  title: "VLSI Unit 3 quiz",
  difficulty: "medium",
  questionCount: 2,
  createdAt: new Date("2026-08-11T00:00:00Z"),
};

const questions = [
  {
    id: "q1",
    quizId: "quiz_1",
    question: "What is threshold voltage?",
    options: ["A", "B", "C", "D"],
    correctIndex: 1,
    explanation: "The gate voltage at which the channel conducts.",
    order: 0,
  },
  {
    id: "q2",
    quizId: "quiz_1",
    question: "What is Vt?",
    options: ["X", "Y"],
    correctIndex: 0,
    explanation: "Threshold voltage.",
    order: 1,
  },
];

beforeEach(() => {
  vi.clearAllMocks();
  (dbMock.query.quizzes.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([quizRow]);
  (dbMock.query.quizAttempts.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([
    { quizId: "quiz_1", score: 1, totalQuestions: 2 },
  ]);
  (consumeAiAction as ReturnType<typeof vi.fn>).mockResolvedValue({ allowed: true });
});

describe("GET /api/quizzes", () => {
  it("lists the user's quizzes with attempt stats", async () => {
    const res = await GET();
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.quizzes).toHaveLength(1);
    expect(body.quizzes[0]).toMatchObject({
      id: "quiz_1",
      title: "VLSI Unit 3 quiz",
      attempts: 1,
      bestScore: 1,
      bestTotal: 2,
    });
  });

  it("reports no attempts when there are none", async () => {
    (dbMock.query.quizAttempts.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([]);
    const res = await GET();
    const body = await res.json();
    expect(body.quizzes[0].attempts).toBe(0);
    expect(body.quizzes[0].bestScore).toBeNull();
  });
});

describe("POST /api/quizzes", () => {
  it("requires a notebookId", async () => {
    const res = await POST(new Request("http://x", { method: "POST", body: JSON.stringify({}) }));
    expect(res.status).toBe(400);
  });

  it("rejects a notebook the user does not own", async () => {
    (getNotebookForUser as ReturnType<typeof vi.fn>).mockRejectedValue(
      new NotFoundError("Notebook not found."),
    );
    const res = await POST(
      new Request("http://x", { method: "POST", body: JSON.stringify({ notebookId: "nb_x" }) }),
    );
    expect(res.status).toBe(404);
  });

  it("blocks when the AI allowance is used up", async () => {
    (getNotebookForUser as ReturnType<typeof vi.fn>).mockResolvedValue({ id: "nb_1", title: "VLSI Unit 3" });
    (consumeAiAction as ReturnType<typeof vi.fn>).mockResolvedValue({ allowed: false });
    const res = await POST(
      new Request("http://x", { method: "POST", body: JSON.stringify({ notebookId: "nb_1" }) }),
    );
    expect(res.status).toBe(429);
  });

  it("generates, persists, and returns the quiz", async () => {
    (getNotebookForUser as ReturnType<typeof vi.fn>).mockResolvedValue({ id: "nb_1", title: "VLSI Unit 3" });
    (runAction as ReturnType<typeof vi.fn>).mockResolvedValue({
      data: {
        title: "VLSI Unit 3 quiz",
        questions: [
          { question: "What is threshold voltage?", options: ["A", "B", "C", "D"], correctIndex: 1, explanation: "…", sourceMarkers: [1] },
          { question: "What is Vt?", options: ["X", "Y"], correctIndex: 0, explanation: "…", sourceMarkers: [1] },
        ],
      },
    });
    (dbMock.insert as ReturnType<typeof vi.fn>).mockReturnValue({
      values: vi.fn(() => ({
        returning: vi.fn(async () => [{ ...quizRow, difficulty: "hard" }]),
      })),
    });

    const res = await POST(
      new Request("http://x", {
        method: "POST",
        body: JSON.stringify({ notebookId: "nb_1", difficulty: "hard", count: 2 }),
      }),
    );
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.quiz.title).toBe("VLSI Unit 3 quiz");
    expect(body.quiz.difficulty).toBe("hard");
    expect(body.quiz.questionCount).toBe(2);
    expect(body.questions).toHaveLength(2);
    expect(consumeAiAction).toHaveBeenCalledTimes(1);
  });

  it("rejects an invalid difficulty and defaults to medium", async () => {
    (getNotebookForUser as ReturnType<typeof vi.fn>).mockResolvedValue({ id: "nb_1", title: "VLSI Unit 3" });
    (runAction as ReturnType<typeof vi.fn>).mockResolvedValue({
      data: {
        questions: [
          { question: "Q?", options: ["A", "B"], correctIndex: 0, explanation: "…", sourceMarkers: [1] },
        ],
      },
    });
    (dbMock.insert as ReturnType<typeof vi.fn>).mockReturnValue({
      values: vi.fn(() => ({
        returning: vi.fn(async () => [{ ...quizRow, difficulty: "medium" }]),
      })),
    });
    const res = await POST(
      new Request("http://x", {
        method: "POST",
        body: JSON.stringify({ notebookId: "nb_1", difficulty: "insane" }),
      }),
    );
    const body = await res.json();
    expect(body.quiz.difficulty).toBe("medium");
  });
});

describe("GET /api/quizzes/[quizId]", () => {
  it("returns the quiz with its questions", async () => {
    (dbMock.query.quizzes.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(quizRow);
    (dbMock.query.quizQuestions.findMany as ReturnType<typeof vi.fn>).mockResolvedValue(questions);

    const res = await quizGET(new Request("http://x"), { params: Promise.resolve({ quizId: "quiz_1" }) });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.quiz.title).toBe("VLSI Unit 3 quiz");
    expect(body.questions).toHaveLength(2);
    expect(body.questions[0].correctIndex).toBe(1);
  });

  it("404s for a quiz the user does not own", async () => {
    (dbMock.query.quizzes.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(null);
    const res = await quizGET(new Request("http://x"), { params: Promise.resolve({ quizId: "quiz_x" }) });
    expect(res.status).toBe(404);
  });
});

describe("DELETE /api/quizzes/[quizId]", () => {
  it("deletes an owned quiz", async () => {
    (dbMock.query.quizzes.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(quizRow);
    const res = await quizDELETE(new Request("http://x", { method: "DELETE" }), {
      params: Promise.resolve({ quizId: "quiz_1" }),
    });
    expect(res.status).toBe(200);
    expect((await res.json()).ok).toBe(true);
  });
});

describe("POST /api/quizzes/[quizId]/answers", () => {
  it("scores the attempt and returns per-question feedback", async () => {
    (dbMock.query.quizzes.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(quizRow);
    (dbMock.query.quizQuestions.findMany as ReturnType<typeof vi.fn>).mockResolvedValue(questions);

    const res = await answersPOST(
      new Request("http://x", { method: "POST", body: JSON.stringify({ answers: [1, 0] }) }),
      { params: Promise.resolve({ quizId: "quiz_1" }) },
    );
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.score).toBe(2);
    expect(body.total).toBe(2);
    expect(body.percent).toBe(100);
    expect(body.perQuestion[0].correct).toBe(true);
    expect(body.perQuestion[1].correct).toBe(true);
    expect(dbMock.insert).toHaveBeenCalled();
  });

  it("reports wrong answers correctly", async () => {
    (dbMock.query.quizzes.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(quizRow);
    (dbMock.query.quizQuestions.findMany as ReturnType<typeof vi.fn>).mockResolvedValue(questions);

    const res = await answersPOST(
      new Request("http://x", { method: "POST", body: JSON.stringify({ answers: [3, 1] }) }),
      { params: Promise.resolve({ quizId: "quiz_1" }) },
    );
    const body = await res.json();
    expect(body.score).toBe(0);
    expect(body.perQuestion[0].correct).toBe(false);
    expect(body.perQuestion[0].correctIndex).toBe(1);
  });

  it("rejects a partial submission", async () => {
    (dbMock.query.quizzes.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(quizRow);
    (dbMock.query.quizQuestions.findMany as ReturnType<typeof vi.fn>).mockResolvedValue(questions);
    const res = await answersPOST(
      new Request("http://x", { method: "POST", body: JSON.stringify({ answers: [0] }) }),
      { params: Promise.resolve({ quizId: "quiz_1" }) },
    );
    expect(res.status).toBe(400);
  });
});
