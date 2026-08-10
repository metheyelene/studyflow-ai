import { headers } from "next/headers";
import { NextResponse } from "next/server";

import { auth } from "@/lib/auth";
import { invalidateNotebook } from "@/lib/ai/cache";
import { NotFoundError, deleteNotebook, getNotebookForUser, listSources } from "@/lib/ai/sources";

export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { id } = await params;
  try {
    const notebook = await getNotebookForUser(session.user.id, id);
    const sources = await listSources(session.user.id, id);
    return NextResponse.json({ notebook, sources });
  } catch (err) {
    if (err instanceof NotFoundError) {
      return NextResponse.json({ error: "Notebook not found." }, { status: 404 });
    }
    console.error("[notebooks:get]", err);
    return NextResponse.json({ error: "Failed to load notebook." }, { status: 500 });
  }
}

export async function DELETE(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { id } = await params;
  try {
    await deleteNotebook(session.user.id, id);
    await invalidateNotebook(id);
    return NextResponse.json({ ok: true });
  } catch (err) {
    if (err instanceof NotFoundError) {
      return NextResponse.json({ error: "Notebook not found." }, { status: 404 });
    }
    console.error("[notebooks:delete]", err);
    return NextResponse.json({ error: "Failed to delete notebook." }, { status: 500 });
  }
}
