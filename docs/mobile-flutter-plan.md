# StudyFlow AI — Flutter Mobile App: Audit & Build Plan

One Flutter codebase → Android + iOS, sharing the existing StudyFlow backend,
auth, database, AI engine, subscriptions, and analytics. This document is the
result of the pre-implementation audit (implementation rule §53) and the
phase-by-phase build order (§54). It is the contract for the work; the repo is
not modified beyond this doc until the plan is approved.

---

## 1. Audit: what the mobile app can reuse today

### 1.1 Backend API surface (exists, callable from Flutter)

| Area | Endpoint(s) | Notes |
|---|---|---|
| Auth | `/api/auth/[...all]` (Better Auth) | sign-up, sign-in, sign-out, forgot/reset password, session, Google OAuth, delete account. Cookie-based sessions today. |
| Notebooks | `GET/POST /api/notebooks`, `GET/DELETE /api/notebooks/[id]` | list/create/get/delete, auth-checked server-side. |
| Sources | `POST /api/notebooks/[id]/sources` (JSON paste **or** multipart file), `DELETE .../sources/[sourceId]` | PDF/DOCX/TXT/MD extraction + chunking runs server-side. |
| AI chat | `POST /api/notebooks/[id]/chat` | **Streams** plain text; answer followed by a `__SF_CITATIONS__{json}` trailer with validated citations. Consumes 1 AI action atomically. |
| AI actions | `POST /api/notebooks/[id]/actions` | summarize, explain, flashcards, quiz, study guide, FAQ, extract, outline, compare, mind map. Structured, validated, grounded. |
| Billing | `POST /api/billing/checkout`, `POST /api/billing/portal`, `POST /api/billing/webhook` | Stripe web flows + webhooks; `subscriptions` table mirrors state. |
| Limits/entitlement | Server-side (`usage`, `subscriptions`, `plans.ts`) | Enforced in the API layer — mobile never computes its own limits. 429/403 carry user-facing messages. |

### 1.2 Backend gaps: server-action-only logic (NOT callable from Flutter)

Next.js **server actions** are not HTTP endpoints. These existed as server
actions and are now exposed as REST routes (**Phase 0 — done**):

| Logic | Today | Mobile needs |
|---|---|---|
| Analytics events (`trackEventAction`) | **`POST /api/analytics`** (works logged out for pre-auth events) | done |
| Onboarding (`completeOnboarding`) | **`GET` + `POST /api/onboarding`** (state restore + idempotent completion) | done |
| Profile/settings (`updateProfileAction`, password change, data export) | **`GET` + `PUT /api/profile`**; password change stays on better-auth (`/api/auth/change-password`); data export remains a server action for now | mostly done |
| AI usage widget data | **`GET /api/usage`** (plan + used/limit/remaining/reset) | done |

The shared logic lives in `src/lib/onboarding.ts` and `src/lib/profile.ts` —
the server actions and the REST routes call the same functions, so web and
mobile validate and persist identically.

### 1.3 Schema-level reuse

All domain tables already exist and are mobile-agnostic: `profiles`,
`subjects`, `notebooks`, `notebook_sources`, `source_chunks`, `ai_cache`,
`flashcard*`, `quiz*`, `exams`, `study_plans`, `subscriptions`, `founding_*`,
`usage`, `ai_requests`, `analytics_events`. **Flashcards, quizzes, exams, and
study plans have tables but no REST APIs yet** (web pages are placeholders).
The mobile roadmap must sequence these features *with* their APIs — built once,
consumed by both platforms.

### 1.4 What must NOT be duplicated

AI orchestration, retrieval, citation validation, extraction/chunking, usage
limits, subscription logic, founding-member allocation, analytics: all stay
server-side. **The Flutter app contains zero AI provider keys** (§40–41).

---

## 2. Environment constraint (read first)

~~**Flutter/Dart is not installed on this machine**~~ **Resolved**: Flutter
3.44.9 (stable, arm64) installed via Homebrew. Android SDK and Xcode are not
complete on this machine, so `flutter analyze` + `flutter test` are the local
verification gates; platform builds run in CI.

## Status (updated)

- **Phase 1 — scaffold**: `mobile/` created (android + ios + web targets),
  core deps in (`riverpod`, `go_router`, `dio`, `flutter_secure_storage`,
  `url_launcher`, `package_info_plus`).
