// ─────────────────────────────────────────────────────────────────────
// Google Play Billing — purchase verification, founding-member
// fulfillment, and RTDN (Real-time Developer Notifications) handling.
//
// Security model (mirrors docs/founding-members.md §6 for Stripe):
//  - The mobile app NEVER decides entitlement. It sends the Play
//    purchase token to POST /api/billing/play/verify; the backend
//    verifies the token against the Google Play Developer API, checks
//    product + purchase state, and only then routes through the
//    founding store's atomic claim. No fake success path exists.
//  - Prices are rendered from Play's product details on-device; this
//    module only accepts purchases for the configured founding product
//    id, so the client can never buy a different product as founding.
//  - Credentials live in GOOGLE_PLAY_SERVICE_ACCOUNT_JSON (a service
//    account with the Android Publisher role — never in the app). When
//    absent, every payment path returns a clear "not configured" error.
//  - RTDN notifications carry no userId, so they can only update state
//    for purchase tokens this backend already attributed (via verify).
//    Unknown tokens are acknowledged and left for the next in-app
//    verify to reconcile — the backend stays the source of truth.
//  - RTDN is idempotent: the atomic founding claim + subscriptions
//    upsert make replay a no-op, never a double-claim.
// ─────────────────────────────────────────────────────────────────────
import { createSign, randomUUID } from "node:crypto";

import { eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { trackEvent } from "@/lib/analytics";
import {
  FOUNDING_TERMS,
  type FoundingStore,
  foundingOfferOpenFor,
  postgresFoundingStore,
} from "@/lib/founding";
import type { WebhookResult } from "@/lib/billing";

const PLAY_API =
  "https://androidpublisher.googleapis.com/androidpublisher/v3/applications";

/** Purchase states returned by the Play Developer API. */
export const PLAY_PURCHASE_STATE = {
  PURCHASED: 0,
  CANCELED: 1,
  PENDING: 2,
} as const;

/** RTDN subscriptionNotification.notificationType values we act on. */
export const RTDN_TYPE = {
  SUBSCRIPTION_PURCHASED: 0,
  SUBSCRIPTION_RENEWED: 1,
  SUBSCRIPTION_CANCELED: 2,
  SUBSCRIPTION_RESTARTED: 4,
  SUBSCRIPTION_REVOKED: 7,
  SUBSCRIPTION_EXPIRED: 8,
  SUBSCRIPTION_GRACE_PERIOD: 9,
  SUBSCRIPTION_RESTORED: 12,
  SUBSCRIPTION_CANCEL_SCHEDULED: 13,
  SUBSCRIPTION_RECOVERED: 14,
} as const;

export class PlayBillingNotConfigured extends Error {
  constructor(message = "Play billing is not configured") {
    super(message);
    this.name = "PlayBillingNotConfigured";
  }
}

export class PlayVerificationError extends Error {
  constructor(message: string, readonly status = 400) {
    super(message);
    this.name = "PlayVerificationError";
  }
}

export function playBillingConfigured(): boolean {
  return Boolean(process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON);
}

/** A verified Play subscription purchase (shape of the Developer API
 *  subscriptions.get response, normalized to what fulfillment needs). */
export interface PlaySubscriptionPurchase {
  /** Product id this subscription belongs to (e.g. founding_member_monthly). */
  productId: string;
  packageName: string;
  orderId: string;
  purchaseToken: string;
  /** PLAY_PURCHASE_STATE — must be PURCHASED to fulfill. */
  purchaseState: number;
  expiryTimeMillis: number;
  autoRenewing: boolean;
  /** Price fields from the Play API (real amounts, used for the founder
   *  dashboard revenue — never fabricated). */
  priceAmountMicros?: number;
  priceCurrencyCode?: string;
}

export interface PlayVerifyInput {
  packageName: string;
  /** Product id — the Developer API's subscriptions.get `subscriptionId`. */
  subscriptionId: string;
  purchaseToken: string;
}

export interface PlayVerifier {
  verifySubscription(input: PlayVerifyInput): Promise<PlaySubscriptionPurchase>;
  /** Best-effort acknowledgment (Play requires subscriptions be acked
   *  within 3 days). Failures are logged, never fatal. */
  acknowledgeSubscription(input: PlayVerifyInput): Promise<void>;
  /** Real price for a purchase, for the founder dashboard. Optional so
   *  existing fakes/tests keep compiling; implementers without it make
   *  Play revenue report "unavailable" rather than fabricate it. */
  getSubscriptionPrice?(
    input: PlayVerifyInput,
  ): Promise<{ priceAmountMicros: number; priceCurrencyCode: string }>;
}

interface ServiceAccount {
  clientEmail: string;
  privateKey: string;
}

function loadServiceAccount(): ServiceAccount {
  const raw = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;
  if (!raw) {
    throw new PlayBillingNotConfigured(
      "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is not set — add the Play service account JSON (Android Publisher role)",
    );
  }
  try {
    const parsed = JSON.parse(raw) as {
      client_email?: string;
      private_key?: string;
    };
    if (!parsed.client_email || !parsed.private_key) {
      throw new Error("missing client_email/private_key");
    }
    return { clientEmail: parsed.client_email, privateKey: parsed.private_key };
  } catch {
    throw new PlayBillingNotConfigured(
      "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is not a valid service-account JSON",
    );
  }
}

// Module-level token cache (process-lifetime). Access tokens live 1h;
// caching keeps serverless cold paths cheap.
let _tokenCache: { token: string; expiresAt: number } | undefined;

const b64url = (o: object | string) =>
  Buffer.from(typeof o === "string" ? o : JSON.stringify(o)).toString(
    "base64url",
  );

async function fetchAccessToken(
  account: ServiceAccount,
  fetchImpl: typeof fetch,
): Promise<string> {
  if (_tokenCache && _tokenCache.expiresAt > Date.now() + 60_000) {
    return _tokenCache.token;
  }
  const now = Math.floor(Date.now() / 1000);
  const header = b64url({ alg: "RS256", typ: "JWT" });
  const claim = b64url({
    iss: account.clientEmail,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  });
  const signingInput = `${header}.${claim}`;
  const signature = createSign("RSA-SHA256")
    .update(signingInput)
    .sign(account.privateKey, "base64url");
  const jwt = `${signingInput}.${signature}`;

  const res = await fetchImpl("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const data = (await res.json().catch(() => ({}))) as {
    access_token?: string;
    expires_in?: number;
  };
  if (!res.ok || !data.access_token) {
    throw new PlayVerificationError("could not obtain Play access token", 503);
  }
  _tokenCache = {
    token: data.access_token,
    expiresAt: Date.now() + (data.expires_in ?? 3600) * 1000,
  };
  return data.access_token;
}

/** Real Play Developer API verifier. Zero dependencies: signs a JWT with
 *  node:crypto, exchanges it for an access token, and calls the
 *  androidpublisher API with global fetch. */
export class GooglePlayVerifier implements PlayVerifier {
  constructor(
    private readonly fetchImpl: typeof fetch = fetch,
    private readonly packageName: string = FOUNDING_TERMS.playPackageName,
  ) {}

  async verifySubscription(
    input: PlayVerifyInput,
  ): Promise<PlaySubscriptionPurchase> {
    const account = loadServiceAccount();
    const token = await fetchAccessToken(account, this.fetchImpl);
    const url =
      `${PLAY_API}/${encodeURIComponent(input.packageName)}` +
      `/purchases/subscriptions/${encodeURIComponent(input.subscriptionId)}` +
      `/tokens/${encodeURIComponent(input.purchaseToken)}`;
    const res = await this.fetchImpl(url, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) {
      throw new PlayVerificationError(
        `Play verification failed (${res.status})`,
        res.status === 404 ? 400 : 502,
      );
    }
    const data = (await res.json()) as {
      productId?: string;
      orderId?: string;
      purchaseState?: number;
      expiryTimeMillis?: string | number;
      autoRenewing?: boolean;
      acknowledgementState?: number;
      priceAmountMicros?: string | number;
      priceCurrencyCode?: string;
    };
    const purchaseState = data.purchaseState ?? PLAY_PURCHASE_STATE.PENDING;
    if (purchaseState !== PLAY_PURCHASE_STATE.PURCHASED) {
      throw new PlayVerificationError("purchase is not in a purchased state");
    }
    return {
      productId: data.productId ?? input.subscriptionId,
      packageName: input.packageName,
      orderId: data.orderId ?? "",
      purchaseToken: input.purchaseToken,
      purchaseState,
      expiryTimeMillis: Number(data.expiryTimeMillis ?? 0),
      autoRenewing: data.autoRenewing ?? false,
      priceAmountMicros: data.priceAmountMicros
        ? Number(data.priceAmountMicros)
        : undefined,
      priceCurrencyCode: data.priceCurrencyCode ?? undefined,
    };
  }

  /** Real price for a purchase (founder dashboard revenue). Unlike
   *  verifySubscription this does NOT reject canceled/expired purchases —
   *  a canceled subscription still generated billed revenue. Returns a
   *  404 as an error; the caller decides how to treat missing tokens. */
  async getSubscriptionPrice(input: PlayVerifyInput): Promise<{
    priceAmountMicros: number;
    priceCurrencyCode: string;
  }> {
    const account = loadServiceAccount();
    const token = await fetchAccessToken(account, this.fetchImpl);
    const url =
      `${PLAY_API}/${encodeURIComponent(input.packageName)}` +
      `/purchases/subscriptions/${encodeURIComponent(input.subscriptionId)}` +
      `/tokens/${encodeURIComponent(input.purchaseToken)}`;
    const res = await this.fetchImpl(url, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) {
      throw new PlayVerificationError(
        `Play price lookup failed (${res.status})`,
        res.status === 404 ? 400 : 502,
      );
    }
    const data = (await res.json()) as {
      priceAmountMicros?: string | number;
      priceCurrencyCode?: string;
    };
    if (data.priceAmountMicros == null || !data.priceCurrencyCode) {
      throw new PlayVerificationError("price unavailable for purchase");
    }
    return {
      priceAmountMicros: Number(data.priceAmountMicros),
      priceCurrencyCode: data.priceCurrencyCode,
    };
  }

  /** Best-effort acknowledgment (Play requires subscriptions be acked
   *  within 3 days). Failures are logged, never fatal. */
  async acknowledgeSubscription(input: PlayVerifyInput): Promise<void> {
    try {
      const account = loadServiceAccount();
      const token = await fetchAccessToken(account, this.fetchImpl);
      const url =
        `${PLAY_API}/${encodeURIComponent(input.packageName)}` +
        `/purchases/subscriptions/${encodeURIComponent(input.subscriptionId)}` +
        `/tokens/${encodeURIComponent(input.purchaseToken)}:acknowledge`;
      await this.fetchImpl(url, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
      });
    } catch (err) {
      console.error("[play] acknowledge failed (non-fatal):", err);
    }
  }
}

