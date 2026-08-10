import { headers } from "next/headers";
import { NextResponse } from "next/server";

import { auth } from "@/lib/auth";
import { BillingNotConfigured, createFoundingCheckoutSession } from "@/lib/billing";
import { foundingOfferOpenFor } from "@/lib/founding";

/**
 * POST /api/billing/checkout — starts the founding-member checkout.
 * Server-side only: the session is created with a fixed price, and the
 * offer is refused once the 35-slot cap is reached. Never trusts a
 * client-supplied amount or membership count.
 */
export async function POST() {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const open = await foundingOfferOpenFor(session.user.id);
  if (!open) {
    return NextResponse.json(
      { error: "founding offer is full or already claimed" },
      { status: 409 },
    );
  }

  try {
    const { url } = await createFoundingCheckoutSession({
      userId: session.user.id,
      email: session.user.email,
    });
    return NextResponse.json({ url });
  } catch (err) {
    if (err instanceof BillingNotConfigured) {
      return NextResponse.json(
        { error: "billing not configured" },
        { status: 503 },
      );
    }
    console.error("[billing] checkout failed:", err);
    return NextResponse.json(
      { error: "checkout failed" },
      { status: 500 },
    );
  }
}
