import { headers } from "next/headers";
import { NextResponse } from "next/server";

import { auth } from "@/lib/auth";
import { LimitError, createNotebook, listNotebooks } from "@/lib/ai/sources";
import { getPlanForSession } from "@/lib/premium";

export async function GET() {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  try {
    const notebooks = await listNotebooks(session.user.id);
    return NextResponse.json({ notebooks });
  } catch (err) {
    console.error("[notebooks:list]", err);
    return NextResponse.json({ error: "Failed to load notebooks." }, { status: 500 });
  }
}

export async function POST(request: Request) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const planCtx = await getPlanForSession();
  const plan = planCtx?.plan ?? "free";
  const body = (await request.json().catch(() => null)) as { title?: string; description?: string } | null;
  const title = body?.title?.trim();
  if (!title) return NextResponse.json({ error: "A title is required." }, { status: 400 });
  if (title.length > 120) return NextResponse.json({ error: "Title is too long (max 120 chars)." }, { status: 400 });

  try {
    const notebook = await createNotebook(session.user.id, plan, {
      title,
      description: body?.description,
    });
    return NextResponse.json({ notebook }, { status: 201 });
  } catch (err) {
    if (err instanceof LimitError) {
      return NextResponse.json({ error: err.message }, { status: 403 });
    }
    console.error("[notebooks:create]", err);
    return NextResponse.json({ error: "Failed to create notebook." }, { status: 500 });
  }
}
