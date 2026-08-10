/**
 * Minimal, ethical A/B testing infrastructure.
 *
 * Every experiment MUST be registered here before it can run, with a
 * hypothesis, metric, control/variant definitions, duration, and a
 * decision rule. Experiments that hide pricing, hide cancellation, or
 * make one group unknowingly pay more are forbidden by policy.
 *
 * Assignment is deterministic per user: a user always sees the same
 * variant of a given experiment (stable across requests) without any
 * cross-user state. Variants are picked from an env override first
 * (for manual QA), then by hashing the user id.
 */

export interface ExperimentVariant {
  id: string;
  weight: number; // relative weight; normalized against total
}

export interface Experiment {
  id: string;
  hypothesis: string;
  metric: string;
  variants: ExperimentVariant[];
  durationDays: number;
  decisionRule: string;
  startedAt: string; // ISO date; past = live
}

const EXPERIMENTS: Experiment[] = [
  // First candidate: pricing page presentation. Control = current layout
  // (comparison table, annual first). Variant = headline ordering only —
  // identical pricing, no deception.
  {
    id: "pricing-headline",
    hypothesis:
      "Leading with the hero feature (Smart Study Mode) rather than the price raises checkout starts without raising paywall views.",
    metric: "checkout_started / pricing_viewed",
    variants: [
      { id: "control", weight: 1 },
      { id: "hero-first", weight: 1 },
    ],
    durationDays: 14,
    decisionRule:
      "Adopt variant if lift ≥ +10% on the metric at 95% confidence; otherwise revert to control.",
    startedAt: "2026-08-10",
  },
];

/** List all registered experiments (for the admin panel / docs). */
export function listExperiments(): ReadonlyArray<Experiment> {
  return EXPERIMENTS;
}

/**
 * Deterministically assign a user to a variant of an experiment.
 * `forceVariant` lets an admin pin a variant via env for QA
 * (e.g. EXPERIMENT_pricing-headline=hero-first).
 */
export function getVariant(
  experimentId: string,
  userId: string,
): { experiment: Experiment; variant: ExperimentVariant } | null {
  const experiment = EXPERIMENTS.find((e) => e.id === experimentId);
  if (!experiment) return null;

  const override = process.env[`EXPERIMENT_${experimentId}`];
  if (override) {
    const forced = experiment.variants.find((v) => v.id === override);
    if (forced) return { experiment, variant: forced };
  }

  // Stable hash of (experiment, user) -> 0..1
  const key = `${experimentId}:${userId}`;
  let hash = 0;
  for (let i = 0; i < key.length; i++) {
    hash = (hash * 31 + key.charCodeAt(i)) >>> 0;
  }
  const total = experiment.variants.reduce((sum, v) => sum + v.weight, 0);
  const roll = (hash % 10000) / 10000; // 0..1

  let acc = 0;
  for (const variant of experiment.variants) {
    acc += variant.weight / total;
    if (roll < acc) return { experiment, variant };
  }
  return { experiment, variant: experiment.variants[0] };
}
