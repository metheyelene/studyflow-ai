// ─────────────────────────────────────────────────────────────────────
// AIProviderManager — the single seam between StudyFlow and AI models.
//
//  - Task-tiered routing: simple / standard / complex tasks map to
//    progressively stronger (and more expensive) models. Per-tier env
//    overrides (AI_MODEL_SIMPLE|STANDARD|COMPLEX) let the model lineup
//    change without code edits.
//  - Free-first ordering: AI_PROVIDER_ORDER controls failover order
//    (default "openai,anthropic"); the first provider with a key is
//    used, and transient failures fall through to the next.
//  - Never exposes provider internals to users: all failures surface as
//    AiNotConfiguredError / AiProviderError with friendly messages.
//  - Every successful call optionally logs an ai_requests row (tokens,
//    latency, estimated cost) when `log` is supplied.
//
// Feature code never imports a provider SDK — it calls generate() /
// generateJson() / stream() from here or the higher-level actions in
// ./grounded.ts and ./actions.ts.
// ─────────────────────────────────────────────────────────────────────
import { anthropic } from "@ai-sdk/anthropic";
import { openai } from "@ai-sdk/openai";
import { generateObject, generateText, streamText, type LanguageModel } from "ai";
import type { z } from "zod";

import { getDb, schema } from "@/db";
import { healthyProviderOrder, recordProviderFailure, recordProviderSuccess } from "./health";

export type TaskTier = "simple" | "standard" | "complex";
export type AIProviderName = "openai" | "anthropic";

export const TIERS: TaskTier[] = ["simple", "standard", "complex"];
export const PROVIDER_NAMES: AIProviderName[] = ["openai", "anthropic"];

export class AiNotConfiguredError extends Error {
  constructor(public readonly missingKeys: string[]) {
    super(
      "AI is not configured. Add an API key for one of: " + missingKeys.join(", ") +
        " (see docs/environment-variables.md).",
    );
    this.name = "AiNotConfiguredError";
  }
}

export class AiProviderError extends Error {
  constructor(message: string, cause?: unknown) {
    super(message, cause === undefined ? undefined : { cause });
    this.name = "AiProviderError";
  }
}

/**
 * User-facing copy when no provider is configured. Never reveals which
 * keys are missing — that detail stays in server logs (zero-config UX:
 * users see "StudyFlow is temporarily unavailable", never
 * "OPENAI_API_KEY" or a docs URL).
 */
export const AI_NOT_CONFIGURED_MESSAGE =
  "AI is temporarily unavailable. Please try again shortly.";

interface ProviderConfig {
  keyVar: string;
  models: Record<TaskTier, string>;
  makeModel: (model: string) => LanguageModel;
  /** Approximate $ per 1K tokens [input, output] — used for cost
   *  estimates in ai_requests. Update when models change. */
  costPer1K: Record<TaskTier, [number, number]>;
}

const PROVIDERS: Record<AIProviderName, ProviderConfig> = {
  openai: {
    keyVar: "OPENAI_API_KEY",
    models: { simple: "gpt-4o-mini", standard: "gpt-4o-mini", complex: "gpt-4o" },
    makeModel: (m) => openai(m),
    costPer1K: { simple: [0.00015, 0.0006], standard: [0.00015, 0.0006], complex: [0.0025, 0.01] },
  },
  anthropic: {
    keyVar: "ANTHROPIC_API_KEY",
    models: {
      simple: "claude-3-5-haiku-latest",
      standard: "claude-3-5-haiku-latest",
      complex: "claude-3-5-sonnet-latest",
    },
    makeModel: (m) => anthropic(m),
    costPer1K: { simple: [0.0008, 0.004], standard: [0.0008, 0.004], complex: [0.003, 0.015] },
  },
};

function providerOrder(): AIProviderName[] {
  const raw = process.env.AI_PROVIDER_ORDER?.split(",").map((s) => s.trim().toLowerCase()) ?? [];
  const valid = raw.filter((n): n is AIProviderName => (PROVIDER_NAMES as string[]).includes(n));
  // Preserve configured order, then append any unlisted providers.
  const rest = PROVIDER_NAMES.filter((n) => !valid.includes(n));
  // Adaptive routing: healthy providers first, degraded ones sunk to the
  // end (still usable as last-resort fallbacks).
  return healthyProviderOrder([...valid, ...rest]);
}

function envModelOverride(tier: TaskTier): string | null {
  const key = `AI_MODEL_${tier.toUpperCase()}`;
  return process.env[key]?.trim() || null;
}

interface ResolvedModel {
  provider: AIProviderName;
  model: string;
  languageModel: LanguageModel;
}

/** Pick the first configured provider (with its API key present) for a
 *  tier. Throws AiNotConfiguredError when no provider has a key. */
export function resolveModel(tier: TaskTier): ResolvedModel {
  const missing: string[] = [];
  for (const name of providerOrder()) {
    const config = PROVIDERS[name];
    if (!process.env[config.keyVar]) {
      missing.push(config.keyVar);
      continue;
    }
    const model = envModelOverride(tier) ?? config.models[tier];
    return { provider: name, model, languageModel: config.makeModel(model) };
  }
  throw new AiNotConfiguredError(missing);
}

export interface GenerateOptions {
  /** Feature name for ai_requests + usage: summary | flashcards | quiz | qa | ... */
  feature: string;
  tier?: TaskTier;
  system?: string;
  prompt: string;
  maxOutputTokens?: number;
  temperature?: number;
  /** When set, logs an ai_requests row (best-effort, never fatal). */
  log?: { userId: string };
}

export interface GenerateResult {
  text: string;
  provider: AIProviderName;
  model: string;
  inputTokens: number;
  outputTokens: number;
  costUsd: string;
  latencyMs: number;
}

