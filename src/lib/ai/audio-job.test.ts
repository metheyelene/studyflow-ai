import { beforeEach, describe, expect, it, vi } from "vitest";

// ── module mocks ────────────────────────────────────────────────────
const dbMock = {
  update: vi.fn(() => ({
    set: vi.fn(() => ({
      where: vi.fn(async () => {}),
    })),
  })),
};

vi.mock("@/db", () => ({
  getDb: () => dbMock,
  schema: {
    audioEpisodes: { id: "id" },
  },
}));

vi.mock("@/lib/ai/audio", () => ({
  generatePodcastScript: vi.fn(),
  synthesizeMp3: vi.fn(),
}));

vi.mock("@/lib/ai/orchestrator", () => ({
  AiNotConfiguredError: class AiNotConfiguredError extends Error {},
  AiProviderError: class AiProviderError extends Error {},
}));

vi.mock("@/lib/usage", () => ({
  refundMonthly: vi.fn(async () => {}),
}));

// ── imports (after mocks) ───────────────────────────────────────────
import { generatePodcastScript, synthesizeMp3 } from "@/lib/ai/audio";
import { AiNotConfiguredError, AiProviderError } from "@/lib/ai/orchestrator";
import { refundMonthly } from "@/lib/usage";
import { runEpisodeGeneration } from "@/lib/ai/audio-job";

const script = {
  title: "Electromagnetics — Study Podcast",
  narration: "Section: Introduction\nWelcome.",
  wordCount: 40,
  durationSec: 30,
  transcript: [{ heading: "Introduction", text: "Welcome.", startSec: 0, sources: [] }],
};

beforeEach(() => {
  vi.clearAllMocks();
  (generatePodcastScript as ReturnType<typeof vi.fn>).mockResolvedValue({
    script,
    sourcesUsed: ["src_1"],
  });
  (synthesizeMp3 as ReturnType<typeof vi.fn>).mockResolvedValue(Buffer.from("MP3BYTES"));
});

function lastUpdateSets(): Array<Record<string, unknown>> {
  return (dbMock.update as ReturnType<typeof vi.fn>).mock.results.map((r) => {
    const set = (r.value as { set: ReturnType<typeof vi.fn> }).set;
    return set.mock.calls[0][0] as Record<string, unknown>;
  });
}

describe("runEpisodeGeneration", () => {
  const input = {
    episodeId: "ep_1",
    userId: "user_1",
    notebookId: "nb_1",
    style: "focused" as const,
    length: "standard" as const,
  };

  it("walks the pipeline stages and marks the episode ready with MP3 data", async () => {
    const status = await runEpisodeGeneration(input);
    expect(status).toBe("ready");

    const sets = lastUpdateSets();
    // organizing → writing (script/transcript) → generating audio → ready
    expect(sets[0].pipelineStage).toBe("organizing");
    expect(sets[1].pipelineStage).toBe("writing");
    expect(sets[1].script).toContain("Section: Introduction");
    expect(sets[1].durationSec).toBe(30);
    expect(sets[2].pipelineStage).toBe("generating audio");
    expect(sets[3]).toMatchObject({
      status: "ready",
      pipelineStage: "ready",
      audioData: Buffer.from("MP3BYTES").toString("base64"),
      mimeType: "audio/mpeg",
    });
    expect(synthesizeMp3).toHaveBeenCalledWith(script.narration, "focused");
  });

  it("marks the episode failed and refunds the slot when TTS fails", async () => {
    (synthesizeMp3 as ReturnType<typeof vi.fn>).mockRejectedValue(new AiProviderError("provider down"));
    const status = await runEpisodeGeneration(input);
    expect(status).toBe("failed");

    const last = lastUpdateSets().at(-1);
    expect(last).toMatchObject({
      status: "failed",
      pipelineStage: "failed",
    });
    expect(last?.errorMessage).toBe("The audio service is temporarily unavailable. Please try again in a moment.");
    expect(refundMonthly).toHaveBeenCalledWith("user_1", "audio_episodes");
  });

  it("refunds the slot when AI is not configured", async () => {
    (generatePodcastScript as ReturnType<typeof vi.fn>).mockRejectedValue(
      new AiNotConfiguredError(["OPENAI_API_KEY"]),
    );
    const status = await runEpisodeGeneration(input);
    expect(status).toBe("failed");
    const last = lastUpdateSets().at(-1);
    expect(String(last?.errorMessage)).toContain("OPENAI_API_KEY");
    expect(refundMonthly).toHaveBeenCalledWith("user_1", "audio_episodes");
  });

  it("keeps the reserved slot when generation succeeds (no refund)", async () => {
    await runEpisodeGeneration(input);
    expect(refundMonthly).not.toHaveBeenCalled();
  });
});