- **Phase 2 — design system**: theme tokens (light/dark), glass materials,
  responsive breakpoints, and the full glass widget library (card, button,
  pill, badge, input, sheet, progress, nav, misc) — all centralized, no
  per-screen blur.
- **Creator page** (from the earlier web feature, now in Flutter): MV
  monogram, mailto links via `url_launcher`, live version/build from
  `package_info_plus`, About StudyFlow, under Profile → Settings → About.
  On web the section is public at `/about/creator` (linked from the landing
  footer); the mobile screen is the 1:1 in-app equivalent — see §10 build
  order for the explicit About/Creator row.
- **Web deep links**: `usePathUrlStrategy()` in `main.dart` (no-op on
  mobile) so the Flutter web build answers real paths — the landing
  footer's "Made by Mithil" href `/about/creator` opens the Creator screen
  directly. SPA fallback (serve `index.html` for unknown paths) is required
  when hosting the web build.
- **Phase 3 — navigation to real screens**: dashboard (quick actions that
  navigate, upcoming-exams section), notebooks (list + search + create via
  glass sheet, detail workspace with Sources / Ask AI / Study tools tabs),
  profile (plan card), with `/about/creator` reachable and a master-detail
  split on tablet/desktop (`/notebooks/:id`). Notebooks hold device-local
  state (Riverpod `NotebooksNotifier`) until the backend client lands.
  Found + fixed a real bug: sheets/modals now use the root navigator so
  they render above the floating bottom nav (branch navigators sit under
  the shell); GlassTabBar scales down instead of overflowing.
- Verification: `flutter analyze` clean, **21 tests passing** (notebook
  create/open/search, master-detail, controller, quick-action navigation),
  `flutter build web` succeeds.
- Next: Phase 0 (4 server-action → REST routes) then Phase 4 (auth + API
  client) to replace the device-local state with the real backend.

---

## 3. Project structure & architecture

**Location:** `mobile/` inside the existing `studyflow-ai` repo (monorepo).
Same CI, same release workflow, backend stays centralized.

**Stack (one choice each, no mixing):**

| Concern | Choice | Why |
|---|---|---|
| State | **Riverpod** (flutter_riverpod) | Testable, compile-safe, no codegen needed for providers; the prompt's preferred option. |
| Routing | **go_router** | Declarative, deep-link support (§28), per-platform nav adaptation. |
| Networking | **dio** + `cookie_jar` | Interceptors for auth expiry/retry/timeout/offline (§32); cookie persistence for the existing cookie-based auth. |
| Secure storage | **flutter_secure_storage** | Session/preferences only — never AI keys (§31, §40). |
| Local cache | **drift** (SQLite) or **hive** | Notebook/source/quiz offline cache (§30). |
| In-app purchases | **in_app_purchase** (store billing) | Platform-compliant subscriptions (§26) — see §8. |
| Analytics | REST `POST /api/analytics` | Same events table as web. |
| Crash reporting | **Sentry Flutter** | Server-side DSN; no PII. |
| Background | `workmanager` (Android) / BGTaskScheduler (iOS) | Study reminders, no spam (§29). |

**Layers** (strict, per §2): `features/*` (UI + Riverpod providers) →
`repositories/*` (domain logic) → `services/*` (api, auth, storage, payments)
→ `core/*` (theme, routing, networking, errors, constants). Widgets never
touch HTTP; repositories never import UI.

**Planned `lib/` tree** (per §4):

```
lib/
  main.dart
  core/        theme/ routing/ networking/ storage/ errors/ constants/ utils/
  shared/      widgets/ models/ services/
  features/
    auth/ onboarding/ dashboard/ notebooks/ sources/ ai_chat/
    flashcards/ quizzes/ study_planner/ exams/ progress/
    subscription/ profile/ settings/
```

## 4. Design system (glass → Flutter)

Recreate the web tokens in a single `GlassTheme` (light/dark):
background fields, `--glass-bg` translucency tiers, border, highlight,
blur radii, shadows, radius, spacing, typography, indigo accent, motion
(springs), reduced-motion flag.

Widgets (each in `shared/widgets/glass/`, centralized — never per-screen):

`GlassCard, GlassButton, GlassNavigation(rail/tab), GlassBottomSheet,
GlassModal, GlassInput, GlassPill, GlassBadge, GlassToolbar, GlassProgress,
GlassTabBar, GlassListTile, GlassSkeleton, GlassToast`.

