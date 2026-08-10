# StudyFlow AI — 5-Week MVP Plan

> **Start:** 2026-08-10 · **Soft launch:** week 5 · **First paying users:** weeks 5–6
>
> Target: **5 paying users before building one more feature.** This checklist is
> the tracker — check items off as we complete them, and don't start a new week
> until the previous week's gate passes.
>
> Related docs: [`architecture.md`](architecture.md) · [`plans-and-limits.md`](plans-and-limits.md) ·
> [`playbook-first-students.md`](playbook-first-students.md)

---

## Critical review (2026-08-10) — what changed and why

This plan was reviewed against the goal ("5 paying users, fast") and the
constraint (one person, evenings/weekends). Three weeks were over-scoped for a
solo founder; the cuts and moves below are already reflected in the checklists.

**Cut from the MVP (all now post-launch):**

- **Q&A with citations** — the hardest AI feature (chunking, retrieval,
  citation mapping) and the least essential to the "aha". Revisit once paying
  users exist.
- **Flashcard review-progress system** — MVP keeps generate + flip +
  know/don't-know. Progress/history tracking is a product of its own.
- **Quiz history** — keep score + explanations; history charts are post-launch.
- **Rule-based study planner** — moved after launch. The exam countdown stays
  (cheap, sticky, brings users back).
- **PWA + SEO articles** — post-launch. Week 5 keeps robots.txt + sitemap
  basics only.

**Moved:**

