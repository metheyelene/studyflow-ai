// ─────────────────────────────────────────────────────────────────────
// Single entry point for every AI call in the app.
//
// Phase 5 wires these hooks in:
//   - usage check (free/premium limits) via src/lib/usage.ts
//   - ai_requests row (tokens + cost) via src/lib/ai/logger.ts
//   - friendly error mapping (src/lib/errors.ts)
// For now this is the thin seam those land behind, so feature code
// written today won't need to change.
// ─────────────────────────────────────────────────────────────────────
import { generateText } from "ai";

import { getModel, currentModelName, currentProviderName } from "./provider";

export interface GenerateOptions {
  /** Feature name for usage metering + logging: summary | flashcards | quiz | qa | planner */
  feature: string;
  system?: string;
  prompt: string;
  maxOutputTokens?: number;
  temperature?: number;
}

export interface GenerateResult {
  text: string;
  provider: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
}

export async function generate(
  options: GenerateOptions,
): Promise<GenerateResult> {
  const model = getModel();

  const startedAt = Date.now();
  const { text, usage } = await generateText({
    model,
    system: options.system,
    prompt: options.prompt,
    maxOutputTokens: options.maxOutputTokens ?? 2048,
    temperature: options.temperature ?? 0.7,
  });
  const latencyMs = Date.now() - startedAt;

  // TODO(Phase 5): log to ai_requests (tokens, cost, latency) and
  // increment the user's usage meter. See src/lib/ai/logger.ts.
  void latencyMs;

  return {
    text,
    provider: currentProviderName(),
    model: currentModelName(),
    inputTokens: usage?.inputTokens ?? 0,
    outputTokens: usage?.outputTokens ?? 0,
  };
}
