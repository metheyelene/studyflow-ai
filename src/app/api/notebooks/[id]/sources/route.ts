import { headers } from "next/headers";
import { NextResponse } from "next/server";

import { auth } from "@/lib/auth";
import { LimitError, NotFoundError, addPastedSource, addUploadedSource, listSources } from "@/lib/ai/sources";
import { SourceExtractionError } from "@/lib/ai/extract";
import { getPlanForSession } from "@/lib/premium";

/**
 * GET /api/notebooks/[id]/sources — the notebook's sources, oldest first.
 * The mobile Sources tab renders this list (title, kind, status, size).
 */
export async function GET(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { id } = await params;
  try {
    const sources = await listSources(session.user.id, id);
    return NextResponse.json({
      sources: sources.map((s) => ({
        id: s.id,
        title: s.title,
        kind: s.sourceType,
        status: s.status,
        wordCount: s.wordCount,
        pageCount: s.pageCount,
        sizeBytes:
          (s.meta as Record<string, unknown> | null | undefined)?.["sizeBytes"] as
            | number
            | undefined,
        createdAt: s.createdAt.toISOString(),
        updatedAt: s.updatedAt.toISOString(),
      })),
    });
  } catch (err) {
    if (err instanceof NotFoundError) {
      return NextResponse.json({ error: "Notebook not found." }, { status: 404 });
    }
    console.error("[sources:list]", err);
    return NextResponse.json({ error: "Failed to load sources." }, { status: 500 });
  }
}

/**
 * POST /api/notebooks/[id]/sources
 * JSON body:  { title, text }            → pasted source
 * FormData:   { title?, file }           → uploaded PDF/DOCX/TXT/MD
 */
export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { id } = await params;
  const planCtx = await getPlanForSession();
  const plan = planCtx?.plan ?? "free";

  try {
    const contentType = request.headers.get("content-type") ?? "";
    if (contentType.includes("multipart/form-data")) {
      const form = await request.formData();
      const file = form.get("file");
      const title = form.get("title");
      if (!(file instanceof File)) {
        return NextResponse.json({ error: "A file is required." }, { status: 400 });
      }
      const buffer = Buffer.from(await file.arrayBuffer());
      const source = await addUploadedSource(session.user.id, id, plan, {
        filename: (typeof title === "string" && title.trim() ? title : file.name).trim(),
        mimeType: file.type || "application/octet-stream",
        buffer,
      });
      return NextResponse.json({ source }, { status: 201 });
    }

    const body = (await request.json().catch(() => null)) as { title?: string; text?: string } | null;
    const title = body?.title?.trim();
    const text = body?.text?.trim();
    if (!title) return NextResponse.json({ error: "A title is required." }, { status: 400 });
    if (!text) return NextResponse.json({ error: "Source text is required." }, { status: 400 });

    const source = await addPastedSource(session.user.id, id, plan, { title, text });
    return NextResponse.json({ source }, { status: 201 });
  } catch (err) {
    if (err instanceof NotFoundError) {
      return NextResponse.json({ error: "Notebook not found." }, { status: 404 });
    }
    if (err instanceof LimitError) {
      return NextResponse.json({ error: err.message }, { status: 403 });
    }
    if (err instanceof SourceExtractionError) {
      return NextResponse.json({ error: err.message }, { status: 422 });
    }
    console.error("[sources:create]", err);
    return NextResponse.json({ error: "Failed to add source." }, { status: 500 });
  }
}