**Performance rules** (§7): `BackdropFilter` is GPU-expensive — use one
ambient background layer per screen; blur the **navigation shell** and
sheets/modals only; cards use translucent fill + border without per-card
blur; a `disableBlur` theme flag for low-end devices. Lists use `ListView.builder`
and const widgets.

**Responsive** (§8): `LayoutBuilder`-driven breakpoints — phone (bottom tab
bar), tablet ≥ 600dp (navigation rail), ≥ 900dp (master-detail: notebook list
+ workspace side-by-side).

## 5. Auth on mobile

Recommendation: **keep the existing Better Auth cookie flow** — dio
`CookieJar` persists `better-auth.session_token`; zero backend change.
- sign-up / sign-in / forgot-password / reset-password / logout: existing
  `/api/auth/*` endpoints.
- session restoration on cold start: `GET /api/auth/get-session` (auth API
  catch-all) — 401 → routing to login.
- Google OAuth on mobile: Better Auth's `/api/auth/oauth2` flows are
  redirect-based; on mobile use the **in-app browser / custom tab** to reuse
  the same endpoint without new backend work, or gate Google sign-in to
  platforms where it's clean. Decision point at Phase 4.
- account deletion: existing endpoint.

## 6. Notebook experience mapping (web → mobile)

| Web (exists) | Mobile screen | Reuse |
|---|---|---|
| `/notebooks` list | Notebooks tab + master-detail on tablet | `GET/POST /api/notebooks` |
| Notebook workspace: sources + chat + tools | Workspace screen (sources sheet, chat, action sheet) | sources + chat + actions endpoints |
| Paste/upload source | Source sheet with file picker (`file_picker`) + paste | multipart + JSON endpoints, upload progress/retry (§39) |
| Chat with citations | Chat UI; citations open a **source viewer** (§18) | streaming + `__SF_CITATIONS__` trailer |
| Study tools | Bottom-sheet action menu | `/api/notebooks/[id]/actions` |

