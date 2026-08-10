# StudyFlow AI — Architecture Specification

> **Approved:** 2026-08-10 · **Status:** Phase 1 complete, Phase 2 in progress
>
> *Turn your notes into your smartest study system.*

This document is the single source of truth for how StudyFlow AI is built and why.
It was approved by the founder before any application code was written.

---

## 1. Product

**StudyFlow AI** is an AI-powered student productivity app for students preparing
for exams. Users upload/paste notes, then generate summaries, flashcards, quizzes,
and study plans from that material — all in one premium-feeling web app.

**MVP scope (ship this first, nothing more):**

- Auth + short onboarding + subjects
- Paste notes + upload PDFs (server-side parsing) → organized into subjects
- AI summary (short / detailed / key concepts / definitions / exam points)
- Ask questions about your notes
- Flashcards (auto-generate, flip, review, progress)
- Quizzes (MCQ, difficulty, score, explanations, history)
- Exam countdown + basic (rule-based) study planner

**Deferred until paying users exist** (no exceptions): AI-powered planner,
referral system, marketing automation, premium themes, advanced spaced
repetition, admin analytics polish, native mobile app.

**Business principle:** find a real student problem → useful solution → first
users → observe → improve retention → convert a small percentage → control AI
costs → grow organically. Target: **5 paying users before building one more
feature.**

---

## 2. Technology Stack

| Layer | Choice | Why |
|---|---|---|
| Frontend + backend | Next.js 16 (App Router), React 19, TypeScript | One codebase, SSR for SEO, secure API layer, fastest solo-dev path |
| Styling / UI | Tailwind CSS v4 + shadcn/ui (Radix) | Accessible, themeable, premium without building from scratch |
| Database | PostgreSQL on **Neon** (scale-to-zero) | Pay only when traffic exists; branching for previews |
| ORM / migrations | Drizzle ORM + drizzle-kit | Type-safe, SQL migrations as code |
| Auth | **Better Auth** (self-hosted) | Full control of sessions + roles (admin), no lock-in |
| AI | **Vercel AI SDK** + modular `provider.ts` | Provider-agnostic by design; keys stay server-side |
| File storage | Cloudflare R2 (S3-compatible) | Zero egress fees, near-free at our scale |
| PDF parsing | Server-side (pdf-parse on the API route) | Never ships parsing code or file content to the client |
| Payments | **Stripe** (Checkout + Billing Portal + webhooks) | Standard for subscriptions; webhooks signature-verified |
| Rate limiting | Upstash Redis | Serverless, sub-ms, generous free tier |
| Error tracking | Sentry | Free tier; server + client errors |
| Analytics | In-house events table in Postgres + admin dashboard | Privacy-conscious, $0, same data the admin needs |
| Testing | Vitest + React Testing Library, Playwright (E2E) | Standard, excellent DX |
| CI/CD | GitHub Actions → Vercel | Lint → typecheck → test → build → security → deploy |
| Native later | Clean HTTP API layer; future Expo app calls the same endpoints | No rewrite needed |

**Rejected:** Firebase/Supabase-only (auth lock-in, less abuse-prevention
control), separate Node backend service (more moving parts than a solo founder
needs), native mobile first (slower to revenue).

---

## 3. System Architecture

```
Browser (Next.js app, SSR)
   │  HTTPS
   ▼
Next.js route handlers (/api/*)  ← auth (Better Auth) · rate limit (Upstash) · validation (Zod)
   │
   ├── Services layer:
   │     ├── lib/ai/provider.ts   →  ai provider SDKs (openai, anthropic, …)   [swap via AI_PROVIDER env]
   │     ├── lib/ai/generate.ts   →  single AI entry point (usage + logging hooks)
   │     ├── lib/ai/*.ts          →  summary / flashcards / quiz / qa / planner (Phase 5)
   │     ├── lib/documents.ts     →  upload → R2, parse PDF server-side (Phase 4)
   │     ├── lib/usage.ts         →  metering; enforces free/premium limits atomically (Phase 5)
   │     └── lib/subscription.ts  →  entitlement checks (Phase 7)
   │
   ├── Stripe webhook endpoint (signature-verified, idempotent)
   │     └── updates subscriptions table → premium unlocked server-side ONLY
   │
   └── Postgres (Neon) ── R2 file storage ── Upstash Redis
```

Rules that never bend:

- **Every AI call** goes through `lib/ai/generate.ts`: check limit → record →
  call provider → log tokens/cost to `ai_requests`.
- **Premium entitlement** is computed server-side from the `subscriptions`
  table. Never from a client flag, never from a frontend success screen.
