# Glass UI Overhaul — Design Plan (iOS-26-inspired, not an Apple clone)

**Principle:** translucent materials, layered depth, soft light, and system typography
— used to create *hierarchy*, not decoration. Glass creates three layers:

```
Foreground  → floating navigation, primary actions, modals   (strong glass, high contrast)
Middle      → content cards, widgets, editors               (subtle glass, readable)
Background  → ambient gradient light, theme-aware           (atmosphere, never noise)
```

Hard rules:

- **Never put glass around everything.** Text-heavy surfaces (note editor,
  table rows, error states) stay solid or near-opaque where readability wins.
- **Accessibility beats aesthetics.** If a glass surface fails contrast, raise
  its opacity. Every interactive element keeps a visible focus ring.
- **`prefers-reduced-motion`** disables decorative drift/springs.
- No Apple assets, logos, or copied screens. StudyFlow keeps its own identity:
  indigo accent, Geist type, its own layout.

---

## 1. Design tokens (globals.css)

| Token | Light | Dark |
|---|---|---|
| `--background` | near-white, cool tint `oklch(0.985 0.002 250)` | deep near-black `oklch(0.16 0.015 265)` — never pure black |
| `--primary` (accent) | indigo `oklch(0.55 0.2 277)` | brighter indigo `oklch(0.68 0.17 277)` |
| `--glass-bg` | `oklch(1 0 0 / 0.55)` | `oklch(1 0 0 / 0.07)` |
| `--glass-bg-strong` (modals) | `oklch(1 0 0 / 0.72)` | `oklch(1 0 0 / 0.12)` |
| `--glass-bg-subtle` (secondary) | `oklch(1 0 0 / 0.35)` | `oklch(1 0 0 / 0.045)` |
| `--glass-border` | `oklch(1 0 0 / 0.65)` (lit edge) | `oklch(1 0 0 / 0.12)` |
| `--glass-highlight` | `oklch(1 0 0 / 0.9)` inset top | `oklch(1 0 0 / 0.08)` inset top |
| blur | `12 / 20 / 36px` | same (cheap radii) |
| shadow | soft layered `0 1px 2px rgb(0 0 0/4%), 0 12px 32px rgb(0 0 0/8%)` | deeper `0 12px 32px rgb(0 0 0/45%)` |

Motion: `--ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1)` for sheets/pills;
`--ease-out-soft: cubic-bezier(0.16, 1, 0.3, 1)` for cards. Durations 150/250/400ms.

## 2. Ambient background (root layout)

Three fixed, cheap radial-gradient "light fields" (no `filter: blur`, no
backdrop-filter on the background itself) tinted with the accent — one large
cool glow top-left, one warm-violet right, one small lower-center. They drift
~40s on a slow loop; drift is disabled under reduced motion. `aria-hidden`,
`pointer-events-none`, behind everything (`-z-10`). Per-screen intensity can be
tuned later (e.g. exam screens warm up).

## 3. Component architecture

New/updated primitives (all consume tokens, no duplicated styles):

- **`GlassCard`** — tone prop: `primary` (content cards), `secondary` (widgets,
  more transparent), `floating` (quick actions, elevated, stronger shadow),
  `modal` (dialogs, strong blur). Rounded 2xl, inset top highlight.
- **`GlassPill`** — contextual actions, quiz answers, chips.
- **Button** gains `glass` + `glass-secondary` variants (translucent, spring
  press scale). Hierarchy: solid accent primary → glass secondary → ghost/tertiary.
- **Input / Select / Textarea** — translucent fill, glass border, accent focus ring.
- **Card** (existing shadcn) restyled to glass so every current screen upgrades
  uniformly; keep solid-foreground text for contrast.
- **Sheet** — new Radix-dialog bottom sheet, glass modal surface, spring slide-up.
- **Skeleton / Progress / Badge / Dialog / Dropdown** — restyled to the glass
  material system.
- **Navigation** — desktop: floating glass sidebar (rounded, inset from edges,
  no full-height border). Mobile: floating glass bottom tab bar (Home, Notes,
  Study, Progress, Profile) with safe-area padding; selected tab gets a glass
  highlight + accent icon.

## 4. Screen-by-screen

| Screen | Change |
|---|---|
| **Landing** | Glass nav bar, ambient background, hero headline with soft glow, glass product mock, glass feature/steps/pricing cards, FAQ accordions |
| **Auth (login/signup/forgot/reset)** | Transparent layout over ambient bg; glass card; solid input fills for readability; glass "or" chip |
| **Onboarding** | Glass card; goal chips become glass pills with `aria-pressed` glass highlight |
| **Dashboard** | Time-based greeting ("Good evening — Ready to study?"); floating hero card with Today's Focus progress ring (real metering data); 5 floating quick-action buttons (Upload/Summarize/Flashcards/Quiz/Plan); striking exam countdown card from **real** exams table; glass streak + AI-usage widgets; premium discovery cards |
| **Notes / Flashcards / Quizzes / Planner (placeholders)** | Coming-soon empty states restyled: glass surface, useful copy ("Create your first study plan…"), CTA to nearest available action — no "No data found." |
| **Settings** | Grouped glass sections via Card |
| **Pricing** | Premium hero glass card ("Unlock your complete AI study system"), glass comparison, glass FAQ |
| **Design system page** | New "Glass materials" section documenting the four tones + tokens |

## 5. Motion & performance

- Springs only where they carry meaning: sheet presentation, pill press,
  card hover lift, quiz answer selection. Everything else is a 150–250ms
  opacity/transform ease.
- Backdrop blur is bounded: sidebar + tab bar + modals + hero card only.
  Never stack blur on blur.
- Charts/progress use CSS rings — no chart library, no canvas, no cost.

## 6. Honesty guardrails (unchanged from product rules)

No fake data in the redesign: the exam countdown shows real rows or a genuine
empty state; the "Today's Focus" ring shows real usage/streak values; premium
surfaces keep the transparent copy from `docs/premium-conversion.md`.
