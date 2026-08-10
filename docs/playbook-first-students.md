# StudyFlow AI — First 20–50 Students Playbook

> **Goal:** 20–50 real students using StudyFlow AI within 2 weeks of soft launch,
> at least 60% of them actually using it with their real notes, and a handful
> saying "I'd pay for this."
>
> **Golden rule:** the ask is *feedback*, not money. These are beta users who get
> premium free during the beta in exchange for honest feedback. Money comes in
> week 3+ when the beta ends — from the people who saw real value.
>
> **Honesty rules (non-negotiable):** no invented testimonials, no fake stats, no
> fake urgency, no spam, no paid fake accounts. Every message is personal,
> human-sent, and can be deleted without hard feelings.

---

## 0. Before you start (launch week, prep)

Do this while the app is still being finished. Don't pitch anyone until the
product works.

1. **Build the candidate list (target 60+ names).** Open a spreadsheet (Google
   Sheets is fine). Columns:

   | name | contact (DM/email) | channel | exam | subjects | date added | date onboarded | activated? | returned day 2? | feedback | paid? |
   |---|---|---|---|---|---|---|---|---|---|---|

   Sources, in order of warmth: people you actually know → friends of friends →
   classmates → campus groups you're in → online communities.

2. **Write your one-line story.** You'll say it a hundred times. Example:
   > "I built a study app that turns your notes into flashcards, summaries, and
   > practice quizzes automatically. It's brand new — I'm looking for the first
   > 20 students to try it free and tell me what's broken."

3. **Prepare a 2-minute demo.** Upload ONE set of real notes (or a sample PDF)
   → generate a summary → generate flashcards → start a quiz. Practice until it
   takes under 2 minutes from signup to "here are your flashcards."

4. **Prepare sample notes.** A clean sample PDF + sample pasted text (so
   students who don't have notes handy can still see the magic in 30 seconds).

5. **Set up a booking link** (Calendly free tier or just "DM me and I'll send a
   link") for the 1:1 onboarding calls in Week 2.

---

## 1. Which channels (ranked by likely yield for a solo founder)

| Channel | Effort | Conversion | Risk | Notes |
|---|---|---|---|---|
| Personal network + friends of friends | Low | **High** | Low | Start here. The warmest possible lead. |
| Campus group chats you're already in (WhatsApp/Telegram/Discord/class groups) | Low | Medium-High | Low | You're a member, not a spammer. One post, offer to delete. |
| Subject-specific Discords/study servers | Medium | Medium | Medium | Read their self-promo rules first. |
| Study subreddits / Facebook groups | High | Low-Medium | **High (ban risk)** | Many ban self-promo outright. Contribute value first, mention the tool only where allowed. |
| Professors/TA (ask them to share) | Low | Low | Low | Only if you have a real relationship. One polite ask, zero expectation. |
| Physical campus (notice boards, clubs, library) | Medium | Low | Low | A simple QR-code flyer can work at exam season. |
| Paid ads | High cost | — | — | Not now. Spend zero money on acquisition until someone pays. |

**Realistic split for 20–50 users:** ~40% from your personal network, ~40% from
campus group chats, ~20% from online communities. If you're not a student
anymore, lean on friends-of-friends, alumni/student groups you can access, and
online study communities — it's slower but works.

---

## 2. Week 1 — Recruit (days 1–7)

### Message Template A — warm DM (someone you know)

> Hey [name]! Quick question — are you studying for any exams this semester?
> I just built a study app that turns your notes into AI summaries, flashcards,
> and practice quizzes. It's genuinely early, so I'm looking for ~20 students to
> try it free and tell me what sucks — I want real feedback, not compliments.
> Takes 2 minutes to start. Want me to set you up?

### Message Template B — campus group chat post

> Hey everyone 👋 I built a study app that turns your class notes into
> flashcards, summaries, and practice quizzes automatically. It's brand new, so
> I'm looking for the first ~20 students to try it free in exchange for honest
> feedback — what's broken, what's missing, what you'd never use. Takes 2
> minutes: upload one set of notes and it makes your flashcards. DM me for the
> link, or happy to delete this if it's not welcome here.

### Message Template C — online community (only where rules allow)

Follow the community's rules first. Where self-promo is allowed (or in a
dedicated thread), adapt:

> I built [StudyFlow AI] — upload your notes, it generates flashcards, summaries,
> and practice quizzes. I'm not here to sell it: I'm looking for beta testers
> who'll tell me what's broken before I charge anyone. Free during beta. If
> you're studying for exams and want to try it, DM me — happy to take the link
> down if this isn't appropriate here.

Where self-promo is banned: **don't post it.** Contribute genuinely (answer
study questions, share what works for you), and only mention the tool if someone
asks what you use.

