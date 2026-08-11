# StudyFlow AI — Google Play Store Listing Package

Everything needed to fill the Play Console for the first release.
Version of the app this package describes: **1.0.0 (build 1)**, package `ai.studyflow.studyflow_mobile`.

**Status: DRAFT.** Google requires the store listing to match what the app actually does —
before submitting, verify each section against the live build and your privacy policy
(see "Before you submit" at the end). Do not submit until YOU have reviewed the legal items.

---

## 1. Core listing fields

| Field | Value |
|---|---|
| App name | StudyFlow AI |
| Short description (80 char max) | Turn your notes into a source-grounded AI study system — summaries, flashcards, quizzes. |
| Full description | see §2 below |
| Category | Education |
| Tags | Study, Education, Productivity |
| Application ID | `ai.studyflow.studyflow_mobile` (already in the manifest) |
| Contact email | `mithilviswask@gmail.com` |
| Website | https://studyflow.ai (⚠ see note §7) |
| Price | Free (subscription inside: StudyFlow Premium) |
| In-app purchases | Yes — subscription (StudyFlow Premium, founding-member $2/month offer) |

---

## 2. Full store description

> **Turn your notes into your smartest study system.**
>
> StudyFlow AI is a private, source-grounded study workspace. Upload your lecture PDFs,
> textbook chapters, or class notes, and StudyFlow builds a knowledge base that answers
> **only from your material** — with citations back to the source, so you can verify
> every answer.
>
> **How it works**
>
> 1. **Create a notebook** for each subject or unit (e.g. "VLSI Unit 3").
> 2. **Add your sources** — PDF, DOCX, TXT, Markdown, or pasted text.
> 3. **Ask questions** — StudyFlow retrieves the relevant passages from *your* notes and
>    answers with citations, not guesses.
> 4. **Transform your material** — generate summaries, study guides, flashcards, and
>    quizzes that are grounded in your own sources.
>
> **Study tools**
>
> • **Source-grounded AI chat** — answers drawn from your uploaded material, with
>   tap-to-view citations. Strict "answer only from my sources" mode available.
> • **Smart summaries** — short, detailed, or exam-focused summaries of your documents.
> • **Flashcards** — AI-generated decks from your notes, with flip-and-swipe study mode.
> • **Quizzes** — practice questions generated from your material, with explanations.
> • **Study planner** — a realistic schedule built around your exams and available time.
> • **Exam countdowns** — upcoming exams and how much time you have left.
> • **Progress tracking** — streaks, quiz performance, and study consistency.
>
> **Private by default.** Your notebooks are yours. StudyFlow never mixes one user's
> material into another user's answers, and uploaded documents are never made public.
>
> **StudyFlow Premium** — unlock the full AI study system:
> AI Study Tutor, Smart Study Mode, Advanced PDF intelligence, adaptive quizzes, smart
> flashcards, exam simulation, and higher AI limits. Founding members lock in Premium at
> $2/month for the first 35 members.
>
> StudyFlow AI is built to help students study more organized, interactive, and
> intelligent. It does not guarantee grades or exam outcomes.

---

## 3. Screenshots guide (2–8 required; 8 recommended)

Google requires at least 2 screenshots. Portrait phone screenshots are the most
important; add tablet screenshots for better visibility.

### Phone screenshots — 1080×1920 (or 1080×1620), PNG or JPEG, max 8

Recommended capture list, in order (tell the story):

1. **Landing / sign-up screen** — shows the brand, glass design, "Start studying" CTA.
2. **Dashboard (home)** — "Ready to study?", Today's Focus card, quick actions
   (Upload notes, Summarize, Flashcards, Quiz, Study plan). The single most important shot.
3. **Notebook list** — notebooks side by side with search ("VLSI Unit 3", "Biology Ch 4").
4. **Notebook chat with citation** — a real question and answer; make sure a
   **citation chip** (e.g. "Physics Notes • p.14") is visible — this is the feature that
   differentiates the app. Show the source panel if possible.
5. **Flashcards** — a card front/back with the flip affordance visible.
6. **Quiz** — a question with 4 options and progress ("Question 3 / 10").
7. **Study plan** — a timeline/schedule with tasks.
8. **Premium / founding-member card** — "Founding Member — $2/month" with the benefit list.