- **Admin** is a separate route group (`/admin/*`) with role + session checks
  at both the middleware and API layers. Ordinary users can never reach it.
- **Keys/secrets** (AI, Stripe, DB, admin) exist only in server env vars.

---

## 4. Database Schema (Postgres)

All tables live in `src/db/`. Auth tables are the canonical Better Auth output
(`npx @better-auth/cli generate`, verified); domain tables in `src/db/schema.ts`.

| Table | Purpose |
|---|---|
| `user`, `session`, `account`, `verification` | Better Auth core (plus `role` column: user/admin) |
| `profiles` | Onboarding answers, daily study minutes, streak |
| `subjects` | User's subjects (unique per user+name) |
| `notes` | Plain-text study material (pasted or extracted from documents) |
| `documents` | File uploads: R2 storage key, status (processing/ready/failed) |
| `flashcard_decks`, `flashcards`, `flashcard_reviews` | Decks, cards, spaced-repetition ratings |
| `quizzes`, `quiz_questions`, `quiz_attempts` | Generated quizzes, questions, user attempts/scores |
| `exams`, `study_plans` | Exam dates, generated plans (JSON) |
| `subscriptions` | Stripe mirror — the source of premium entitlement |
| `usage` | Monthly per-user-per-feature counters + limits (unique per user/feature/period) |
| `ai_requests` | Every AI call: provider, model, tokens, cost, latency, error |
| `analytics_events` | Privacy-conscious event log for the admin dashboard |

Conventions: text UUID ids, timestamptz, every user-owned table FKs
`user.id` with `ON DELETE CASCADE`, hot query paths indexed. No sensitive data
stored beyond what's needed; no card data ever (Stripe owns that).

Migration: `drizzle/0000_silky_scrambler.sql` (generated, applies cleanly).

---

## 5. AI Architecture

- **Provider-agnostic:** `src/lib/ai/provider.ts` maps `AI_PROVIDER` env →
  `openai` (gpt-4o-mini) or `anthropic` (claude-3-5-haiku-latest). Feature code
  only calls `generate()` and never imports an SDK directly. Adding a provider
  = one npm install + one `case` + one model name.
- **Cost control:** every call records input/output tokens and an estimated
  cost in `ai_requests`. The revenue dashboard (Phase 9) computes real
  per-user AI spend — no guesswork.
- **Usage limits:** `lib/usage.ts` meters per-feature monthly counters and
  enforces free vs premium limits atomically.
- **Quality guardrails:** AI-generated study content is marked
  "AI-generated — verify against your notes"; QA answers cite the source text.

---

## 6. Monetization & Pricing

