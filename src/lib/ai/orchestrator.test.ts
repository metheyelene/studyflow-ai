import { describe, expect, it } from "vitest";

import { AiNotConfiguredError, currentModelName, resolveModel } from "./orchestrator";

const KEYS = ["OPENAI_API_KEY", "ANTHROPIC_API_KEY", "AI_PROVIDER_ORDER", "AI_MODEL_SIMPLE"] as const;

function withEnv(env: Record<string, string | undefined>, fn: () => void): void {
  const saved = new Map<string, string | undefined>();
  for (const k of KEYS) {
    saved.set(k, process.env[k]);
    if (env[k] === undefined) delete process.env[k];
    else process.env[k] = env[k];
  }
  try {
    fn();
  } finally {
    for (const k of KEYS) {
      if (saved.get(k) === undefined) delete process.env[k];
      else process.env[k] = saved.get(k);
    }
  }
}

describe("resolveModel", () => {
  it("throws AiNotConfiguredError when no provider has a key", () => {
    withEnv({ OPENAI_API_KEY: undefined, ANTHROPIC_API_KEY: undefined }, () => {
      expect(() => resolveModel("standard")).toThrow(AiNotConfiguredError);
    });
  });

  it("uses the first configured provider by default order", () => {
    withEnv({ OPENAI_API_KEY: "sk-test", ANTHROPIC_API_KEY: undefined }, () => {
      const resolved = resolveModel("standard");
      expect(resolved.provider).toBe("openai");
      expect(resolved.model).toBe("gpt-4o-mini");
    });
  });

  it("honors AI_PROVIDER_ORDER for failover order", () => {
    withEnv({ OPENAI_API_KEY: "sk-o", ANTHROPIC_API_KEY: "sk-a", AI_PROVIDER_ORDER: "anthropic" }, () => {
      const resolved = resolveModel("standard");
      expect(resolved.provider).toBe("anthropic");
      expect(resolved.model).toBe("claude-3-5-haiku-latest");
    });
  });

  it("applies per-tier model overrides", () => {
    withEnv({ OPENAI_API_KEY: "sk-test", AI_MODEL_SIMPLE: "gpt-4.1-mini" }, () => {
      const resolved = resolveModel("simple");
      expect(resolved.model).toBe("gpt-4.1-mini");
      expect(resolveModel("standard").model).toBe("gpt-4o-mini");
    });
  });

  it("skips providers without keys in the failover chain", () => {
    withEnv({ OPENAI_API_KEY: undefined, ANTHROPIC_API_KEY: "sk-a" }, () => {
      const resolved = resolveModel("complex");
      expect(resolved.provider).toBe("anthropic");
      expect(resolved.model).toBe("claude-3-5-sonnet-latest");
    });
  });
});

describe("currentModelName", () => {
  it("returns unconfigured rather than throwing", () => {
    withEnv({ OPENAI_API_KEY: undefined, ANTHROPIC_API_KEY: undefined }, () => {
      expect(currentModelName()).toBe("unconfigured");
    });
  });
});
