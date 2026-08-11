import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";

export const runtime = "nodejs";

/** Ownership-checked deck fetch. Returns null when missing or not owned. */
async function deckForUser(userId: string, deckId: string) {
  const db = getDb();
  return db.query.flashcardDecks.findFirst({
    where: and(eq(schema.flashcardDecks.id, deckId), eq(schema.flashcardDecks.userId, userId)),
  });
}

/** GET /api/flashcards/[deckId] — the deck and its cards, in study order. */
export async function GET(_request: Request, { params }: { params: Promise<{ deckId: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { deckId } = await params;
  const deck = await deckForUser(session.user.id, deckId);
  if (!deck) return NextResponse.json({ error: "Deck not found." }, { status: 404 });

  const cards = await getDb()
    .query.flashcards.findMany({
      where: eq(schema.flashcards.deckId, deckId),
      orderBy: (c, { asc }) => [asc(c.order), asc(c.createdAt)],
    })
    .then((rows) =>
      rows.map((c) => ({
        id: c.id,
        front: c.front,
        back: c.back,
        order: c.order,
      })),
    );

  return NextResponse.json({
    deck: {
      id: deck.id,
      title: deck.title,
      notebookId: deck.notebookId,
      cardCount: cards.length,
      createdAt: deck.createdAt.toISOString(),
      updatedAt: deck.updatedAt.toISOString(),
    },
    cards,
  });
}

/** DELETE /api/flashcards/[deckId] — remove the deck and its cards. */
export async function DELETE(_request: Request, { params }: { params: Promise<{ deckId: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { deckId } = await params;
  const deck = await deckForUser(session.user.id, deckId);
  if (!deck) return NextResponse.json({ error: "Deck not found." }, { status: 404 });

  await getDb().delete(schema.flashcardDecks).where(eq(schema.flashcardDecks.id, deckId));
  return NextResponse.json({ ok: true });
}
