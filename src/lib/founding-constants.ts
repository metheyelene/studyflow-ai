// Client-safe founding-member constants. This module must NEVER import
// server-only code (db drivers etc.) — it is imported by client
// components (founding-card.tsx) and bundled for the browser.
export const FOUNDING_TERMS = {
  /** Monthly price in USD — set server-side at checkout creation. */
  priceUsd: 2.0,
  planLabel: "Founding Member",
  /** Value stored in subscriptions.plan. */
  planStorage: "founding_member",
  /** Google Play subscription product (product id / base plan). */
  playProductId: "founding_member_monthly",
  /** Android application id (matches Flutter applicationId). */
  playPackageName: "ai.studyflow.studyflow_mobile",
} as const;
