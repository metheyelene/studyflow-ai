# Billing decision: Google Play Billing vs alternative billing (founding offer)

**Status: DECIDED — ship Google Play Billing for Android. Defer alternative billing (PhonePe) until it pays for itself.**
_Last reviewed: Aug 2026. Policy facts below are dated; re-verify before relying on them at launch._

## 1. The decision, in one paragraph

StudyFlow's $2/month founding offer on Android will be sold through **Google Play
Billing** as a dedicated subscription product that the backend gates to the first 35
claimants. We will **not** integrate PhonePe or any alternative billing system at
launch. Alternative billing would save roughly **5% of revenue** (see §4) while
requiring Play Console program enrollment, Billing Library 9.1+, a mandated choice
screen, mandatory sale reporting to Google, a PhonePe **merchant** account, and
server-side payment verification — a large compliance surface to chase pennies per
month at this scale. We revisit the decision once the 10%-fee model reaches India
and monthly Android subscription revenue is meaningfully above the cost of building it.

The **web** app keeps its existing Stripe checkout (web is not subject to Play
Billing policy). The **iOS** app will use Apple's in-app purchase/subscription
mechanism — a separate integration, same backend entitlement.

## 2. Current policy facts (June 2026)

- **June 30, 2026 "expanded billing choice" model** (rolled out first in US/UK/EEA;
  India NOT in the first phase — staggered): the service fee (10% on first $1M/yr)
  now applies **regardless of billing system**, and Play adds a separate **5% billing
  fee** only when Play Billing processes the transaction. Net for subscriptions:
  **Play Billing ≈ 15%** (10% service + 5% billing), **alternative billing ≈ 10%**
  (service fee only), in rollout regions.
- **India today** (pre-rollout): the older regime applies — 15% service fee on
  subscriptions via Play Billing. The CCI-mandated India User Choice Billing exists,
  with a ~4% service-fee reduction for alternative billing, but it requires enrollment,
  a choice screen, and transaction reporting. Google has not yet published India's
  billing-fee rate under the new model ("details for other markets soon").
- **Play subscription minimums**: USD floor $0.99; $2 (or ~₹165–175) is fine.
- **Cohort pricing**: Play does NOT support different prices per user cohort on one
  product. The honest pattern is a **separate product** at the founding price,
  **backend-gated** while the offer is open, and deprecated after the 35th claim —
  existing subscribers keep $2 (you cannot raise their price without consent).
- **Restore/entitlement**: Play purchases must be verified server-side (purchase
  token) and restored on reinstall — matching the existing "backend is source of
  truth" architecture.

## 3. Why Play Billing wins for launch

| Factor | Play Billing | PhonePe / alternative billing |
|---|---|---|
| Compliance | Default; no enrollment | Requires program enrollment + choice screen + reporting |
| India payments | UPI is a built-in Play payment method | You build the merchant flow + webhook verification |
| Fee at launch scale | 15% (~$0.30/mo per member) | 10% (~$0.20/mo) — saves ~$0.10/member/mo |
| Refunds / disputes | Google handles | You handle, merchant-side |
| Setup cost | Console product + client SDK | Billing Lib 9.1 + choice screen + PhonePe merchant onboarding (needs your identity/documents) + reporting |
| Risk | Low | Policy-violation risk if done wrong (e.g., app linking to a raw UPI/PhonePe page) |

## 4. Revisit criteria (when to build alternative billing)

Reconsider only when **all** hold:
1. Google's new fee model has reached India and the numbers are published (billing fee for Play in India, alternative-billing fee).
2. Monthly Android subscription revenue is high enough that the 5%-point delta exceeds the build cost (rough rule of thumb: > $1k/mo).
3. You are prepared for PhonePe **merchant** onboarding (business documents, settlement bank) — this is a manual, identity-required step.

## 5. What you must do in the Play Console (manual, in order)

