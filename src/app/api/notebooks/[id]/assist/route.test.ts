import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("next/headers", () => ({
  headers: () => new Headers(),
}));

vi.mock("@/db", () => ({ getDb: () => ({}), schema: {} }));

vi.mock("@/lib/auth", () => ({
  auth: { api: { getSession: vi.fn() } },
}));

// Keep the real error classes (instanceof checks in the route) but stub
// the generation call.
vi.mock("@/lib/ai/orchestrator", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/ai/orchestrator")>();
  return { ...actual, generate: vi.fn() };
});

vi.mock("@/lib/usage", () => ({
  consumeAiAction: vi.fn(),
}));

vi.mock("@/lib/premium", () => ({
  getPlanForSession: vi.fn(),
}));

import { POST } from "@/app/api/notebooks/[id]/assist/route";
import {
  AI_NOT_CONFIGURED_MESSAGE,
  AiNotConfiguredError,
  AiProviderError,
  generate,
} from "@/lib/ai/orchestrator";
import { auth } from "@/lib/auth";
import { getPlanForSession } from "@/lib/premium";
import { resetRateLimits } from "@/lib/rateLimit";
import { consumeAiAction } from "@/lib/usage";

const session = { user: { id: "user_1", name: "Test", email: "t@example.com" } };

function makeRequest(body?: unknown) {
  return new Request("http://localhost/api/notebooks/nb-1/assist", {
    method: "POST",
    body: body === undefined ? null : JSON.stringify(body),
    headers: { "Content-Type": "application/json" },
  });
}

beforeEach(() => {
  vi.clearAllMocks();
  resetRateLimits();
  vi.mocked(getPlanForSession).mockResolvedValue({ plan: "free" } as never);
  vi.mocked(consumeAiAction).mockResolvedValue({
    allowed: true,
    usage: { used: 1, limit: 10, remaining: 9, percent: 10, state: "ok" },
  } as never);
  vi.mocked(generate).mockResolvedValue({
    text: "ATP powers cellular work.",
    provider: "openai",
    model: "gpt-4o-mini",
    inputTokens: 10,
    outputTokens: 20,
    costUsd: "0.0001",
    latencyMs: 100,
  } as never);
});

afterEach(() => {
  delete process.env.AI_RATE_LIMIT_PER_MINUTE;
  resetRateLimits();
});

describe("POST /api/notebooks/[id]/assist", () => {
  it("returns 401 without a session", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(null);
    const res = await POST(makeRequest({ mode: "explain", text: "ATP powers cells." }), {
      params: Promise.resolve({ id: "nb-1" }),
    });
    expect(res.status).toBe(401);
    expect(generate).not.toHaveBeenCalled();
  });

  it("returns 400 for an unknown mode", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(session as never);
    const res = await POST(makeRequest({ mode: "poem", text: "ATP powers cells." }), {
      params: Promise.resolve({ id: "nb-1" }),
    });
    expect(res.status).toBe(400);
    expect(generate).not.toHaveBeenCalled();
  });

  it("returns 400 for missing or blank text", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(session as never);
    const res = await POST(makeRequest({ mode: "explain", text: "   " }), {
      params: Promise.resolve({ id: "nb-1" }),
    });
    expect(res.status).toBe(400);
    expect(generate).not.toHaveBeenCalled();
  });

  it("returns 400 when the selection exceeds the limit", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(session as never);
    const res = await POST(makeRequest({ mode: "summarize", text: "x".repeat(4001) }), {
      params: Promise.resolve({ id: "nb-1" }),
    });
    expect(res.status).toBe(400);
    expect(generate).not.toHaveBeenCalled();
  });

  it("returns 429 when the AI allowance is exhausted", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(session as never);
    vi.mocked(consumeAiAction).mockResolvedValue({
      allowed: false,
      usage: { used: 10, limit: 10, remaining: 0, percent: 100, state: "exhausted" },
    } as never);
    const res = await POST(makeRequest({ mode: "explain", text: "ATP powers cells." }), {
      params: Promise.resolve({ id: "nb-1" }),
    });
    expect(res.status).toBe(429);
    expect(generate).not.toHaveBeenCalled();
  });

  it("transforms the selection and returns the text", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(session as never);
    const res = await POST(makeRequest({ mode: "explain", text: "ATP powers cells." }), {
      params: Promise.resolve({ id: "nb-1" }),
    });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.text).toBe("ATP powers cellular work.");
    expect(generate).toHaveBeenCalledWith(
      expect.objectContaining({
        feature: "assist:explain",
        tier: "simple",
        prompt: "ATP powers cells.",
      }),
    );
  });

  it("trims surrounding whitespace from the selection before generating", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(session as never);
    const res = await POST(makeRequest({ mode: "quiz", text: "  ATP powers cells.  " }), {
      params: Promise.resolve({ id: "nb-1" }),
    });
    expect(res.status).toBe(200);
    expect(generate).toHaveBeenCalledWith(
      expect.objectContaining({ prompt: "ATP powers cells." }),
    );
  });

  it("returns 503 with friendly copy when AI is not configured", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(session as never);
    vi.mocked(generate).mockRejectedValue(
      new AiNotConfiguredError(["OPENAI_API_KEY"]),
    );
    const res = await POST(makeRequest({ mode: "explain", text: "ATP powers cells." }), {
      params: Promise.resolve({ id: "nb-1" }),
    });
    expect(res.status).toBe(503);
    // Zero-config UX: the user sees a product message, never the missing
    // key name or a docs URL.
    const body = (await res.json()) as { error: string };
    expect(body.error).toBe(AI_NOT_CONFIGURED_MESSAGE);
    expect(body.error).not.toContain("OPENAI_API_KEY");
    expect(body.error).not.toContain("environment-variables");
  });

  it("returns 429 when the per-minute AI rate limit is exceeded", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(session as never);
    process.env.AI_RATE_LIMIT_PER_MINUTE = "1";

    const first = await POST(
      makeRequest({ mode: "explain", text: "ATP powers cells." }),
      { params: Promise.resolve({ id: "nb-1" }) },
    );
    expect(first.status).toBe(200);

    const second = await POST(
      makeRequest({ mode: "explain", text: "ATP powers cells." }),
      { params: Promise.resolve({ id: "nb-1" }) },
    );
    expect(second.status).toBe(429);
    expect(second.headers.get("Retry-After")).toBeTruthy();
    const body = (await second.json()) as { error: string };
    expect(body.error).not.toContain("limit");
  });

  it("returns 502 when every provider fails", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(session as never);
    vi.mocked(generate).mockRejectedValue(
      new AiProviderError("AI generation failed after trying all configured providers."),
    );
    const res = await POST(makeRequest({ mode: "explain", text: "ATP powers cells." }), {
      params: Promise.resolve({ id: "nb-1" }),
    });
    expect(res.status).toBe(502);
  });

  it("returns 502 when the model returns an empty answer", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(session as never);
    vi.mocked(generate).mockResolvedValue({
      text: "   ",
      provider: "openai",
      model: "gpt-4o-mini",
      inputTokens: 10,
      outputTokens: 0,
      costUsd: "0.0000",
      latencyMs: 100,
    } as never);
    const res = await POST(makeRequest({ mode: "simplify", text: "ATP powers cells." }), {
      params: Promise.resolve({ id: "nb-1" }),
    });
    expect(res.status).toBe(502);
  });
});
