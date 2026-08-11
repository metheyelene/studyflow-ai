import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";

export const runtime = "nodejs";

interface ReviewBody {
  cardId: string;
  /** 1 (again) … 5 (easy) — matches the flashcard_reviews schema. */
  rating: number;
}

/**
 * POST /api/flashcards/[deckId]/review — record one review rating for a
 * card in an owned deck. The client fires one request per rating so a
 * partially-completed session still leaves review history behind.
 */
export async function POST(request: Request, { params }: { params: Promise<{ deckId: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { deckId } = await params;
  const body = (await request.json().catch(() => null)) as ReviewBody | null;
  const cardId = body?.cardId;
  const rating = body?.rating;
  if (!cardId || typeof cardId !== "string") {
    return NextResponse.json({ error: "Missing card." }, { status: 400 });
  }
  if (typeof rating !== "number" || !Number.isInteger(rating) || rating < 1 || rating > 5) {
    return NextResponse.json({ error: "Rating must be a whole number from 1 to 5." }, { status: 400 });
  }

  const db = getDb();
  const deck = await db.query.flashcardDecks.findFirst({
    where: and(eq(schema.flashcardDecks.id, deckId), eq(schema.flashcardDecks.userId, session.user.id)),
  });
  if (!deck) return NextResponse.json({ error: "Deck not found." }, { status: 404 });

  const card = await db.query.flashcards.findFirst({
    where: and(eq(schema.flashcards.id, cardId), eq(schema.flashcards.deckId, deckId)),
  });
  if (!card) return NextResponse.json({ error: "Card not found in this deck." }, { status: 404 });

  await db.insert(schema.flashcardReviews).values({
    cardId,
    userId: session.user.id,
    rating,
  });

  return NextResponse.json({ ok: true });
}
