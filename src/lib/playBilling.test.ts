import { generateKeyPairSync } from "node:crypto";

import { beforeEach, describe, expect, it, vi } from "vitest";

// DB + analytics are not exercised as SQL — the founding store is
// injected and analytics is best-effort, mirroring founding.test.ts.
const dbMock = {
  insert: vi.fn(() => ({
    values: vi.fn(() => ({
      onConflictDoUpdate: vi.fn(() => Promise.resolve({})),
    })),
  })),
  update: vi.fn(() => ({
    set: vi.fn(() => ({
      where: vi.fn(() => Promise.resolve({})),
    })),
  })),
  query: {
    subscriptions: { findFirst: vi.fn() },
  },
};

vi.mock("@/db", () => ({
  getDb: () => dbMock,
  schema: {
    subscriptions: {
      id: "id",
      userId: "user_id",
      playPackageName: "play_package_name",
      playSubscriptionId: "play_subscription_id",
      playPurchaseToken: "play_purchase_token",
      playOrderId: "play_order_id",
      status: "status",
      plan: "plan",
      currentPeriodEnd: "current_period_end",
      updatedAt: "updated_at",
    },
  },
}));

vi.mock("@/lib/analytics", () => ({
  trackEvent: vi.fn(),
}));

import {
  fulfillPlayFoundingPurchase,
  GooglePlayVerifier,
  handlePlayRtdn,
  PlayBillingNotConfigured,
  PlayVerificationError,
  PLAY_PURCHASE_STATE,
  rtdnAuthorized,
  RTDN_TYPE,
  type PlaySubscriptionPurchase,
  type PlayVerifier,
  type PlayVerifyInput,
} from "@/lib/playBilling";
import { FOUNDING_TERMS, inMemoryFoundingStore } from "@/lib/founding";
import { trackEvent } from "@/lib/analytics";

const encode = (obj: unknown) =>
  Buffer.from(JSON.stringify(obj)).toString("base64");
const pushBody = (data: string) => ({
  message: { data, messageId: "msg-1", publishTime: "2026-01-01T00:00:00Z" },
});

/** Real throwaway RSA key so JWT signing works without network/keys. */
const testPrivateKey = generateKeyPairSync("rsa", {
  modulusLength: 2048,
}).privateKey.export({ type: "pkcs1", format: "pem" }) as string;
const testServiceAccount = JSON.stringify({
  client_email: "svc@example.iam.gserviceaccount.com",
  private_key: testPrivateKey,
});

type VerifyMock = ReturnType<
  typeof vi.fn<(input: PlayVerifyInput) => Promise<PlaySubscriptionPurchase>>
>;
type AckMock = ReturnType<
  typeof vi.fn<(input: PlayVerifyInput) => Promise<void>>
>;

interface FakeVerifier extends PlayVerifier {
  acknowledgeSubscription: AckMock;
  verifySubscription: VerifyMock;
}

/** Verifier that returns a purchased, unexpired founding subscription. */
function fakeVerifier(
  purchase: Partial<PlaySubscriptionPurchase> = {},
): FakeVerifier {
  return {
    acknowledgeSubscription: vi.fn(() => Promise.resolve()),
    verifySubscription: vi.fn(async (input) => ({
      productId: FOUNDING_TERMS.playProductId,
      packageName: FOUNDING_TERMS.playPackageName,
      orderId: "GPA.1234-5678",
      purchaseToken: input.purchaseToken,
      purchaseState: PLAY_PURCHASE_STATE.PURCHASED,
      expiryTimeMillis: Date.now() + 30 * 24 * 3600 * 1000,
      autoRenewing: true,
      ...purchase,
    })),
  };
}

beforeEach(() => {
  vi.clearAllMocks();
  dbMock.query.subscriptions.findFirst.mockReset();
  dbMock.query.subscriptions.findFirst.mockResolvedValue(undefined);
});

