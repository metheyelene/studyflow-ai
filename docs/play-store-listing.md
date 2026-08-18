# StudyFlow AI — Google Play Store Listing Package (v1.3.0)

Everything needed to fill the Play Console for the **v1.3.0** release.
Version: **1.3.0 (build 4)**, package `ai.studyflow.studyflow_mobile`.

**Status: READY for submission review.** Screenshots, store copy, privacy policy,
and terms are prepared and live. Two items remain yours to decide (marked ⚠ below):
legal review of the policy/terms and the public website field.

---

## 1. Core listing fields

| Field | Value |
|---|---|
| App name | StudyFlow AI |
| Short description (80 char max) | Turn your notes into a source-grounded AI study system — summaries, flashcards, quizzes, podcasts. |
| Full description | see §2 below |
| Category | Education |
| Tags | Study, Education, Productivity |
| Application ID | `ai.studyflow.studyflow_mobile` (already in the manifest) |
| Contact email | `mithilviswask@gmail.com` |
| Website | ⚠ decide — the live backend is `https://studyflow-ai-beryl-alpha.vercel.app`; use a domain you own (e.g. `studyflow.ai`) once it points at the product |
| Privacy policy URL | **https://studyflow-ai-beryl-alpha.vercel.app/privacy** (live) |
| Terms URL (optional) | **https://studyflow-ai-beryl-alpha.vercel.app/terms** (live) |
| Price | Free (in-app subscription: StudyFlow Premium, founding-member $2/month offer) |
| In-app purchases | Yes — subscription (StudyFlow Premium) |

---

## 2. Full store description

> **Your notes. Your AI study system.**
>
> StudyFlow AI is a private, source-grounded study workspace. Upload your lecture
> PDFs, textbook chapters, or class notes, and StudyFlow builds a knowledge base
> that answers **only from your material** — with citations back to the source, so
> you can verify every answer.
>
> **How it works**
>
> 1. **Create a Study Space** for each subject or unit (e.g. "VLSI Unit 3").
> 2. **Add your sources** — PDF, DOCX, PPTX, images, or pasted text.
> 3. **Ask StudyFlow** — it retrieves the relevant passages from *your* notes and
>    answers with citations, not guesses.
> 4. **Transform your material** — generate summaries, study guides, flashcards,
>    quizzes, and study podcasts grounded in your own sources.
>
> **Study tools**
>
> • **Source-grounded AI chat** — answers drawn from your uploaded material, with
>   tap-to-view citations.
> • **Smart summaries & study guides** — concise, detailed, or exam-focused.
> • **Flashcards** — AI-generated decks with a flip-and-swipe study mode.
> • **Quizzes** — practice questions generated from your material, with instant
>   explanations.
> • **AI study podcasts** — your notes turned into audio you can listen to anywhere.
> • **Exam countdowns & study plans** — upcoming exams and time remaining.
> • **Progress tracking** — mastery rings, weak-topic review, and study streaks.
> • **Offline-friendly** — review flashcards and see your progress even without a
>   connection.
>
> **Private by default.** Your notebooks are yours. StudyFlow never mixes one
> user's material into another user's answers, and uploaded documents are never
> made public.
>
> **StudyFlow Premium** — unlock the full AI study system: advanced AI tutor,
> smart study mode, advanced PDF intelligence, adaptive quizzes, exam simulation,
> progress analytics, audio podcasts, and higher AI limits. Founding members lock
> in Premium at **$2/month** for the first 35 members.
>
> StudyFlow AI helps you study more organized, interactive, and intelligent. It
> does not guarantee grades or exam outcomes.

---

## 3. Screenshots — captured and ready

All screenshots are **real captures of the v1.3.0 monochrome UI** (1080×1920,
strictly black/white/gray, seeded sample data clearly labeled "Sample:"). They
live in `mobile/screenshots/play-store/`:

| # | File (dark) | File (light) | Screen |
|---|---|---|---|
| 1 | `01-signup-dark.png` | `01-signup.png` | Sign-up — brand first impression |
| 2 | `02-login-dark.png` | `02-login.png` | Log in |
| 3 | `03-home-dark.png` | `03-home.png` | Home — editorial focus + continue studying |
| 4 | `04-notebooks-dark.png` | `04-notebooks.png` | Study spaces |
| 5 | `05-study-space-dark.png` | `05-study-space.png` | Study Space — sources + actions |
| 6 | `06-ask-ai-dark.png` | `06-ask-ai.png` | AI chat with grounded answer + citation |
| 7 | `07-flashcards-dark.png` | `07-flashcards.png` | Flashcard study card |
| 8 | `08-quiz-dark.png` | `08-quiz.png` | Quiz question |
| 9 | `09-audio-dark.png` | `09-audio.png` | AI study podcasts |
| 10 | `10-progress-dark.png` | `10-progress.png` | Progress & mastery |
| 11 | `11-premium-dark.png` | `11-premium.png` | Premium founding offer |

