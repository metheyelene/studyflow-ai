import { beforeEach, describe, expect, it, vi } from "vitest";

// ── module mocks ────────────────────────────────────────────────────
vi.mock("next/headers", () => ({
  headers: () => new Headers(),
}));

vi.mock("@/db", () => ({
  getDb: () => dbMock,
  schema: {
    profiles: { userId: "user_id" },
    subjects: { userId: "user_id" },
    exams: { userId: "user_id" },
    usage: { userId: "user_id", feature: "feature", period: "period" },
  },
}));

const dbMock = {
  query: {
    profiles: { findFirst: vi.fn() },
    subjects: { findMany: vi.fn() },
    exams: { findMany: vi.fn() },
    usage: { findFirst: vi.fn() },
  },
};

vi.mock("@/lib/auth", () => ({
  auth: {
    api: {
      getSession: vi.fn(),
      updateUser: vi.fn(),
    },
  },
}));

vi.mock("@/lib/analytics", () => ({ trackEvent: vi.fn() }));

vi.mock("@/lib/onboarding", () => ({ completeOnboarding: vi.fn() }));

vi.mock("@/lib/profile", () => ({ updateProfile: vi.fn() }));

vi.mock("@/lib/premium", () => ({ getPlanForSession: vi.fn() }));

vi.mock("@/lib/usage", () => ({
  getAiUsage: vi.fn(),
  periodKey: () => "2026-08",
  percentUsed: (used: number, limit: number) => (limit <= 0 ? 100 : Math.min(100, Math.round((used / limit) * 100))),
  usageState: () => "ok",
}));

// ── imports (after mocks) ───────────────────────────────────────────
import { POST as analyticsPOST } from "@/app/api/analytics/route";
import { GET as onboardingGET, POST as onboardingPOST } from "@/app/api/onboarding/route";
import { GET as profileGET, PUT as profilePUT } from "@/app/api/profile/route";
import { GET as usageGET } from "@/app/api/usage/route";
import { trackEvent } from "@/lib/analytics";
import { auth } from "@/lib/auth";
import { completeOnboarding } from "@/lib/onboarding";
import { updateProfile } from "@/lib/profile";
import { getPlanForSession } from "@/lib/premium";
import { getAiUsage } from "@/lib/usage";

const session = { user: { id: "user_1", name: "Test", email: "t@example.com" } };

beforeEach(() => {
  vi.clearAllMocks();
  dbMock.query.profiles.findFirst.mockResolvedValue(undefined);
  dbMock.query.subjects.findMany.mockResolvedValue([]);
  dbMock.query.exams.findMany.mockResolvedValue([]);
});

function authed() {
  vi.mocked(auth.api.getSession).mockResolvedValue(session as never);
}

function loggedOut() {
  vi.mocked(auth.api.getSession).mockResolvedValue(null as never);
}

describe("POST /api/analytics", () => {
  it("rejects a missing eventName with 400", async () => {
    const res = await analyticsPOST(new Request("http://x/api/analytics", {
      method: "POST",
      body: JSON.stringify({}),
    }));
    expect(res.status).toBe(400);
    expect(trackEvent).not.toHaveBeenCalled();
  });

  it("records an event with the resolved user id (authed)", async () => {
    authed();
    const res = await analyticsPOST(new Request("http://x/api/analytics", {
      method: "POST",
      body: JSON.stringify({ eventName: "app_opened", properties: { tab: "home" } }),
    }));
    expect(res.status).toBe(202);
    expect(trackEvent).toHaveBeenCalledWith("user_1", "app_opened", { tab: "home" });
  });

  it("records pre-auth events with a null user id", async () => {
    loggedOut();
    const res = await analyticsPOST(new Request("http://x/api/analytics", {
      method: "POST",
      body: JSON.stringify({ eventName: "landing_viewed" }),
    }));
    expect(res.status).toBe(202);
    expect(trackEvent).toHaveBeenCalledWith(null, "landing_viewed", undefined);
  });
});

describe("POST /api/onboarding", () => {
  it("requires a session", async () => {
    loggedOut();
    const res = await onboardingPOST(new Request("http://x/api/onboarding", { method: "POST" }));
    expect(res.status).toBe(401);
  });

  it("returns 400 when validation fails (lib error)", async () => {
    authed();
    vi.mocked(completeOnboarding).mockResolvedValue({ error: "Please fill in every field." });
    const res = await onboardingPOST(new Request("http://x/api/onboarding", {
      method: "POST",
      body: JSON.stringify({}),
    }));
    expect(res.status).toBe(400);
    expect(await res.json()).toEqual({ error: "Please fill in every field." });
  });

  it("returns 200 ok on success", async () => {
    authed();
    vi.mocked(completeOnboarding).mockResolvedValue({ ok: true });
    const input = {
      course: "Physics",
      subjects: "Thermodynamics",
      exams: [],
      dailyMinutes: 45,
      goals: ["summaries"],
    };
    const res = await onboardingPOST(new Request("http://x/api/onboarding", {
      method: "POST",
      body: JSON.stringify(input),
    }));
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true });
    expect(completeOnboarding).toHaveBeenCalledWith("user_1", input);
  });
});

