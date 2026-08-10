# Founding Member Offer — Specification & Terms

**Plan:** `founding_member_monthly` — StudyFlow Premium at **$2/month**, limited to the
**first 35 successful subscriptions**. No fake scarcity anywhere: every number on
screen is computed server-side from the database.

---

## 1. What counts as a founding member (counting rule)

A founding membership is **claimed** only when:

1. The payment processor's webhook delivers a **confirmed successful subscription**
   (`checkout.session.completed` with `mode = subscription`), **and**
2. The session's charged amount equals the founding price ($2.00), **and**
3. The user has not already claimed a founding membership.

**Never counted:** page views, checkout starts, abandoned checkouts, failed payments,
cancelled checkout sessions, or any frontend signal. This logic lives in
`src/lib/founding.ts` (claim) and `src/lib/billing.ts` (fulfillment) — the webhook is
the only entry point that can consume a slot.

## 2. Slot permanence (explicit decision)

> **Decision: once a customer successfully claims one of the 35 founding
> memberships, that slot is permanently consumed — even if they later cancel.**

Rationale (per product guidance): prevents cycling the offer and keeps the
"first 35 members" promise meaningful. Cancellation marks the member's record
`canceled` but never frees the slot. Documented here and asserted by tests 9.

## 3. Race safety

Allocation uses a single-row atomic counter:

```sql
UPDATE founding_member_counter
SET claimed = claimed + 1
WHERE id = 1 AND claimed < cap
RETURNING claimed;
```

Postgres row-locks the counter row, so two concurrent webhook fulfillments racing
for slot 35 serialize: exactly one succeeds, the other sees `claimed = cap` (0 rows)
and is rejected. The member insert happens in the same transaction; a unique
constraint on `founding_members.user_id` makes double-claims idempotent-safe
(webhook replay returns `already_claimed`, never a second slot).

## 4. Pricing terms (transparency)

- **Founding Member:** $2/month, **ongoing for the life of the membership**. The
  $2 price does NOT increase after the 35th member is claimed. No introductory
  period, no future price change — this is the member's price while subscribed.
- Billed monthly, recurring. Cancellation: via the Stripe billing portal or in-app
  cancel; access continues to the end of the paid period.
- After the 35th slot is claimed, the $2 offer is no longer offered to new users;
  they see regular Premium ($4.99/mo). Existing founding members keep $2.

## 5. Admin / display rules

- The **claimed count** shown anywhere (pricing, landing, dashboard) comes from
  `getFoundingStatus()` — the database counter. Never hard-coded.
- When `claimed >= cap`, all "Become a Founding Member" CTAs are replaced with
  "Founding memberships are now full" + regular Premium.

## 6. Security model

- Checkout sessions are created **server-side** with a fixed price ID — the client
  never sends an amount (test 10).
- The webhook verifies the Stripe signature (`stripe.webhooks.constructEvent`) before
  any fulfillment; unverifiable payloads return 400 (test 12). Fulfillment is
  idempotent against replay (test: duplicate event → single claim).
- `NODE_ENV === "production"` guards the dev affordances; there is no
  client-triggered "mark me premium" path.

## 7. Business/legal items requiring founder review (do NOT launch without these)

- [ ] **Refund policy** — the current draft: standard Stripe default (refunds on
      request within 14 days, no questions). Confirm or override.
- [ ] **Taxes** — Stripe Tax is NOT enabled; prices are exclusive of any applicable
      VAT/GST/sales tax. Decide whether to enable Stripe Tax before launch.
- [ ] **Payment failure** — if a recurring charge fails, Stripe retries; after
      ~4 failed attempts the subscription moves to `unpaid` and access is revoked
      at the end of the period. Confirm this is the desired policy.
- [ ] **Terms text** — the exact wording "first 35 members", slot permanence, and
      $2-forever statement must appear in the Terms of Service (currently a draft
      template in `docs/legal/`).
- [ ] **Promotional framing** — "Founding Member" is a lifetime label; confirm it
      should persist even after the program closes (recommended: yes).

## 8. Rollout note

Test the full flow in Stripe test mode first (test price `$2/month`, webhook
endpoint `https://<host>/api/billing/webhook`). The 35 cap is a test-mode-friendly
constant read from the database row; set it to a small number (e.g. 2) in the
sandbox database to exercise the "full" path, then set 35 for production.
