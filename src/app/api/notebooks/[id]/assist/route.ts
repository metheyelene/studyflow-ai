import { headers } from "next/headers";
import { NextResponse } from "next/server";

import { auth } from "@/lib/auth";
import {
  AI_NOT_CONFIGURED_MESSAGE,
  AiNotConfiguredError,
  AiProviderError,
  generate,
} from "@/lib/ai/orchestrator";
import { getPlanForSession } from "@/lib/premium";
import { checkRateLimit } from "@/lib/rateLimit";
import { consumeAiAction } from "@/lib/usage";

export const runtime = "nodejs";

export const ASSIST_MODES = ["explain", "summarize", "simplify", "quiz"] as const;
export type AssistMode = (typeof ASSIST_MODES)[number];

const MAX_SELECTION = 4000;

const SYSTEM_PROMPTS: Record<AssistMode, string> = {
  explain:
    "You are StudyFlow's AI tutor. Explain the selected passage clearly at an undergraduate level, with a concrete example when it helps. Use plain, well-structured prose and do not quote the passage back verbatim. Keep the explanation under 250 words.",
  summarize:
    "You are StudyFlow's summarizer. Condense the selected passage into a tight summary that keeps every key point, definition, and conclusion. Use plain prose and under 150 words.",
  simplify:
    "You are StudyFlow's rewriter. Rewrite the selected passage in simpler, clearer language without losing any important detail or technical meaning. Prefer shorter sentences and everyday words where they do not reduce precision. Keep it under 200 words.",
  quiz:
    "You are StudyFlow's quiz maker. Create a short quiz from the selected passage: exactly 3 questions, each with 4 answer choices labeled A-D, the correct choice, and a one-line explanation. Format each question exactly like this:\nQ1. <question>\nA) <choice>  B) <choice>  C) <choice>  D) <choice>\nAnswer: <letter>\nWhy: <one-line explanation>\nDo not add anything else.",
};

interface AssistBody {
  mode?: string;
  text?: string;
}

/**
 * POST /api/notebooks/[id]/assist — transform selected note text.
 * The note editor's floating toolbar asks the AI to explain, summarize,
 * simplify, or quiz the user's selection and inserts the result back
 * into the editor. The endpoint is notebook-scoped so it shares the same
 * auth and AI-action metering as every other AI surface; the
 * transformation itself only needs the selected text. One AI action is
 * consumed per call (atomic, server-side).
 */
export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { id } = await params;
  if (!id) return NextResponse.json({ error: "Notebook id is required." }, { status: 400 });

  const body = (await request.json().catch(() => null)) as AssistBody | null;
  const mode = body?.mode as AssistMode | undefined;
  if (!mode || !ASSIST_MODES.includes(mode)) {
    return NextResponse.json({ error: "Unknown assist mode." }, { status: 400 });
  }
  const text = body?.text?.trim() ?? "";
  if (!text) {
    return NextResponse.json({ error: "Select some text first." }, { status: 400 });
  }
  if (text.length > MAX_SELECTION) {
    return NextResponse.json(
      { error: `Selection is too long (max ${MAX_SELECTION} characters).` },
      { status: 400 },
    );
  }

  // Abuse protection: a short per-minute ceiling on top of the monthly
  // allowance (docs: rate limiting / request quotas).
  const rate = checkRateLimit(session.user.id, "ai:assist");
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
    const result = await generate({
      feature: `assist:${mode}`,
      tier: "simple",
      system: SYSTEM_PROMPTS[mode],
      prompt: text,
      maxOutputTokens: 900,
      temperature: 0.3,
      log: { userId: session.user.id },
    });
    const answer = result.text.trim();
    if (!answer) {
      return NextResponse.json(
        { error: "The AI returned an empty result. Please try again." },
        { status: 502 },
      );
    }
    return NextResponse.json({ text: answer });
  } catch (err) {
    if (err instanceof AiNotConfiguredError) {
      return NextResponse.json({ error: AI_NOT_CONFIGURED_MESSAGE }, { status: 503 });
    }
    if (err instanceof AiProviderError) {
      return NextResponse.json(
        {
          error:
            "The AI service is temporarily unavailable. Please try again in a moment.",
        },
        { status: 502 },
      );
    }
    console.error("[assist:run]", err);
    return NextResponse.json({ error: "Failed to run that action." }, { status: 500 });
  }
}
