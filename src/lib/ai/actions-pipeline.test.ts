import { beforeEach, describe, expect, it, vi } from "vitest";

// ── module mocks ────────────────────────────────────────────────────
vi.mock("@/lib/ai/sources", () => ({
  getSourcesForUser: vi.fn(),
  loadChunks: vi.fn(),
  sourceVersions: vi.fn(async () => ({})),
}));

vi.mock("@/lib/ai/retrieval", () => ({
  hybridRetrieve: vi.fn(),
}));

vi.mock("@/lib/ai/orchestrator", () => ({
  resolveModel: vi.fn(() => ({ model: "test-model" })),
  generateJson: vi.fn(),
  generate: vi.fn(),
  AiNotConfiguredError: class AiNotConfiguredError extends Error {},
  AiProviderError: class AiProviderError extends Error {},
}));

vi.mock("@/lib/ai/cache", () => ({
  getCached: vi.fn(async () => null),
  putCached: vi.fn(async () => {}),
  cacheKey: vi.fn(() => "test-cache-key"),
}));

vi.mock("@/lib/ai/prompts", () => ({
  systemPrompt: () => "",
}));

// ── imports (after mocks) ───────────────────────────────────────────
import { getSourcesForUser, loadChunks } from "@/lib/ai/sources";
import { hybridRetrieve } from "@/lib/ai/retrieval";
import { generateJson } from "@/lib/ai/orchestrator";
import { runAction } from "@/lib/ai/actions";

const chunk = (id: string) => ({
  id,
  sourceId: "s1",
  notebookId: "nb-1",
  content: "Threshold voltage is the gate voltage at which the channel conducts.",
  chunkIndex: 0,
  page: null,
  sourceTitle: "Lecture 4",
});

beforeEach(() => {
  vi.clearAllMocks();
  (generateJson as ReturnType<typeof vi.fn>).mockResolvedValue({
    provider: "openai",
    model: "test-model",
    costUsd: "0.001",
    data: {
      cards: [
        { front: "What is threshold voltage?", back: "The gate voltage at which the channel conducts.", sourceMarkers: [1] },
        { front: "What is Vt?", back: "Threshold voltage.", sourceMarkers: [1] },
      ],
    },
  });
});

describe("runAction pipeline", () => {
  it("resolves ready source ids when none are given (regression: sourceIdsForNotebook returned [] always)", async () => {
    (getSourcesForUser as ReturnType<typeof vi.fn>).mockResolvedValue([
      { id: "s1", status: "ready" },
      { id: "s2", status: "processing" }, // must be excluded
    ]);
    (loadChunks as ReturnType<typeof vi.fn>).mockResolvedValue([chunk("c1")]);
    (hybridRetrieve as ReturnType<typeof vi.fn>).mockResolvedValue([
      { ...chunk("c1"), score: 0.9 },
    ]);

    const result = await runAction("flashcards", { userId: "u1", notebookId: "nb-1" }, {});

    expect(getSourcesForUser).toHaveBeenCalledWith("u1", "nb-1");
    // Only the ready source id is passed down to chunk loading.
    expect(loadChunks).toHaveBeenCalledWith("u1", "nb-1", ["s1"]);
    const cards = (result.data as { cards: unknown[] }).cards;
    expect(cards).toHaveLength(2);
  });

  it("falls back to source-order chunks when retrieval scores nothing (regression: generic queries over short sources failed)", async () => {
    (getSourcesForUser as ReturnType<typeof vi.fn>).mockResolvedValue([
      { id: "s1", status: "ready" },
    ]);
    (loadChunks as ReturnType<typeof vi.fn>).mockResolvedValue([chunk("c1")]);
    // The generic generation query has no lexical overlap with a short source.
    (hybridRetrieve as ReturnType<typeof vi.fn>).mockResolvedValue([]);

    const result = await runAction("flashcards", { userId: "u1", notebookId: "nb-1" }, {});

    const cards = (result.data as { cards: unknown[] }).cards;
    expect(cards).toHaveLength(2);
    expect(generateJson).toHaveBeenCalled();
  });

  it("still rejects a notebook with no chunks at all", async () => {
    (getSourcesForUser as ReturnType<typeof vi.fn>).mockResolvedValue([]);
    (loadChunks as ReturnType<typeof vi.fn>).mockResolvedValue([]);

    await expect(
      runAction("flashcards", { userId: "u1", notebookId: "nb-1" }, {}),
    ).rejects.toThrow("no ready sources");
  });
});
