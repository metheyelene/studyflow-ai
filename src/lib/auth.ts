// ─────────────────────────────────────────────────────────────────────
// Better Auth server configuration.
// - email/password auth (Google OAuth can be added later via plugins)
// - `role` additional field: "user" | "admin" (admin panel keys off it)
// - secure cookies in production
// - sessions stored in Postgres (see src/db)
// ─────────────────────────────────────────────────────────────────────
import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";

import { getDb, schema } from "@/db";

export const auth = betterAuth({
  database: drizzleAdapter(getDb(), { provider: "pg", schema }),
  emailAndPassword: {
    enabled: true,
    // requireEmailVerification: false — flip to true once email sending
    // is configured (Phase 2 hardening). Keeping it off now so test
    // users can sign up instantly during the soft launch.
  },
  user: {
    additionalFields: {
      role: {
        type: "string",
        defaultValue: "user",
        input: false, // never settable through the client API
      },
    },
  },
  advanced: {
    useSecureCookies: process.env.NODE_ENV === "production",
    cookiePrefix: "studyflow",
  },
});

export type Session = typeof auth.$Infer.Session;