// ── Founding fulfillment ─────────────────────────────────────────────

export interface PlayFulfillmentResult {
  ok: boolean;
  status: number;
  message?: string;
  /** Stored plan when fulfilled ("founding_member"). */
  plan?: string;
}

export interface PlayFulfillmentDeps {
  verifier?: PlayVerifier;
  store?: FoundingStore;
}

/**
 * The ONLY path that consumes a Play founding slot. Verifies the token
 * server-side, checks product + purchase state, then routes through the
 * same atomic claim as the Stripe flow. Idempotent: a repeated verify
 * (or an RTDN renewal) returns ok without double-claiming.
 */
export async function fulfillPlayFoundingPurchase(
  input: {
    userId: string;
    packageName: string;
    productId: string;
    purchaseToken: string;
  },
  deps: PlayFulfillmentDeps = {},
): Promise<PlayFulfillmentResult> {
  const verifier = deps.verifier ?? new GooglePlayVerifier();
  const store = deps.store ?? postgresFoundingStore;
  const { userId, packageName, productId, purchaseToken } = input;

  if (productId !== FOUNDING_TERMS.playProductId) {
    return { ok: false, status: 400, message: "unknown product" };
  }
  if (packageName !== FOUNDING_TERMS.playPackageName) {
    return { ok: false, status: 400, message: "unknown package" };
  }

  let verified: PlaySubscriptionPurchase;
  try {
    verified = await verifier.verifySubscription({
      packageName,
      subscriptionId: productId,
      purchaseToken,
    });
  } catch (err) {
    if (err instanceof PlayBillingNotConfigured) {
      return { ok: false, status: 503, message: "billing not configured" };
    }
    await trackEvent(userId, "founding_subscription_failed", {
      reason: "play_verification_failed",
    });
    return { ok: false, status: 400, message: "purchase verification failed" };
  }

  if (verified.productId !== FOUNDING_TERMS.playProductId) {
    return { ok: false, status: 400, message: "product mismatch" };
  }
  if (verified.purchaseState !== PLAY_PURCHASE_STATE.PURCHASED) {
    return { ok: false, status: 400, message: "purchase not active" };
  }
  if (
    verified.expiryTimeMillis > 0 &&
    verified.expiryTimeMillis <= Date.now()
  ) {
    return { ok: false, status: 400, message: "subscription expired" };
  }

  // The claim is keyed on the purchase token (stable, unique, and what
  // RTDN carries) so cancellation lookups work across the webhook.
  const claim = await store.claim(userId, purchaseToken);
  if (claim.status === "already_claimed") {
    // Idempotent replay — make sure the subscription row is active and ack.
    await verifier.acknowledgeSubscription({
      packageName,
      subscriptionId: productId,
      purchaseToken,
    });
    return { ok: true, status: 200, plan: FOUNDING_TERMS.planStorage };
  }
  if (claim.status === "full") {
    await trackEvent(userId, "founding_subscription_failed", {
      reason: "offer_full",
      claimed: claim.claimed,
      cap: claim.cap,
    });
    return { ok: false, status: 409, message: "founding offer is full" };
  }

  // Persist the subscription row (upsert by userId).
  const db = getDb();
  await db
    .insert(schema.subscriptions)
    .values({
      userId,
      playPackageName: packageName,
      playSubscriptionId: verified.orderId || productId,
      playPurchaseToken: purchaseToken,
      playOrderId: verified.orderId || null,
      status: "active",
      plan: FOUNDING_TERMS.planStorage,
      currentPeriodEnd: verified.expiryTimeMillis
        ? new Date(verified.expiryTimeMillis)
        : null,
    })
    .onConflictDoUpdate({
      target: schema.subscriptions.userId,
      set: {
        playPackageName: packageName,
        playSubscriptionId: verified.orderId || productId,
        playPurchaseToken: purchaseToken,
        playOrderId: verified.orderId || null,
        status: "active",
        plan: FOUNDING_TERMS.planStorage,
        currentPeriodEnd: verified.expiryTimeMillis
          ? new Date(verified.expiryTimeMillis)
          : null,
        updatedAt: new Date(),
      },
    });

  // Ack after state is persisted (subscriptions must be acknowledged
  // within 3 days of purchase; failures are non-fatal).
  await verifier.acknowledgeSubscription({
    packageName,
    subscriptionId: productId,
    purchaseToken,
  });

  await trackEvent(userId, "founding_membership_claimed", {
    channel: "play",
    claimed: claim.claimed,
    cap: claim.cap,
  });
  await trackEvent(userId, "subscription_started", {
    plan: FOUNDING_TERMS.planStorage,
    channel: "play",
  });

  return { ok: true, status: 200, plan: FOUNDING_TERMS.planStorage };
}

