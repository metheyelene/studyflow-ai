// ─────────────────────────────────────────────────────────────────────
// Better Auth server configuration.
// - email/password auth + optional Google OAuth (env-gated)
// - password reset + email verification via pluggable email sender
// - `role` additional field: "user" | "admin" (admin panel keys off it)
// - secure cookies in production; sessions stored in Postgres
// - rate limiting enabled (in-memory by default; use Upstash in prod)
// ─────────────────────────────────────────────────────────────────────
import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";

import { getDb, schema } from "@/db";
import { emailLayout, sendEmail } from "@/lib/email";

const appUrl = process.env.BETTER_AUTH_URL ?? "http://localhost:3000";

export const auth = betterAuth({
  database: drizzleAdapter(getDb(), { provider: "pg", schema }),

  emailAndPassword: {
    enabled: true,
    // Turn on in production once email sending is configured:
    //   EMAIL_VERIFICATION_REQUIRED=true (see src/lib/email.ts).
    requireEmailVerification:
      process.env.EMAIL_VERIFICATION_REQUIRED === "true",
    sendResetPassword: async ({ user, url }) => {
      await sendEmail({
        to: user.email,
        subject: "Reset your StudyFlow password",
        html: emailLayout(
          "Reset your password",
          `<p>Click the link below to choose a new password. It expires in 1 hour.</p>
           <p><a href="${url}" style="background:#18181b;color:#fff;padding:10px 16px;border-radius:8px;text-decoration:none;display:inline-block;">Reset password</a></p>
           <p style="font-size:13px;">Or paste this into your browser: <br/>${url}</p>`,
        ),
      });
    },
  },

  emailVerification: {
    sendVerificationEmail: async ({ user, url }) => {
      await sendEmail({
        to: user.email,
        subject: "Verify your StudyFlow email",
        html: emailLayout(
          "Verify your email",
          `<p>Confirm this email address to finish creating your account.</p>
           <p><a href="${url}" style="background:#18181b;color:#fff;padding:10px 16px;border-radius:8px;text-decoration:none;display:inline-block;">Verify email</a></p>`,
        ),
      });
    },
    autoSignInAfterVerification: true,
  },

  // Google OAuth activates automatically once GOOGLE_CLIENT_ID and
  // GOOGLE_CLIENT_SECRET are in .env (see docs/environment-variables.md).
  ...(process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET
    ? {
        socialProviders: {
          google: {
            clientId: process.env.GOOGLE_CLIENT_ID,
            clientSecret: process.env.GOOGLE_CLIENT_SECRET,
            redirectURI: `${appUrl}/api/auth/callback/google`,
          },
        },
      }
    : {}),

  user: {
    additionalFields: {
      role: {
        type: "string",
        defaultValue: "user",
        input: false, // never settable through the client API
      },
    },
    // Allow users to delete their own account (cascades to all data).
    deleteUser: { enabled: true },
  },

  session: {
    expiresIn: 60 * 60 * 24 * 7, // 7 days
    updateAge: 60 * 60 * 24, // refresh session daily
  },

  // Basic auth rate limiting. In-memory is fine for a single instance;
  // with multiple serverless instances use Upstash (documented in
  // docs/environment-variables.md).
  rateLimit: {
    enabled: true,
    window: 60,
    limit: 20,
    customRules: {
      "/sign-in/email": { window: 60, max: 5 },
      "/sign-up/email": { window: 60 * 60, max: 10 },
    },
  },

  advanced: {
    useSecureCookies: process.env.NODE_ENV === "production",
    cookiePrefix: "studyflow",
  },
});

export type Session = typeof auth.$Infer.Session;