### A. Account prerequisites (one-time)
1. **Play Console developer account** — one-time $25; add a payment profile, complete **identity verification** (your documents — not automatable), tax information, and the Developer Distribution Agreement.
2. **Create the app**: package name **`ai.studyflow.studyflow_mobile`** (matches the Flutter `applicationId`). Complete the listing essentials: app name, description, screenshots (docs/play-store-listing.md), privacy policy URL (hosted at /privacy), data-safety form, content rating, target audience, app-access instructions.
3. **Declare subscriptions**: in the app's pricing section, declare that the app sells subscriptions and link the subscription products (below). Play shows the subscription terms to users on the store listing.

### B. Subscription products (Monetize with Play → Subscriptions)
4. Create **`founding_member_monthly`** — auto-renewing monthly base plan. Price: set the INR price directly (≈₹165–175, the $2 equivalent; Play converts to other currencies). **No intro offer** — the $2 IS the price, not a limited-time deal.
5. Create **`premium_monthly`** — the regular plan at full price (your call: pick one price and document it; e.g., ₹399/month — decide before creating).
6. Both products: enable for the app; note the store listing will show each price per region.

### C. Testing before launch
7. **License testing**: add yourself + testers as license testers; use a license-test account to buy the $2 plan **without real charges** and verify: purchase → server-side token verification → founding store claims slot → Premium unlocks → restore works.
8. **Play Billing Library floor**: new/updated app must target Billing Library **8+** by Aug 31, 2026 (11+ Billing Choice later if we ever enroll). The Flutter `in_app_purchase` integration + a Play Developer API/RTDN webhook on the backend is the code work that sits on top of these Console steps.

### D. The 35th member (business procedure)
9. When the backend counter reaches 35: stop offering `founding_member_monthly` in the app (backend gate — the client must not show it), and in Play Console you may leave the product **inactive** (existing subscribers keep renewing at $2). Remove the founding price from the store listing's pricing section and surface the regular plan.

### E. Ongoing obligations
10. Play handles Indian taxes on the subscription price; set prices **inclusive or exclusive** consistently and state it in the app (Stripe Tax question from docs/founding-members.md also applies here — decide before launch).
11. Refunds/chargebacks are managed from the Play Console (Orders & refunds) and via Google's subscription-cancellation UI (users cancel in Play, not the app — state this in the app's cancellation copy).
12. Quarterly Play billing reports + service-fee invoicing flow automatically to the payment profile; reconcile with the founder dashboard.

## 6. Existing code and what's still needed

Already built: `src/lib/founding.ts` (atomic 35-cap claim, permanent slots, idempotent vs webhook replay), `src/lib/billing.ts` (Stripe fulfillment for **web**), entitlement plumbing (`src/lib/premium.ts`, usage limits keyed off plan).

Still needed for Android (code, not Console):
- Flutter `in_app_purchase` (or similar) with product IDs matching the Console products; prices rendered **from Play's product details, never hard-coded**.
- Backend Play purchase verification endpoint + RTDN (Play Developer API push notification) webhook that verifies the purchase token server-side, then routes through the **same** `postgresFoundingStore.claim` for the founding plan (reuses the atomic claim, so the 35-cap logic is identical across Stripe-web and Play).
- `plans.ts` gains a `founding_member` entitlement (currently `Plan = "free" | "premium"`).
- Restore-purchases + backend entitlement sync on reinstall.
- iOS: separate Apple StoreKit integration against the same backend entitlement.

## 7. Open questions for you (business decisions, not mine to invent)

1. Regular Premium price and whether to also sell it on Play at launch.
2. INR price point for the $2 founding offer (exact ₹ value) and whether prices shown are inclusive of Indian GST.
3. Whether the founding $2 is promised **forever** for the 35 (current copy says yes) — this determines whether you ever attempt a consent-based price change later.
4. Refund policy wording in-app (Play's default vs your own stated policy).
