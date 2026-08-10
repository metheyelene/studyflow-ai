// ─────────────────────────────────────────────────────────────────────
// Provider-agnostic AI layer.
//
// Change providers by editing ONE env var (AI_PROVIDER) — no code
// changes anywhere else in the app. Feature code (summary, flashcards,
// quiz, qa, planner) only ever calls `generate()` from ./generate and
// never imports a provider SDK directly.
//
// To add a provider: 1) npm install its @ai-sdk package, 2) add a case
// here, 3) add the model name below. Done.
// ─────────────────────────────────────────────────────────────────────
import { anthropic } from "@ai-sdk/anthropic";
import { openai } from "@ai-sdk/openai";
import type { LanguageModel } from "ai";

export type AIProviderName = "openai" | "anthropic";

export const AI_PROVIDERS = ["openai", "anthropic"] as const;

interface ProviderConfig {
  model: string;
  provider: () => LanguageModel;
}

const PROVIDERS: Record<AIProviderName, ProviderConfig> = {
  openai: {
    model: "gpt-4o-mini",
    provider: () => openai("gpt-4o-mini"),
  },
  anthropic: {
    model: "claude-3-5-haiku-latest",
    provider: () => anthropic("claude-3-5-haiku-latest"),
  },
};

export const DEFAULT_PROVIDER: AIProviderName = "openai";

export function currentProviderName(): AIProviderName {
  const name = process.env.AI_PROVIDER as AIProviderName | undefined;
  if (name && name in PROVIDERS) return name;
  return DEFAULT_PROVIDER;
}

/** The LanguageModel for the configured provider. Throws a friendly
 *  error if the provider's API key is missing. */
export function getModel(): LanguageModel {
  const name = currentProviderName();
  const config = PROVIDERS[name];

  const keyVar = name === "openai" ? "OPENAI_API_KEY" : "ANTHROPIC_API_KEY";
  if (!process.env[keyVar]) {
    throw new Error(
      `${keyVar} is not set. Add your API key to .env (see .env.example) ` +
        `or set AI_PROVIDER to the provider you have a key for.`,
    );
  }

  return config.provider();
}

export function currentModelName(): string {
  return PROVIDERS[currentProviderName()].model;
}
