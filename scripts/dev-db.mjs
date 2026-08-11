#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────────
// In-project Postgres for development — no system install needed.
// Runs a real Postgres binary (embedded-postgres devDependency) inside
// .freebuff/pgdata, on port 5432, with user/password `postgres`.
//
// Usage:
//   node scripts/dev-db.mjs          # start (stays in foreground)
//   PGPORT=5433 node scripts/dev-db.mjs   # different port if 5432 is busy
//
// Once running, point .env at it:
//   DATABASE_URL="postgresql://postgres:postgres@localhost:5432/studyflow"
//   DATABASE_URL_DIRECT="postgresql://postgres:postgres@localhost:5432/studyflow"
// then `npm run db:migrate`.
// ─────────────────────────────────────────────────────────────────────
import EmbeddedPostgres from "embedded-postgres";
import { existsSync } from "node:fs";

const PORT = Number(process.env.PGPORT ?? 5432);
const DB_NAME = "studyflow";
const DATA_DIR = ".freebuff/pgdata";

const pg = new EmbeddedPostgres({
  databaseDir: DATA_DIR,
  user: "postgres",
  password: "postgres",
  port: PORT,
  persistent: true,
});

async function main() {
  const alreadyInitialised = existsSync(`${DATA_DIR}/PG_VERSION`);
  if (!alreadyInitialised) {
    await pg.initialise();
  }
  await pg.start();
  try {
    await pg.createDatabase(DB_NAME);
    console.log(`created database "${DB_NAME}"`);
  } catch (err) {
    const msg = String(err?.message ?? err);
    if (!/already exists|duplicate database/i.test(msg)) throw err;
  }
  console.log(`Postgres ready on 127.0.0.1:${PORT} (db "${DB_NAME}", user/pass postgres/postgres)`);
  console.log(`Connection: postgresql://postgres:postgres@localhost:${PORT}/${DB_NAME}`);
}

main().catch((err) => {
  console.error("dev-db failed:", err);
  process.exit(1);
});
