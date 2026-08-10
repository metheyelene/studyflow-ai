# StudyFlow AI

> Turn your notes into your smartest study system.

AI-powered study app for students preparing for exams: upload or paste notes,
then generate summaries, flashcards, quizzes, and study plans.

**Status:** Phase 1 (architecture) complete · Phase 2 (database + auth) in progress.
See [`docs/architecture.md`](docs/architecture.md) for the full spec.

## Stack

Next.js 16 · React 19 · TypeScript · Tailwind v4 · Drizzle ORM · PostgreSQL (Neon) ·
Better Auth · Vercel AI SDK · Stripe (later) · Vercel + GitHub Actions.

## Local setup

```bash
# 1. Install dependencies
npm install

# 2. Create your local env file
cp .env.example .env
#    → fill in DATABASE_URL, DATABASE_URL_DIRECT, BETTER_AUTH_SECRET
#      (see "Environment variables" below)

# 3. (After creating the Neon database) apply the schema:
npm run db:migrate

# 4. Start the dev server
npm run dev
#    → http://localhost:3000

# 5. (Optional) explore the database visually:
npm run db:studio
```

## Commands

| Command | What it does |
|---|---|
| `npm run dev` | Start the dev server |
| `npm run build` | Production build |
| `npm run start` | Run the production build |
| `npm run lint` | Lint |
| `npm run typecheck` | Type-check (no output = no errors) |
| `npm run db:generate` | Generate a migration from schema changes |
| `npm run db:migrate` | Apply migrations to the database |
| `npm run db:push` | Push schema directly (dev only, not for production) |
| `npm run db:studio` | Open Drizzle Studio (visual DB browser) |

## Environment variables

Copy `.env.example` → `.env` and fill in. **Never commit `.env`.**

| Variable | Where to get it | Used for |
|---|---|---|
| `DATABASE_URL` | Neon project → pooled connection string | App database connections |
| `DATABASE_URL_DIRECT` | Neon project → direct connection string | Migrations |
| `BETTER_AUTH_SECRET` | `openssl rand -base64 32` | Signing sessions |
| `BETTER_AUTH_URL` | `http://localhost:3000` (dev) / your domain (prod) | Auth base URL |
| `AI_PROVIDER` | `openai` or `anthropic` | Which AI provider to use |
| `OPENAI_API_KEY` | https://platform.openai.com/api-keys | OpenAI calls |
| `ANTHROPIC_API_KEY` | https://console.anthropic.com/settings/keys | Anthropic calls |

Later phases add: Stripe keys, R2 keys, Upstash URL/token, Sentry DSN (see
`.env.example` for placeholders).

## Project structure

```
src/
  app/                # Pages + API routes (App Router)
  db/                 # Schema + database client
  lib/                # auth, AI provider layer, services
  middleware.ts       # session refresh + route guards
drizzle/              # SQL migrations
docs/architecture.md  # the architecture spec
```

## Next steps (Phase 2)

1. Create a free Neon account (https://neon.tech) → new project → copy the
   two connection strings into `.env`.
2. Run `npm run db:migrate`.
3. Start the dev server and confirm `http://localhost:3000` loads.
4. We'll then add the signup/login pages (Phase 2 finish), then move to
   Phase 3 (core UI).