describe("GET /api/onboarding", () => {
  it("requires a session", async () => {
    loggedOut();
    const res = await onboardingGET();
    expect(res.status).toBe(401);
  });

  it("returns the current state with safe defaults when no profile exists", async () => {
    authed();
    const res = await onboardingGET();
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.onboardingCompleted).toBe(false);
    expect(body.profile).toMatchObject({
      course: null,
      dailyStudyMinutes: 30,
      timezone: null,
    });
    expect(body.subjects).toEqual([]);
    expect(body.exams).toEqual([]);
  });

  it("returns saved profile, subjects, and exams", async () => {
    authed();
    dbMock.query.profiles.findFirst.mockResolvedValue({
      course: "CS",
      educationLevel: "undergraduate",
      goal: "flashcards",
      dailyStudyMinutes: 90,
      timezone: "Asia/Kolkata",
      onboardingCompleted: true,
    });
    dbMock.query.subjects.findMany.mockResolvedValue([
      { id: "s1", name: "VLSI" },
      { id: "s2", name: "Algorithms" },
    ]);
    dbMock.query.exams.findMany.mockResolvedValue([
      { id: "e1", title: "Midterm", examDate: new Date("2026-09-15T00:00:00Z") },
    ]);

    const body = await (await onboardingGET()).json();
    expect(body.onboardingCompleted).toBe(true);
    expect(body.subjects.map((s: { name: string }) => s.name)).toEqual(["VLSI", "Algorithms"]);
    expect(body.exams[0]).toMatchObject({ id: "e1", title: "Midterm" });
    expect(body.exams[0].date).toBe("2026-09-15T00:00:00.000Z");
  });
});

describe("GET /api/profile", () => {
  it("requires a session", async () => {
    loggedOut();
    const res = await profileGET();
    expect(res.status).toBe(401);
  });

  it("returns user identity, plan, and profile", async () => {
    authed();
    vi.mocked(getPlanForSession).mockResolvedValue({
      userId: "user_1",
      plan: "premium",
      subscriptionPlan: "premium",
    });
    dbMock.query.profiles.findFirst.mockResolvedValue({
      course: "CS",
      educationLevel: "undergraduate",
      goal: "quizzes",
      dailyStudyMinutes: 60,
      timezone: null,
      onboardingCompleted: true,
      studyStreak: 3,
    });

    const body = await (await profileGET()).json();
    expect(body.user).toEqual({ id: "user_1", name: "Test", email: "t@example.com" });
    expect(body.plan).toBe("premium");
    expect(body.profile).toMatchObject({
      course: "CS",
      dailyStudyMinutes: 60,
      onboardingCompleted: true,
      studyStreak: 3,
    });
  });
});

describe("PUT /api/profile", () => {
  it("requires a session", async () => {
    loggedOut();
    const res = await profilePUT(new Request("http://x/api/profile", { method: "PUT" }));
    expect(res.status).toBe(401);
  });

  it("returns 400 when the profile update fails validation", async () => {
    authed();
    vi.mocked(updateProfile).mockResolvedValue({ error: "Your name can't be empty." });
    const res = await profilePUT(new Request("http://x/api/profile", {
      method: "PUT",
      body: JSON.stringify({ name: "" }),
    }));
    expect(res.status).toBe(400);
    expect(await res.json()).toEqual({ error: "Your name can't be empty." });
  });

  it("delegates to the shared updateProfile with user id and request headers", async () => {
    authed();
    vi.mocked(updateProfile).mockResolvedValue({ ok: true });
    const req = new Request("http://x/api/profile", {
      method: "PUT",
      body: JSON.stringify({ name: "New", dailyStudyMinutes: 75 }),
    });
    const res = await profilePUT(req);
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true });
    expect(updateProfile).toHaveBeenCalledWith("user_1", req.headers, {
      name: "New",
      dailyStudyMinutes: 75,
    });
  });
});

describe("GET /api/usage", () => {
  it("requires a session", async () => {
    vi.mocked(getPlanForSession).mockResolvedValue(null);
    const res = await usageGET();
    expect(res.status).toBe(401);
  });

  it("returns the plan and AI usage for the widget", async () => {
    vi.mocked(getPlanForSession).mockResolvedValue({
      userId: "user_1",
      plan: "free",
      subscriptionPlan: null,
    });
    vi.mocked(getAiUsage).mockResolvedValue({
      used: 3,
      limit: 20,
      remaining: 17,
      percent: 15,
      state: "ok",
      resetsAt: "2026-09-01T00:00:00.000Z",
    });

    const body = await (await usageGET()).json();
    expect(body.plan).toBe("free");
    expect(body.usage).toMatchObject({ used: 3, limit: 20, remaining: 17, state: "ok" });
    expect(getAiUsage).toHaveBeenCalledWith("user_1", "free");
  });
});