describe("fulfillPlayFoundingPurchase", () => {
  const base = {
    userId: "user_a",
    packageName: FOUNDING_TERMS.playPackageName,
    productId: FOUNDING_TERMS.playProductId,
    purchaseToken: "tok_founding",
  };

  it("fulfills a verified purchase through the atomic claim", async () => {
    const store = inMemoryFoundingStore(35);
    const verifier = fakeVerifier();
    const result = await fulfillPlayFoundingPurchase(base, { verifier, store });

    expect(result).toMatchObject({ ok: true, status: 200, plan: "founding_member" });
    expect((await store.getStatus()).claimed).toBe(1);
    // Subscription row persisted + purchase acknowledged.
    expect(dbMock.insert).toHaveBeenCalled();
    expect(verifier.acknowledgeSubscription).toHaveBeenCalled();
    expect(trackEvent).toHaveBeenCalledWith(
      "user_a",
      "founding_membership_claimed",
      expect.objectContaining({ channel: "play" }),
    );
  });

  it("is idempotent on replay — never double-claims", async () => {
    const store = inMemoryFoundingStore(35);
    const verifier = fakeVerifier();
    const first = await fulfillPlayFoundingPurchase(base, { verifier, store });
    const second = await fulfillPlayFoundingPurchase(base, { verifier, store });

    expect(first.ok).toBe(true);
    expect(second).toMatchObject({ ok: true, status: 200 });
    expect((await store.getStatus()).claimed).toBe(1);
  });

  it("refuses once the offer is full", async () => {
    const store = inMemoryFoundingStore(1);
    await store.claim("user_other", "tok_other");
    const result = await fulfillPlayFoundingPurchase(base, {
      verifier: fakeVerifier(),
      store,
    });

    expect(result).toMatchObject({ ok: false, status: 409 });
    expect(trackEvent).toHaveBeenCalledWith(
      "user_a",
      "founding_subscription_failed",
      expect.objectContaining({ reason: "offer_full" }),
    );
  });

  it("rejects an unknown product id", async () => {
    const result = await fulfillPlayFoundingPurchase(
      { ...base, productId: "premium_monthly" },
      { verifier: fakeVerifier(), store: inMemoryFoundingStore(35) },
    );
    expect(result).toMatchObject({ ok: false, status: 400, message: "unknown product" });
  });

  it("rejects a mismatched package", async () => {
    const result = await fulfillPlayFoundingPurchase(
      { ...base, packageName: "com.other.app" },
      { verifier: fakeVerifier(), store: inMemoryFoundingStore(35) },
    );
    expect(result).toMatchObject({ ok: false, status: 400, message: "unknown package" });
  });

  it("rejects a purchase not in the purchased state", async () => {
    const verifier = fakeVerifier({
      purchaseState: PLAY_PURCHASE_STATE.PENDING,
    });
    const result = await fulfillPlayFoundingPurchase(base, {
      verifier,
      store: inMemoryFoundingStore(35),
    });
    expect(result).toMatchObject({ ok: false, status: 400 });
  });

  it("rejects an expired subscription", async () => {
    const verifier = fakeVerifier({
      expiryTimeMillis: Date.now() - 1000,
    });
    const result = await fulfillPlayFoundingPurchase(base, {
      verifier,
      store: inMemoryFoundingStore(35),
    });
    expect(result).toMatchObject({ ok: false, status: 400, message: "subscription expired" });
  });

  it("returns 503 when Play billing is not configured", async () => {
    const verifier: PlayVerifier = {
      verifySubscription: vi.fn(async () => {
        throw new PlayBillingNotConfigured("not configured");
      }),
      acknowledgeSubscription: vi.fn(() => Promise.resolve()),
    };
    const result = await fulfillPlayFoundingPurchase(base, {
      verifier,
      store: inMemoryFoundingStore(35),
    });
    expect(result).toMatchObject({ ok: false, status: 503 });
  });

  it("returns 400 when verification fails", async () => {
    const verifier: PlayVerifier = {
      verifySubscription: vi.fn(async () => {
        throw new PlayVerificationError("token invalid");
      }),
      acknowledgeSubscription: vi.fn(() => Promise.resolve()),
    };
    const result = await fulfillPlayFoundingPurchase(base, {
      verifier,
      store: inMemoryFoundingStore(35),
    });
    expect(result).toMatchObject({ ok: false, status: 400 });
    expect(trackEvent).toHaveBeenCalledWith(
      "user_a",
      "founding_subscription_failed",
      expect.objectContaining({ reason: "play_verification_failed" }),
    );
  });
});

