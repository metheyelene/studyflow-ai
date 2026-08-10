import { headers } from "next/headers";
import { NextResponse } from "next/server";

import { auth } from "@/lib/auth";
import { NotFoundError, deleteSource } from "@/lib/ai/sources";

export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ id: string; sourceId: string }> },
) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { id, sourceId } = await params;
  try {
    await deleteSource(session.user.id, id, sourceId);
    return NextResponse.json({ ok: true });
  } catch (err) {
    if (err instanceof NotFoundError) {
      return NextResponse.json({ error: "Source not found." }, { status: 404 });
    }
    console.error("[sources:delete]", err);
    return NextResponse.json({ error: "Failed to delete source." }, { status: 500 });
  }
}
