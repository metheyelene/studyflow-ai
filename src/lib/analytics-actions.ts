"use server";

import { headers } from "next/headers";

import { auth } from "@/lib/auth";
import { trackEvent, type EventName } from "@/lib/analytics";

/** Client-callable analytics: resolves the user from the session
 *  server-side and records the event. Safe to call from any component. */
export async function trackEventAction(
  eventName: EventName | string,
  properties?: Record<string, unknown>,
): Promise<void> {
  const session = await auth.api.getSession({ headers: await headers() });
  await trackEvent(session?.user.id ?? null, eventName, properties);
}
