import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { and, eq, inArray } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";

export const runtime = "nodejs";

/**
 * Accuracy definition (documented): a review counts as "remembered" when
 * the rating is 3 or higher — matching the session's scale of
 * Again(1) / Hard(3) / Good(4) / Easy(5). So "remembered" means the card
 * was recalled with Hard difficulty or better; only Again(1) counts as
 * forgotten. This mirrors what the study-session summary shows.
 */
const REMEMBERED_MIN = 3;

/**
 * GET /api/progress/flashcards — the user's flashcard review history,
 * computed server-side from flashcard_reviews:
 *   - totalReviews:  review events recorded (a card can be reviewed many
 *     times across sessions)
 *   - uniqueCards:   distinct cards that have at least one review
 *   - decks:         per-deck aggregates (reviews, remembered, accuracy)
 *                    for decks that actually have review history, newest
 *                    activity first
 */
export async function GET() {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  try {
    const db = getDb();
    const reviews = await db.query.flashcardReviews.findMany({
      where: eq(schema.flashcardReviews.userId, session.user.id),
      orderBy: (r, { desc }) => [desc(r.reviewedAt)],
    });

    if (reviews.length === 0) {
      return NextResponse.json({ totalReviews: 0, uniqueCards: 0, decks: [] });
    }

    // card → deck mapping (reviews only store cardId)
    const cardIds = [...new Set(reviews.map((r) => r.cardId))];
    const cards = await db.query.flashcards.findMany({
      where: inArray(schema.flashcards.id, cardIds),
    });
    const deckByCard = new Map(cards.map((c) => [c.id, c.deckId]));

    const deckIds = [...new Set(cards.map((c) => c.deckId))];
    const decks = await db.query.flashcardDecks.findMany({
      where: and(
        inArray(schema.flashcardDecks.id, deckIds),
        eq(schema.flashcardDecks.userId, session.user.id),
      ),
    });
    const titleByDeck = new Map(decks.map((d) => [d.id, d.title]));

    const perDeck = new Map<
      string,
      { deckId: string; title: string; reviews: number; remembered: number; lastReviewedAt: Date }
    >();
    for (const review of reviews) {
      const deckId = deckByCard.get(review.cardId);
      if (!deckId) continue; // card was deleted — orphaned review, ignore
      const entry = perDeck.get(deckId) ?? {
        deckId,
        title: titleByDeck.get(deckId) ?? "Untitled deck",
        reviews: 0,
        remembered: 0,
        lastReviewedAt: review.reviewedAt,
      };
      entry.reviews += 1;
      if (review.rating >= REMEMBERED_MIN) entry.remembered += 1;
      if (review.reviewedAt > entry.lastReviewedAt) entry.lastReviewedAt = review.reviewedAt;
      perDeck.set(deckId, entry);
    }

    const decksOut = [...perDeck.values()]
      .map((d) => ({
        deckId: d.deckId,
        title: d.title,
        reviews: d.reviews,
        remembered: d.remembered,
        accuracy: Math.round((d.remembered / d.reviews) * 100),
      }))
      .sort((a, b) => b.reviews - a.reviews);

    return NextResponse.json({
      totalReviews: reviews.length,
      uniqueCards: cardIds.length,
      decks: decksOut,
    });
  } catch (err) {
    console.error("[progress:flashcards]", err);
    return NextResponse.json({ error: "Failed to load your flashcard history." }, { status: 500 });
  }
}
