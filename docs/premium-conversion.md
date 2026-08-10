# Premium Conversion & Monetization Strategy

> Goal: make Premium feel like "this actually saves me time and helps me
> study better" — never "this app keeps annoying me until I pay."
> Companion doc: [`plans-and-limits.md`](plans-and-limits.md) (the numbers)
> and [`src/lib/plans.ts`](../src/lib/plans.ts) (the single source of truth).

---

## 1. Audit — where the Premium experience actually is

**Honest starting point:** the *product* has no paywall, no checkout, no
usage metering, and no premium features built yet. What exists today:

| Piece | State |
|---|---|
| Plan limits contract (`plans.ts`) | ✅ Free/premium limits, pricing, plan copy |
| Usage table (DB) | ✅ schema + unique(user, feature, period) |
| Analytics events table (DB) | ✅ schema |
| Subscriptions table (DB) | ✅ schema (no rows yet — Stripe comes later) |
| Paywall / pricing page | ❌ |
| Usage metering (`lib/usage.ts`) | ❌ |
| Stripe checkout/webhook/portal | ❌ (Week 4) |
| Premium features (tutor, smart mode, exam sim) | ❌ (depend on notes + AI phases) |
| Premium onboarding / contextual prompts | ❌ |

So the audit's job now: build the *monetization backbone* (metering,
pricing page, paywall component, analytics, premium UI primitives) so that
every future feature plugs in, and define the feature strategy.

### Current free (what users get today)
Unlimited pasted notes, 20 AI actions/month, 3 documents, 1 subject,
basic summaries/flashcards/quizzes (≤ caps), basic rule-based planner,
unlimited quiz attempts.

### Weakest parts of the current state
1. **No visible upgrade path** — nothing in the app tells a user Premium
   exists or what it adds.
2. **No metering** — "AI actions left" is hardcoded to 20/20 on the
   dashboard; free limits aren't enforced server-side yet.
3. **No value demonstration** — free users can't *see* what premium
   features do, so there's no pull.
4. **Onboarding is generic** — it collects goals but never uses them to
   personalize anything.

### Strongest opportunity
The **one-set-of-notes → full study system** loop is the product's core
value and the natural upsell moment: after a free user experiences
summary → flashcards → quiz, the honest next step is "turn this into a
complete revision plan." That moment is where Premium earns its price.

### Hero feature decision
**Smart Study Mode** is the flagship Premium feature:
- It is the **daily habit driver** — every login it answers "what should I
  study today?" which is the retention engine, not just a feature.
- It wraps every other premium feature (review, quiz weak areas,
  flashcards, exam countdown) into one workflow, so it *is* the value
  calculator made real.
- It costs ~1 AI action per day to generate — cheap to serve.

Supporting cast (in priority order): **AI Study Tutor** (deep Q&A on your
notes), **Exam Simulation** (the emotional hook), **Adaptive Quiz
analysis**, **Advanced PDF chapter analysis**, **Premium analytics**.

---

## 2. Free / Premium / Future feature matrix

| Capability | Free | Premium | Future "Pro" (only if demand) |
|---|---|---|---|
| Paste unlimited notes | ✅ | ✅ | ✅ |
| Basic summaries (short, key concepts) | ✅ | ✅ | ✅ |
| Deep summaries (detailed, exam points, definitions) | — | ✅ | ✅ |
| AI Study Tutor (chat with notes) | 5 msgs/month (preview) | ✅ unlimited within fair use | ✅ |
| Flashcards | 100 cards/mo, basic flip | Advanced: smart review, weak-card priority, bigger decks | Spaced-repetition engine |
| Quizzes | ≤10 Q, no analysis | Adaptive difficulty, topic/weak-area, exam simulation, performance analysis | Peer-compare |
| Exam simulation | — | ✅ (time-limited, mixed topics) | — |
| Study planner | Basic (rule-based) | Smart, adapts to quiz/usage data | Calendar sync |
| PDF analysis | Basic text→note | Chapter summaries, topic extraction | OCR / handwritten notes |
| Progress analytics | Streak + basics | Weakest/strongest subjects, study consistency, revision gaps | Exportable reports |
| **Smart Study Mode** | — | ✅ daily recommendations (HERO) | — |
| Documents | 3 lifetime | 50 | Unlimited (monitored) |
| Subjects | 1 | 20 | Unlimited |
| AI actions/month | 20 | 500 | 2000+ (measured) |
| AI tutor messages | — | counts toward AI actions | — |

**Rules applied:** never paywall what creates the first "aha" (paste note →
summary → flashcards is free); never paywall retention-critical basics
(streak, unlimited quiz attempts); premium features must pass the six-test
bar (value, frequency, differentiation, cost, UX, trust).

---

## 3. Pricing

Keep the approved structure — simple beats clever:

| Plan | Price | Effective monthly |
|---|---|---|
| Free | ₹0 / $0 | — |
| Premium monthly | $4.99 / ₹399 | $4.99 |
| Premium yearly | $39.99 / ₹3,199 | **$3.33/mo — save ~33%** |

