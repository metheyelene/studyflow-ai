import { beforeEach, describe, expect, it, vi } from "vitest";

// ── module mocks ────────────────────────────────────────────────────
vi.mock("next/headers", () => ({
  headers: () => new Headers(),
}));

const dbMock = {
  query: {
    flashcardReviews: { findMany: vi.fn() },
    flashcards: { findMany: vi.fn() },
    flashcardDecks: { findMany: vi.fn() },
  },
};

vi.mock("@/db", () => ({
  getDb: () => dbMock,
  schema: {
    flashcardReviews: { userId: "user_id", cardId: "card_id", rating: "rating", reviewedAt: "reviewed_at" },
    flashcards: { id: "id", deckId: "deck_id" },
    flashcardDecks: { id: "id", userId: "user_id", title: "title" },
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

// ── imports (after mocks) ───────────────────────────────────────────
import { GET } from "@/app/api/progress/flashcards/route";

const review = (cardId: string, rating: number, daysAgo: number) => ({
  id: `rv_${cardId}_${rating}`,
  cardId,
  userId: "user_1",
  rating,
  reviewedAt: new Date(Date.now() - daysAgo * 86_400_000),
});

const card = (id: string, deckId: string) => ({ id, deckId });
const deck = (id: string, title: string) => ({ id, userId: "user_1", title });

beforeEach(() => {
  vi.clearAllMocks();
});

describe("GET /api/progress/flashcards", () => {
  it("returns empty history when the user has no reviews", async () => {
    (dbMock.query.flashcardReviews.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([]);
    const res = await GET();
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ totalReviews: 0, uniqueCards: 0, decks: [] });
  });

  it("aggregates per-deck reviews and accuracy from ratings", async () => {
    // Deck A: 4 reviews, ratings 1, 3, 4, 5 → 3 remembered (75%)
    // Deck B: 2 reviews, ratings 1, 1 → 0 remembered (0%)
    (dbMock.query.flashcardReviews.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([
      review("c1", 1, 6),
      review("c1", 5, 3),
      review("c2", 3, 2),
      review("c2", 4, 1),
      review("c3", 1, 1),
      review("c3", 1, 0),
    ]);
    (dbMock.query.flashcards.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([
      card("c1", "deck_a"),
      card("c2", "deck_a"),
      card("c3", "deck_b"),
    ]);
    (dbMock.query.flashcardDecks.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([
      deck("deck_a", "VLSI Unit 3"),
      deck("deck_b", "Thermo"),
    ]);

    const res = await GET();
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.totalReviews).toBe(6);
    expect(body.uniqueCards).toBe(3);

    // Most-reviewed deck first.
    expect(body.decks).toHaveLength(2);
    expect(body.decks[0]).toMatchObject({ deckId: "deck_a", title: "VLSI Unit 3", reviews: 4, remembered: 3, accuracy: 75 });
    expect(body.decks[1]).toMatchObject({ deckId: "deck_b", title: "Thermo", reviews: 2, remembered: 0, accuracy: 0 });
  });

  it("ignores reviews whose card was deleted", async () => {
    (dbMock.query.flashcardReviews.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([
      review("c1", 5, 1),
      review("ghost", 1, 0),
    ]);
    (dbMock.query.flashcards.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([card("c1", "deck_a")]);
    (dbMock.query.flashcardDecks.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([deck("deck_a", "A")]);

    const res = await GET();
    const body = await res.json();
    expect(body.totalReviews).toBe(2);
    expect(body.uniqueCards).toBe(2);
    expect(body.decks).toHaveLength(1);
    expect(body.decks[0].reviews).toBe(1);
  });

  it("requires a session", async () => {
    authMock.getSession.mockResolvedValueOnce(null);
    const res = await GET();
    expect(res.status).toBe(401);
  });
});