**Recommended upload (8 phone shots, in order):**
`01-signup` → `03-home` → `04-notebooks` → `05-study-space` → `06-ask-ai` →
`07-flashcards` → `08-quiz` → `09-audio`.
Dark mode is the primary StudyFlow identity — use the `-dark` set. (Light set is
available if you prefer, or for A/B.)

**Feature graphic:** `mobile/screenshots/play-store/feature-graphic.png` (1024×500,
monochrome wordmark + knowledge motif, no rounded corners, no transparency).

**Guidance that still applies:** no mock data that could be mistaken for real user
data (all titles carry "Sample:"), no admin/backend screens, default text size,
one screen per shot, no third-party logos.

---

## 4. Content rating answers (IARC)

Unchanged from the submission doc (`docs/play-console-submission.md`): education
app, no user-to-user communication, no ads, no location, no personal-info sharing.
Expected rating: **Everyone (3+)**. Re-answer only if a future release adds
user-to-user features.

---

## 5. Data safety form

Follow `docs/play-console-submission.md` §5. Summary of the honest answers for
v1.3.0:

- **Collected:** name, email, user ID, user content (documents, notes, chat,
  quiz/flashcard progress), first-party analytics events, subscription status.
- **Not collected:** location, photos/videos/audio (no camera/mic permissions),
  contacts, health data, device IDs.
- **Shared:** no data is sold; nothing shared beyond the service providers
  required to run the app (hosting/DB, AI provider for document processing, email
  for password resets, payment processor). The AI-processing disclosure belongs in
  the privacy policy (it is — §4 of the policy).
- **Security practices:** HTTPS in transit ✓, in-app account deletion ✓,
  security contact = `mithilviswask@gmail.com` ✓.

---

## 6. Additional Play Console fields

| Field | Value |
|---|---|
| "About this app" synopsis | Same as short description |
| App category secondary | Productivity |
| Target audience | Students (13+); school/university level. If you market to under-13, you must declare the Families policy — not the case for v1.3.0 |
| Ads | None |
| News app designation | No |
| US export compliance | No cryptography beyond standard HTTPS |
| Account deletion | In-app (Profile → Settings → Delete account); Play may also ask for a URL/web form — the in-app path + support email covers the requirement |

---

## 7. Before you submit — status checklist

- [x] **Privacy policy live** — `https://studyflow-ai-beryl-alpha.vercel.app/privacy` (effective Aug 18, 2026)
- [x] **Terms live** — `https://studyflow-ai-beryl-alpha.vercel.app/terms` (effective Aug 18, 2026)
- [x] **Backend deployed & sign-up verified** — production backend live, `API_BASE_URL` set, sign-up → session → usage tested end-to-end
- [x] **8+ phone screenshots captured** (`mobile/screenshots/play-store/`, dark + light)
- [x] **Feature graphic 1024×500** (`feature-graphic.png`)
- [ ] ⚠ **Legal review of privacy policy & terms** — drafted from what the app actually does; have a lawyer or legal template service review before public launch
- [ ] ⚠ **Website field** — pick the public product domain
- [ ] **App icon 512×512** — reuse the iOS `Icon-App-1024x1024@1x.png` with Play safe-zone padding (center ~66%, no text)
- [ ] **App signing key backed up off-device** — the release keystore is the only way to update the app under the same identity
- [ ] **IARC questionnaire** — answer per §4 (expect "Everyone")
- [ ] **Data safety form** — answer per §5
- [ ] **Upload `app-release.aab`** from the v1.3.0 release into Play Console
- [ ] **Internal test track** — invite ≥1 tester, verify install + login + core flow before submitting for review

---

## 8. Reproduce the screenshots (for future releases)

```bash
cd mobile
./tool/capture-screenshots.sh --dark   # dark set (primary identity)
./tool/capture-screenshots.sh          # light set
```

Outputs to `mobile/screenshots/play-store/`. The capture build seeds sample data
(`lib/core/config/capture_seed.dart`) so every screen renders without a backend.
