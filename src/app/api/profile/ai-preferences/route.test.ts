import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("next/headers", () => ({
  headers: () => new Headers(),
}));

vi.mock("@/db", () => ({ getDb: () => ({}), schema: {} }));

vi.mock("@/lib/auth", () => ({
  auth: { api: { getSession: vi.fn() } },
}));

// Keep the real zod schema + types; stub only the DB-backed loader/saver.
vi.mock("@/lib/ai/preferences", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/ai/preferences")>();
  return { ...actual, loadAiPreferences: vi.fn(), saveAiPreferences: vi.fn() };
});

import { GET, PUT } from "@/app/api/profile/ai-preferences/route";
import { loadAiPreferences, saveAiPreferences } from "@/lib/ai/preferences";
import { auth } from "@/lib/auth";

const session = { user: { id: "user_1", name: "Test", email: "t@example.com" } };

const defaults = {
  responseStyle: "balanced",
  studyLevel: "university",
  language: "English",
} as const;

function putRequest(body: unknown) {
  return new Request("http://localhost/api/profile/ai-preferences", {
    method: "PUT",
    body: JSON.stringify(body),
    headers: { "Content-Type": "application/json" },
  });
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(loadAiPreferences).mockResolvedValue({ ...defaults });
  vi.mocked(saveAiPreferences).mockResolvedValue(undefined);
});

describe("GET /api/profile/ai-preferences", () => {
  it("401 when unauthenticated", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(null);
    expect((await GET()).status).toBe(401);
  });

  it("returns the user's AI preferences", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(session as never);
    vi.mocked(loadAiPreferences).mockResolvedValue({
      responseStyle: "detailed",
      studyLevel: "professional",
      language: "Spanish",
    });
    const res = await GET();
    expect(res.status).toBe(200);
    const body = (await res.json()) as { preferences: unknown };
    expect(body.preferences).toEqual({
      responseStyle: "detailed",
      studyLevel: "professional",
      language: "Spanish",
    });
  });
});

describe("PUT /api/profile/ai-preferences", () => {
  it("401 when unauthenticated", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(null);
    const res = await PUT(putRequest({ ...defaults }));
    expect(res.status).toBe(401);
  });

  it("validates and saves the preferences", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(session as never);
    const res = await PUT(
      putRequest({
        responseStyle: "concise",
        studyLevel: "professional",
        language: "Spanish",
      }),
    );
    expect(res.status).toBe(200);
    expect(saveAiPreferences).toHaveBeenCalledWith("user_1", {
      responseStyle: "concise",
      studyLevel: "professional",
      language: "Spanish",
    });
  });

  it("rejects invalid values without saving", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(session as never);
    const res = await PUT(
      putRequest({
        responseStyle: "neon",
        studyLevel: "university",
        language: "English",
      }),
    );
    expect(res.status).toBe(400);
    expect(saveAiPreferences).not.toHaveBeenCalled();
  });

  it("rejects an empty language", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValue(session as never);
    const res = await PUT(
      putRequest({
        responseStyle: "balanced",
        studyLevel: "university",
        language: "   ",
      }),
    );
    expect(res.status).toBe(400);
    expect(saveAiPreferences).not.toHaveBeenCalled();
  });
});
