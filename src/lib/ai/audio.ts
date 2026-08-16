// ─────────────────────────────────────────────────────────────────────
// Study Podcast pipeline (AI Audio Learning).
//
// A podcast episode is NOT raw text-to-speech. The pipeline is:
//
//   notebook sources → bounded context → AI organizes into a script
//   (intro, grounded sections, recap, self-test, final review) → TTS
//   renders each part → MP3 bytes + transcript with per-section source
//   references and estimated timestamps.
//
// TTS uses OpenAI's official speech endpoint (POST /v1/audio/speech,
// model tts-1) with the same OPENAI_API_KEY the rest of the AI system
// uses. That is the only authorized audio provider wired in; we never
// scrape voice services or embed keys anywhere near the client.
//
// Cost control: script generation is one AI call (complex tier) and TTS
// is ~$15/1M chars (~$0.10–0.30 per episode); the monthly episode meter
// (plans.audioEpisodesPerMonth) caps volume, and the route reuses an
// unchanged episode instead of regenerating it.
// ─────────────────────────────────────────────────────────────────────
import { z } from "zod";

import type { AudioTranscriptSection } from "@/db/schema";
import { AiNotConfiguredError, AiProviderError, generateJson } from "@/lib/ai/orchestrator";
import { getSourcesForUser, loadChunks } from "@/lib/ai/sources";

export const PODCAST_STYLES = ["focused", "friendly", "quick", "deep", "podcast"] as const;
export type PodcastStyle = (typeof PODCAST_STYLES)[number];

export const PODCAST_LENGTHS = ["quick", "standard", "deep"] as const;
export type PodcastLength = (typeof PODCAST_LENGTHS)[number];

/** TTS voice per style (tts-1 voices; all natural, none imitate real people). */
const STYLE_VOICE: Record<PodcastStyle, string> = {
  focused: "onyx",
  friendly: "nova",
  quick: "onyx",
  deep: "alloy",
  podcast: "shimmer",
};

export const STYLE_COPY: Record<PodcastStyle, string> = {
  focused: "Straightforward academic explanation.",
  friendly: "Warm and conversational teaching.",
  quick: "Fast, concise exam-style review.",
  deep: "Long-form, thorough deep dive.",
  podcast: "Natural conversational educational format.",
};

const LENGTH_TARGET: Record<PodcastLength, { target: string; guidance: string }> = {
  quick: { target: "about 600–900 words (roughly 5–8 minutes of speech)", guidance: "cover only the most important concepts; be concise." },
  standard: { target: "about 1,200–1,800 words (roughly 10–15 minutes of speech)", guidance: "cover the core concepts with a few concrete examples." },
  deep: { target: "about 2,400–3,600 words (roughly 20–30 minutes of speech)", guidance: "cover the material in depth, with detailed examples and connections between concepts." },
};

const SCRIPT_MAX_CHARS = 120_000;
const TTS_MAX_CHARS = 4000; // OpenAI tts-1 request limit
const CHARS_PER_MINUTE = 900; // tts-1 ≈ 150 wpm ≈ 900 chars/min → duration estimate

// ── script schema ────────────────────────────────────────────────────
const scriptSchema = z.object({
  title: z.string().min(1).max(120),
  intro: z.string().min(1),
  sections: z
    .array(
      z.object({
        heading: z.string().min(1).max(120),
        narration: z.string().min(1),
        sourceMarkers: z.array(z.number().int().min(1).max(30)).optional().default([]),
      }),
    )
    .min(1)
    .max(10),
  recap: z.string().min(1),
  selfTest: z.string().min(1),
  finalReview: z.string().min(1),
});

interface ScriptSection {
  heading: string;
  text: string;
  sources: string[];
}

export interface PodcastScript {
  title: string;
  /** Narration text with section headings (what gets spoken). */
  narration: string;
  wordCount: number;
  /** Estimated duration in seconds (chars / wpm estimate). */
  durationSec: number;
  /** Transcript sections in order, with startSec for seeking. */
  transcript: AudioTranscriptSection[];
}

function podcastSystem(style: PodcastStyle, length: PodcastLength): string {
  const { target, guidance } = LENGTH_TARGET[length];
  return [
    "You are the scriptwriter for a StudyFlow study podcast. You turn a student's own study material into a clear, engaging audio lesson.",
    `Style: ${STYLE_COPY[style]}`,
    `Length: aim for ${target}. ${guidance}`,
    "",
    "RULES (never break these):",
    "1. Ground every factual claim in the provided source excerpts. Cite the relevant source with its bracketed marker (e.g. [3]).",
    "2. NEVER invent facts, formulas, page numbers, or source names that are not in the excerpts.",
    "3. If a source is thin, say what it does and does not cover honestly — do not pad with invented content.",
    "4. Equations and formulas must be spoken in natural language (e.g. 'voltage equals current multiplied by resistance'), never read symbol-by-symbol.",
    "5. Diagrams/tables: explain the relationships verbally ('this shows three stages: first…, then…'), never narrate visual layout.",
    "6. Write for the ear: short sentences, plain words, natural transitions. No markdown, no bullet lists.",
    "7. The self-test asks the listener a few questions from the material; the final review restates only the most important takeaways.",
    "8. Everything you write will be read aloud by a text-to-speech voice — write complete sentences that sound natural when spoken.",
  ].join("\n");
}

