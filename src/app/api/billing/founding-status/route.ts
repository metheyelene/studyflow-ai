import { headers } from "next/headers";
import { NextResponse } from "next/server";

import { auth } from "@/lib/auth";
import { foundingOfferOpenFor, getFoundingStatusSafe } from "@/lib/founding";

/**
 * GET /api/billing/founding-status — the mobile app asks "is the
 * founding offer active for me, and how many slots remain?" The answer
 * is always backend-derived; the app never hard-codes the count or the
 * cap. `offer.active` is false once all 35 slots are claimed OR the
 * user already claimed, and `remaining` is only included when the
 * counter could actually be read (never invented on a DB outage).
 */
export async function GET() {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const [status, open] = await Promise.all([
    getFoundingStatusSafe(),
    foundingOfferOpenFor(session.user.id),
  ]);

  return NextResponse.json({
    offer: {
      active: open && !status.full,
      // Only surface counts the backend actually read.
      ...(status.available
        ? {
            remaining: status.remaining,
            claimed: status.claimed,
            cap: status.cap,
          }
        : {}),
    },
    status,
  });
}
