import { NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { getLimits } from "@/lib/plans";
import { getPlanForSession } from "@/lib/premium";
import { getAiUsage, periodKey, percentUsed, usageState } from "@/lib/usage";

/**
 * GET /api/usage — the AI-usage widget: used/limit/remaining, UX state,
 * when the meter resets, and the user's plan. Limits are resolved
 * server-side (free vs premium), never from the client. Also reports the
 * monthly audio-episode meter so the Podcast feature can show its own cap.
 */
export async function GET() {
  const planContext = await getPlanForSession();
  if (!planContext) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const usage = await getAiUsage(planContext.userId, planContext.plan);
  const audioLimit = getLimits(planContext.plan).audioEpisodesPerMonth;
  const row = await getDb().query.usage.findFirst({
    where: and(
      eq(schema.usage.userId, planContext.userId),
      eq(schema.usage.feature, "audio_episodes"),
      eq(schema.usage.period, periodKey()),
    ),
  });
  const audioUsed = row?.count ?? 0;
  const audio = {
    used: audioUsed,
    limit: audioLimit,
    remaining: Math.max(0, audioLimit - audioUsed),
    percent: percentUsed(audioUsed, audioLimit),
    state: usageState(audioUsed, audioLimit),
    resetsAt: usage.resetsAt,
  };
  return NextResponse.json({ plan: planContext.plan, usage, audio });
}
