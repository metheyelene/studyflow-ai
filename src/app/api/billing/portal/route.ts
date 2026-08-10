import { headers } from "next/headers";
import { NextResponse } from "next/server";

import { eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";
import { BillingNotConfigured, createBillingPortalSession } from "@/lib/billing";

/** POST /api/billing/portal — opens Stripe's billing portal for the
 *  authenticated user (official subscription management: cancel, update
 *  payment method, etc.). Never client-side. */
export async function POST() {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const db = getDb();
  const sub = await db.query.subscriptions.findFirst({
    where: eq(schema.subscriptions.userId, session.user.id),
  });
  if (!sub?.stripeCustomerId) {
    return NextResponse.json(
      { error: "no active subscription" },
      { status: 404 },
    );
  }

  try {
    const { url } = await createBillingPortalSession({
      stripeCustomerId: sub.stripeCustomerId,
    });
    return NextResponse.json({ url });
  } catch (err) {
    if (err instanceof BillingNotConfigured) {
      return NextResponse.json(
        { error: "billing not configured" },
        { status: 503 },
      );
    }
    console.error("[billing] portal failed:", err);
    return NextResponse.json({ error: "portal failed" }, { status: 500 });
  }
}
