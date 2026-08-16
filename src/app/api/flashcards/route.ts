import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { count, eq, inArray } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";
import {
  AI_NOT_CONFIGURED_MESSAGE,
  AiNotConfiguredError,
  AiProviderError,
} from "@/lib/ai/orchestrator";
import { runAction, type ActionName } from "@/lib/ai/actions";
import { NotFoundError, getNotebookForUser } from "@/lib/ai/sources";
import { getPlanForSession } from "@/lib/premium";
import { checkRateLimit } from "@/lib/rateLimit";
import { consumeAiAction } from "@/lib/usage";

export const runtime = "nodejs";

interface GenerateBody {
  notebookId: string;
  title?: string;
}

/** Serialize a deck row + card count into the API shape. */
function deckJson(deck: typeof schema.flashcardDecks.$inferSelect, cardCount: number) {
  return {
    id: deck.id,
    title: deck.title,
    notebookId: deck.notebookId,
    cardCount,
    createdAt: deck.createdAt.toISOString(),
    updatedAt: deck.updatedAt.toISOString(),
  };
}

/** GET /api/flashcards — the signed-in user's decks, newest first. */
export async function GET() {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  try {
    const db = getDb();
    const decks = await db.query.flashcardDecks.findMany({
      where: eq(schema.flashcardDecks.userId, session.user.id),
      orderBy: (d, { desc }) => [desc(d.updatedAt)],
    });

    const counts = new Map<string, number>();
    if (decks.length > 0) {
      const rows = await db
        .select({ deckId: schema.flashcards.deckId, count: count() })
        .from(schema.flashcards)
        .where(inArray(schema.flashcards.deckId, decks.map((d) => d.id)))
        .groupBy(schema.flashcards.deckId);
      for (const row of rows) counts.set(row.deckId, row.count);
    }

    return NextResponse.json({
      decks: decks.map((d) => deckJson(d, counts.get(d.id) ?? 0)),
    });
  } catch (err) {
    console.error("[flashcards:list]", err);
    return NextResponse.json({ error: "Failed to load your flashcard decks." }, { status: 500 });
  }
}

/**
 * POST /api/flashcards — generate a source-grounded deck from a notebook
 * and persist it atomically. One AI action per request, consumed before
 * generation (same quota as the notebook actions route). The cards are the
 * AI's validated output — structurally invalid or fabricated cards are
 * dropped upstream in `runAction`, never persisted.
 */
export async function POST(request: Request) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const body = (await request.json().catch(() => null)) as GenerateBody | null;
  const notebookId = body?.notebookId;
  if (!notebookId || typeof notebookId !== "string") {
    return NextResponse.json({ error: "Pick a notebook to generate from." }, { status: 400 });
  }

  // Abuse protection: a short per-minute ceiling on top of the monthly
  // allowance (docs: rate limiting / request quotas).
  const rate = checkRateLimit(session.user.id, "ai:flashcards");
  if (!rate.allowed) {
    return NextResponse.json(
      {
        error:
          "You're sending requests too quickly. Please slow down and try again in a moment.",
      },
      {
        status: 429,
        headers: { "Retry-After": String(Math.ceil(rate.retryAfterMs / 1000)) },
      },
    );
  }

  let notebook;
  try {
    notebook = await getNotebookForUser(session.user.id, notebookId);
  } catch (err) {
    if (err instanceof NotFoundError) {
      return NextResponse.json({ error: "Notebook not found." }, { status: 404 });
    }
    console.error("[flashcards:owner]", err);
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
      "flashcards" as ActionName,
      { userId: session.user.id, notebookId },
      {},
    );
    const cards = (result.data as { cards: { front: string; back: string }[] }).cards;
    if (!Array.isArray(cards) || cards.length === 0) {
      return NextResponse.json(
        { error: "The AI couldn't build cards from this material. Add more sources and try again." },
        { status: 422 },
      );
    }

    const db = getDb();
    const title = body?.title?.trim() || `${notebook.title} flashcards`;
    const deck = await db.transaction(async (tx) => {
      const [inserted] = await tx
        .insert(schema.flashcardDecks)
        .values({
          userId: session.user.id,
          notebookId,
          title: title.slice(0, 100),
        })
        .returning();
      if (cards.length > 0) {
        await tx.insert(schema.flashcards).values(
          cards.map((card, i) => ({
            deckId: inserted.id,
            front: card.front.slice(0, 2000),
            back: card.back.slice(0, 4000),
            order: i,
          })),
        );
      }
      return inserted;
    });

    return NextResponse.json({
      deck: deckJson(deck, cards.length),
      cards: cards.map((card, i) => ({ ...card, order: i })),
    });
  } catch (err) {
    if (err instanceof AiNotConfiguredError) {
      return NextResponse.json({ error: AI_NOT_CONFIGURED_MESSAGE }, { status: 503 });
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
    console.error("[flashcards:generate]", err);
    return NextResponse.json({ error: "Failed to generate flashcards." }, { status: 500 });
  }
}