- Yearly presented with the real, arithmetic savings — no fake "SALE".
- **No free trial initially.** A full trial risks expensive AI usage with
  low commitment. Instead use the cost-safe equivalents from the brief:
  (a) a **capped Premium preview** — free users get 5 AI-tutor messages +
  one exam simulation *preview* to feel the feature; (b) contextual value
  previews (see §5).
- Revisit a trial only when: activation ≥ 60%, cost/action verified from
  real `ai_requests` data, and Stripe trial infra can be safely capped.

### Cost implications (from `plans-and-limits.md`)
- Blended cost per AI action (gpt-4o-mini / claude-haiku): ~$0.001–0.002.
- Premium worst case: 500 actions ≈ **$1.00/mo** vs $4.54 net revenue →
  **~71% gross margin** even at ceiling. This is the guardrail for all
  premium features: keep per-action cost ≤ $0.002.
- Smart Study Mode: ~1 action/day ≈ $0.03–0.06/mo per user. ✅
- AI Tutor: chat is the costliest pattern → cap input tokens
  (`maxInputTokensPerGeneration`), cap ~30 messages/session, cheap model. ✅
- Exam simulation: ~4–6 actions per run. ✅ within margins.

---

## 4. Paywall & pricing page design (honest by construction)

**Paywall contents (every time, no surprises):**
1. What Premium includes (benefit list, from `PLAN_COPY`).
2. Both prices + the yearly savings arithmetic.
3. What happens on cancel (keep access to end of period, cancel in one
   click from the billing portal).
4. A clearly visible **"Keep using free"** escape hatch on every screen.
5. No countdowns, no fake scarcity, no preselection, no trial language
   unless a real trial exists.

**Pricing page (`/pricing`):** full comparison table (the matrix above),
monthly/yearly toggle, honest FAQ, security/privacy note. Public — linked
from the landing page, the paywall, and the dashboard.

**Contextual triggers (never random popups):**
- **At 70% AI usage** → subtle inline meter note.
- **At 90%** → "X actions left this month" + one-line premium mention.
- **At 100%** → friendly "You've used your free allowance — resets on the
  1st" + transparent premium explanation + escape to free features.
- **After a quiz** → "Want your weak topics analyzed?" (premium preview).
- **After 2nd+ document** → "Premium adds chapter-by-chapter analysis."
- **After 2nd+ deck** → "Premium adds smart review and weak-card priority."
- **Onboarding** → personalize: user picks "I struggle with revision" →
  highlight Smart Flashcards; "exam preparation" → highlight Exam
  Simulation. No manipulation — match stated needs.

**Value previews (demonstrate → explain → offer):**
- Free summary shows the basic version; a collapsed "Want the full chapter
  breakdown?" preview shows what premium would add.
- Free quiz shows score; a "Performance analysis" preview lists what
  premium would reveal.
- Smart Study Mode gets a **sample daily plan** rendered for free users
  with locked sections — seeing the output sells it better than any copy.

---

## 5. Conversion analytics (privacy-conscious, in-house)

Events (typed in `src/lib/analytics.ts`, stored in `analytics_events`):
`premium_feature_viewed`, `premium_preview_started`, `paywall_viewed`,
`pricing_viewed`, `checkout_started`, `checkout_completed`,
`subscription_started`, `subscription_cancelled`, `upgrade_declined`,
plus existing product events (signup, onboarding, first note, first AI
action, first quiz, first deck). No third-party scripts; no personal data
beyond the user id.

Key analysis: which feature preview → highest checkout start; where
checkout abandons; monthly vs yearly split; onboarding answers that
correlate with upgrade.

## 6. A/B testing infrastructure (ethical)

- Every experiment needs: hypothesis, metric, control, variant, duration,
  decision rule — documented in `docs/experiments/`.
- Never: hide pricing, hide cancellation, silently charge more to one
  group, manipulate.
- Mechanism: a simple server-side flag in `plans.ts`/env
  (`EXPERIMENT_*`) or `analyticsEvents`-based cohorting; feature flags via
  `feature.ts` helpers. Roll out only when the metering + analytics are
  live (post-launch).

## 7. Implementation order (what we're building now)

1. ✅ Audit (this doc)
2. **Metering** — `src/lib/usage.ts` (atomic, server-side) + tests
3. **Premium helpers** — `src/lib/premium.ts` (plan from subscriptions)
4. **Analytics** — `src/lib/analytics.ts` (typed events)
5. **Pricing page** — `/pricing` (comparison, monthly/yearly, honest FAQ)
6. **Paywall component** — `PaywallDialog` + `UpgradePrompt` +
   `PremiumBadge` + `UsageMeter`
7. **Dashboard wiring** — real AI-usage widget + contextual upgrade +
   Smart Study Mode teaser (hero feature preview)
8. Later phases (need notes/AI/Stripe): tutor, exam sim, adaptive quiz,
   smart mode engine, PDF chapter analysis, checkout, portal, cancel
   flow, win-back.
