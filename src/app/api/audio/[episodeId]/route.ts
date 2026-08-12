import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";

export const runtime = "nodejs";

/** Ownership-checked episode fetch. Returns null when missing or not owned. */
async function episodeForUser(userId: string, episodeId: string) {
  return getDb().query.audioEpisodes.findFirst({
    where: and(eq(schema.audioEpisodes.id, episodeId), eq(schema.audioEpisodes.userId, userId)),
  });
}

/**
 * GET /api/audio/[episodeId] — the episode (polled by the client while it
 * is "processing"). Never includes the base64 audio payload — playback
 * streams from /stream; the transcript + script are included so the
 * player can show chapters and the transcript.
 */
export async function GET(_request: Request, { params }: { params: Promise<{ episodeId: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { episodeId } = await params;
  const episode = await episodeForUser(session.user.id, episodeId);
  if (!episode) return NextResponse.json({ error: "Episode not found." }, { status: 404 });

  const notebook = episode.notebookId
    ? await getDb().query.notebooks.findFirst({
        where: eq(schema.notebooks.id, episode.notebookId),
      })
    : null;

  return NextResponse.json({
    episode: {
      id: episode.id,
      notebookId: episode.notebookId,
      notebookTitle: notebook?.title ?? null,
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
      script: episode.script,
      audioUrl: `/api/audio/${episode.id}/stream`,
      createdAt: episode.createdAt.toISOString(),
      updatedAt: episode.updatedAt.toISOString(),
    },
  });
}

/**
 * PATCH /api/audio/[episodeId] — update playback state. Only the
 * playback position is mutable (used to resume on this device and sync
 * across devices). Other fields are written by the server-side job.
 */
export async function PATCH(request: Request, { params }: { params: Promise<{ episodeId: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { episodeId } = await params;
  const episode = await episodeForUser(session.user.id, episodeId);
  if (!episode) return NextResponse.json({ error: "Episode not found." }, { status: 404 });

  const body = (await request.json().catch(() => null)) as { playbackPositionSec?: number } | null;
  const position = body?.playbackPositionSec;
  if (typeof position !== "number" || !Number.isFinite(position) || position < 0) {
    return NextResponse.json({ error: "Invalid playback position." }, { status: 400 });
  }

  await getDb()
    .update(schema.audioEpisodes)
    .set({ playbackPositionSec: Math.round(position) })
    .where(eq(schema.audioEpisodes.id, episodeId));

  return NextResponse.json({ ok: true });
}

/** DELETE /api/audio/[episodeId] — permanently remove the episode. */
export async function DELETE(_request: Request, { params }: { params: Promise<{ episodeId: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { episodeId } = await params;
  const episode = await episodeForUser(session.user.id, episodeId);
  if (!episode) return NextResponse.json({ error: "Episode not found." }, { status: 404 });

  await getDb()
    .delete(schema.audioEpisodes)
    .where(and(eq(schema.audioEpisodes.id, episodeId), eq(schema.audioEpisodes.userId, session.user.id)));

  return NextResponse.json({ ok: true });
}
