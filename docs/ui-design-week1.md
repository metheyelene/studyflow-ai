# StudyFlow AI — Week 1 UI Design Spec

Status: **Implemented** (Week 1). This document is the canonical design
reference for the auth pages, onboarding, and app shell. Weeks 2–5 must stay
consistent with these tokens and layouts.

---

## 1. Design principles

- **Premium, not generic.** Minimal surfaces, generous whitespace, one accent
  behavior per screen. No gradients-on-everything, no confetti.
- **Dark and light are first-class**, not afterthoughts. Every screen is
  designed in both modes and every color comes from a token — never a raw hex
  in a component.
- **Mobile-first.** The app must be fully usable on a phone; the desktop
  experience adds structure (sidebar) rather than changing behavior.
- **Honest UI.** No fake urgency, no invented metrics, no "guaranteed grades".
  Empty states say what's coming and when (e.g. "Usage metering arrives in
  Week 3") instead of pretending features exist.
- **Accessible by default.** Real labels, `aria-current`/`aria-pressed`/
  `role="alert"`, keyboard-operable menus, focus rings from the token system.

---

## 2. Theme token system

Class-based dark mode: `next-themes` toggles `.dark` on `<html>`; Tailwind v4
maps the CSS variables via `@theme inline` in `globals.css`.

### Light mode

| Token | Value (oklch) | Usage |
|---|---|---|
| `--background` | `1 0 0` | Page background |
| `--foreground` | `0.145 0 0` | Primary text |
| `--card` | `1 0 0` | Cards, menus |
| `--primary` | `0.205 0 0` | Buttons (near-black on light) |
| `--primary-foreground` | `0.985 0 0` | Text on primary |
| `--secondary` / `--accent` / `--muted` | `0.97 0 0` | Subtle fills, hovers |
| `--muted-foreground` | `0.556 0 0` | Secondary text, hints |
| `--destructive` | `0.577 0.245 27.325` | Errors |
| `--border` / `--input` | `0.922 0 0` | Hairlines, field borders |
| `--ring` | `0.708 0 0` | Focus ring |

### Dark mode

| Token | Value (oklch) | Usage |
|---|---|---|
| `--background` | `0.145 0 0` | Page background (near-black) |
| `--foreground` | `0.985 0 0` | Primary text |
| `--card` | `0.205 0 0` | Cards, menus |
| `--primary` | `0.922 0 0` | Buttons (near-white on dark) |
| `--primary-foreground` | `0.205 0 0` | Text on primary |
| `--secondary` / `--accent` / `--muted` | `0.269 0 0` | Subtle fills, hovers |
| `--muted-foreground` | `0.708 0 0` | Secondary text, hints |
| `--destructive` | `0.704 0.191 22.216` | Errors |
| `--border` | `1 0 0 / 10%` | Hairlines |
| `--input` | `1 0 0 / 15%` | Field borders |
| `--ring` | `0.556 0 0` | Focus ring |

### Conventions

- `--radius: 0.625rem` base → `sm/md/lg/xl` derived (`-4px`/`-2px`/`+4px`).
- Fonts: Geist Sans (body) + Geist Mono (code) via `--font-sans`/`--font-mono`.
- **Rule:** components only use token classes (`bg-card`, `text-muted-foreground`,
  `border-border`, …). Hard-coded colors are a design bug.
- The primary button is a **contrast flip**: near-black on light mode,
  near-white on dark mode — the single strongest signal on any screen.

---

## 3. Signup / Login layout

Both pages live in the `(auth)` route group with a shared centered layout.

### Anatomy (desktop + mobile)

1. **Brand mark** — rounded-xl `bg-primary text-primary-foreground` tile with
   the book icon, centered above the card.
