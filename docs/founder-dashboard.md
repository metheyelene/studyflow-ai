# Founder Dashboard — Payment Provider Access

The founder dashboard at `/admin` reports **real revenue only** — never
estimates. Each number comes from a payment provider API, so each provider
needs credentials with the narrowest permission that still lets the
dashboard read that data.

Two providers, two access models:

| Provider | What the dashboard calls | Credential | Env var |
|---|---|---|---|
| Stripe | `GET /v1/invoices?status=paid` (paginated) | API key with `invoices:read` | `STRIPE_SECRET_KEY` |
| Google Play | `purchases.subscriptions.get` per purchase token | Service account with Play Console Finance access | `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` |

The dashboard treats a missing/unreachable provider as **unavailable** — it
shows "Unavailable" and never invents a number. So a provider can be
unconfigured without breaking the page; you just won't see that channel
until the access below is set up.

---

## Stripe — exact access

**What the code calls** (`src/lib/founderDashboard.ts` →
`defaultListStripePaidInvoices`):

```
GET /v1/invoices?status=paid&limit=100[&starting_after=<invoice_id>]
```

Cursor-paginated: it walks every page until `has_more` is false, so revenue
is not capped at the most recent 100 invoices.

**Minimum permission scope: `invoices:read`**

**Where to create it (Stripe Dashboard):**

1. Go to **Developers → API keys**.
2. Click **Create restricted key** (recommended — a full `sk_live_...`
   secret key also works but grants far more than this dashboard needs).
3. Under **Invoices**, enable **Read** only. Do not enable write scopes.
4. Copy the resulting `rk_live_...` key.

**Where it goes:**

- Local: `.env` → `STRIPE_SECRET_KEY=rk_live_...`
- Production: Vercel → project → Settings → Environment Variables →
  `STRIPE_SECRET_KEY` (production environment).

**Notes:**

- Restricted keys start with `rk_live_`; full secret keys with `sk_live_`.
  Both are accepted by the same client.
- This same key is already used by web checkout/webhooks, so if one is
  already deployed, reuse it — just confirm it has `invoices:read`.

---

## Google Play — exact access

**What the code calls** (`src/lib/playBilling.ts` →
`GooglePlayVerifier.getSubscriptionPrice`):

```
GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/
  {packageName}/purchases/subscriptions/{subscriptionId}/tokens/{purchaseToken}
```

One call per purchase token held in the `subscriptions` table. The dashboard
runs these with bounded concurrency (max 5 in flight) so a large subscriber
base cannot trip the API quota.

**Credential: a service-account JSON key**, NOT an OAuth client, NOT a Play
Console login, NOT an API key. The code signs its own JWT from the JSON and
exchanges it for an access token, so **no API key is involved at all**.

### Step 1 — Create the service account (Google Cloud Console)

1. Go to https://console.cloud.google.com → create or select a project.
2. **IAM & Admin → Service Accounts → Create service account**.
   - Name it e.g. `studyflow-revenue-reader`.
   - No role is needed in Google Cloud itself — the Play Console permission
     (Step 2) is what grants API access. Do not grant broad GCP roles.
3. Open the service account → **Keys → Add key → Create new key → JSON**.
   - Download the file. This JSON is the entire credential.

### Step 2 — Grant Play Console Finance access

1. Go to **Play Console** → **Settings → Users and permissions → Invite new
   user** (or click an existing user).
2. Enter the service account's email
   (`studyflow-revenue-reader@<project>.iam.gserviceaccount.com`).
3. Under **Account permissions**, grant:
   - **Finance → View financial data** — this is the permission that allows
     the Android Publisher API to read purchase/subscription data for
     revenue. (App-level access is not required; account-level finance is
     what gates `purchases.subscriptions.get`.)
   - Do NOT grant Admin, payments editing, or release permissions unless you
     want this credential to have them.
4. Save. Propagation is usually immediate; occasionally takes a few minutes.

### Step 3 — Store the JSON

**Where it goes:**

- Local: `.env` →
  `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON={"type":"service_account",...}`
  (the whole downloaded file, JSON-quoted as one env value).
- Production: Vercel → project → Settings → Environment Variables →
  `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` (production environment).

**Notes:**

- The same service account also powers Play purchase verification
  (`verifySubscription`) and RTDN webhook calls — if one is already deployed,
  reuse it.
- **Never commit the JSON.** It is a private-key credential; `.env` and
  `.env.example` exclude it. If it is ever committed, rotate it in Google
  Cloud (delete the key, generate a new one) and update the env var.
- The RTDN webhook itself is protected by a separate shared token,
  `PLAY_RTDN_AUTH_TOKEN` — unrelated to this service account.

---

## What each channel shows without its provider

| State | Stripe panel | Play panel |
|---|---|---|
| No purchases at all | ₹0 headline (whole card) | ₹0 headline (whole card) |
| Purchases exist, provider reachable | Real USD sums + monthly chart | Real INR sums + monthly chart |
| Purchases exist, provider missing/down | "Unavailable — STRIPE_SECRET_KEY missing or API error" | "Unavailable — GOOGLE_PLAY_SERVICE_ACCOUNT_JSON missing or API error" |

Revenue is shown in each provider's native currency (Stripe: USD · Google
Play: INR) and is **never converted** — a conversion would be an estimate,
and this dashboard does not estimate.

## Founder access to the page itself

The `/admin` route is gated server-side by `ADMIN_EMAILS` (comma-separated,
e.g. `ADMIN_EMAILS=mithilviswask@gmail.com`). Set it in the same production
environment as the provider keys. The mobile Profile tab shows a "Founder
Dashboard" card to that same email and opens the page in a browser.