// ── RTDN (Real-time Developer Notifications) ─────────────────────────

export interface PubSubPushBody {
  message?: {
    data?: string; // base64-encoded JSON
    messageId?: string;
    publishTime?: string;
  };
  subscription?: string;
}

interface SubscriptionNotification {
  version: string;
  notificationType: number;
  purchaseToken: string;
  subscriptionId: string;
}

interface VoidedPurchaseNotification {
  purchaseToken: string;
  productId: string;
  orderId: string;
  refundType?: number;
}

/** Optional shared-secret auth for the RTDN endpoint. When
 *  PLAY_RTDN_AUTH_TOKEN is set, Pub/Sub push must carry it in the
 *  Authorization header (configure the push subscription's OIDC/basic
 *  token accordingly). When unset, the endpoint is open by design for
 *  local dev — document this before production. */
export function rtdnAuthorized(req: { headers: Headers }): boolean {
  const expected = process.env.PLAY_RTDN_AUTH_TOKEN;
  if (!expected) return true;
  return req.headers.get("authorization") === `Bearer ${expected}`;
}

/**
 * Entry point for POST /api/webhooks/play. Pub/Sub delivers a base64
 * payload; we act on subscription + voided notifications. Because the
 * payload carries no userId, only tokens this backend already attributed
 * are updated — unknown tokens are acknowledged and reconciled on the
 * next in-app verify.
 */
export async function handlePlayRtdn(
  body: PubSubPushBody,
  deps: PlayFulfillmentDeps = {},
): Promise<WebhookResult> {
  const store = deps.store ?? postgresFoundingStore;
  const raw = body?.message?.data;
  if (!raw) return { ok: false, status: 400, message: "missing message data" };

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(Buffer.from(raw, "base64").toString("utf8")) as Record<
      string,
      unknown
    >;
  } catch {
    return { ok: false, status: 400, message: "invalid message data" };
  }

  const sub = payload.subscriptionNotification as
    | SubscriptionNotification
    | undefined;
  if (sub && sub.purchaseToken) {
    await handleSubscriptionNotification(sub, store);
    return { ok: true, status: 200 };
  }

  const voided = payload.voidedPurchaseNotification as
    | VoidedPurchaseNotification
    | undefined;
  if (voided && voided.purchaseToken) {
    await markPlayCanceled(voided.purchaseToken, "refunded", store);
    return { ok: true, status: 200 };
  }

  // one_time_product_notification / test messages etc. — acknowledge.
  return { ok: true, status: 200 };
}

