import { headers } from "next/headers";
import { after } from "next/server";
import { NextResponse } from "next/server";
import { eq, inArray } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";
import { NotFoundError, getNotebookForUser } from "@/lib/ai/sources";
import { PODCAST_LENGTHS, PODCAST_STYLES, type PodcastLength, type PodcastStyle } from "@/lib/ai/audio";
import { runEpisodeGeneration } from "@/lib/ai/audio-job";
import { getPlanForSession } from "@/lib/premium";
import { getLimits } from "@/lib/plans";
import { consumeMonthly } from "@/lib/usage";

export const runtime = "nodejs";

const AUDIO_EPISODES = "audio_episodes";

/** API shape for an episode (never includes the base64 audio payload). */
function episodeJson(
  episode: typeof schema.audioEpisodes.$inferSelect,
  notebookTitle: string | null,
  opts?: { includeScript?: boolean },
) {
  return {
    id: episode.id,
    notebookId: episode.notebookId,
    notebookTitle,
    title: episode.title,
    style: episode.style,
    length: episode.length,
    status: episode.status,
    pipelineStage: episode.pipelineStage,
    errorMessage: episode.errorMessage,
    durationSec: episode.durationSec,
    wordCount: episode.wordCount,
    playbackPositionSec: episode.playbackPositionSec,
    transcript: episode.transcript,
    script: opts?.includeScript ? episode.script : undefined,
    audioUrl: `/api/audio/${episode.id}/stream`,
    createdAt: episode.createdAt.toISOString(),
    updatedAt: episode.updatedAt.toISOString(),
  };
}

/** GET /api/audio — the user's podcast library, newest first. */
export async function GET() {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  try {
    const db = getDb();
    const episodes = await db.query.audioEpisodes.findMany({
      where: eq(schema.audioEpisodes.userId, session.user.id),
      orderBy: (e, { desc }) => [desc(e.createdAt)],
      limit: 100,
    });

    const notebooks = episodes.length
      ? await db.query.notebooks.findMany({
          where: inArray(schema.notebooks.id, [...new Set(episodes.map((e) => e.notebookId))]),
        })
      : [];
    const titles = new Map(notebooks.map((n) => [n.id, n.title]));

    return NextResponse.json({
      episodes: episodes.map((e) => episodeJson(e, titles.get(e.notebookId) ?? null)),
    });
  } catch (err) {
    console.error("[audio:list]", err);
    return NextResponse.json({ error: "Failed to load your audio library." }, { status: 500 });
  }
}

/**
 * POST /api/audio — start a Study Podcast for a notebook.
 *
 * The monthly episode slot is reserved atomically BEFORE the job starts
 * (consumeMonthly, same race-safe pattern as AI actions), the episode row
 * is created with status "processing", and the generation runs in the
 * background via `after()` — the request returns immediately with the
 * episode id and the client polls GET /api/audio/[id]. On failure the
 * job marks the episode "failed" and refunds the reserved slot.
 */
export async function POST(request: Request) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const body = (await request.json().catch(() => null)) as {
    notebookId?: string;
    style?: string;
    length?: string;
  } | null;
  const notebookId = body?.notebookId;
  if (!notebookId || typeof notebookId !== "string") {
    return NextResponse.json({ error: "Pick a notebook to turn into a podcast." }, { status: 400 });
  }
  const style = (body?.style ?? "focused") as PodcastStyle;
  const length = (body?.length ?? "standard") as PodcastLength;
  if (!PODCAST_STYLES.includes(style)) {
    return NextResponse.json({ error: "Unknown podcast style." }, { status: 400 });
  }
  if (!PODCAST_LENGTHS.includes(length)) {
    return NextResponse.json({ error: "Unknown podcast length." }, { status: 400 });
  }

  let notebook;
  try {
    notebook = await getNotebookForUser(session.user.id, notebookId);
  } catch (err) {
    if (err instanceof NotFoundError) {
      return NextResponse.json({ error: "Notebook not found." }, { status: 404 });
    }
    console.error("[audio:owner]", err);
    return NextResponse.json({ error: "Failed to load that notebook." }, { status: 500 });
  }

  const planCtx = await getPlanForSession();
  const plan = planCtx?.plan ?? "free";
  const limit = getLimits(plan).audioEpisodesPerMonth;
  const consumed = await consumeMonthly(session.user.id, AUDIO_EPISODES, limit);
  if (!consumed.allowed) {
    return NextResponse.json(
      {
        error: `You've used this month's podcast allowance (${limit}). It resets at the start of next month — or upgrade for a higher limit.`,
      },
      { status: 429 },
    );
  }

  const db = getDb();
  const [episode] = await db
    .insert(schema.audioEpisodes)
    .values({
      userId: session.user.id,
      notebookId,
      title: `${notebook.title} — Study Podcast`,
      style,
      length,
      status: "processing",
      pipelineStage: "queued",
    })
    .returning();

  // Fire the pipeline in the background; the response is sent immediately.
  after(() =>
    runEpisodeGeneration({
      episodeId: episode.id,
      userId: session.user.id,
      notebookId,
      style,
      length,
    }),
  );

  return NextResponse.json(
    { episode: episodeJson(episode, notebook.title, { includeScript: false }) },
    { status: 202 },
  );
}
