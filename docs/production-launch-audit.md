# StudyFlow AI — Production Launch Audit

Audit date: 2026-08-11 · Branch: `main` · Commits through `e44b179`

This is the honest state of the product against the final-launch objective.
Every claim below was verified against the current repository. The short
version: **the backend is near production-complete; the Flutter app is at
Phase 4 of 20 and cannot ship as-is; and Play/Apple accounts + a payments
architecture decision are hard blockers that only you can resolve.**

Legend: ✅ done · 🟡 partially done · ❌ missing · 🔒 needs you (account/credential/decision)

---

## 1. Two-sided inventory

### Backend (Next.js 16) — the good news

| Area | Status | Notes |
|---|---|---|
| Auth (better-auth, email/password + Google) | ✅ | sessions, reset, verification hooks, rate limits |
| Onboarding / profile / usage REST routes | ✅ | Phase 0 routes; used by mobile |
| Notebooks REST API | ✅ | list/create with plan limits |
| Source-grounded AI | ✅ | orchestrator, retrieval, cache, grounded Q&A, extraction — all tested (87 tests) |
| Stripe billing | ✅ | checkout / portal / webhook, signature verification, idempotent |
| Founding-member store | ✅ | atomic 35-slot allocation, permanent claim, tested |
| Entitlement (`getPlanForSession`) | ✅ | free / premium / founding_member |
| Analytics + AI cost logging | ✅ | `analyticsEvents`, `aiRequests` tables |
| Admin panel | ✅ | `/admin` gated by `ADMIN_EMAILS` |
| DB schema | ✅ | 22 tables incl. sources, chunks, usage, subscriptions |
| Deployment docs | ✅ | vercel.json + step-by-step guide |

**Backend gap:** not deployed anywhere. `studyflow.ai` serves a *different* app;
`.env` points at `localhost`. There is no production URL, DB, or live AI key wired up.

### Flutter mobile — the gap

| Phase (mobile plan) | Status | What exists / what's missing |
|---|---|---|
| Phase 0 (REST routes) | ✅ | backend side done |
| Phase 1–2 (scaffold, glass design system) | ✅ | full glass component set |
| Phase 3 (navigation, real screens) | ✅ | dashboard, notebooks, profile, settings, about |
| Phase 4 (auth + API client) | ✅ | cookie session, login/signup, notebooks on API |
| Phase 5 (onboarding) | ❌ | not implemented in Flutter |
| Phase 6 (dashboard data) | 🟡 | static shell; quick actions navigate; no live usage widget |
| Phase 7 (notebooks) | 🟡 | list/create/delete live; **detail tabs are placeholders** |
| Phase 8 (sources + upload) | ❌ | "arrives with the backend" empty states |
| Phase 9 (notebook AI chat) | ❌ | not implemented |
| Phase 10 (citations/source viewer) | ❌ | not implemented |
| Phase 11 (flashcards) | ❌ | "Study tools" tab lists them, no screens |
| Phase 12 (quizzes) | ❌ | not implemented |
| Phase 13 (study planner) | ❌ | Study tab is a FeaturePlaceholder |
| Phase 14 (progress) | ❌ | Progress tab is a FeaturePlaceholder |
| Phase 15 (premium/subscriptions) | ❌ | profile shows a "Free" card only |
| Phase 16–20 (notifications, offline, analytics, testing, release) | ❌ | not started |

**Placeholder screens:** `StudyScreen`, `ProgressScreen` (FeaturePlaceholder);
notebook detail Sources/Ask AI/Study tools tabs (honest empty states).
**No Google Play Billing plugin, no in-app purchase code, no restore.**

---

## 2. Release blockers, in priority order

### 🔒 B1 — Payments architecture decision (YOUR decision, before any code)

The web/backend uses **Stripe**. But this is a **Flutter app distributed on
Google Play selling a digital subscription**. Google Play policy requires
**Google Play Billing** for digital subscriptions in the Play-distributed
Android app — a direct Stripe checkout inside the Android app, or a redirect
to a PhonePe/Stripe payment page, violates Play policy and risks removal.

**Options:**

1. **Google Play Billing (recommended)** — `flutter_inapp_purchase` /
   `in_app_purchase` plugin; backend webhook validates Play purchases
   (RTDN), entitlement stays server-side. Founding $2 plan becomes a Play
   subscription product with the 35-cap enforced by the backend entitlement
   service. Web checkout remains Stripe. iOS later uses StoreKit.