**Source viewer** (§18): for PDFs, a server-rendered page-image viewer is a
future phase (backend serves page images or the app renders extracted text
with page navigation from `source_chunks.page`); MVP = chunk-level citation
navigation (tap citation → show the chunk's excerpt + source + page), which
the existing `citations[].excerpt/page` payload already supports.

**Camera/OCR** (§15): `camera` + `google_mlkit_text_recognition` on-device OCR
(no server key), then upload the recognized text as a pasted source. Permission
requested only when the user taps "Scan".

## 7. Streaming chat client

The chat endpoint returns a raw text stream with a `__SF_CITATIONS__` trailer.
Dart: read `http.Response` body as a `Stream<Uint8List>`, `utf8.decoder`,
split on the trailer marker, parse JSON, then render citations as chips.
Handle interrupted streams (§38) by surfacing "Answer was interrupted" + Try
Again, and log server-side via the existing `ai_requests` error path.

## 8. Payments & subscriptions (§26, §27)

Apple and Google require **store billing** for digital subscriptions; Stripe
web checkout cannot be the primary in-app path. Plan:

1. **Store billing** via `in_app_purchase` (Apple IAP / Google Play Billing),
   products mirroring the founding-member ($2/mo, capped at 35) and standard
   Premium ($4.99/mo, $39.99/yr).
2. **Server-side verification**: extend the existing `subscriptions` +
   webhook machinery with IAP verification endpoints
   (`POST /api/billing/iap/apple`, `.../google`) — the app sends the
   purchase token/receipt, the backend verifies with the store, and ONLY the
   verified webhook path flips the entitlement (never the client callback).
   Founding-member allocation stays in the atomic counter service.
3. **Restore purchases** (§27): store restore + backend re-verification;
   entitlement always read from the backend.
4. Web (Stripe) stays as-is; both converge on the same `subscriptions` table.

This requires the user's **Apple Developer** and **Google Play Console**
accounts (Phase 21–22). No store credentials can be embedded in the repo.

## 9. Notifications, offline, analytics, crash reporting

- **Push (§29)**: Firebase Cloud Messaging (FCM) for both platforms; a
  notification-preferences screen writing to a new `notification_prefs` store
  (server-side table or profile column); permission prompt deferred to a
  meaningful moment (e.g., after first exam is created).
- **Offline (§30)**: cache notebooks/sources/quizzes locally (drift); a
  "Available offline" vs "Requires connection" badge; AI features explain
  they need a connection.
- **Analytics (§43)**: `app_opened`, `notebook_created`, `source_uploaded`,
  `ai_question`, `quiz_started/completed`, `paywall_viewed`,
  `checkout_started`, `subscription_started/restored`, … via
  `POST /api/analytics` → the existing `analytics_events` table.
- **Crash reporting (§44)**: Sentry Flutter, scrubbed breadcrumbs.

## 10. Phase-by-phase build order (§54) with backend coupling

| Phase | Mobile work | Backend prerequisite |
|---|---|---|
| 0 | — | **REST endpoints** — **done**: `/api/analytics`, `/api/onboarding`, `/api/profile`, `/api/usage` (server actions → routes, shared lib logic, 21 new tests). |
| 1 | `mobile/` scaffold, Riverpod + go_router + dio skeleton, CI (flutter analyze/test/build) | none |
| 2 | Glass design system + tokens | none |
| 3 | Navigation (bottom tab / rail / master-detail), deep links — **done** | none |
| 4 | Auth (cookie jar, restore session, reset password) | none |
| 5 | Onboarding | `/api/onboarding` |
| 6 | Dashboard (greeting, Today's Focus, quick actions, exam countdown, AI usage) | `/api/usage` |
| 6.5 | **About / Creator** — Profile → Settings → About StudyFlow → Creator: glass creator card (MV monogram, bio, tappable `mailto:` Contact Creator / Send Feedback, live version via `package_info_plus`). Mirrors the public web route `/about/creator` (1:1 content mapping, in-app instead of a web page). Scaffolded in Phase 2; completed with the Profile/Settings phase. | none |
| 7 | Notebooks list/create/rename/delete | existing |
| 8 | Sources + upload (progress, retry, cancel) + scan/OCR | existing |
| 9 | Notebook AI chat (streaming) + actions | existing |
| 10 | Citations + source viewer | existing (chunk/page payload) |
| 11–14 | Flashcards, quizzes, planner, progress | **new REST APIs** for these features (shared with web) |
| 15 | Premium/paywall + IAP + restore | `/api/billing/iap/*` |
| 16 | Notifications | FCM project + prefs store |
| 17 | Offline cache | none |
| 18 | Analytics + crash reporting | `/api/analytics` |
| 19–20 | Tests, perf/security audit | none |
| 21–22 | iOS/Android release prep (icons, screenshots, store copy) | user's store accounts |
| 23 | Production launch | user review of legal/billing |

**About / Creator mapping** (web → mobile): the web app serves the creator
page publicly at `/about/creator` (linked from the landing footer as "Made by
Mithil — StudyFlow AI" and from Settings → About StudyFlow). The Flutter app
reproduces the same section as an in-app screen under Profile → Settings →
About StudyFlow → Creator — same monogram, quote, email, and Contact
Creator / Send Feedback `mailto:` actions (`url_launcher`), with version/build
read from the app config instead of `package.json`. No backend dependency;
no extra permissions; only the two provided creator details are shown.

## 11. Testing & CI (§45–47)

- Unit: repositories (auth, chat trailer parsing, citations), state.
- Widget: glass widgets, auth screens, flashcard flip, quiz flow.
- Integration: notebook → upload → chat → citations; IAP restore.
- CI (GitHub Actions, matrix: analyze → test → build debug APK; iOS archive on
  macOS runner at release). **Never commit signing certs or store keys** —
  secrets live in the repo's GitHub secrets.

## 12. Versioning & changelog (§49)

SemVer `1.0.0` base; `CHANGELOG.md` maintained; pubspec version mirrored with
each release.

## 13. Open decisions requiring you

1. ~~**Install the Flutter SDK on this machine**~~ **Done** (see §2).
2. **Repo layout**: `mobile/` inside `studyflow-ai` — **done** (monorepo).
3. **Google OAuth on mobile**: in-app browser reuse vs. skip on mobile initially.
4. **Store billing** accounts (Apple Developer, Google Play Console) are yours
   to create — the code will be ready before they're needed (Phase 15/21).
5. Store **legal copy** (subscription terms, privacy) must be reviewed by you
   before submission (§48).

## 14. Immediate next step (recommended)

Phase 0 (4 small REST routes in this repo, tested) + Phase 3 (mobile
navigation/routing to real screens). Each phase lands as a verified commit,
same cadence as the web build.