describe("GooglePlayVerifier", () => {
  it("verifies a subscription against the Play Developer API", async () => {
    const fetchImpl = vi.fn(async (input: string | URL | Request) => {
      const url = String(input);
      if (url.includes("oauth2.googleapis.com/token")) {
        return new Response(
          JSON.stringify({ access_token: "ya.test-token", expires_in: 3600 }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }
      return new Response(
        JSON.stringify({
          productId: FOUNDING_TERMS.playProductId,
          orderId: "GPA.99",
          purchaseState: 0,
          expiryTimeMillis: String(Date.now() + 86400_000),
          autoRenewing: true,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    });
    process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = testServiceAccount;
    try {
      const verifier = new GooglePlayVerifier(fetchImpl);
      const purchase = await verifier.verifySubscription({
        packageName: FOUNDING_TERMS.playPackageName,
        subscriptionId: FOUNDING_TERMS.playProductId,
        purchaseToken: "tok",
      });
      expect(purchase.purchaseState).toBe(PLAY_PURCHASE_STATE.PURCHASED);
      expect(purchase.productId).toBe(FOUNDING_TERMS.playProductId);
      // Two calls: token exchange, then the purchase lookup.
      expect(fetchImpl).toHaveBeenCalledTimes(2);
      const tokenUrl = fetchImpl.mock.calls[0]![0];
      expect(String(tokenUrl)).toContain("oauth2.googleapis.com/token");
      const lookupUrl = fetchImpl.mock.calls[1]![0];
      expect(String(lookupUrl)).toContain("androidpublisher.googleapis.com");
    } finally {
      delete process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;
    }
  });

  it("throws when the API returns an error", async () => {
    const fetchImpl = vi.fn(async () => new Response("{}", { status: 404 }));
    process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = testServiceAccount;
    try {
      const verifier = new GooglePlayVerifier(fetchImpl);
      await expect(
        verifier.verifySubscription({
          packageName: FOUNDING_TERMS.playPackageName,
          subscriptionId: FOUNDING_TERMS.playProductId,
          purchaseToken: "tok",
        }),
      ).rejects.toBeInstanceOf(PlayVerificationError);
    } finally {
      delete process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;
    }
  });

  it("throws when no service account is configured", async () => {
    delete process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;
    const verifier = new GooglePlayVerifier(vi.fn());
    await expect(
      verifier.verifySubscription({
        packageName: FOUNDING_TERMS.playPackageName,
        subscriptionId: FOUNDING_TERMS.playProductId,
        purchaseToken: "tok",
      }),
    ).rejects.toBeInstanceOf(PlayBillingNotConfigured);
  });
});

/** Args passed to the latest db.update().set(...) call (if any). */
function lastSetArgs(): Record<string, unknown> {
  const updateResult = dbMock.update.mock.results.at(-1)!.value as {
    set: (v: object) => unknown;
  };
  return (updateResult.set as ReturnType<typeof vi.fn>).mock
    .calls[0]![0] as Record<string, unknown>;
}

describe("handlePlayRtdn", () => {
  const store = inMemoryFoundingStore(35);
  const subRow = {
    id: "sub_1",
    userId: "user_a",
    status: "active",
    cancelAtPeriodEnd: false,
    playPurchaseToken: "tok_founding",
  };

  beforeEach(() => {
    dbMock.query.subscriptions.findFirst.mockResolvedValue(subRow as never);
  });

  it("marks cancel-at-period-end on SUBSCRIPTION_CANCELED", async () => {
    const result = await handlePlayRtdn(
      pushBody(
        encode({
          subscriptionNotification: {
            version: "1.0",
            notificationType: RTDN_TYPE.SUBSCRIPTION_CANCELED,
            purchaseToken: "tok_founding",
            subscriptionId: FOUNDING_TERMS.playProductId,
          },
        }),
      ),
      { store },
    );
    expect(result).toMatchObject({ ok: true, status: 200 });
    expect(lastSetArgs().cancelAtPeriodEnd).toBe(true);
    expect(trackEvent).toHaveBeenCalledWith("user_a", "subscription_cancelled", {
      channel: "play",
    });
  });

  it("ends entitlement on SUBSCRIPTION_EXPIRED / REVOKED", async () => {
    const result = await handlePlayRtdn(
      pushBody(
        encode({
          subscriptionNotification: {
            version: "1.0",
            notificationType: RTDN_TYPE.SUBSCRIPTION_EXPIRED,
            purchaseToken: "tok_founding",
            subscriptionId: FOUNDING_TERMS.playProductId,
          },
        }),
      ),
      { store },
    );
    expect(result.ok).toBe(true);
    expect(lastSetArgs().status).toBe("canceled");
  });

  it("reactivates on renewal / restore", async () => {
    const result = await handlePlayRtdn(
      pushBody(
        encode({
          subscriptionNotification: {
            version: "1.0",
            notificationType: RTDN_TYPE.SUBSCRIPTION_RESTORED,
            purchaseToken: "tok_founding",
            subscriptionId: FOUNDING_TERMS.playProductId,
          },
        }),
      ),
      { store },
    );
    expect(result.ok).toBe(true);
    expect(lastSetArgs().status).toBe("active");
    expect(lastSetArgs().cancelAtPeriodEnd).toBe(false);
    expect(trackEvent).toHaveBeenCalledWith("user_a", "subscription_renewed", {
      channel: "play",
    });
  });

  it("handles voided purchases as refunds", async () => {
    const result = await handlePlayRtdn(
      pushBody(
        encode({
          voidedPurchaseNotification: {
            purchaseToken: "tok_founding",
            productId: FOUNDING_TERMS.playProductId,
            orderId: "GPA.1",
          },
        }),
      ),
      { store },
    );
    expect(result.ok).toBe(true);
    expect(lastSetArgs().status).toBe("canceled");
  });

  it("acknowledges unknown tokens without error", async () => {
    dbMock.query.subscriptions.findFirst.mockResolvedValue(undefined);
    const result = await handlePlayRtdn(
      pushBody(
        encode({
          subscriptionNotification: {
            version: "1.0",
            notificationType: RTDN_TYPE.SUBSCRIPTION_RENEWED,
            purchaseToken: "tok_unattributed",
            subscriptionId: FOUNDING_TERMS.playProductId,
          },
        }),
      ),
      { store },
    );
    expect(result).toMatchObject({ ok: true, status: 200 });
    expect(dbMock.update).not.toHaveBeenCalled();
  });

  it("rejects missing or invalid data", async () => {
    expect(await handlePlayRtdn({}, { store })).toMatchObject({
      ok: false,
      status: 400,
    });
    expect(
      await handlePlayRtdn({ message: { data: "!!not-base64-json!!" } }, { store }),
    ).toMatchObject({ ok: false, status: 400 });
  });

  it("ignores non-subscription payloads (test messages etc.)", async () => {
    const result = await handlePlayRtdn(
      pushBody(encode({ test: { message: "ok" } })),
      { store },
    );
    expect(result).toMatchObject({ ok: true, status: 200 });
  });
});

describe("rtdnAuthorized", () => {
  it("is open when no token is configured", () => {
    delete process.env.PLAY_RTDN_AUTH_TOKEN;
    expect(rtdnAuthorized({ headers: new Headers() })).toBe(true);
  });

  it("enforces the shared secret when configured", () => {
    process.env.PLAY_RTDN_AUTH_TOKEN = "secret123";
    try {
      const ok = new Headers({ Authorization: "Bearer secret123" });
      const bad = new Headers({ Authorization: "Bearer nope" });
      expect(rtdnAuthorized({ headers: ok })).toBe(true);
      expect(rtdnAuthorized({ headers: bad })).toBe(false);
    } finally {
      delete process.env.PLAY_RTDN_AUTH_TOKEN;
    }
  });
});
