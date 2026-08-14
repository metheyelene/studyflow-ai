import { beforeEach, describe, expect, it, vi } from "vitest";

// ── module mocks ────────────────────────────────────────────────────
vi.mock("next/headers", () => ({
  headers: () => new Headers(),
}));

vi.mock("@/lib/auth", () => ({
  auth: { api: { getSession: vi.fn() } },
}));

vi.mock("@/lib/analytics", () => ({ trackEvent: vi.fn() }));

vi.mock("@/lib/playBilling", () => ({
  fulfillPlayFoundingPurchase: vi.fn(),
  handlePlayRtdn: vi.fn(),
  rtdnAuthorized: vi.fn(() => true),
}));

const dbMock = {
  query: {
    foundingMemberCounter: {
      findFirst: vi.fn(),
    },
    foundingMembers: {
      findMany: vi.fn(),
    },
  },
};

vi.mock("@/db", () => ({
  getDb: () => dbMock,
  schema: {
    subscriptions: {
      userId: "user_id",
      status: "status",
      plan: "plan",
      currentPeriodEnd: "current_period_end",
      updatedAt: "updated_at",
    },
    foundingMembers: { userId: "user_id", subscriptionId: "subscription_id" },
    foundingMemberCounter: { id: "id" },
  },
}));

// ── imports (after mocks) ───────────────────────────────────────────
import { NextRequest } from "next/server";

import { GET as foundingStatusGET } from "@/app/api/billing/founding-status/route";
import { POST as verifyPOST } from "@/app/api/billing/play/verify/route";
import { POST as webhookPOST } from "@/app/api/webhooks/play/route";
import { auth } from "@/lib/auth";
import {
  fulfillPlayFoundingPurchase,
  handlePlayRtdn,
  rtdnAuthorized,
} from "@/lib/playBilling";
import { FOUNDING_TERMS } from "@/lib/founding-constants";

const session = { user: { id: "user_a", email: "a@example.com" } };

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(auth.api.getSession).mockResolvedValue(session as never);
  // RTDN auth defaults to open; individual tests override it.
  vi.mocked(rtdnAuthorized).mockImplementation(() => true);
  dbMock.query.foundingMemberCounter.findFirst.mockReset();
  dbMock.query.foundingMembers.findMany.mockReset();
  dbMock.query.foundingMemberCounter.findFirst.mockResolvedValue({
    claimed: 0,
    cap: 35,
  });
  dbMock.query.foundingMembers.findMany.mockResolvedValue([]);
});

const jsonReq = (body: unknown) =>
  new NextRequest("http://localhost/api", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

describe("POST /api/billing/play/verify", () => {
  it("returns 401 without a session", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(null);
    const res = await verifyPOST(jsonReq({ purchaseToken: "t" }));
    expect(res.status).toBe(401);
  });

  it("returns 400 when fields are missing", async () => {
    const res = await verifyPOST(jsonReq({ purchaseToken: "t" }));
    expect(res.status).toBe(400);
    expect(fulfillPlayFoundingPurchase).not.toHaveBeenCalled();
  });

  it("verifies a purchase and returns the granted plan", async () => {
    vi.mocked(fulfillPlayFoundingPurchase).mockResolvedValue({
      ok: true,
      status: 200,
      plan: FOUNDING_TERMS.planStorage,
    });
    const res = await verifyPOST(
      jsonReq({
        packageName: FOUNDING_TERMS.playPackageName,
        productId: FOUNDING_TERMS.playProductId,
        purchaseToken: "tok_1",
      }),
    );
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body).toEqual({ ok: true, plan: "founding_member" });
    expect(fulfillPlayFoundingPurchase).toHaveBeenCalledWith({
      userId: "user_a",
      packageName: FOUNDING_TERMS.playPackageName,
      productId: FOUNDING_TERMS.playProductId,
      purchaseToken: "tok_1",
    });
  });

  it("maps a refusal (offer full) to 409", async () => {
    vi.mocked(fulfillPlayFoundingPurchase).mockResolvedValue({
      ok: false,
      status: 409,
      message: "founding offer is full",
    });
    const res = await verifyPOST(
      jsonReq({
        packageName: FOUNDING_TERMS.playPackageName,
        productId: FOUNDING_TERMS.playProductId,
        purchaseToken: "tok_1",
      }),
    );
    expect(res.status).toBe(409);
  });
});

describe("POST /api/webhooks/play", () => {
  it("returns 401 when RTDN auth fails", async () => {
    vi.mocked(rtdnAuthorized).mockReturnValue(false);
    const res = await webhookPOST(jsonReq({ message: { data: "x" } }));
    expect(res.status).toBe(401);
    expect(handlePlayRtdn).not.toHaveBeenCalled();
  });

  it("returns 400 on an invalid body", async () => {
    const res = await webhookPOST(
      new NextRequest("http://localhost/api", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "{not-json",
      }),
    );
    expect(res.status).toBe(400);
  });

  it("acknowledges handled notifications", async () => {
    vi.mocked(handlePlayRtdn).mockResolvedValue({ ok: true, status: 200 });
    const res = await webhookPOST(jsonReq({ message: { data: "e30=" } }));
    expect(res.status).toBe(200);
    expect(handlePlayRtdn).toHaveBeenCalled();
  });
});

describe("GET /api/billing/founding-status", () => {
  it("returns 401 without a session", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(null);
    const res = await foundingStatusGET();
    expect(res.status).toBe(401);
  });

  it("reports an open offer with the backend-derived count", async () => {
    const res = await foundingStatusGET();
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.offer.active).toBe(true);
    expect(body.offer.remaining).toBe(35);
    expect(body.status).toMatchObject({ claimed: 0, cap: 35, available: true });
  });

  it("closes the offer once the cap is reached", async () => {
    dbMock.query.foundingMemberCounter.findFirst.mockResolvedValue({
      claimed: 35,
      cap: 35,
    });
    const res = await foundingStatusGET();
    const body = await res.json();
    expect(body.offer.active).toBe(false);
    expect(body.offer.remaining).toBe(0);
  });
});
