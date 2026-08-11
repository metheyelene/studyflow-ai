# StudyFlow AI — Design-Quality Audit

Audit date: 2026-08-11 · Branch: `main` · Every finding was verified against the current Flutter code (`mobile/lib`) and the shared backend routes. The bar: StudyFlow must read as a professionally shipped product — **designed by humans, engineered professionally, powered by AI** — not as an AI-generated scaffold.

---

## 1. What is strong (keep)

- **Glass material system** is centralized (`GlassTheme`, four surface tiers, blur reserved for shell/sheets/modals) — cards don't over-blur.
- **Honest empty states** exist on notebooks and the chat ("Ask your notebook"), with real CTAs.
- **Real data pipeline** on notebooks + chat; backend is the source of truth; no client-side limits.
- **Error copy** is user-safe (no HTTP codes/stack traces), retries are wired.
- Radius tokens (`radiusCard/Inner/Pill`) and the responsive breakpoint helpers are in place.

## 2. Highest-severity findings (fixed this pass)

| # | Finding | Where | Fix |
|---|---|---|---|
| 1 | **Fake buttons**: "Paste text" / "Upload PDF" toast *"arrives with the backend (next phases)"* | notebook Sources tab | Implemented real paste-text source creation (POST source route) + real source list (new GET route); removed the fake PDF button |
| 2 | **Placeholder tabs in nav**: Study and Progress show *"Coming in a later phase"* — dead-end tabs in the primary nav | Study/Progress routes | Replaced with real screens: exam countdowns + study-material entry (Study); live stats + honest insights state (Progress) |
| 3 | **Fake-looking hardcoded widget**: "0/20 AI actions" ring was hardcoded; the real `/api/usage` endpoint was never wired | dashboard hero | Wired real usage (used/limit/remaining/plan/reset), skeletons, retry-on-error |
| 4 | **Hardcoded "No upcoming exams"** — onboarding exams exist server-side but never rendered | dashboard | Real countdown cards from `GET /api/onboarding`, honest empty state retained |
| 5 | **No spacing/typography tokens** — ad-hoc `fontSize: 12/12.5/13/14/15/16` and arbitrary paddings (8…120) across screens | all screens | Added `AppSpacing` scale + `AppText` scale in the theme; new screens use them |

## 3. Follow-up sweep (documented, not all done this pass)

- **Typography**: migrate remaining screens to `AppText` styles; one scale, no random sizes.
- **Motion language**: default Material page transitions everywhere; add context transitions (detail fade/slide, modal scale, sheet spring). GlassButton got a press micro-interaction (subtle scale) this pass; card/list entrance animation is next.
- **Shared-element continuity**: notebook card → detail could share the title morph; source card → viewer likewise.
- **Bottom padding parity**: pushed branch routes are overlapped by the floating nav on phones (chat input fixed last pass); scroll views use 40–120px varied clearance — normalize via a single `kNavClearance` constant.
- **Haptics**: no `HapticFeedback` yet — add on quiz answer / save / subscribe.
- **AI progress language**: chat now shows a typing indicator; longer actions should stream stage copy ("Reading your sources…") only when the backend genuinely reports stages.
- **Performance**: `blurEnabled` is already toggleable; verify per-device on real hardware (weakest link is CanvasKit on web, not the app shell).

## 4. Vibe-code checklist (run before each release)

- [ ] No fake buttons / toasts that say "arrives with the backend" — implement or remove
- [ ] No "Coming in a later phase" text in user-visible surfaces
- [ ] No hardcoded numbers that look like data (usage rings, counts) — always from API
- [ ] Every nav destination renders real content or a designed empty state with a real CTA
- [ ] Consistent spacing/type on any screen touched this release
- [ ] Loading = skeleton or contextual state, never a bare spinner; errors = friendly + retry
