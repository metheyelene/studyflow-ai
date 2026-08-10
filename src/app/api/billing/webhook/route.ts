import { NextRequest, NextResponse } from "next/server";

import { handleStripeWebhook } from "@/lib/billing";

/**
 * Stripe webhook endpoint. Stripe posts raw JSON; we must pass the RAW
 * body (not the parsed JSON) to constructEvent for signature verification.
 */
export async function POST(req: NextRequest) {
  const payload = await req.text();
  const signature = req.headers.get("stripe-signature");
  if (!signature) {
    return NextResponse.json(
      { error: "missing stripe-signature header" },
      { status: 400 },
    );
  }

  const result = await handleStripeWebhook(payload, signature);
  return NextResponse.json(
    result.ok ? {} : { error: result.message },
    { status: result.status },
  );
}
