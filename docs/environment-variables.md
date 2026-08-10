# Environment Variables

This is the single reference for every environment variable StudyFlow AI
reads. The working template is `.env.example` (committed); real values live
in `.env` locally and in Vercel's secret store for production/preview —
**never in git, never in chat.**

**Naming rule:** anything prefixed `NEXT_PUBLIC_` is exposed to the browser.
Everything else is server-only. Never put a secret in a `NEXT_PUBLIC_` var.

---

## Required now

| Variable | Used for | Where to get it | Dev value | Production value |
|---|---|---|---|---|
| `DATABASE_URL` | App database connections (pooled) | Neon project → **pooled** connection string | Your Neon pooled URL | Same (real Neon) |
| `DATABASE_URL_DIRECT` | Drizzle migrations (`npm run db:migrate`) | Neon project → **direct** connection string | Your Neon direct URL | Same (real Neon) |
| `BETTER_AUTH_SECRET` | Signing + verifying sessions | `openssl rand -base64 32` | Generated once | **Must match the dev value** — if it differs, sessions break on redeploy |
| `BETTER_AUTH_URL` | Auth base URL (redirects, cookies) | Your app URL | `http://localhost:3000` | `https://your-domain.com` |
| `AI_PROVIDER_ORDER` | Failover order for AI providers (comma-separated) | `openai,anthropic` | `openai,anthropic` | Same |
| `OPENAI_API_KEY` | OpenAI model calls | https://platform.openai.com/api-keys | `sk-…` | `sk-…` |

`ANTHROPIC_API_KEY` is required only if it's in your `AI_PROVIDER_ORDER`
(https://console.anthropic.com/settings/keys). `AI_MODEL_SIMPLE` /
`AI_MODEL_STANDARD` / `AI_MODEL_COMPLEX` optionally override the per-tier
model names (defaults are in `src/lib/ai/orchestrator.ts`).

### Email + optional auth (Phase 3)

| Variable | Required? | Used for |
|---|---|---|
| `EMAIL_VERIFICATION_REQUIRED` | No (default `false`) | `true` in production to gate sign-in behind email verification |
| `RESEND_API_KEY` | No in dev (emails log to console) · **Yes in production** | Sending password-reset + verification emails |
| `EMAIL_FROM` | No | Sender address (defaults to a StudyFlow placeholder) |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | No | Google OAuth (one-click signup). Add both to enable |
| `NEXT_PUBLIC_GOOGLE_CLIENT_ID` | No | Shows/hides the Google button in the UI (client IDs are public) |

> **Neon gotcha:** the two strings are different. The **pooled** one contains
> `-pooler` and is for the app (serverless-safe); the **direct** one is for
> one-shot migrations. Swapping them works by accident for migrations but
> breaks under serverless load.

---

## Added in later phases (placeholders already in `.env.example`)

| Variable | Phase | Used for |
|---|---|---|
| `STRIPE_SECRET_KEY` | Payments | Stripe API (server-only) |
| `STRIPE_WEBHOOK_SECRET` | Payments | Verifying webhook signatures |
| `NEXT_PUBLIC_STRIPE_PRICE_MONTHLY` / `_YEARLY` | Payments | Checkout price IDs |
| `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME` | Notes/docs | Cloudflare R2 file storage |
| `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN` | Hardening | Rate limiting |
| `SENTRY_DSN` | Error monitoring | Sentry ingestion |

---

## Environments summary

| Environment | Where vars live | Notes |
|---|---|---|
| Local dev | `.env` (gitignored) | Loaded by `next dev` automatically |
| CI (GitHub Actions) | workflow `env:` block | Placeholders only — the build must not need a live DB |
| Preview (Vercel) | Vercel dashboard → Settings → Environment Variables (Preview) | Copied from production; keep in sync |
| Production (Vercel) | Vercel dashboard → Settings → Environment Variables (Production) | Real values only |

### Rules

- `BETTER_AUTH_SECRET`, `DATABASE_URL*` must be consistent across all
  environments (or sessions/deploys break).
- Sensitive vars in Vercel are stored as **Sensitive** so they're hidden in
  logs and pull output.
- If you change an env var in Vercel, redeploy — deployments snapshot the
  values at build time.
