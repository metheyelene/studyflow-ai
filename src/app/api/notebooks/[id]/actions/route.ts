import { headers } from "next/headers";
import { NextResponse } from "next/server";

import { auth } from "@/lib/auth";
import { ACTION_NAMES, runAction, type ActionName, type ActionParams } from "@/lib/ai/actions";
import { AiNotConfiguredError, AiProviderError } from "@/lib/ai/orchestrator";
import { getPlanForSession } from "@/lib/premium";
import { consumeAiAction } from "@/lib/usage";

export const runtime = "nodejs";

interface ActionBody {
  action: string;
  params?: Record<string, string | number | boolean>;
}

/** POST /api/notebooks/[id]/actions — run a source-grounded study
 *  transformation (summarize, flashcards, quiz, studyGuide, …). One AI
 *  action per request, consumed atomically before generation. */
export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { id } = await params;
  const body = (await request.json().catch(() => null)) as ActionBody | null;
  const action = body?.action as ActionName | undefined;
  if (!action || !ACTION_NAMES.includes(action)) {
    return NextResponse.json({ error: "Unknown action." }, { status: 400 });
  }

  const planCtx = await getPlanForSession();
  const plan = planCtx?.plan ?? "free";
  const consumed = await consumeAiAction(session.user.id, plan);
  if (!consumed.allowed) {
    return NextResponse.json(
      {
        error: "You've used this month's free AI allowance. It resets at the start of next month — or upgrade for a much higher limit.",
      },
      { status: 429 },
    );
  }

  try {
    const params_: ActionParams = { ...(body?.params ?? {}) };
    const result = await runAction(action, { userId: session.user.id, notebookId: id }, params_);
    return NextResponse.json({ result });
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
    if (err instanceof Error && err.message.includes("no ready sources")) {
      return NextResponse.json({ error: err.message }, { status: 422 });
    }
    console.error("[actions:run]", err);
    return NextResponse.json({ error: "Failed to run that action." }, { status: 500 });
  }
}