### What to avoid

- No mock data that a reviewer could mistake for real user data — use obviously
  sample-ish titles ("Sample: Cell Biology") or real-ish but clearly generated content.
- No screenshots of admin panels, the API, or backend internals.
- Keep the UI at default text size; no scrolling-captured images (each shot = one screen).
- No logos of other companies (no Apple/Google logos).

### Tablet screenshots (recommended, optional)

- 7-inch tablet: 1920×1200 landscape (or 1200×1920 portrait).
- 10-inch tablet: 2560×1600 landscape.
- Reuse the same screens, which already adapt (master-detail notebooks layout looks great
  on tablets).

### Feature graphic (required for the listing)

- 1024×500 PNG/JPG, no rounded corners, no transparent background.
- Suggestion: the StudyFlow wordmark centered on the deep glass background with a soft
  accent glow, and a one-line tagline: "Your notes. Your AI study system."

### App icon

- 512×512 PNG. The existing `Icon-App-1024x1024@1x.png` (iOS asset) can be reused after
  adding the 16px safe-zone padding Play requires — icons are masked by Play, so keep the
  design inside the center ~66% and avoid text.

---

## 4. Content rating answers (IARC questionnaire)

These answers describe **version 1.0.0**. Re-verify before each release — if a feature
adds user-to-user communication, re-take the questionnaire.

| Question | Answer | Notes |
|---|---|---|
| Category of app | Education | |
| Sexual content / nudity | **No** | |
| Violence — realistic | **No** | |
| Violence — cartoon/fantasy | **No** | |
| Gambling (real or simulated, incl. loot boxes) | **No** | Subscriptions are billing, not gambling |
| Alcohol / tobacco / drugs references | **No** | |
| Profanity / crude humor | **No** | |
| Horror / fear themes | **No** | |
| Weapons / weapon use | **No** | |
| Hate speech | **No** | |
| User-generated content / user interaction | **No** | Users do NOT communicate with each other; all content is private per-user |
| Does the app share location? | **No** | |
| Does the app share personal info? | **No** | No public sharing; data stays in the user's own account |
| Does the app allow users to communicate with each other? | **No** | No chat/forums between users |

**Result:** the rating questionnaire should yield **Everyone** (3+). If you add any
user-to-user communication or public content later, you MUST re-answer.

---

## 5. Data safety form answers

Answer these **honestly** — they're shown to users and are legally binding. The app
currently has **no third-party analytics SDK** (no Firebase/Amplitude/etc.); all analytics
are first-party server events. Re-check `mobile/pubspec.yaml` before each release.

### 5.1 Is your app required to follow a data safety policy? — **Yes** (education app, processes personal data)

### 5.2 Data collection & sharing

**Data collected** (each row is a Play form entry):

| Data type | Collected | Shared | Encrypted in transit | Can user request deletion? |
|---|---|---|---|---|
| Name | Yes (account display name) | No | Yes (HTTPS) | Yes |
| Email address | Yes (account login + password reset) | No | Yes (HTTPS) | Yes |
| User IDs | Yes (internal account id) | No | Yes | Yes |
| User content — documents/notes/notebooks | Yes (the core feature) | No* | Yes | Yes |
| User content — quiz answers, flashcard progress | Yes (to show progress) | No | Yes | Yes |
| App interactions / analytics events | Yes (first-party, e.g. `app_opened`, `signup`) | No | Yes | Yes |
| Purchase history | Yes (subscription status) | No† | Yes | Yes |
| Device or other IDs | No | — | — | — |
| Precise/approx location | **Not collected** | — | — | — |
| Photos/videos/audio | **Not collected** (no camera/mic permissions) | — | — | — |
| Contacts | **Not collected** | — | — | — |
| Health/fitness | **Not collected** | — | — | — |

\* **One exception to disclose:** uploaded documents are sent to the configured AI
provider (server-side) to generate summaries, flashcards, and answers. This is a
service-provider processing disclosure — the data is not sold and is not shared with
other users. The Play "Shared data" section should still say **No** because nothing is
shared with third parties *outside the service providers required to operate the app*;
verify against Google's current wording on service providers and AI processing.

† Payment card details are handled by the payment processor (Stripe) — the app never
stores card numbers.