### Message Template D — follow-up (day 3, if no reply)

> Hey [name] — no stress if you're not interested, just wanted to say the beta
> spot's still open if you ever want to poke at it. It takes 2 minutes and I'd
> genuinely love your feedback. 🙏

**Daily rhythm (week 1):** send 8–12 personal messages + 1–2 group posts per
day. Track every message in the sheet. Never send the same message twice to the
same person. **Rule of thumb:** for every 10 people you message, expect ~2–3 to
sign up. That means ~60–80 messages gets you to 20.

---

## 3. Week 2 — Onboard & observe (days 8–14)

### The 1:1 onboarding (15 minutes, or async)

On the call (or via a 2-minute Loom video they can watch async):

1. "Put in your email and password" (30 seconds).
2. "Now paste in or upload ONE set of notes you actually have — the messier the
   better, this is a test." (1 minute)
3. "Here's your summary. Here are your flashcards. Flip one. Start a quiz."
   (1 minute)
4. "That's the whole thing. What would make this useful for YOUR exam?"

**The single most important thing:** they leave with their OWN notes uploaded
and something generated from them. If they only look at the sample, they're a
tourist, not a user.

### What to watch for (the analytics we built — check the admin dashboard daily)

| Signal | Event(s) | What it means |
|---|---|---|
| **Activation** | `note_created` / `document_uploaded` in the first session | Did they hit value fast? Target ≥60% of signups. |
| **First feature** | `summary_generated` vs `flashcards_generated` vs `quiz_started` | Which one is the "aha"? That's what we double down on. |
| **Quiz drop-off** | `quiz_started` → `quiz_completed` | If people start but don't finish, the quiz UX or length is wrong. |
| **Retention** | `app_opened` day 2 / day 3 | Did they come back? This is the #1 thing to watch. |
| **Documents failing** | `documents` with status `failed` | Quality bug — fix immediately. |
| **Limit hits** | user hits free limit, `paywall_viewed` | Where the wall goes up (week 3+, when beta ends). |

### Daily routine (15 minutes, every day of week 2)

1. Check the dashboard: how many activated, who came back.
2. Message anyone who signed up but never uploaded notes: "Did it work? What
   got in the way?"
3. Write down every piece of feedback verbatim in the sheet — even the mean
   ones. The mean ones are the most valuable.
4. Fix the top bug of the day if there is one (document failures first).

### The weekly "what did you learn" debrief

Answer in one sentence each: What did students actually use? What did they say
they'd pay for? What confused them? What's the one thing we should build/fix
next? That answer becomes the roadmap for weeks 3–4 — **not** your feature wish
list.

---

## 4. Beta → first paying users (week 3+, honest conversion)

Everyone who joined during the beta gets **premium free until the beta ends**
(a real, communicated date — e.g., "premium free until [date], then it's
$4.99/mo"). When the beta ends:

### Message Template E — the beta-end message

> Hey [name] — quick update: the StudyFlow AI beta ends on [date]. Everything
> you have keeps working, and your notes stay right where they are. If you've
> gotten value from it, you can keep premium at the beta price: $4.99/month or
> $39.99/year. If it wasn't useful, no hard feelings — I'd rather hear what to
> fix than take your money. Reply and tell me either way?

**Expect:** of the 20–50 beta users, the ones who activated and came back are
your realistic prospects. **5 paying users from the first cohort is a win.** The
rest of the cohort's feedback is still worth more than their $4.99.

**Never:** fake urgency, fake discounts, "only 3 spots left", invented
testimonials on the landing page. The honest framing above is the whole
strategy — and it's exactly what converts students who trust you.

---

## 5. Guardrails (what NOT to do)

- ❌ No paid fake accounts, no review manipulation, no bot signups.
- ❌ No spam: never message someone twice about the same thing, never post the
  same blurb in 10 servers without reading each one's rules.
- ❌ No invented social proof anywhere: no fake testimonials, no fake numbers on
  the landing page.
- ❌ No charging anyone without them knowing exactly what they're paying for and
  how to cancel.
- ✅ Every piece of outreach is personal, human-controlled, and deletable.

---

## 6. KPI targets (end of the 2 weeks)

| Metric | Target |
|---|---|
| Signups | 20–50 |
| Activation (uploaded real notes) | ≥60% of signups |
| Returned on day 2 | ≥30% of activated |
| Verbatim feedback items captured | 10+ |
| Documents failing | 0 (fix anything that fails) |
| "I'd pay for this" signals | 5+ |
| First paying users (week 3–4) | 5 |
