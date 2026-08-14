import { headers } from "next/headers";
import { NextRequest, NextResponse } from "next/server";

import { auth } from "@/lib/auth";
import { fulfillPlayFoundingPurchase } from "@/lib/playBilling";

/**
 * POST /api/billing/play/verify — the mobile app sends the Google Play
 * purchase token; the backend verifies it against the Play Developer
 * API and routes through the atomic founding claim. The client never
 * unlocks anything itself — entitlement is derived from the response
 * (and the subscriptions row it writes) only.
 */
export async function POST(req: NextRequest) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  let body: Record<string, unknown>;
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    return NextResponse.json({ error: "invalid body" }, { status: 400 });
  }

  const { packageName, productId, purchaseToken } = body;
  if (
    typeof packageName !== "string" ||
    typeof productId !== "string" ||
    typeof purchaseToken !== "string" ||
    !packageName ||
    !productId ||
    !purchaseToken
  ) {
    return NextResponse.json(
      { error: "packageName, productId and purchaseToken are required" },
      { status: 400 },
    );
  }

  const result = await fulfillPlayFoundingPurchase({
    userId: session.user.id,
    packageName,
    productId,
    purchaseToken,
  });

  return NextResponse.json(
    result.ok ? { ok: true, plan: result.plan } : { error: result.message },
    { status: result.status },
  );
}
