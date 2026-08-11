import { beforeEach, describe, expect, it, vi } from "vitest";

const dbMock = { execute: vi.fn() };

vi.mock("@/db", () => ({
  getDb: () => dbMock,
}));

vi.mock("@/lib/version", () => ({
  appVersion: () => "1.0.0",
}));

import { GET } from "@/app/api/health/route";

beforeEach(() => {
  vi.clearAllMocks();
});

describe("GET /api/health", () => {
  it("returns 200 with version + db status when the database answers", async () => {
    dbMock.execute.mockResolvedValue([[{ "?column?": 1 }]]);

    const res = await GET();
    expect(res.status).toBe(200);
    expect(res.headers.get("cache-control")).toBe("no-store");
    const body = await res.json();
    expect(body.status).toBe("ok");
    expect(body.version).toBe("1.0.0");
    expect(body.database).toBe("ok");
    expect(body.durationMs).toBeGreaterThanOrEqual(0);
  });

  it("returns 503 with database:down when the query fails", async () => {
    dbMock.execute.mockRejectedValue(new Error("connection refused"));

    const res = await GET();
    expect(res.status).toBe(503);
    const body = await res.json();
    expect(body.status).toBe("degraded");
    expect(body.database).toBe("down");
    expect(body.version).toBe("1.0.0");
  });

  it("returns 503 when the database check times out (hung pool)", async () => {
    // Never resolves — the route's withTimeout guard must answer "down"
    // within the 5s window instead of hanging the uptime monitor.
    dbMock.execute.mockImplementation(() => new Promise(() => {}));

    vi.useFakeTimers();
    try {
      const pending = GET();
      await vi.advanceTimersByTimeAsync(6000);
      const res = await pending;
      expect(res.status).toBe(503);
      const body = await res.json();
      expect(body.database).toBe("down");
    } finally {
      vi.useRealTimers();
    }
  });
});