function estimateCost(provider: AIProviderName, tier: TaskTier, input: number, output: number): string {
  const [pi, po] = PROVIDERS[provider].costPer1K[tier];
  return ((input / 1000) * pi + (output / 1000) * po).toFixed(6);
}

async function logRequest(
  log: { userId: string },
  feature: string,
  result: Omit<Pick<GenerateResult, "provider" | "model" | "inputTokens" | "outputTokens" | "costUsd" | "latencyMs">, "provider"> & { provider: string },
  status: "success" | "error",
  errorCode?: string,
): Promise<void> {
  try {
    const db = getDb();
    await db.insert(schema.aiRequests).values({
      userId: log.userId,
      provider: result.provider,
      model: result.model,
      feature,
      inputTokens: result.inputTokens,
      outputTokens: result.outputTokens,
      costUsd: result.costUsd,
      status,
      errorCode,
      latencyMs: result.latencyMs,
    });
  } catch {
    // Logging must never break a generation.
  }
}

/**
 * Plain-text generation with provider failover. Throws AiNotConfiguredError
 * (no key anywhere) or AiProviderError (all providers failed).
 */
export async function generate(options: GenerateOptions): Promise<GenerateResult> {
  const startedAt = Date.now();
  const errors: string[] = [];

  for (const name of providerOrder()) {
    const config = PROVIDERS[name];
    if (!process.env[config.keyVar]) continue;
    const model = envModelOverride(options.tier ?? "standard") ?? config.models[options.tier ?? "standard"];
    try {
      const { text, usage } = await generateText({
        model: config.makeModel(model),
        system: options.system,
        prompt: options.prompt,
        maxOutputTokens: options.maxOutputTokens ?? 2048,
        temperature: options.temperature ?? 0.7,
      });
      const result: GenerateResult = {
        text,
        provider: name,
        model,
        inputTokens: usage?.inputTokens ?? 0,
        outputTokens: usage?.outputTokens ?? 0,
        costUsd: estimateCost(name, options.tier ?? "standard", usage?.inputTokens ?? 0, usage?.outputTokens ?? 0),
        latencyMs: Date.now() - startedAt,
      };
      if (options.log) {
        await logRequest(options.log, options.feature, result, "success");
      }
      recordProviderSuccess(name);
      return result;
    } catch (err) {
      recordProviderFailure(name);
      errors.push(`${name}: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  if (options.log) {
    await logRequest(
      options.log,
      options.feature,
      { provider: "unknown", model: "unknown", inputTokens: 0, outputTokens: 0, costUsd: "0", latencyMs: Date.now() - startedAt },
      "error",
      "all-providers-failed",
    );
  }
  throw new AiProviderError(
    "AI generation failed after trying all configured providers. Please try again.",
    errors.join(" | "),
  );
}

/** Structured generation (zod schema) with failover. Throws on invalid
 *  output so callers can discard rather than present garbage. The data
 *  is typed as unknown because AI SDK output types vary by SDK version;
 *  callers validate against their zod schema. */
export async function generateJson<S extends z.ZodType>(
  options: GenerateOptions & { schema: S },
): Promise<GenerateResult & { data: unknown }> {
  const startedAt = Date.now();
  const errors: string[] = [];
  const tier = options.tier ?? "standard";

  for (const name of providerOrder()) {
    const config = PROVIDERS[name];
    if (!process.env[config.keyVar]) continue;
    const model = envModelOverride(tier) ?? config.models[tier];
    try {
      const { object, usage } = await generateObject({
        model: config.makeModel(model),
        schema: options.schema,
        system: options.system,
        prompt: options.prompt,
        maxOutputTokens: options.maxOutputTokens ?? 2048,
        temperature: options.temperature ?? 0.7,
      });
      const result = {
        text: "",
        data: object,
        provider: name,
        model,
        inputTokens: usage?.inputTokens ?? 0,
        outputTokens: usage?.outputTokens ?? 0,
        costUsd: estimateCost(name, tier, usage?.inputTokens ?? 0, usage?.outputTokens ?? 0),
        latencyMs: Date.now() - startedAt,
      };
      if (options.log) await logRequest(options.log, options.feature, result, "success");
      recordProviderSuccess(name);
      return result;
    } catch (err) {
      recordProviderFailure(name);
      errors.push(`${name}: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  throw new AiProviderError(
    "Structured AI generation failed after trying all providers.",
    errors.join(" | "),
  );
}

export interface StreamOptions {
  feature: string;
  tier?: TaskTier;
  system?: string;
  prompt: string;
  maxOutputTokens?: number;
  temperature?: number;
  /** Called when generation completes (used for citation validation). */
  onFinish?: (info: {
    text?: string;
    usage?: { inputTokens?: number; outputTokens?: number };
  }) => void;
}

/**
 * Streaming generation. Provider + model are resolved BEFORE streaming
 * starts (so missing keys fail fast with a friendly error); mid-stream
 * provider failure is surfaced as a stream error event. Returns the
 * AI SDK stream plus the resolved metadata for logging.
 */
export async function stream(options: StreamOptions) {
  const resolved = resolveModel(options.tier ?? "standard");
  const startedAt = Date.now();
  const result = streamText({
    model: resolved.languageModel,
    system: options.system,
    prompt: options.prompt,
    maxOutputTokens: options.maxOutputTokens ?? 2048,
    temperature: options.temperature ?? 0.7,
    onFinish: options.onFinish,
  });
  return {
    result,
    meta: { provider: resolved.provider, model: resolved.model, startedAt },
  };
}

export function currentModelName(tier: TaskTier = "standard"): string {
  try {
    return resolveModel(tier).model;
  } catch {
    return "unconfigured";
  }
}
