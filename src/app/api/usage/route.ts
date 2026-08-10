import { NextResponse } from "next/server";

import { getPlanForSession } from "@/lib/premium";
import { getAiUsage } from "@/lib/usage";

/**
 * GET /api/usage — the AI-usage widget: used/limit/remaining, UX state,
 * when the meter resets, and the user's plan. Limits are resolved
 * server-side (free vs premium), never from the client.
 */
export async function GET() {
  const planContext = await getPlanForSession();
  if (!planContext) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const usage = await getAiUsage(planContext.userId, planContext.plan);
  return NextResponse.json({ plan: planContext.plan, usage });
}