async function handleSubscriptionNotification(
  notif: SubscriptionNotification,
  store: FoundingStore,
): Promise<void> {
  const type = notif.notificationType;
  const token = notif.purchaseToken;

  switch (type) {
    case RTDN_TYPE.SUBSCRIPTION_CANCELED:
    case RTDN_TYPE.SUBSCRIPTION_CANCEL_SCHEDULED:
      // Cancel-at-period-end: entitlement continues until expiry.
      await markCancelAtPeriodEnd(token, store);
      break;
    case RTDN_TYPE.SUBSCRIPTION_REVOKED:
    case RTDN_TYPE.SUBSCRIPTION_EXPIRED:
      await markPlayCanceled(token, "expired", store);
      break;
    case RTDN_TYPE.SUBSCRIPTION_PURCHASED:
    case RTDN_TYPE.SUBSCRIPTION_RENEWED:
    case RTDN_TYPE.SUBSCRIPTION_RESTARTED:
    case RTDN_TYPE.SUBSCRIPTION_RECOVERED:
    case RTDN_TYPE.SUBSCRIPTION_GRACE_PERIOD:
    case RTDN_TYPE.SUBSCRIPTION_RESTORED:
      // Entitlement-affirming events. The authoritative claim happens on
      // the in-app verify (which carries the userId); here we only
      // re-activate a row we already attributed, so a renewal or a
      // restore mid-period never looks canceled.
      await reactivateKnownSubscription(token);
      break;
    default:
      // Unknown / future notification types — acknowledge and ignore.
      break;
  }
}

/** Cancel-at-period-end: keep active, set cancelAtPeriodEnd. */
async function markCancelAtPeriodEnd(
  purchaseToken: string,
  store: FoundingStore,
): Promise<void> {
  const db = getDb();
  const sub = await db.query.subscriptions.findFirst({
    where: eq(schema.subscriptions.playPurchaseToken, purchaseToken),
  });
  if (!sub) return; // Unknown token — reconciled on next in-app verify.
  await db
    .update(schema.subscriptions)
    .set({ cancelAtPeriodEnd: true, updatedAt: new Date() })
    .where(eq(schema.subscriptions.id, sub.id));
  await store.markCanceled(purchaseToken);
  await trackEvent(sub.userId, "subscription_cancelled", {
    channel: "play",
  });
}

/** Hard cancellation/expiry: entitlement ends. Slot stays consumed. */
async function markPlayCanceled(
  purchaseToken: string,
  reason: "expired" | "refunded",
  store: FoundingStore,
): Promise<void> {
  const db = getDb();
  const sub = await db.query.subscriptions.findFirst({
    where: eq(schema.subscriptions.playPurchaseToken, purchaseToken),
  });
  if (!sub) return;
  await db
    .update(schema.subscriptions)
    .set({ status: "canceled", updatedAt: new Date() })
    .where(eq(schema.subscriptions.id, sub.id));
  await store.markCanceled(purchaseToken);
  await trackEvent(sub.userId, "subscription_cancelled", {
    channel: "play",
    reason,
  });
}

/** Renewal / restore / grace: ensure the row is active again. */
async function reactivateKnownSubscription(
  purchaseToken: string,
): Promise<void> {
  const db = getDb();
  const sub = await db.query.subscriptions.findFirst({
    where: eq(schema.subscriptions.playPurchaseToken, purchaseToken),
  });
  if (!sub) return;
  await db
    .update(schema.subscriptions)
    .set({ status: "active", cancelAtPeriodEnd: false, updatedAt: new Date() })
    .where(eq(schema.subscriptions.id, sub.id));
  await trackEvent(sub.userId, "subscription_renewed", {
    channel: "play",
  });
}

/** Debug/test helper: deterministic order id for synthetic purchases. */
export function syntheticOrderId(): string {
  return `GPA.${randomUUID().replaceAll("-", "").slice(0, 16)}`;
}

export { foundingOfferOpenFor };
