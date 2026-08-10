import { headers } from "next/headers";
import { NextResponse } from "next/server";

import { auth } from "@/lib/auth";
import { findCitations, prepareGrounded, stripFabricatedMarkers, type Citation } from "@/lib/ai/grounded";
import { stream } from "@/lib/ai/orchestrator";
import { getPlanForSession } from "@/lib/premium";
import { consumeAiAction, type AiUsage } from "@/lib/usage";

export const runtime = "nodejs";

interface ChatBody {
  question?: string;
  mode?: "sources" | "study";
  sourceIds?: string[];
  history?: Array<{ role: "user" | "assistant"; content: string }>;
}

/**
 * POST /api/notebooks/[id]/chat — streaming grounded chat.
 * Response: the answer text stream, followed by a trailer line
 * `__SF_CITATIONS__{json}` with { citations, stripped, provider, model }.
 * One AI action is consumed per turn (atomic, server-side).
 */
export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { id } = await params;
  const body = (await request.json().catch(() => null)) as ChatBody | null;
  const question = body?.question?.trim() ?? "";
  if (!question) return NextResponse.json({ error: "A question is required." }, { status: 400 });
  if (question.length > 2000) {
    return NextResponse.json({ error: "Question is too long (max 2000 chars)." }, { status: 400 });
  }

  let prepared;
  try {
    prepared = await prepareGrounded(session.user.id, id, question, {
      mode: body?.mode === "study" ? "study" : "sources",
      sourceIds: Array.isArray(body?.sourceIds) ? body.sourceIds.map(String) : undefined,
      history: body?.history,
    });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Failed to prepare an answer." },
      { status: 422 },
    );
  }

  // Meter only after retrieval succeeded — failed attempts don't burn allowance.
  const planCtx = await getPlanForSession();
  const plan = planCtx?.plan ?? "free";
  const consumed = await consumeAiAction(session.user.id, plan);
  if (!consumed.allowed) {
    return NextResponse.json(
      {
        error: "You've used this month's free AI allowance. It resets at the start of next month — or upgrade for a much higher limit.",
        usage: consumed.usage satisfies AiUsage,
      },
      { status: 429 },
    );
  }

  // Citation validation happens when generation finishes; the trailer is
  // appended to the response stream after the text.
  let resolveTrailer!: (t: Trailer) => void;
  const trailerPromise = new Promise<Trailer>((resolve) => {
    resolveTrailer = resolve;
  });

  const { result, meta } = await stream({
    feature: "qa",
    tier: "standard",
    system: prepared.system,
    prompt: prepared.prompt,
    temperature: 0.3,
    maxOutputTokens: 1200,
    onFinish: ({ text, usage }) => {
      const stripped = stripFabricatedMarkers(text ?? "", prepared.validMarkers).stripped;
      const citations = findCitations(text ?? "", prepared.markerToChunk);
      resolveTrailer({
        citations,
        stripped,
        provider: meta.provider,
        model: meta.model,
        inputTokens: usage?.inputTokens ?? 0,
        outputTokens: usage?.outputTokens ?? 0,
      });
    },
  });

  const encoder = new TextEncoder();
  const streamBody = new ReadableStream<Uint8Array>({
    async start(controller) {
      const reader = result.textStream.getReader();
      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          controller.enqueue(encoder.encode(value));
        }
      } catch {
        // Mid-stream provider failure: send a friendly trailer instead of dying.
        resolveTrailer({
          citations: [],
          stripped: [],
          provider: meta.provider,
          model: meta.model,
          inputTokens: 0,
          outputTokens: 0,
        });
      } finally {
        reader.releaseLock();
      }
      const trailer = await trailerPromise;
      controller.enqueue(
        encoder.encode(
          "\n\n__SF_CITATIONS__" +
            JSON.stringify({
              citations: trailer.citations,
              stripped: trailer.stripped,
              provider: trailer.provider,
              model: trailer.model,
            }),
        ),
      );
      controller.close();
    },
  });

  return new Response(streamBody, {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      "X-Accel-Buffering": "no",
    },
  });
}

interface Trailer {
  citations: Citation[];
  stripped: number[];
  provider: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
}
