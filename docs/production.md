# Production Setup

This covers everything needed to run StudyFlow AI in production. Credential
steps that only you can perform are marked **MANUAL** — do them yourself,
never send secrets through chat.

## 1. Database (Neon)

**MANUAL — create the database once:**

1. Sign up at https://neon.tech → **New project** (name: `studyflow`).
2. Copy both connection strings:
   - **Pooled** (contains `-pooler`) → `DATABASE_URL`
   - **Direct** → `DATABASE_URL_DIRECT`
3. Put them in local `.env` **and** in Vercel (Settings → Environment
   Variables → Production + Preview). Values must be **unquoted**.

```bash
npm run db:migrate   # apply the 20-table schema
```

**Backups:** Neon's free tier includes point-in-time restore and daily
backups. Document your restore procedure in the operations runbook (backup
plan is a Phase 28 deliverable).

## 2. Application (Vercel)

**MANUAL — connect the repo once:**

1. vercel.com → **Settings → Login Connections → Connect GitHub** (authorize
   the Vercel GitHub app).
2. In the `studyflow-ai` project → **Settings → Git** → connect
   `metheyelene/studyflow-ai`.
3. After that: push to `main` → production deploy; every PR/branch → its own
   preview URL, automatically.

Full steps, including the CLI alternative: [deployment.md](deployment.md).

## 3. Environment variables in Vercel

Add these to **Production** and **Preview** (all stored as **Sensitive**):

| Variable | Value |
|---|---|
| `DATABASE_URL` | Neon pooled URL (real) |
| `DATABASE_URL_DIRECT` | Neon direct URL (real) |
| `BETTER_AUTH_SECRET` | Same value as local `.env` — otherwise sessions break |
| `BETTER_AUTH_URL` | `https://your-domain.com` |
| `AI_PROVIDER` | `openai` |
| `OPENAI_API_KEY` | Your key |

Later phases add Stripe (`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`,
`NEXT_PUBLIC_STRIPE_PRICE_*`), R2 (`R2_*`), Upstash, and Sentry.

> **Remember:** deployments snapshot env vars at build time — after changing
> them, redeploy.

## 4. Domain + HTTPS

**MANUAL — you must own the domain and verify it:**

1. Buy a domain (e.g. Namecheap/Cloudflare registrar).
2. In Vercel: project → **Settings → Domains** → add it → follow Vercel's
   DNS instructions at your registrar (CNAME/ALIAS to `cname.vercel-dns.com`).
3. Vercel provisions HTTPS automatically (Let's Encrypt). Wait for the
   certificate to issue, then update `BETTER_AUTH_URL` and redeploy.
4. If you use an email provider (later phase), set the DNS records it
   requires (SPF/DKIM).

## 5. Monitoring

- **Errors:** Sentry (add `SENTRY_DSN`, install `@sentry/nextjs`) — planned
  for the launch week.
- **Costs:** the `ai_requests` table logs every generation (provider, model,
  tokens, cost). Query it weekly — it's the source of truth for AI spend.
- **Health:** Vercel provides deployment status + runtime logs; add uptime
  checks (e.g. cron hitting `/` + `/api/auth/get-session`) before launch.

## 6. Launch checklist

The full 22-item audit lives in the project brief; the working tracker is
[docs/mvp-plan.md](docs/mvp-plan.md) (Week 5). Critical items: legal pages,
privacy/terms, Sentry, rate limiting, Stripe webhook verification, backups,
and the first-student playbook ([docs/playbook-first-students.md](docs/playbook-first-students.md)).

## 7. What must NEVER happen in production

- A frontend payment-success callback unlocking premium (webhook only).
- Client-side enforcement of usage limits (server-side only).
- API keys, DB credentials, or `BETTER_AUTH_SECRET` in client code, git, or
  logs.
- `npm run db:push` against the production database (migrations only).