2. **India alternative-billing program (PhonePe/UPI)** — only if you
   complete Play Console enrollment for the alternative-billing program,
   implement the required APIs + user-choice screens + transaction
   reporting, and keep Play Billing alongside. Not something to attempt at
   launch; verify current eligibility first.
3. **Stripe-only** — acceptable for the *web* product; not for the Android app.

**Decision needed:** which path for Android subscriptions. Until this is
decided, the "payments in Flutter" work is blocked by design, not by effort.

### 🔒 B2 — Google Play developer account ($25, one-time)

**STEP:** https://play.google.com/console → create developer account →
pay → verify identity (may require a real bank/card + sometimes a short
video verification). Play review can take days after submission.

### 🔒 B3 — Apple Developer account ($99/year) for iOS

iOS is code-complete-ready only; **no Xcode, no signing certs, no App Store
Connect** on this machine. iOS release is entirely manual after Phase 20.

### 🔒 B4 — Production backend deployment

Vercel project exists and is linked (`.vercel/project.json`), but nothing is
deployed. Requires: Neon project + URLs, env vars in Vercel, `npx vercel
--prod` (or GitHub connection), then setting the GitHub Actions
`API_BASE_URL` variable and rebuilding the release APK. Full steps:
`docs/deployment.md`. **Until this is live, no build can sign in.**

### 🔒 B5 — Legal pages review

`/privacy` and `/terms` exist with flagged placeholders (effective date,
refund policy, governing law). Play requires a privacy-policy URL and
accurate data-safety answers. Review is yours.

### 🟡 B6 — Mobile feature completion (the bulk of the work)

Phases 5, 7(partial), 8–15 in the Flutter app. Nothing here is blocked by
accounts — it's build work. Priority order below.

### 🟡 B7 — iOS assets/config polish (non-blocking for Android launch)

Icons exist; bundle ID set; display name fixed. Verify splash + adaptive
icon for Android before submission.

---

## 3. Execution plan (priority order, code-side)

1. **P1 — Mobile onboarding (Phase 5)** — screens + wiring to
   `GET/POST /api/onboarding`; the router already awaits it conceptually.
   Smallest complete feature with an existing backend.
2. **P2 — Notebook detail real backend** — list sources, upload/paste text
   → `POST /api/notebooks/:id/sources` (new REST route), processing status,
   then Ask AI → `POST /api/ai/chat` (new REST route wrapping the existing
   grounded orchestrator). This is the NotebookLM core.
3. **P3 — Flashcards + quizzes (Phases 11–12)** — new REST routes +
   screens; generation from a notebook via the existing AI actions.
4. **P4 — Study planner + exams + progress (Phases 13–14)** — REST routes +
   screens + dashboard widgets.
5. **P5 — Premium UI + entitlement (Phase 15)** — pricing/paywall screen
   reading `GET /api/usage` + plan; checkout links (web Stripe) or Play
   Billing once B1 is decided.
6. **P6 — Release hardening** — analytics events in Flutter, error
   handling, offline notes, integration tests, release build per §34.
7. **Store + launch** — after B2/B4/B5: internal test → closed test →
   production; founder dashboard (`/admin`) already exists for revenue.

---

## 4. What I did not find (and will not fake)

- No fake users, purchases, revenue, or testimonials anywhere. ✅
- No secrets in the Flutter app (no AI keys, no payment keys). ✅
- The mobile app has **no payment code yet** — nothing to bypass. The
  backend Stripe path is web-only and correctly refuses to fulfill without
  verified webhooks. ✅
- Play submission itself cannot be automated (identity/banking/legal are
  manual by policy) — that is B2/B3 and the "final Publish" button.

---

## 5. Bottom line

**Backend:** deploy it (B4) and the web product is genuinely shippable.
**Mobile:** 6 build phases remain; nothing is built on a broken foundation —
the design system, auth, routing, and API client are solid and tested.
**Money:** the $2 founding offer is fully engineered server-side; the
remaining question is which billing rails the Android app must use (B1).

Priority order for me: P1 → P2 → P3 → P4 → P5 (code), interleaved with B4
(the moment you give me a Neon URL / Vercel login) and B1 (the payments
decision). Store submission waits on B2 + B5.
