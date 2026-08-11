import { beforeEach, describe, expect, it, vi } from "vitest";

// ── module mocks ────────────────────────────────────────────────────
vi.mock("next/headers", () => ({
  headers: () => new Headers(),
}));

const chain = {
  where: vi.fn(() => chain),
  groupBy: vi.fn(async () => []),
};

const dbMock = {
  query: {
    flashcardDecks: { findMany: vi.fn(), findFirst: vi.fn() },
    flashcards: { findMany: vi.fn(), findFirst: vi.fn() },
  },
  select: vi.fn(() => ({ from: vi.fn(() => chain) })),
  insert: vi.fn(() => ({
    values: vi.fn(() => ({
      returning: vi.fn(async () => []),
    })),
  })),
  delete: vi.fn(() => ({ where: vi.fn(async () => {}) })),
  transaction: vi.fn(async (fn: (tx: unknown) => unknown) => fn(dbMock)),
};

vi.mock("@/db", () => ({
  getDb: () => dbMock,
  schema: {
    flashcardDecks: { userId: "user_id", id: "id", updatedAt: "updated_at" },
    flashcards: { deckId: "deck_id", id: "id", order: "order", createdAt: "created_at" },
    flashcardReviews: {},
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
import { GET, POST } from "@/app/api/flashcards/route";
import {
  DELETE as deckDELETE,
  GET as deckGET,
} from "@/app/api/flashcards/[deckId]/route";
import { POST as reviewPOST } from "@/app/api/flashcards/[deckId]/review/route";

const deckRow = {
  id: "deck_1",
  userId: "user_1",
  notebookId: "nb_1",
  noteId: null,
  subjectId: null,
  title: "VLSI Unit 3 flashcards",
  createdAt: new Date("2026-08-11T00:00:00Z"),
  updatedAt: new Date("2026-08-11T00:00:00Z"),
};

beforeEach(() => {
  vi.clearAllMocks();
  (dbMock.query.flashcardDecks.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([deckRow]);
  (chain.where as ReturnType<typeof vi.fn>).mockReturnValue(chain);
  (chain.groupBy as ReturnType<typeof vi.fn>).mockResolvedValue([
    { deckId: "deck_1", count: 5 },
  ]);
  // Re-establish defaults: mockResolvedValue replaces any implementation a
  // previous test set, so each test starts quota-available.
  (consumeAiAction as ReturnType<typeof vi.fn>).mockResolvedValue({ allowed: true });
});

describe("GET /api/flashcards", () => {
  it("lists the user's decks with card counts", async () => {
    const res = await GET();
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.decks).toHaveLength(1);
    expect(body.decks[0]).toMatchObject({ id: "deck_1", title: "VLSI Unit 3 flashcards", cardCount: 5 });
  });

  it("handles a deck with no cards", async () => {
    (chain.groupBy as ReturnType<typeof vi.fn>).mockResolvedValue([]);
    const res = await GET();
    const body = await res.json();
    expect(body.decks[0].cardCount).toBe(0);
  });
});

describe("POST /api/flashcards", () => {
  it("requires a notebookId", async () => {
    const res = await POST(new Request("http://x", {
      method: "POST",
      body: JSON.stringify({}),
    }));
    expect(res.status).toBe(400);
  });

  it("rejects a notebook the user does not own", async () => {
    (getNotebookForUser as ReturnType<typeof vi.fn>).mockRejectedValue(
      new NotFoundError("Notebook not found."),
    );
    const res = await POST(new Request("http://x", {
      method: "POST",
      body: JSON.stringify({ notebookId: "nb_x" }),
    }));
    expect(res.status).toBe(404);
  });

  it("blocks when the AI allowance is used up", async () => {
    (getNotebookForUser as ReturnType<typeof vi.fn>).mockResolvedValue({ id: "nb_1", title: "VLSI Unit 3" });
    (consumeAiAction as ReturnType<typeof vi.fn>).mockResolvedValue({ allowed: false });
    const res = await POST(new Request("http://x", {
      method: "POST",
      body: JSON.stringify({ notebookId: "nb_1" }),
    }));
    expect(res.status).toBe(429);
  });

  it("generates, persists, and returns the deck", async () => {
    (getNotebookForUser as ReturnType<typeof vi.fn>).mockResolvedValue({ id: "nb_1", title: "VLSI Unit 3" });
    (runAction as ReturnType<typeof vi.fn>).mockResolvedValue({
      data: {
        cards: [
          { front: "What is threshold voltage?", back: "The gate voltage at which the channel conducts.", sourceChunkIds: [] },
          { front: "What is Vt?", back: "Threshold voltage.", sourceChunkIds: [] },
        ],
      },
    });
    (dbMock.insert as ReturnType<typeof vi.fn>).mockReturnValue({
      values: vi.fn(() => ({
        returning: vi.fn(async () => [{ ...deckRow }]),
      })),
    });

    const res = await POST(new Request("http://x", {
      method: "POST",
      body: JSON.stringify({ notebookId: "nb_1" }),
    }));
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.deck.title).toBe("VLSI Unit 3 flashcards");
    expect(body.cards).toHaveLength(2);
    expect(consumeAiAction).toHaveBeenCalledTimes(1);
  });

  it("returns a friendly 422 when the notebook has no indexed sources", async () => {
    (getNotebookForUser as ReturnType<typeof vi.fn>).mockResolvedValue({ id: "nb_1", title: "VLSI Unit 3" });
    (runAction as ReturnType<typeof vi.fn>).mockRejectedValue(
      new Error("This notebook has no ready sources yet. Add a source first."),
    );
    const res = await POST(new Request("http://x", {
      method: "POST",
      body: JSON.stringify({ notebookId: "nb_1" }),
    }));
    expect(res.status).toBe(422);
    const body = await res.json();
    expect(body.error).toContain("no indexed sources");
  });
});

describe("GET /api/flashcards/[deckId]", () => {
  it("returns the deck with its cards", async () => {
    (dbMock.query.flashcardDecks.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(deckRow);
    (dbMock.query.flashcards.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([
      { id: "c_1", front: "Q1", back: "A1", order: 0 },
      { id: "c_2", front: "Q2", back: "A2", order: 1 },
    ]);

    const res = await deckGET(new Request("http://x"), { params: Promise.resolve({ deckId: "deck_1" }) });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.deck.title).toBe("VLSI Unit 3 flashcards");
    expect(body.cards).toHaveLength(2);
    expect(body.cards[0].front).toBe("Q1");
  });

  it("404s for a deck the user does not own", async () => {
    (dbMock.query.flashcardDecks.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(null);
    const res = await deckGET(new Request("http://x"), { params: Promise.resolve({ deckId: "deck_x" }) });
    expect(res.status).toBe(404);
  });
});

describe("DELETE /api/flashcards/[deckId]", () => {
  it("deletes an owned deck", async () => {
    (dbMock.query.flashcardDecks.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(deckRow);
    const res = await deckDELETE(new Request("http://x", { method: "DELETE" }), {
      params: Promise.resolve({ deckId: "deck_1" }),
    });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.ok).toBe(true);
  });

  it("404s for a deck the user does not own", async () => {
    (dbMock.query.flashcardDecks.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(null);
    const res = await deckDELETE(new Request("http://x", { method: "DELETE" }), {
      params: Promise.resolve({ deckId: "deck_x" }),
    });
    expect(res.status).toBe(404);
  });
});

describe("POST /api/flashcards/[deckId]/review", () => {
  it("records a rating for a card in an owned deck", async () => {
    (dbMock.query.flashcardDecks.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(deckRow);
    (dbMock.query.flashcards.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue({
      id: "c_1",
      deckId: "deck_1",
    });

    const res = await reviewPOST(
      new Request("http://x", {
        method: "POST",
        body: JSON.stringify({ cardId: "c_1", rating: 4 }),
      }),
      { params: Promise.resolve({ deckId: "deck_1" }) },
    );
    expect(res.status).toBe(200);
    expect(dbMock.insert).toHaveBeenCalled();
  });

  it("rejects out-of-range ratings", async () => {
    (dbMock.query.flashcardDecks.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(deckRow);
    const res = await reviewPOST(
      new Request("http://x", {
        method: "POST",
        body: JSON.stringify({ cardId: "c_1", rating: 9 }),
      }),
      { params: Promise.resolve({ deckId: "deck_1" }) },
    );
    expect(res.status).toBe(400);
  });

  it("404s when the deck is not owned", async () => {
    (dbMock.query.flashcardDecks.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(null);
    const res = await reviewPOST(
      new Request("http://x", {
        method: "POST",
        body: JSON.stringify({ cardId: "c_1", rating: 3 }),
      }),
      { params: Promise.resolve({ deckId: "deck_x" }) },
    );
    expect(res.status).toBe(404);
  });
});
