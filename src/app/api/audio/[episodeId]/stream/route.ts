import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";

export const runtime = "nodejs";

/**
 * GET /api/audio/[episodeId]/stream — streams the generated MP3 with
 * HTTP Range support so the player can seek, scrub, and jump to
 * transcript timestamps without downloading the whole file.
 *
 * Only "ready" episodes stream. The audio bytes are stored base64 in
 * Postgres (drizzle 0.45 has no bytea column); this route decodes on the
 * fly. Ownership is enforced by the session — a user can never stream
 * another user's episode.
 */
export async function GET(request: Request, { params }: { params: Promise<{ episodeId: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { episodeId } = await params;
  const episode = await getDb().query.audioEpisodes.findFirst({
    where: and(eq(schema.audioEpisodes.id, episodeId), eq(schema.audioEpisodes.userId, session.user.id)),
  });
  if (!episode || episode.status !== "ready" || !episode.audioData) {
    return NextResponse.json(
      { error: episode ? "This episode isn't ready yet." : "Episode not found." },
      { status: episode ? 409 : 404 },
    );
  }

  const audio = Buffer.from(episode.audioData, "base64");
  const size = audio.length;
  const range = request.headers.get("range");
  const contentType = episode.mimeType || "audio/mpeg";

  // Range request → 206 with the requested byte window (for seeking).
  if (range) {
    const match = /^bytes=(\d*)-(\d*)$/.exec(range);
    if (match) {
      const start = match[1] ? Number(match[1]) : 0;
      let end = match[2] ? Number(match[2]) : size - 1;
      if (!Number.isFinite(start) || !Number.isFinite(end) || start > end || start >= size) {
        return new NextResponse(null, {
          status: 416,
          headers: { "Content-Range": `bytes */${size}` },
        });
      }
      end = Math.min(end, size - 1);
      return new NextResponse(audio.subarray(start, end + 1), {
        status: 206,
        headers: {
          "Content-Type": contentType,
          "Content-Length": String(end - start + 1),
          "Content-Range": `bytes ${start}-${end}/${size}`,
          "Accept-Ranges": "bytes",
          "Cache-Control": "private, max-age=3600",
        },
      });
    }
  }

  return new NextResponse(audio, {
    status: 200,
    headers: {
      "Content-Type": contentType,
      "Content-Length": String(size),
      "Accept-Ranges": "bytes",
      "Cache-Control": "private, max-age=3600",
    },
  });
}
