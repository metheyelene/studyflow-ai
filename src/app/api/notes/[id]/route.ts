import { headers } from "next/headers";
import { NextResponse } from "next/server";

import { auth } from "@/lib/auth";
import { NoteNotFoundError, deleteNote, getNote, updateNote } from "@/lib/notes";

export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { id } = await params;
  try {
    const note = await getNote(session.user.id, id);
    return NextResponse.json({ note });
  } catch (err) {
    if (err instanceof NoteNotFoundError) {
      return NextResponse.json({ error: "Note not found." }, { status: 404 });
    }
    console.error("[notes:get]", err);
    return NextResponse.json({ error: "Failed to load the note." }, { status: 500 });
  }
}

/** PUT /api/notes/[id] — partial update (title/content/subjectId/favorite/archived). */
export async function PUT(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { id } = await params;
  const body = (await request.json().catch(() => null)) as Record<string, unknown> | null;
  if (!body || Object.keys(body).length === 0) {
    return NextResponse.json({ error: "Nothing to update." }, { status: 400 });
  }

  try {
    const note = await updateNote(session.user.id, id, {
      title: typeof body.title === "string" ? body.title : undefined,
      content: typeof body.content === "string" ? body.content : undefined,
      subjectId: body.subjectId === undefined ? undefined : body.subjectId === null ? null : String(body.subjectId),
      favorite: typeof body.favorite === "boolean" ? body.favorite : undefined,
      archived: typeof body.archived === "boolean" ? body.archived : undefined,
    });
    return NextResponse.json({ note });
  } catch (err) {
    if (err instanceof NoteNotFoundError) {
      return NextResponse.json({ error: "Note not found." }, { status: 404 });
    }
    console.error("[notes:update]", err);
    return NextResponse.json({ error: "Failed to save the note." }, { status: 500 });
  }
}

export async function DELETE(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { id } = await params;
  try {
    await deleteNote(session.user.id, id);
    return NextResponse.json({ ok: true });
  } catch (err) {
    if (err instanceof NoteNotFoundError) {
      return NextResponse.json({ error: "Note not found." }, { status: 404 });
    }
    console.error("[notes:delete]", err);
    return NextResponse.json({ error: "Failed to delete the note." }, { status: 500 });
  }
}
