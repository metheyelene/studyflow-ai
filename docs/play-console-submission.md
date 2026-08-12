# StudyFlow AI — Play Console Submission Checklist (v1.1.0 AAB)

Click-by-click walkthrough for submitting **v1.1.0 (build 2)** to Google Play.
Everything below assumes you are signed into the **Play Console** as the developer
account owner.

**Application ID:** `ai.studyflow.studyflow_mobile`
**Version being submitted:** 1.1.0 — version code **2**, version name **1.1.0**
**AAB to upload:** `app-release.aab` from the GitHub release
`https://github.com/metheyelene/studyflow-ai/releases/tag/v1.1.0` (signed, Play-ready)
**Contact / security email:** `mithilviswask@gmail.com`
**Status:** DRAFT — legal/pricing items marked ⚠ are yours to confirm. Do not hit
"Send for review" until every section here is verified against the live build.

---

## 0. Before you open the Console (15 minutes)

- [ ] **Back up the release keystore.** The AAB is signed with
  `.freebuff/studyflow-release.jks` (plus its passwords). Copy it to at least two
  off-machine locations (password manager + encrypted drive). If it is lost after
  you enroll in Play App Signing, you can still update via Play's key, but back it up
  anyway — it is the identity of the app.
- [ ] Confirm the production backend is live and `API_BASE_URL` (GitHub → Settings →
  Secrets and variables → Actions) points at it. Reviewers will install the app and
  test sign-up, so the API must be reachable from the app.
- [ ] Confirm **Privacy Policy** and **Terms** are live at public URLs
  (`https://studyflow.ai/privacy` and `/terms` on the deployed Next.js app). ⚠ Legal
  review of both is yours before submission.
- [ ] Have the 8 phone screenshots (1080×1920), the 1024×500 feature graphic, and the
  512×512 app icon ready (capture guide: `docs/play-store-listing.md` §3).
- [ ] Decide the two business numbers you'll type below (see §8):
  1. The exact **₹ price of the founding plan** ($2 equivalent, ≈₹165–175) and whether
     it's inclusive of Indian GST.
  2. The **regular Premium price** (candidate: ₹399/month) — and whether to sell it on
     Play at launch at all.

---

## 1. Open / create the app

1. Go to https://play.google.com/console → **All apps**.
2. If the app already exists, click **StudyFlow AI** and skip to §2.
3. If not: click **Create app** → fill:
   - **App name:** `StudyFlow AI`
   - **Default language:** English (United States)
   - **App or game:** App
   - **Free or paid:** Free
   - **Declaration:** tick both boxes (Google Play App Signing + Developer Program
     Policies) — you must tick these to proceed.
   - Click **Create app**.

---

## 2. App integrity / Play App Signing (first upload only)

1. In the left menu: **App integrity → App signing**.
2. **Play App Signing** → **Enroll** → confirm. Google will generate an upload key and
   sign the app with its own key from here on. The AAB you upload uses the release
   keystore's certificate, which becomes the upload certificate — this is expected.
3. Note the upload key fingerprint for your records. (If you ever regenerate the
   keystore, you must re-register the new upload key here.)
4. Do **not** change anything in **App signing → Key management** unless you know what
   you're doing.

---

## 3. Upload the AAB (Internal testing track — do this first)

Review flow: **Internal testing → Production**, in that order. Start internal.

1. Left menu: **Testing → Internal testing**.
2. Click **Create new release** (or **Edit release** on the next one).
3. Under **App bundles**, click **Upload** → select `app-release.aab`.
   - Release notes (required): e.g.
     "StudyFlow AI 1.1.0 — Material 3 Expressive design system, dynamic color, adaptive
     study planner weighted by quiz performance, exam countdowns on the dashboard, and
     appearance (light/dark/system) settings."
4. **Review release** — check the displayed **version name 1.1.0** and **version code 2**
   match the AAB.
5. Click **Roll out** → choose **Internal testing** → **Save**.
6. **Testers** tab → **Create email list** → add yourself + one test device email →
   **Save changes**. Send the opt-in link to that email and **accept the tester invite
   on the device** (Google Play → Settings → Play Store → testing).

> Do not submit for review from internal testing — it is only for your install test
> (see §9).

---

## 4. Main store listing (left menu: **Store presence → Main store listing**)

Fill each field; most values are in `docs/play-store-listing.md`.

