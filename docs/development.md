# Development Setup

## Prerequisites

- **Node.js 22+** (Next.js 16 requires ≥ 20.9; CI uses 22 LTS)
- **npm** (the project's package manager — don't mix pnpm/yarn)
- A **Neon** Postgres database (free tier) — see [production.md](production.md) §Database

## First run

```bash
cd ~/studyflow-ai
npm install
cp .env.example .env
#   edit .env — DATABASE_URL (pooled), DATABASE_URL_DIRECT (direct),
#   BETTER_AUTH_SECRET (openssl rand -base64 32), BETTER_AUTH_URL
npm run db:migrate     # applies the 20-table schema to Neon
npm run dev            # → http://localhost:3000
```

If port 3000 is busy, Next picks another and prints it. (On this machine
3000 is often taken by other software — use whatever port it reports.)

## Verifying your setup

```bash
npm run lint && npm run typecheck && npm test && npm run build
```

Then in the browser: sign up → onboarding → dashboard. Until real Neon URLs
are in `.env`, auth will fail at the database layer with a friendly error —
that's expected; the DB gate is the first item in
[docs/mvp-plan.md](docs/mvp-plan.md).

## Database workflows

```bash
npm run db:generate   # after editing src/db/schema.ts — writes a new SQL migration
npm run db:migrate    # apply pending migrations
npm run db:studio     # visual browser (Drizzle Studio)
npm run db:push       # DEV ONLY — syncs schema without a migration; never in production
```

**Auth schema note:** `src/db/auth-schema.ts` must match what Better Auth
expects. If you upgrade Better Auth, verify with the CLI's generated schema
(`npx @better-auth/cli@latest generate`) and diff table names/columns before
committing a migration.

## Switching the AI provider

The app is provider-agnostic (`src/lib/ai/provider.ts`). To switch:

```bash
# .env
AI_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-...
```

To add a **new** provider (e.g. Google): `npm install @ai-sdk/google`, add a
case in `src/lib/ai/provider.ts` (provider + model), add it to
`AI_PROVIDERS`. No other code changes.

## Common workflows

- **Add a page:** create `src/app/.../page.tsx`. Server components by
  default; add `"use client"` only when the page needs state/interactivity.
- **Add a UI primitive:** create `src/components/ui/<name>.tsx` using the
  existing shadcn-style pattern and design tokens — never raw colors.
- **Add a server action:** co-locate `actions.ts` next to the page; validate
  with Zod; return `{ error }` shapes for friendly UI messages.
- **Track an event:** insert into the `analyticsEvents` table (server-side).

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `ECONNREFUSED` on queries | `.env` still has the localhost placeholder | Put the real Neon URLs in `.env` |
| `Invalid URL` in builds | Env var value contains quotes or is malformed | Re-add the var **unquoted** (Vercel: remove + re-add) |
| `npm ci` fails with "Missing: … from lock file" | Lockfile out of sync | `npm install`, commit the lockfile |
| Auth errors show raw objects | Missing `friendlyAuthError()` mapping | Route errors through `src/lib/auth-errors.ts` |
| Dev server serves the wrong app/title | Turbopack root resolved to a parent dir | `turbopack.root` is pinned in `next.config.ts` — don't remove it |
