import { NextRequest, NextResponse } from "next/server";

import { handlePlayRtdn, rtdnAuthorized } from "@/lib/playBilling";

/**
 * POST /api/webhooks/play — Google Play Real-time Developer
 * Notifications via Pub/Sub push. Pub/Sub posts a JSON envelope whose
 * `message.data` is base64-encoded; signature/attribution handling lives
 * in lib/playBilling.ts. Always acknowledge handled notifications so
 * Pub/Sub stops retrying; malformed payloads get a 400.
 */
export async function POST(req: NextRequest) {
  if (!rtdnAuthorized({ headers: req.headers })) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  let body: Record<string, unknown>;
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    return NextResponse.json({ error: "invalid body" }, { status: 400 });
  }

  const result = await handlePlayRtdn(body);
  return NextResponse.json(
    result.ok ? {} : { error: result.message },
    { status: result.status },
  );
}