| Field | Enter |
|---|---|
| App name | `StudyFlow AI` |
| Short description (80 max) | `Turn your notes into a source-grounded AI study system — summaries, flashcards, quizzes.` |
| Full description | Paste the §2 description from `docs/play-store-listing.md` |
| App icon | 512×512 PNG (safe-zone padded) |
| Feature graphic | 1024×500 PNG |
| Phone screenshots | Upload all 8 (1080×1920), in the recommended order |
| Tablet screenshots | Optional; add 2 if you have them |
| Category | Education |
| Tags | Study, Education, Productivity |
| Contact email | `mithilviswask@gmail.com` |
| Website | The production domain (⚠ confirm it's the StudyFlow backend domain, not a placeholder) |
| Privacy policy URL | `https://studyflow.ai/privacy` |
| Price | Free |

Click **Save**.

---

## 5. Data safety form (left menu: **Policy → Data safety**)

Click **Start** and answer **per the table in `docs/play-store-listing.md` §5** — the
exact click-through:

**5.1 Data collection & security — click "Next".**
- For each data type below, toggle **Collected** = On (row appears), **Shared** = No,
  **Encrypted in transit** = Yes, **Users can request deletion** = Yes:
  1. **Name** (personal info)
  2. **Email address** (personal info)
  3. **User IDs** (personal info)
  4. **User content — files and docs** (photos/videos/audio section is **Not collected**;
     use **Other user files** under "Other") — this is your uploaded notes/PDFs
  5. **User content — other user content**: quiz answers, flashcard progress, study
     plans
  6. **App activity — app interactions**: first-party analytics events
     (`app_opened`, `signup`, `notebook_created`, …)
  7. **App activity — purchases**: subscription status/history
- **Do NOT toggle on:** Precise location, Approximate location, Photos, Videos, Audio,
  Contacts, Device IDs, Health/fitness, or any "shared" column.
- ⚠ Reviewer-facing note: documents are sent to the AI provider server-side for
  processing — disclose this as a service-provider note in the "processing" wording if
  the form asks; nothing is sold or shared with other users.

**5.2 Security practices — click "Next".**
- **Encrypted in transit:** Yes
- **Can users request data deletion:** Yes (in-app account deletion in
  Profile → Settings → Delete account)
- **Dedicated security contact:** `mithilviswask@gmail.com`
- **Safety policy URL:** `https://studyflow.ai/privacy`

**5.3 Declaration — click "Next".**
- Tick: data collection complies with Developer Program Policies; data is **not sold**;
  not a government app; no sensitive ID collection.

**5.4 Email — click "Next"**, confirm, **Save**.

---

## 6. Content rating (left menu: **Policy → App content → Content rating**)

Click **Start questionnaire** and answer **exactly** per `docs/play-store-listing.md` §4:

- Category: **Education** (or the education filter Google presents)
- Sexual content/nudity: **No**
- Violence (realistic): **No** · Violence (cartoon/fantasy): **No**
- Gambling (real or simulated, incl. loot boxes): **No** — subscriptions are billing,
  not gambling
- Alcohol/tobacco/drugs: **No** · Profanity/crude humor: **No**
- Horror/fear: **No** · Weapons: **No** · Hate speech: **No**
- User-generated content: **No** (no user-to-user communication; content is private
  per-user)
- Share location: **No** · Share personal info: **No** · Users communicate with each
  other: **No**

Expected result: **Everyone (3+)**. If the app ever adds chat or public content,
re-take this questionnaire.

---

## 7. App access + target audience (left menu: **Policy → App content**)

- **App access:** choose **All functionality is available without special access** and
  explain: "The app requires creating a free account to use core features; review
  credentials below if prompted."
- **Ad disclosures:** **No** — no ad SDKs in `pubspec.yaml`.
- **Target audience:** Students, **13+**. ⚠ Do **not** select under-13 (that triggers
  Families policy). If your actual audience includes under-13s, stop and revisit.
- **Account deletion:** confirm the in-app path (Profile → Settings → Delete account);
  ⚠ decide whether to also provide a web form/URL for account deletion, and put that
  URL here if Play asks for one.
- **News:** No. **US export compliance:** No special cryptography.

---

## 8. Subscription products (left menu: **Monetize with Play → Subscriptions**)

Create both products exactly as decided in `docs/billing-decision.md` §5.B. Prices
are set **per country** — set India first, then let Play auto-convert for the rest
(or add your own values where required).

**Product 1 — the founding offer**
1. Click **Create subscription** → **Enter product details**:
   - **Product ID:** `founding_member_monthly`  ⚠ This ID is referenced by the app's
     billing code — do not rename later.
   - **Name:** `StudyFlow Premium — Founding Member`
   - **Description:** "Founding-member pricing for the first 35 members. After the
     offer closes, this price stays locked for existing members."
   - **App:** StudyFlow AI
2. **Base plans** → **Create base plan**:
   - **Billing period:** Monthly (1 month)
   - **Renews automatically:** Yes
   - **Base plan ID:** `monthly`
   - **Offer:** **None** — the $2 price IS the price. Do **not** create a
     limited-time "intro offer" (the founding cap is enforced by the backend, not by
     Play).
   - **Price:** your decided ₹ value (≈₹165–175, the $2 equivalent). ⚠ Decide
     inclusive/exclusive GST and stay consistent everywhere.
3. **Save** → activate the base plan (state: **Active**).

**Product 2 — regular Premium (optional at launch)**
1. **Create subscription** → **Product ID:** `premium_monthly`
   - Name: `StudyFlow Premium`
   - **Base plan ID:** `monthly`, monthly auto-renewing, **no intro offer**.
   - **Price:** your decided full price (candidate: ₹399/month). ⚠ Decide now whether
     to launch it on Play or only after the founding offer closes.
2. **Save** → activate.

**Store-listing pricing section** (Store presence → Main store listing → **Pricing**):
- Declare **In-app purchases: Yes — subscriptions** and link both products so the
  subscription terms render on the listing.
- Set **free trial**: none.

> ⚠ The founding cap (35) is enforced server-side by `src/lib/founding.ts` — Play does
> not know about it. The app must hide `founding_member_monthly` once the backend
> reports the offer closed (client reads the count from the backend; never hard-coded).

---

## 9. Install test on internal testing (before any review)

1. On the test device, open the Play Store app page for the internal build (via the
   opt-in link) and install.
2. Run the full flow: sign-up → onboarding → create notebook → upload a source →
   AI chat with a citation → flashcards → quiz → study plan → Premium screen.
3. **License test the subscription** (no real charge):
   - Play Console → **Setup → License testing** → add the test account as a license
     tester.
   - On the device, sign in with that test account and buy `founding_member_monthly`
     — the purchase is a test transaction.
   - Verify: purchase token verified server-side → founding store claims a slot →
     Premium unlocks → **restore purchases** works after reinstall.
4. Check **Pre-launch report** (left menu: Testing → Internal testing → Pre-launch
   report) once available and fix any crashes/ANRs it flags.

---

## 10. Send for review (Production)

Only after §0–§9 are green.

1. Left menu: **Testing → Production**.
2. **Create new release** → **Upload** the same `app-release.aab` (v1.1.0, build 2).
   Release notes: same text as §3.
3. **Review release**: version 1.1.0, code 2. Confirm **signing certificate** matches
   your upload key.
4. **Roll out** → pick **100% (or phased: 10% → 50% → 100%)**.
5. Back in **Policy → App content**: confirm all sections (Ads, App access, Content
   rating, Data safety, News, Target audience) show **Done/Complete** — the review
   form blocks submission until they are.
6. Click **Send for review**.

---

## 11. After submission (what to watch)

- **Orders & refunds** (left menu: Monetize → Orders & refunds) — subscriptions,
  cancellations, and any refund requests land here. Users cancel in the Play Store,
  not the app — the app's cancellation copy must say this.
- **Subscriptions dashboard** — active subscribers, MRR, churn. Reconcile with the
  founder dashboard (revenue shown there is backend-derived, never fabricated).
- **Play Console alerts** — any policy/rating/security emails. Handle within the
  deadlines.

---

## 12. The only things YOU must do manually (cannot be automated)

1. **Developer identity verification** and tax information (Play Console → Setup →
   Payments profile) — your documents, your signature.
2. **Decide the two prices** in §0 (founding ₹ value + GST treatment; regular Premium
   price) and confirm the founding offer terms (forever-$2 promise) per
   `docs/founding-members.md`.
3. **Legal review** of the Privacy Policy and Terms before linking them as the
   privacy-policy URL.
4. **Confirm the production domain** used for the Website + privacy-policy URLs is the
   real StudyFlow backend domain.
5. **Enroll in Play App Signing** (one-time click in §2) and accept the Developer
   Distribution Agreement if not yet accepted.

---

## 13. One-page copy-paste checklist

- [ ] Keystore `.freebuff/studyflow-release.jks` backed up off-machine
- [ ] Backend live; `API_BASE_URL` set; sign-up verified from the app
- [ ] Privacy Policy + Terms live at public URLs (⚠ review)
- [ ] App created with package `ai.studyflow.studyflow_mobile`
- [ ] Play App Signing enrolled (upload key noted)
- [ ] `app-release.aab` uploaded to Internal testing → installed on a device
- [ ] Main store listing complete (name, descriptions, 8 screenshots, feature graphic,
      icon, category, contact, privacy URL)
- [ ] Data safety: rows per §5; encrypted=Yes; deletion=Yes; contact set
- [ ] Content rating: "Everyone (3+)" per §6
- [ ] App access: all functionality available; target audience 13+; no ads
- [ ] Subscriptions: `founding_member_monthly` active at decided ₹ price, no intro
      offer; `premium_monthly` per decision; declared in listing pricing
- [ ] License-test purchase + server verification + restore verified
- [ ] Pre-launch report clean
- [ ] Production release created from the same AAB, version 1.1.0 / code 2
- [ ] Policy section shows all Complete
- [ ] **Send for review**