**One premium tier** (tiers can split later once there's data):

| | Free | Premium |
|---|---|---|
| Price | $0 | **$4.99/mo** or **$39.99/yr** (≈$3.33/mo, ~33% off, honestly framed) |
| AI actions | 20/month | Higher limit (fair-use capped) |
| Document uploads | 3 | More |
| Subjects | 1 | Unlimited |
| Flashcards | Basic | Unlimited (fair use) |
| Quizzes | Basic | Advanced |
| Planner | Basic | Advanced |

Final numbers get locked in `src/lib/plans.ts` during the payments phase.

**Unit economics per premium user (monthly):** gross $4.99 − Stripe (~$0.45)
= ~$4.54 net. Heavy usage (500 calls × ~$0.0025) ≈ $1.25 worst case AI cost.
**Net margin ≈ 70–80%.** Revenue per paying user comfortably exceeds variable
cost — this is the design requirement.

**Paywall rules:** appears at the limit; explains what free gets, what premium
adds, pricing, how to cancel. No fake discounts, no fake urgency, no
"guaranteed grades" claims. No dark patterns.

---

## 7. Security

- Auth: Better Auth sessions in Postgres; passwords hashed by better-auth
  (argon2id/bcrypt family); secure cookies in production.
- Authorization: server-side checks on every route; `role` field never
  client-settable (`input: false`); admin group double-guarded.
- Validation/sanitization: Zod on every API input; server-side only.
- Rate limiting: Upstash Redis (API + auth + AI endpoints).
- Secrets: env vars only; `.env*` gitignored; Vercel/GitHub secret stores;
  never in client bundles, chat, or repos.
- Payments: Stripe webhooks verified by signature + idempotency; subscription
  state updated only by the verified webhook; no raw card data.
- Abuse prevention: per-user metering, rate limits, (later) referral validation.

---

## 8. Analytics & Admin

- **Events** (in `analytics_events`): app_opened, onboarding_completed,
  note_created, document_uploaded, summary_generated, flashcards_generated,
  quiz_started, quiz_completed, paywall_viewed, checkout_started,
  subscription_started, subscription_cancelled.
- **Admin panel** (`/admin/*`, admin role only): users, subscription status,
  usage stats, revenue stats, feature usage, error monitoring (Sentry link),
  AI/API usage (from `ai_requests`), system health.
- **Revenue dashboard:** MRR, ARR, new subs, cancellations, conversion, free vs
  premium counts, revenue, API cost estimate, infra cost, gross margin — revenue
  and costs shown separately, real data only, nothing fabricated.

---

## 9. Deployment & CI/CD

- **Environments:** local dev · preview (every PR) · staging (staging branch) ·
  production (main branch). All on Vercel + Neon (Neon branches for previews).
- **Pipeline (GitHub Actions):** push → lint → typecheck → tests → build →
  security scan → deploy to the matching environment.
- **Services:** Vercel (web) · Neon (Postgres, PITR backups) · R2 (files) ·
  Stripe (payments, test/prod keys strictly separated) · Sentry · Upstash.
- **Secrets:** environment-specific stores; never in the repo.

---

## 10. Testing Strategy

- **Unit/integration (Vitest + RTL):** auth, onboarding, note creation, file
  upload, AI generation, quiz generation, flashcards, subscription state,
  payment webhook, free/premium limits, admin authorization.
- **E2E (Playwright):** signup → onboarding → create note → generate summary →
  generate flashcards → take quiz → hit free limit → paywall → subscribe.

---

## 11. Cost Model (monthly)

Assumptions: ~30% of registered users active; ~15 AI calls/active user/month;
blended ~$0.0025/call.

| Registered users | Active | Est. AI cost | Est. hosting | Total/mo |
|---|---|---|---|---|
| 100 | ~30 | ~$1 | $0–20 | ~$1–21 |
| 1,000 | ~300 | ~$11 | ~$30–45 | ~$40–56 |
| 10,000 | ~3,000 | ~$113 | ~$80–150 | ~$195–265 |

Fixed: domain ~$12/yr; Stripe charges only per successful charge.

---

## 12. Roadmap & Phase Status

| Phase | What | Status |
|---|---|---|
| 1 | Architecture + scaffold | ✅ complete |
| 2 | Database + auth | 🔄 in progress |
| 3 | Core UI (landing, dashboard, themes, onboarding) | ⬜ |
| 4 | Notes + document upload (paste, PDF → R2 + parse) | ⬜ |
| 5 | AI engine (summary, QA, flashcards, quiz) + usage metering | ⬜ |
| 6 | Exam countdown + study planner | ⬜ |
| 7 | Payments (Stripe checkout, webhooks, gating) | ⬜ |
| 8 | Testing + security hardening | ⬜ |
| 9 | Launch: CI/CD prod, SEO pages, analytics + admin | ⬜ |
| 10 | Post-launch: referrals, marketing automation, retention | ⬜ |

Each phase opens with: what/why, exact files, exact commands, env vars — and
ends with a verification checklist. Target: soft launch ~week 5, first paying
customer ~weeks 5–6.

---

## 13. Biggest Risks & Mitigations

1. **AI cost > revenue** → per-request cost logging + hard limits + cost dashboard.
2. **No retention** → streak, exam countdown (real deadline), spaced repetition, watch analytics before adding features.
3. **Scope creep** → MVP line is non-negotiable until paying users exist.
4. **Hallucination in educational content** → content labeled AI-generated; QA cites source.
5. **Abuse** → metering, rate limits, referral validation later.
6. **Payment/compliance** → Stripe handles PCI; privacy policy + terms drafted before launch.
7. **Solo bandwidth** → architecture chosen for low ops burden; automation is a stated goal.

---

## 14. First-User Strategy

Build (weeks 1–3) → payments + hardening (week 4) → soft launch (week 5):
founder recruits **20–50 real students** (network, campus groups, study
Discords/Reddits), one-on-one onboarding, observe usage → free limits hit →
honest paywall → first paying users (weeks 5–6). **5 paying users before any
new feature.**

---

## 15. Repository Layout

```
src/
  app/                    # Next.js App Router (pages + API routes)
    api/auth/[...all]/    # Better Auth handler
  db/
    auth-schema.ts        # Better Auth tables (canonical CLI output)
    schema.ts             # Domain tables
    index.ts              # getDb() + merged schema
  lib/
    auth.ts               # Better Auth server config
    auth-client.ts        # Better Auth React client
    ai/provider.ts        # provider-agnostic model factory
    ai/generate.ts        # single AI entry point
  middleware.ts           # session refresh + route guards
drizzle/                  # generated SQL migrations
docs/architecture.md      # this document
```