2. **Card** — `max-w-sm`, centered in the viewport, `bg-card border` rounded-lg.
3. **Header** — title (`text-xl`, e.g. "Welcome back" / "Create your free
   account") + one-line muted subtitle.
4. **Form** — stacked fields (Label above Input, `placeholder` showing a real
   example: `you@university.edu`), full-width primary submit with inline
   spinner while pending.
5. **Error banner** — `bg-destructive/10 text-destructive`, `role="alert"`,
   rendered above the fields, replaced on each submit.
6. **Footer** — muted cross-link ("New to StudyFlow? **Create a free
   account**" / "Already have an account? **Log in**").

### Rules

- One column, no side-by-side split; the form is the only job of the page.
- Theme toggle lives in the top-right corner on every auth screen.
- Never render raw error objects — every error passes through
  `friendlyAuthError()` (`src/lib/auth-errors.ts`) which maps Better Auth
  codes to human copy, with a safe generic fallback.

---

## 4. Onboarding flow

One page, one scroll — **deliberately not a multi-step wizard**. Five quick
questions ("takes about 30 seconds") beat a 5-screen flow for a student who
just signed up; every extra click is a drop-off risk. The server action
(`src/app/(onboarding)/onboarding/actions.ts`) validates with Zod and saves
profile + subjects + exams atomically.

### The five questions (order = least → most effort)

1. **What are you studying?** — text input, real examples as placeholder.
2. **Your subjects** — comma-separated text input (parsed into subject rows).
3. **When are your exams?** — repeatable name + date rows (up to 3, add/remove
   via icon buttons); date is required, name is optional.
4. **Daily study time** — number input in minutes (5–480) with "minutes" suffix.
5. **What do you want help with?** — multi-select goal chips
   (`aria-pressed`, filled state = selected).

### Screen layout

- Full-height muted background (`bg-muted/40`) — visually distinct from the
  app, signaling "you're not in the product yet".
- Single centered card, `max-w-xl`, header personalizes with first name:
  "Set up your study flow, Alex".
- Primary CTA: "**Build my dashboard**" (full-width, large). On success →
  `/app/dashboard`; on validation/DB error → inline friendly banner, no
  navigation.

### Guard behavior

- No session → redirect `/login`.
- Already onboarded (`profiles.onboardingCompleted`) → redirect straight to
  the dashboard.

---

## 5. Dashboard shell structure

`AppShell` (`src/components/app-shell.tsx`) wraps every page in the `(app)`
route group. Layout: a left sidebar on desktop, a top bar + nav strip on
mobile — same content, responsive re-arrangement only.

```
┌──────────┬───────────────────────────────────────┐
│ Sidebar  │  Header (theme toggle, desktop)      │
│  Logo    ├───────────────────────────────────────┤
│  Nav     │  Main (max-w-5xl, p-4 md:p-8)        │
│  User    │                                       │
│  menu    │                                       │
└──────────┴───────────────────────────────────────┘
        Mobile: top bar (logo, theme, avatar) +
        horizontal scrollable nav strip below it
```

### Desktop sidebar (`md:` and up)

- Fixed `w-60`, `h-dvh`, `border-r`, logo row with bottom border (h-14).
- Nav: stacked links, active state `bg-accent text-accent-foreground` with
  `aria-current="page"`; inactive `text-muted-foreground` + hover fill.
- Bottom: user menu (avatar + name + email) opening a dropdown with plan
  badge ("Free plan") and **Sign out**.

### Mobile (`< md`)

- Top bar: compact logo, theme toggle, avatar menu.
- Below it: nav as a horizontally scrollable strip of pill links.

### Dashboard page anatomy (`src/app/(app)/dashboard/page.tsx`)

1. **Greeting** — "Welcome back, {first name}" + one muted line drawing on
   their onboarding course ("Medicine · Ready to turn your notes into a study
   system?").
2. **Status widgets** — 3-up grid (`sm:grid-cols-3`): Study streak, Next exam,
   AI actions left (20/20). Each: icon + title (muted, small), value (bold,
   `text-2xl`), and an honest hint about when the real data arrives.
3. **Get started** — 2-up card grid; each card has an icon tile, title,
   one-line description, and a "when" tag (Week 2 / Week 3) so the roadmap is
   visible inside the product.
4. Cards get `hover:bg-accent/50` transitions only where they're clickable.

### Guard behavior

- No session → `/login?next=…`.
- Onboarding incomplete → `/onboarding` (so a user can't skip setup).

---

## 6. Component conventions (Weeks 2+ must reuse)

| Component | File | Notes |
|---|---|---|
| Button | `src/components/ui/button.tsx` | variants: default/outline/ghost/destructive/link; sizes sm/default/lg/icon |
| Input / Label | `src/components/ui/input.tsx`, `label.tsx` | border-input, focus ring from `--ring` |
| Card | `src/components/ui/card.tsx` | Header/Content/Title/Description slots |
| Badge / Avatar / Separator / DropdownMenu | `src/components/ui/` | Radix primitives, token-styled |
| `cn()` | `src/lib/utils.ts` | tailwind-merge + clsx for all conditional classes |

## 7. Deliberately deferred (not in Week 1)

- Page transitions / micro-animations, skeleton loading, glassmorphism polish
  — added when real data exists to animate (Weeks 3–4).
- Premium themes: later, behind the paywall, as new token sets — never baked
  into component code.