/** Build a bounded context block with source markers (never the whole collection). */
function buildContextBlocks(
  chunks: Array<{ sourceId: string; sourceTitle: string; page: number | null; content: string }>,
): { context: string; titlesByMarker: Map<number, string> } {
  const blocks: string[] = [];
  const titlesByMarker = new Map<number, string>();
  let total = 0;
  for (const chunk of chunks) {
    const marker = blocks.length + 1;
    const excerpt = chunk.content.slice(0, 3000);
    total += excerpt.length;
    if (total > SCRIPT_MAX_CHARS) break;
    const pageNote = chunk.page ? ` (page ${chunk.page})` : "";
    blocks.push(`[${marker}] ${chunk.sourceTitle}${pageNote}\n<untrusted_source ${marker}>\n${excerpt}\n</untrusted_source>`);
    titlesByMarker.set(marker, chunk.sourceTitle);
  }
  return { context: blocks.join("\n\n"), titlesByMarker };
}

/**
 * Generate the source-grounded podcast script for a notebook.
 * Throws the same friendly errors as other AI actions (no ready sources,
 * AI not configured, provider error).
 */
export async function generatePodcastScript(
  userId: string,
  notebookId: string,
  style: PodcastStyle,
  length: PodcastLength,
): Promise<{ script: PodcastScript; sourcesUsed: string[] }> {
  const sources = await getSourcesForUser(userId, notebookId);
  const readyIds = sources.filter((s) => s.status === "ready").map((s) => s.id);
  if (readyIds.length === 0) {
    throw new Error("This notebook has no ready sources yet. Add a source first.");
  }
  const chunks = await loadChunks(userId, notebookId, readyIds);
  if (chunks.length === 0) {
    throw new Error("This notebook has no indexed content yet. Add a source first.");
  }

  const { context, titlesByMarker } = buildContextBlocks(chunks);
  const generated = await generateJson({
    feature: "podcast",
    tier: "complex",
    system: podcastSystem(style, length),
    prompt: [
      "Write the podcast script for the notebook titled below, using ONLY the provided source excerpts.",
      "",
      `Subject/notebook: the student's study material`,
      "",
      `RETRIEVED EXCERPTS FROM THE USER'S SOURCES (mark each claim with its [n] marker):`,
      context,
    ].join("\n"),
    temperature: 0.6,
    maxOutputTokens: 4096,
    schema: scriptSchema,
    log: { userId },
    userId,
  });

  const data = generated.data as z.infer<typeof scriptSchema>;
  const sections: ScriptSection[] = data.sections.map((s) => ({
    heading: s.heading,
    text: s.narration,
    sources: [...new Set((s.sourceMarkers ?? []).map((m) => titlesByMarker.get(m)).filter((t): t is string => Boolean(t)))],
  }));

  const all: Array<{ heading: string; text: string; sources: string[] }> = [
    { heading: "Introduction", text: data.intro, sources: [] },
    ...sections,
    { heading: "Quick recap", text: data.recap, sources: [] },
    { heading: "Self-test", text: data.selfTest, sources: [] },
    { heading: "Final review", text: data.finalReview, sources: [] },
  ];

  const narration = all.map((s) => `Section: ${s.heading}\n${s.text}`).join("\n\n");
  const wordCount = narration.split(/\s+/).filter(Boolean).length;
  const durationSec = Math.max(30, Math.round(narration.length / CHARS_PER_MINUTE * 60));

  let cursor = 0;
  const transcript: AudioTranscriptSection[] = all.map((s) => {
    const startSec = Math.round(cursor);
    cursor += (s.text.length / CHARS_PER_MINUTE) * 60;
    return { heading: s.heading, text: s.text, startSec, sources: s.sources };
  });

  return {
    script: { title: data.title.trim(), narration, wordCount, durationSec, transcript },
    sourcesUsed: [...new Set(chunks.map((c) => c.sourceId))],
  };
}

/** Split narration into ≤ TTS_MAX_CHARS chunks at sentence boundaries. */
export function splitForTts(text: string, maxChars = TTS_MAX_CHARS): string[] {
  const out: string[] = [];
  let remaining = text.trim();
  while (remaining.length > 0) {
    if (remaining.length <= maxChars) {
      out.push(remaining);
      break;
    }
    // Cut at the last sentence boundary within the limit.
    const slice = remaining.slice(0, maxChars);
    const boundary = Math.max(slice.lastIndexOf(". "), slice.lastIndexOf("! "), slice.lastIndexOf("? "), slice.lastIndexOf("\n\n"));
    const cut = boundary > maxChars * 0.4 ? boundary + 1 : maxChars;
    out.push(remaining.slice(0, cut).trim());
    remaining = remaining.slice(cut).trim();
  }
  return out.filter((s) => s.length > 0);
}

/**
 * Synthesize narration to MP3 via OpenAI's official speech endpoint.
 * Returns the raw MP3 bytes. The key stays server-side.
 */
export async function synthesizeMp3(narration: string, style: PodcastStyle): Promise<Buffer> {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) throw new AiNotConfiguredError(["OPENAI_API_KEY"]);
  const voice = STYLE_VOICE[style];
  const speed = style === "quick" ? 1.1 : 1.0;

  const parts: Buffer[] = [];
  for (const chunk of splitForTts(narration)) {
    let res: Response;
    try {
      res = await fetch("https://api.openai.com/v1/audio/speech", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
        body: JSON.stringify({ model: "tts-1", voice, input: chunk, response_format: "mp3", speed }),
      });
    } catch (err) {
      throw new AiProviderError("The audio service could not be reached.", err);
    }
    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      throw new AiProviderError(`The audio service failed (${res.status}).`, detail.slice(0, 200));
    }
    parts.push(Buffer.from(await res.arrayBuffer()));
  }
  return Buffer.concat(parts);
}
