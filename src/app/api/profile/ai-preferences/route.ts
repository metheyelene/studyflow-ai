import { headers } from "next/headers";
import { NextResponse } from "next/server";
import { z } from "zod";

import { auth } from "@/lib/auth";
import {
  loadAiPreferences,
  saveAiPreferences,
  type AiPreferences,
} from "@/lib/ai/preferences";

export const runtime = "nodejs";

const preferencesSchema = z.object({
  responseStyle: z.enum(["concise", "balanced", "detailed"]),
  studyLevel: z.enum(["school", "university", "professional"]),
  language: z.string().trim().min(1, "Pick a language.").max(64),
});

/**
 * GET /api/profile/ai-preferences — the signed-in user's AI preferences
 * (response style, study level, language), always with valid values. This
 * is the ONLY AI configuration the app exposes: no providers, keys,
 * models, or endpoints.
 */
export async function GET() {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const prefs = await loadAiPreferences(session.user.id);
  return NextResponse.json({ preferences: prefs });
}

/** PUT /api/profile/ai-preferences — save the user's AI preferences. */
export async function PUT(request: Request) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const body = (await request.json().catch(() => null)) as unknown;
  const parsed = preferencesSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: parsed.error.issues[0]?.message ?? "Check your preferences." },
      { status: 400 },
    );
  }

  const prefs: AiPreferences = {
    responseStyle: parsed.data.responseStyle,
    studyLevel: parsed.data.studyLevel,
    language: parsed.data.language,
  };

  try {
    await saveAiPreferences(session.user.id, prefs);
    return NextResponse.json({ preferences: prefs });
  } catch (err) {
    console.error("[ai-preferences] save failed:", err);
    return NextResponse.json(
      { error: "We couldn't save your preferences. Please try again." },
      { status: 500 },
    );
  }
}