- **Recruitment no longer waits for week 5.** Week 4 now includes building the
  60-name candidate list and first warm DMs as a waitlist ("beta opens next
  week"), so week 5 is deploy + onboard — not deploy + recruit + onboard.

**Risk register (highest first):**

1. **AI output quality is the product.** If summaries/flashcards/quizzes from
   real student notes are mediocre, nothing else matters. Mitigation: day 1 of
   week 3 is an AI quality check on ONE real note (generate + human review)
   before building any more UI around it.
2. **Recruitment is a human dependency** that can't be automated or coded
   around. It now starts in week 4, and the candidate list is the most
   important non-code task between now and then.
3. **Cost blowup** on quiz generation (long notes × many questions). Capped by
   `plans.ts` + `ai_requests` logging; check the numbers daily in week 3.

**Sequencing dependency:** the weeks stack — Week 3 (AI) can't be validated
until Week 2 (notes) works, and Week 2 can't work until Week 1's DB gate
passes. As of 2026-08-10 that gate is **not** passed (`.env` still has the
local placeholder URL), so the single most important task is the Neon
connection, not more building.

---

## Accounts you'll need (create exactly when listed — nothing earlier)

| When | Account | Where | What for |
|---|---|---|---|
| Week 1, day 1 | **Neon** (free) | https://neon.tech | Postgres database — the gate for everything |
| Week 2 | **Cloudflare R2** (free tier) | https://dash.cloudflare.com → R2 | PDF file storage |
| Week 3 | **OpenAI or Anthropic** (pay-per-use) | platform.openai.com / console.anthropic.com | AI generations |
| Week 4 | **Stripe** (free, pay-per-charge) | https://stripe.com | Payments + subscriptions |
| Week 5 | **Vercel** (free tier) + **GitHub** | vercel.com · github.com | Production deploy + CI/CD |
| Week 5 | **Sentry** (free tier) | https://sentry.io | Error tracking |

Every key goes in `.env` locally (never chat, never git) and, at deploy time, in
Vercel's secret store.

---

## Week 1 — Foundation: live database, auth, app shell (Aug 10–16)

**Goal:** a student can sign up, answer 5 onboarding questions, and land on a
dashboard shell.

### Day 1 — the gate
- [ ] Create Neon account → project `studyflow` → copy **pooled** + **direct** connection strings
- [ ] Put them in `.env` (`DATABASE_URL` = pooled, `DATABASE_URL_DIRECT` = direct)
- [ ] `npm run db:migrate` → all 20 tables apply with no errors
- [ ] `npm run dev` → app loads at localhost

### Rest of week
- [ ] Signup page (name, email, password) — Better Auth `signUp.email`
- [ ] Login page + logout — `signIn.email`, `signOut`
- [ ] Onboarding flow (5 questions → saves `profiles` row): what are you studying / subjects / exam dates / daily study minutes / what do you want help with
- [ ] App shell: authenticated layout, sidebar nav, **light/dark theme toggle**
- [ ] Session guard works (`/app/*` redirects to login when logged out)
- [ ] First version of the landing page (placeholder copy; real copy comes week 5)

**Verify (run before the gate passes):**
```bash
npm run lint && npm run typecheck && npm run build
```
- [ ] Manual: sign up → onboarding → dashboard; log out → /app redirects to login; log back in → session restored
- [ ] **Gate:** a fresh student can go signup → dashboard in under 2 minutes

---

## Week 2 — Notes & documents (Aug 17–23)

**Goal:** a student can upload their real notes (paste or PDF) and see them as
organized, searchable study material.

- [ ] Create **Cloudflare R2** account; add `R2_*` keys + bucket to `.env`
- [ ] Subjects CRUD (name, color)
- [ ] Paste a note (title, subject, content) → saved as `notes` row
- [ ] Note list (grouped by subject) + note detail + edit
- [ ] PDF upload: client uploads → server route → file to R2 → server-side text extraction (`pdf-parse`) → auto-creates a note from the extracted text
- [ ] Upload status flow (processing → ready/failed) with friendly errors ("This file looks damaged…", "PDFs up to 25 MB…")
- [ ] Document limit enforced (3 free / 50 premium, from `src/lib/plans.ts`)

**Verify:**
```bash
npm run lint && npm run typecheck && npm run build
```
- [ ] Manual: paste a note; upload a real PDF and see its text as a note; upload a broken file and see the friendly error; upload a 4th PDF as free user → blocked with clear message
- [ ] **Gate:** upload → note with extracted text in under 1 minute

---

## Week 3 — AI engine (Aug 24–30)

**Goal:** the "aha" moment — notes become summaries, flashcards, and quizzes in
seconds.

- [ ] Add AI provider key to `.env` (`AI_PROVIDER=openai` + `OPENAI_API_KEY`, or `anthropic`)
- [ ] **Day 1 quality check:** generate a summary + 10 flashcards + a quiz from ONE real student note; review the output with the founder before building any more UI around it (risk register #1)
- [ ] Summary generation — all 5 types (short, detailed, key concepts, definitions, exam points) via `lib/ai/generate.ts`
- [ ] Flashcards — generate deck + ~20 cards from a note; flip + know/don't-know buttons (progress tracking is post-launch)
- [ ] Quiz — generate MCQs (difficulty, count ≤ plan cap, explanations); take quiz → score (history charts are post-launch)
- [ ] **Usage metering** (`lib/usage.ts`): atomic AI-action increments, limit enforcement, "AI usage remaining" widget on the dashboard
- [ ] Friendly AI error states (AI unavailable / timeout / rate limit / note too long)
- [ ] Every generation logs to `ai_requests` (provider, model, tokens, cost, latency)

**Verify:**
```bash
npm run lint && npm run typecheck && npm run build
```
- [ ] Manual: generate all 5 summary types from one note; generate a deck and review 5 cards; take a full quiz and see score + explanations; hit the free limit → friendly "upgrade" message (paywall page comes week 4)
- [ ] Check `ai_requests` rows exist with real token/cost numbers (Drizzle Studio)
- [ ] **Gate:** new user uploads notes → has a summary + flashcards in under 2 minutes

---

## Week 4 — Planner, countdown, payments, hardening (Aug 31 – Sep 6)

**Goal:** students get an exam countdown, and the first students can pay.

- [ ] Exam countdown (add exam, "34 days left") — the daily-task planner built from it moves after launch
- [ ] **Start recruitment (playbook §2):** build the 60-name candidate list; send first warm DMs as a waitlist ("beta opens next week")
- [ ] Create **Stripe** account; add test keys to `.env`
- [ ] Checkout (monthly + yearly price points from `PRICING`)
- [ ] Webhook endpoint: verify Stripe signature → update `subscriptions` row (idempotent)
- [ ] Customer portal (manage / cancel subscription)
- [ ] Premium gating server-side: premium ⇔ `subscriptions.status IN ('active','trialing')` — **never** a frontend flag
- [ ] Paywall page using `PLAN_COPY` (honest: what free gets, what premium adds, both prices, how to cancel)
- [ ] Rate limiting on auth + AI endpoints (start with a simple DB-backed limiter; Upstash when scaling)
- [ ] Input validation with Zod on every API route; friendly 4xx messages

**Verify:**
```bash
npm run lint && npm run typecheck && npm run build
```
- [ ] Manual (Stripe **test mode**, card `4242 4242 4242 4242`): subscribe monthly → subscription row becomes `active` → premium features unlock; cancel in portal → `cancel_at_period_end`; a forged webhook body is rejected
- [ ] **Gate:** a test user can go free → limit → paywall → paid → premium, all in test mode

---

## Week 5 — Launch (Sep 7–13)

**Goal:** a real, public, deployable product — and the first students in it.

- [ ] Create **GitHub** repo + **Vercel** project; push code; deploy production
- [ ] CI/CD (GitHub Actions): lint → typecheck → tests → build → security scan → deploy
- [ ] Real landing page copy (hero, problem, solution, how it works, features, pricing, FAQ, privacy) — honest, real product screenshots, no invented social proof
- [ ] Privacy policy + Terms pages (draft; you review before going live)
- [ ] **Sentry** wired up
- [ ] SEO basics: metadata, robots.txt, sitemap (PWA + SEO articles move after launch)
- [ ] **Launch audit** — full pass of the 22-item checklist from the brief (auth, security, payments, webhooks, limits, admin, analytics, backups, domain, mobile, accessibility)
- [ ] **Soft launch:** onboard the waitlist built in week 4 ([`playbook-first-students.md`](playbook-first-students.md)) — first 20–50 students

**Verify:**
```bash
npm run lint && npm run typecheck && npm run build && npm test
```
- [ ] Production URL: full journey end-to-end — signup → onboarding → upload → summary → flashcards → quiz → limit → paywall → test checkout
- [ ] Mobile: phone-width check of landing + app; dark/light both pass
- [ ] Accessibility + performance pass (Lighthouse ≥ 90 on the key pages)
- [ ] **Gate:** production is live, 20+ students are in, and the first feedback is being collected

---

## After launch (weeks 6+)

- [ ] First 5 paying users (beta-end message, [`playbook`](playbook-first-students.md) §4)
- [ ] Build ONLY what the usage data says students actually used
- [ ] Then: referrals, SEO articles, shareable cards (streak/score/countdown), marketing content

---

## How to run this week's verification (non-expert version)

1. Open Terminal, `cd ~/studyflow-ai`
2. Run the three checks: `npm run lint` (no errors) → `npm run typecheck` (no output = good) → `npm run build` (ends with "✓ Compiled successfully")
3. Run the app: `npm run dev`, open the printed URL
4. Walk the manual checklist for the week; if anything fails, tell me exactly what you saw and I'll diagnose it before changing anything
