// ─────────────────────────────────────────────────────────────────────
// App version — read from package.json at runtime, never hard-coded.
// Server-only (uses node:fs); import from server components only.
// ─────────────────────────────────────────────────────────────────────
import { readFileSync } from "node:fs";
import { join } from "node:path";

let cached: string | null = null;

export function appVersion(): string {
  if (cached) return cached;
  try {
    const pkg = JSON.parse(readFileSync(join(process.cwd(), "package.json"), "utf8"));
    cached = String(pkg.version ?? "0.0.0");
  } catch {
    cached = "0.0.0";
  }
  return cached;
}
