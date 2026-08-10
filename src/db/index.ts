// ─────────────────────────────────────────────────────────────────────
// Shared database client (postgres.js driver + Drizzle).
// `getDb()` is lazy so modules can be imported without a live
// DATABASE_URL (e.g. during `next build`). It throws a clear error the
// first time a query actually runs without the env var set.
// ─────────────────────────────────────────────────────────────────────
import { drizzle, type PostgresJsDatabase } from "drizzle-orm/postgres-js";
import postgres from "postgres";

import * as authSchema from "./auth-schema";
import * as domainSchema from "./schema";

// Merged schema: auth tables + domain tables. Passed to Better Auth's
// drizzle adapter so it can find user/session/account/verification, and
// used by queries across the app.
export const schema = { ...authSchema, ...domainSchema };

export type Schema = typeof schema;

let _db: PostgresJsDatabase<Schema> | undefined;

/**
 * Returns the shared DB instance, constructing it lazily on first use.
 * `prepare: false` is required for serverless (Vercel) compatibility.
 */
export function getDb(): PostgresJsDatabase<Schema> {
  if (_db) return _db;

  const connectionString =
    process.env.DATABASE_URL ?? process.env.DATABASE_URL_DIRECT;

  if (!connectionString) {
    throw new Error(
      "DATABASE_URL is not set. Copy .env.example to .env and add your " +
        "Neon connection string (see docs/architecture.md → Deployment).",
    );
  }

  const client = postgres(connectionString, {
    max: 10,
    prepare: false,
  });

  _db = drizzle(client, { schema });
  return _db;
}
