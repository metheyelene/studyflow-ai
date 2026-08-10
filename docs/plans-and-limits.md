# StudyFlow AI — Free / Premium Limits Specification

> **Status:** Approved design · implemented in `src/lib/plans.ts` (single source
> of truth — paywall, metering, and the "AI usage remaining" dashboard all read
> from it).
>
> **Design principle:** revenue per paying user must comfortably exceed the
> variable AI cost per paying user. Every number below is derived from that
> constraint, not guessed.

---

## 1. The limits

| Feature | Free | Premium ($4.99/mo · $39.99/yr) |
|---|---|---|
| **AI actions** (master meter) | **20 / month** | **500 / month** (fair use) |
| **Document uploads** (lifetime) | **3 total** | **50 total** (fair use) |
| **Subjects** (lifetime) | **1** | **20** (fair use) |
| **Flashcards** | **100 cards / month** (≈ 5 generations × 20 cards) | **1,000 cards / month** fair-use ceiling |
| **Quiz generations** | included in AI actions (≤ 10 questions) | included in AI actions (≤ 20 questions) |
| **Quiz attempts** | **Unlimited** | Unlimited |
| **Notes (pasted / text)** | **Unlimited** | Unlimited |
| **Q&A about notes** | included in AI actions (1 question = 1 action) | included in AI actions |
| **Study planner** | **Basic** (rule-based, no AI cost) | **AI planner** (uses actions) |
| **Premium themes** | — | Included (later phase) |

**One master meter — "AI actions" — covers every AI generation:** a summary
(any of the 5 types), one flashcard deck, one quiz, one Q&A question, and one
AI planner run each cost **1 action**. This is the single number users see
("You have 5 AI actions left this month"). No per-feature sub-meters — one
number is easy to understand and easy to meter.

**What does NOT cost an action:** uploading/processing a PDF (text extraction is
local and free), storing notes, taking quizzes (attempts are unlimited for
everyone — zero marginal cost, and it's the feature students share).

---

## 2. Why these numbers (the cost math)

Blended cost per action on the default model (gpt-4o-mini: $0.15/M input,
$0.60/M output), with generation sizes capped (quiz ≤ 20 questions, input
excerpt ≤ ~4,000 tokens):

| Generation type | Est. input | Est. output | Est. cost |
|---|---|---|---|
| Summary | 3,000 | 800 | ~$0.0009 |
| Flashcards (20 cards) | 3,000 | 1,500 | ~$0.0014 |
| Quiz (10 questions) | 3,000 | 2,500 | ~$0.0020 |
| Q&A question | 1,000 | 300 | ~$0.0003 |

**Realistic blended average: ~$0.001–0.002 per action.**

### Free user worst case
20 actions × $0.002 = **$0.04/month** — even at 10,000 free users all hitting
the ceiling, that's ~$400/month, absorbed by the free tier as the acquisition
cost. (The abuse-prevention layer — rate limits, email verification, device
checks — exists precisely so this stays an upper bound, not a norm.)

### Premium user worst case
500 actions × $0.002 = **$1.00/month**. Even at pathological usage (500 quiz
generations ≈ $1.30), the premium user nets us:

```
$4.99 gross − $0.45 Stripe ≈ $4.54 net
$4.54 − $1.30 worst-case AI = $3.24 margin  (~71% gross margin at worst case)
```

**Margin is the point:** the premium allowance is set at 25× free because at
that level the worst case still clears a healthy margin. If real usage data
(later, from the `ai_requests` log) shows blended cost drifting up, we lower the
allowance — the number lives in one file, so the change is one line.

### Psychology (why 20)
20 actions ≈ 1–2 weeks of normal exam-prep use for a casual student: 2
summaries, 2 flashcard decks, 2 quizzes, a handful of questions. The meter runs
out **mid-preparation, at the moment of highest perceived value** — that's the
ideal conversion moment, and the dashboard's visible "AI usage remaining"
counter means it's never a surprise. 3 document uploads covers "my notes for
this one class" — exactly enough to prove value, not enough to live on.

---

## 3. Enforcement design (for the metering implementation)

1. **One source of truth:** `src/lib/plans.ts` exports `PLANS.free` and
   `PLANS.premium`. Paywall copy, metering, and the dashboard import from it —
   no duplicated numbers anywhere.
2. **Entitlement check:** premium ⇔ `subscriptions.status IN ('active',
   'trialing')` — computed server-side only.
3. **AI meter (atomic):** `usage` row keyed `(user_id, feature='ai_actions',
   period='YYYY-MM')`; increment with
   `UPDATE usage SET count = count + 1 WHERE ... AND count < limit RETURNING *`
   — if no row returns, the limit is hit. This is race-safe (no double-spend
   under concurrent requests).
4. **Lifetime meters (documents, subjects):** count live rows in the table
   (`documents.status != 'failed'`). No period; these never reset.
5. **Generation size caps** (quiz questions, card count, input excerpt length)
   are enforced at the API layer, not by the meter.
6. **Period:** calendar month (1st → end), reset automatically by the `period`
   key. Simple to explain: "resets on the 1st."
7. **Document cap:** 25 MB per file, PDF for MVP (pasted text unlimited).

---

## 4. Paywall copy requirements (what the user must always see)

Derived from the approved brief — the paywall must state, plainly:

- **What free gets** — "20 AI actions / month, 3 document uploads, 1 subject,
  basic planner"
- **What premium adds** — "500 AI actions / month, 50 uploads, 20 subjects, AI
  planner, premium themes"
- **Pricing** — $4.99/month or $39.99/year (≈ 2 months free)
- **Cancellation** — "Cancel anytime in Settings; you keep access until the end
  of your paid period"
- **Fair-use framing for premium** — "Unlimited within fair use" (500/1,000/20
  are the enforced ceilings, described honestly as fair-use limits)

**Never:** "guaranteed better grades", fake countdowns, fake discounts, or
invented social proof.
