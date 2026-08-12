// ─────────────────────────────────────────────────────────────────────
// Background podcast-generation job.
//
// POST /api/audio creates the episode row (status "processing") and then
// schedules this runner via Next `after()`, so the API responds instantly
// and the client polls the episode until it is "ready" or "failed". Each
// stage writes the real backend state into `pipelineStage` — the client
// only ever displays a stage the backend actually reports.
//
// On failure the episode is marked "failed" with a friendly message and
// the reserved monthly slot is refunded (refundMonthly), so a failed
// generation never eats the user's quota.
// ─────────────────────────────────────────────────────────────────────
import { eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { AiNotConfiguredError, AiProviderError } from "@/lib/ai/orchestrator";
import { refundMonthly } from "@/lib/usage";
import { generatePodcastScript, synthesizeMp3, type PodcastLength, type PodcastStyle } from "@/lib/ai/audio";

const AUDIO_EPISODES = "audio_episodes";

export interface AudioJobInput {
  episodeId: string;
  userId: string;
  notebookId: string;
  style: PodcastStyle;
  length: PodcastLength;
}

const STAGE = (stage: string) => ({ pipelineStage: stage });

/**
 * Run the full podcast pipeline for one episode: organize → write script →
 * synthesize audio → mark ready. Returns the final status so callers (and
 * tests) can assert on the outcome.
 */
export async function runEpisodeGeneration(input: AudioJobInput): Promise<"ready" | "failed"> {
  const db = getDb();
  const { episodeId, userId, notebookId, style, length } = input;

  try {
    await db
      .update(schema.audioEpisodes)
      .set(STAGE("organizing"))
      .where(eq(schema.audioEpisodes.id, episodeId));

    const { script, sourcesUsed } = await generatePodcastScript(userId, notebookId, style, length);

    await db
      .update(schema.audioEpisodes)
      .set({
        ...STAGE("writing"),
        script: script.narration,
        transcript: script.transcript,
        wordCount: script.wordCount,
        durationSec: script.durationSec,
      })
      .where(eq(schema.audioEpisodes.id, episodeId));

    await db
      .update(schema.audioEpisodes)
      .set(STAGE("generating audio"))
      .where(eq(schema.audioEpisodes.id, episodeId));

    const mp3 = await synthesizeMp3(script.narration, style);

    await db
      .update(schema.audioEpisodes)
      .set({
        status: "ready",
        pipelineStage: "ready",
        audioData: mp3.toString("base64"),
        mimeType: "audio/mpeg",
        durationSec: script.durationSec,
      })
      .where(eq(schema.audioEpisodes.id, episodeId));

    if (sourcesUsed.length > 0) {
      console.log(`[audio] episode ${episodeId} ready (${sourcesUsed.length} sources, ${script.wordCount} words)`);
    }
    return "ready";
  } catch (err) {
    const friendly =
      err instanceof AiNotConfiguredError
        ? err.message
        : err instanceof AiProviderError
          ? "The audio service is temporarily unavailable. Please try again in a moment."
          : err instanceof Error && /no ready sources|no indexed content/i.test(err.message)
            ? "This notebook has no indexed sources yet. Add a source first."
            : "Something went wrong while creating your podcast. Please try again.";

    console.error(`[audio] episode ${episodeId} failed:`, err);
    await db
      .update(schema.audioEpisodes)
      .set({ status: "failed", pipelineStage: "failed", errorMessage: friendly.slice(0, 500) })
      .where(eq(schema.audioEpisodes.id, episodeId));
    // A failed generation must not consume a monthly slot.
    await refundMonthly(userId, AUDIO_EPISODES).catch(() => {});
    return "failed";
  }
}
