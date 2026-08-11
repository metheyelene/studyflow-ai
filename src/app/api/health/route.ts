import { NextResponse } from "next/server";
import { sql } from "drizzle-orm";

import { getDb } from "@/db";
import { appVersion } from "@/lib/version";

// Health checks must always hit the real database and never be cached.
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const DB_TIMEOUT_MS = 5000;

/** Race a promise against a timeout so a hung database can't stall the
 *  uptime monitor — it answers "down" within a few seconds instead. */
async function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      promise,
      new Promise<T>((_, reject) => {
        timer = setTimeout(() => reject(new Error("db check timed out")), ms);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}

async function checkDatabase(): Promise<"ok" | "down"> {
  try {
    await withTimeout(getDb().execute(sql`select 1`), DB_TIMEOUT_MS);
    return "ok";
  } catch {
    return "down";
  }
}

/**
 * GET /api/health — public uptime-monitor endpoint (no auth, no secrets).
 * Reports process version and live DB connectivity. 200 when healthy,
 * 503 when the database is unreachable (or the check times out).
 */
export async function GET() {
  const startedAt = Date.now();
  const database = await checkDatabase();
  const healthy = database === "ok";

  const body = {
    status: healthy ? "ok" : "degraded",
    version: appVersion(),
    database,
    time: new Date().toISOString(),
    durationMs: Date.now() - startedAt,
  };

  return NextResponse.json(body, {
    status: healthy ? 200 : 503,
    headers: { "Cache-Control": "no-store" },
  });
}
