import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("next/headers", () => ({
  headers: () => new Headers(),
}));

vi.mock("@/db", () => ({ getDb: () => ({}), schema: {} }));

vi.mock("@/lib/auth", () => ({
  auth: { api: { getSession: vi.fn() } },
}));

// Keep the real error classes (instanceof checks in the route) but stub
// the list call — its DB wiring is covered by the lib's own tests.
vi.mock("@/lib/ai/sources", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/ai/sources")>();
  return { ...actual, listSources: vi.fn() };
});

import { GET } from "@/app/api/notebooks/[id]/sources/route";
import { auth } from "@/lib/auth";
import { listSources } from "@/lib/ai/sources";

const session = { user: { id: "user_1", name: "Test", email: "t@example.com" } };

function makeRequest() {
  return new Request("http://localhost/api/notebooks/nb-1/sources");
}

beforeEach(() => {
  vi.clearAllMocks();
});

describe("GET /api/notebooks/[id]/sources", () => {
  it("returns 401 without a session", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(null);
    const res = await GET(makeRequest(), { params: Promise.resolve({ id: "nb-1" }) });
    expect(res.status).toBe(401);
    expect(listSources).not.toHaveBeenCalled();
  });

  it("lists the user's sources with a client-friendly shape", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(session as never);
    const now = new Date("2026-08-01T00:00:00Z");
    vi.mocked(listSources).mockResolvedValue([
      {
        id: "src-1",
        title: "Lecture 1",
        sourceType: "pasted",
        status: "ready",
        wordCount: 240,
        pageCount: null,
        meta: { sizeBytes: 12_345 },
        createdAt: now,
        updatedAt: now,
      },
    ] as never);

    const res = await GET(makeRequest(), { params: Promise.resolve({ id: "nb-1" }) });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.sources).toEqual([
      {
        id: "src-1",
        title: "Lecture 1",
        kind: "pasted",
        status: "ready",
        wordCount: 240,
        pageCount: null,
        sizeBytes: 12345,
        createdAt: "2026-08-01T00:00:00.000Z",
        updatedAt: "2026-08-01T00:00:00.000Z",
      },
    ]);
  });
});