**Data shared:** **No data is sold.** Nothing is shared with third parties other than
the service providers needed to run the app (hosting/DB, AI provider for document
processing, email provider for password reset). Google Play's form distinguishes
"shared" from "collected"; for 1.0.0 the honest answer to *shared* is **No** for all rows
except as required by law or service providers.

### 5.3 Security practices

| Question | Answer |
|---|---|
| Data encrypted in transit | **Yes** — all API traffic over HTTPS |
| Can users request data deletion | **Yes** — in-app account deletion (Profile → Settings → account) deletes the account and its data |
| Has a dedicated security contact | **Yes** — `mithilviswask@gmail.com` |
| Data handling policy / safety policy URL | Provide when the privacy policy page goes live (see §7) |

### 5.4 Commitment (section 4 of the form)

- Data collection and security practices comply with the **Google Play Developer Program Policies**.
- Data is not sold.
- The app is not a government entity and does not collect sensitive government-issued IDs.

---

## 6. Additional Play Console fields

| Field | Value / suggestion |
|---|---|
| "About this app" synopsis | Same as short description |
| App category secondary | Productivity |
| Target audience | Students (14+). ⚠ Decide: if you market to under-13, you must declare **Families** policy — for 1.0.0 the app is aimed at school/university students (usually 13+). Verify against your actual audience. |
| Content guidelines compliance | The app is an education tool; no prohibited content. If AI answers can include any subject matter, keep the AI system prompt aligned with the content policy and consider a "report a problem" path (roadmap). |
| News app designation | No |
| Ads | None — no ad SDKs in `pubspec.yaml` |
| US export compliance | No cryptography beyond standard HTTPS |
| Account deletion (newer Play requirement) | Provide the in-app path: Profile → Settings → Delete account. Play now asks for an account-deletion URL/web form too — decide whether to expose a simple web form or rely on the in-app flow + support email, and add it to the store listing. |

---

## 7. Before you submit — things only you can decide/do

1. **Privacy Policy + Terms of Service pages** — the app has **no legal pages yet**
   (`src/app` has none). Google will not approve an app that collects personal data
   without a privacy policy URL. Draft these (or use the templates from the project's
   legal-docs phase) and host them at `https://studyflow.ai/privacy` and
   `/terms` **before** starting the store submission. ⚠ Legal review is yours.
2. **Website field** — `https://studyflow.ai` is currently **not** the StudyFlow app
   backend (it serves a different site). Decide the real production domain before
   publishing the listing.
3. **Backend must be live** — the app cannot sign in until the backend is deployed with
   a real database and `API_BASE_URL` points at it. Do not submit to review with a
   placeholder backend; reviewers test sign-in.
4. **$2 founding-member offer** — confirm the offer terms are documented and the count
   logic is verified (see `docs/founding-members.md`) before it's live in the store.
5. **App signing** — the release keystore (`.freebuff/studyflow-release.jks`) is what
   Play will sign future updates with once you upload the AAB. **Back it up** — losing it
   means you can never update the app under the same identity.
6. **Test on real devices** — Play review will install the AAB from the release
   workflow (`v1.0.0` tag) on at least one device. Run the full flow: sign-up → onboarding
   → notebook → AI chat → quiz before submitting.
7. **IARC/Data-safety re-verification** — every section above is pinned to what the
   1.0.0 build does. Any feature change (chat between users, ads, new permissions,
   third-party SDK) invalidates the answers — re-check before each release.

---

## 8. Release checklist (copy into Play Console)

- [ ] Privacy policy + Terms live at public URLs
- [ ] Production backend deployed, `API_BASE_URL` variable set, sign-up verified end-to-end
- [ ] 8 phone screenshots (1080×1920) captured per §3
- [ ] Feature graphic 1024×500
- [ ] App icon 512×512 with safe-zone padding
- [ ] IARC questionnaire answered per §4 (expect "Everyone")
- [ ] Data safety form answered per §5
- [ ] `ai.studyflow.studyflow_mobile` AAB from `v1.0.0` (or newer) uploaded
- [ ] App signing key backed up off-device
- [ ] Contact email correct: `mithilviswask@gmail.com`
- [ ] Internal test track: invite ≥1 tester, verify install + login + core flow
- [ ] Submit for review
