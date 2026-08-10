import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { z } from "zod";

import { auth } from "@/lib/auth";
import { trackEvent } from "@/lib/analytics";

const bodySchema = z.object({
  eventName: z.string().trim().min(1).max(100),
  properties: z.record(z.string(), z.unknown()).optional(),
});

/**
 * POST /api/analytics — record an event (app_opened, onboarding_completed,
 * paywall_viewed, …). Privacy-conscious: resolves the user server-side
 * from the session; works logged out too (userId is null for pre-auth
 * events). Tracking never fails the request.
 */
export async function POST(request: Request) {
  const body = (await request.json().catch(() => null)) as unknown;
  const parsed = bodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "eventName is required." }, { status: 400 });
  }

  const session = await auth.api.getSession({ headers: await headers() }).catch(() => null);
  await trackEvent(session?.user.id ?? null, parsed.data.eventName, parsed.data.properties);

  return NextResponse.json({ ok: true }, { status: 202 });
}
