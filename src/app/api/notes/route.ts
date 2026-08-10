import { headers } from "next/headers";
import { NextResponse } from "next/server";

import { auth } from "@/lib/auth";
import { createNote, listNotes } from "@/lib/notes";

/** GET /api/notes?search=&subjectId=&favorite=1&archived=1 */
export async function GET(request: Request) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const url = new URL(request.url);
  const notes = await listNotes(session.user.id, {
    search: url.searchParams.get("search") ?? undefined,
    subjectId: url.searchParams.get("subjectId"),
    favoriteOnly: url.searchParams.get("favorite") === "1",
    archived: url.searchParams.get("archived") === "1",
  });
  return NextResponse.json({ notes });
}

/** POST /api/notes — create a note. */
export async function POST(request: Request) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const body = (await request.json().catch(() => null)) as {
    title?: string;
    content?: string;
    subjectId?: string | null;
  } | null;
  if (!body || (body.title === undefined && body.content === undefined)) {
    return NextResponse.json({ error: "A title or content is required." }, { status: 400 });
  }

  try {
    const note = await createNote(session.user.id, {
      title: body.title ?? "Untitled",
      content: body.content ?? "",
      subjectId: body.subjectId ?? null,
    });
    return NextResponse.json({ note }, { status: 201 });
  } catch (err) {
    console.error("[notes:create]", err);
    return NextResponse.json({ error: "Failed to create the note." }, { status: 500 });
  }
}
