import { defineConfig } from "drizzle-kit";

export default defineConfig({
  // Both schema files are read directly (the re-export barrel in
  // src/db/index.ts confuses drizzle-kit's table discovery).
  schema: ["./src/db/auth-schema.ts", "./src/db/schema.ts"],
  out: "./drizzle",
  dialect: "postgresql",
  dbCredentials: {
    // Migrations must use the DIRECT (non-pooled) Neon URL.
    url: process.env.DATABASE_URL_DIRECT ?? process.env.DATABASE_URL ?? "",
  },
  verbose: true,
  strict: true,
});
