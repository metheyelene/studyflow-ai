import "dotenv/config";

const url = process.env.DATABASE_URL ?? "";
console.log("Using host:", new URL(url).host, "| db:", new URL(url).pathname);

import { getDb } from "../src/db";

async function main() {
  const db = getDb();
  const result = await db.execute(
    "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename",
  );
  const rows = result as unknown as { rows: { tablename: string }[] };
  console.log(`Tables (${rows.rows.length}):`, rows.rows.map((r) => r.tablename).join(", "));
  process.exit(0);
}

main().catch((e) => {
  console.error("FULL ERROR:", JSON.stringify(e, Object.getOwnPropertyNames(e), 2));
  process.exit(1);
});
