// ─────────────────────────────────────────────────────────────────────
// Free / Premium limits — SINGLE SOURCE OF TRUTH.
// The paywall, the usage metering (lib/usage.ts), and the "AI usage
// remaining" dashboard all import from here. Never duplicate these
// numbers anywhere else.
//
// Rationale for every number: docs/plans-and-limits.md.
// ─────────────────────────────────────────────────────────────────────

export type Plan = "free" | "premium";

export interface PlanLimits {
  /** Master AI meter: every AI generation (summary, deck, quiz, QA, AI
   *  planner) costs 1 action. Resets monthly. */
  aiActionsPerMonth: number;
  /** Lifetime cap on document uploads (PDFs). Counts rows in documents
   *  where status != 'failed'. Never resets. */
  documentsLifetime: number;
  /** Lifetime cap on subjects. Never resets. */
  subjectsLifetime: number;
  /** Lifetime cap on notebooks (source-grounded AI). Never resets. */
  notebooksLifetime: number;
  /** Per-notebook cap on sources. */
  sourcesPerNotebook: number;
  /** Fair-use ceiling on flashcard cards per month (≈ generations ×
   *  cards-per-generation). Enforced for free; a monitoring ceiling for
   *  premium, never shown as a hard wall. */
  flashcardCardsPerMonth: number;
  /** Hard caps enforced at the API layer. */
  maxQuizQuestions: number;
  maxFlashcardsPerGeneration: number;
  maxInputTokensPerGeneration: number;
  /** Feature gates. */
  aiPlanner: boolean;
  premiumThemes: boolean;
}

export const PLANS: Record<Plan, PlanLimits> = {
  free: {
    aiActionsPerMonth: 20,
    documentsLifetime: 3,
    subjectsLifetime: 1,
    notebooksLifetime: 3,
    sourcesPerNotebook: 10,
    flashcardCardsPerMonth: 100,
    maxQuizQuestions: 10,
    maxFlashcardsPerGeneration: 20,
    maxInputTokensPerGeneration: 4_000,
    aiPlanner: false,
    premiumThemes: false,
  },
  premium: {
    aiActionsPerMonth: 500,
    documentsLifetime: 50,
    subjectsLifetime: 20,
    notebooksLifetime: 20,
    sourcesPerNotebook: 50,
    flashcardCardsPerMonth: 1_000,
    maxQuizQuestions: 20,
    maxFlashcardsPerGeneration: 30,
    maxInputTokensPerGeneration: 4_000,
    aiPlanner: true,
    premiumThemes: true,
  },
};

/** Premium ⇔ an active (or trialing) subscription. Computed server-side;
 *  never trust a client-supplied flag. */
export function getPlan(isPremium: boolean): Plan {
  return isPremium ? "premium" : "free";
}

export function getLimits(plan: Plan): PlanLimits {
  return PLANS[plan];
}

export const PRICING = {
  monthlyUsd: 4.99,
  yearlyUsd: 39.99,
} as const;

/** Human-readable summary strings — used by the paywall and pricing UI.
 *  Keep in sync with PLANS above. */
export const PLAN_COPY: Record<Plan, { name: string; features: string[] }> = {
  free: {
    name: "Free",
    features: [
      "20 AI actions / month",
      "3 document uploads",
      "1 subject",
      "Basic study planner",
    ],
  },
  premium: {
    name: "Premium",
    features: [
      "500 AI actions / month",
      "50 document uploads",
      "20 subjects",
      "AI study planner",
      "Premium themes",
      "Cancel anytime",
    ],
  },
};
