import { beforeEach, describe, expect, it, vi } from "vitest";

// ── module mocks ────────────────────────────────────────────────────
vi.mock("next/headers", () => ({
  headers: () => new Headers(),
}));

// Run `after` callbacks inline so POST tests exercise the whole flow.
vi.mock("next/server", async (importOriginal) => {
  const mod = (await importOriginal()) as Record<string, unknown>;
  return { ...mod, after: vi.fn((fn: () => void) => fn()) };
});

const dbMock = {
  query: {
    audioEpisodes: { findMany: vi.fn(), findFirst: vi.fn() },
    notebooks: { findMany: vi.fn(), findFirst: vi.fn() },
  },
  insert: vi.fn(() => ({
    values: vi.fn(() => ({
      returning: vi.fn(async () => []),
    })),
  })),
  update: vi.fn(() => ({
    set: vi.fn(() => ({
      where: vi.fn(async () => {}),
    })),
  })),
  delete: vi.fn(() => ({
    where: vi.fn(async () => {}),
  })),
};

vi.mock("@/db", () => ({
  getDb: () => dbMock,
  schema: {
    audioEpisodes: { userId: "user_id", id: "id", createdAt: "created_at" },
    notebooks: { id: "id", title: "title" },
    usage: {},
  },
}));

const session = { user: { id: "user_1" } };
vi.mock("@/lib/auth", () => ({
  auth: { api: { getSession: vi.fn(async () => session) } },
}));

vi.mock("@/lib/ai/audio-job", () => ({
  runEpisodeGeneration: vi.fn(),
}));

vi.mock("@/lib/ai/sources", () => ({
  NotFoundError: class NotFoundError extends Error {},
  getNotebookForUser: vi.fn(async () => ({ id: "nb_1", title: "VLSI Unit 3" })),
}));

vi.mock("@/lib/premium", () => ({
  getPlanForSession: vi.fn(async () => ({ plan: "free" })),
}));

vi.mock("@/lib/plans", () => ({
  getLimits: vi.fn(() => ({ audioEpisodesPerMonth: 2 })),
}));

vi.mock("@/lib/usage", () => ({
  consumeMonthly: vi.fn(async () => ({ allowed: true, used: 1 })),
}));

// ── imports (after mocks) ───────────────────────────────────────────
import { consumeMonthly } from "@/lib/usage";
import { runEpisodeGeneration } from "@/lib/ai/audio-job";
import { GET, POST } from "@/app/api/audio/route";
import { DELETE, GET as detailGET, PATCH } from "@/app/api/audio/[episodeId]/route";
import { GET as streamGET } from "@/app/api/audio/[episodeId]/stream/route";

const episodeRow = {
  id: "ep_1",
  userId: "user_1",
  notebookId: "nb_1",
  title: "VLSI Unit 3 — Study Podcast",
  style: "focused",
  length: "standard",
  status: "ready",
  pipelineStage: "ready",
  errorMessage: null,
  script: "Section: Introduction\nHello.",
  transcript: [{ heading: "Introduction", text: "Hello.", startSec: 0, sources: [] }],
  audioData: Buffer.from("test-mp3-bytes").toString("base64"),
  mimeType: "audio/mpeg",
  durationSec: 30,
  wordCount: 2,
  playbackPositionSec: 0,
  createdAt: new Date("2026-08-12T00:00:00Z"),
  updatedAt: new Date("2026-08-12T00:00:00Z"),
};

beforeEach(() => {
  vi.clearAllMocks();
  (dbMock.query.audioEpisodes.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([episodeRow]);
  (dbMock.query.audioEpisodes.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(episodeRow);
  (dbMock.query.notebooks.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([
    { id: "nb_1", title: "VLSI Unit 3" },
  ]);
  (dbMock.query.notebooks.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue({
    id: "nb_1",
    title: "VLSI Unit 3",
  });
  (dbMock.insert as ReturnType<typeof vi.fn>).mockImplementation(() => ({
    values: vi.fn(() => ({
      returning: vi.fn(async () => [{ ...episodeRow, status: "processing", pipelineStage: "queued" }]),
    })),
  }));
  (runEpisodeGeneration as ReturnType<typeof vi.fn>).mockResolvedValue("ready");
  (consumeMonthly as ReturnType<typeof vi.fn>).mockResolvedValue({ allowed: true, used: 1 });
});

describe("GET /api/audio", () => {
  it("lists the user's episodes without the audio payload", async () => {
    const res = await GET();
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.episodes).toHaveLength(1);
    expect(body.episodes[0]).toMatchObject({
      id: "ep_1",
      notebookTitle: "VLSI Unit 3",
      status: "ready",
      audioUrl: "/api/audio/ep_1/stream",
    });
    expect(body.episodes[0].audioData).toBeUndefined();
  });
});

describe("POST /api/audio", () => {
  it("creates a queued episode and schedules the generation job", async () => {
    const res = await POST(
      new Request("http://x", {
        method: "POST",
        body: JSON.stringify({ notebookId: "nb_1", style: "friendly", length: "quick" }),
      }),
    );
    expect(res.status).toBe(202);
    const body = await res.json();
    expect(body.episode.status).toBe("processing");
    expect(body.episode.pipelineStage).toBe("queued");
    expect(body.episode.audioData).toBeUndefined();
    expect(runEpisodeGeneration).toHaveBeenCalledTimes(1);
    expect(runEpisodeGeneration).toHaveBeenCalledWith(
      expect.objectContaining({ episodeId: "ep_1", userId: "user_1", notebookId: "nb_1", style: "friendly", length: "quick" }),
    );
  });

  it("rejects an invalid style", async () => {
    const res = await POST(
      new Request("http://x", { method: "POST", body: JSON.stringify({ notebookId: "nb_1", style: "shouty" }) }),
    );
    expect(res.status).toBe(400);
  });

  it("returns 429 when the monthly podcast allowance is exhausted", async () => {
    (consumeMonthly as ReturnType<typeof vi.fn>).mockResolvedValue({ allowed: false, used: 2 });
    const res = await POST(
      new Request("http://x", { method: "POST", body: JSON.stringify({ notebookId: "nb_1" }) }),
    );
    expect(res.status).toBe(429);
    expect(runEpisodeGeneration).not.toHaveBeenCalled();
  });

  it("rejects a notebook the user does not own", async () => {
    const { getNotebookForUser, NotFoundError } = await import("@/lib/ai/sources");
    (getNotebookForUser as ReturnType<typeof vi.fn>).mockRejectedValue(new NotFoundError("nope"));
    const res = await POST(
      new Request("http://x", { method: "POST", body: JSON.stringify({ notebookId: "other" }) }),
    );
    expect(res.status).toBe(404);
  });
});

describe("GET /api/audio/[episodeId]", () => {
  it("returns the episode with transcript and script", async () => {
    const res = await detailGET(new Request("http://x"), { params: Promise.resolve({ episodeId: "ep_1" }) });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.episode.transcript).toHaveLength(1);
    expect(body.episode.script).toContain("Introduction");
    expect(body.episode.audioData).toBeUndefined();
  });

  it("returns 404 for an episode owned by someone else", async () => {
    (dbMock.query.audioEpisodes.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(null);
    const res = await detailGET(new Request("http://x"), { params: Promise.resolve({ episodeId: "ep_x" }) });
    expect(res.status).toBe(404);
  });
});

describe("PATCH /api/audio/[episodeId]", () => {
  it("saves the playback position for resume", async () => {
    const res = await PATCH(
      new Request("http://x", { method: "PATCH", body: JSON.stringify({ playbackPositionSec: 743 }) }),
      { params: Promise.resolve({ episodeId: "ep_1" }) },
    );
    expect(res.status).toBe(200);
    const updateSet = (dbMock.update as ReturnType<typeof vi.fn>).mock.results[0].value.set;
    const setArgs = updateSet.mock.calls[0][0];
    expect(setArgs.playbackPositionSec).toBe(743);
  });

  it("rejects a negative position", async () => {
    const res = await PATCH(
      new Request("http://x", { method: "PATCH", body: JSON.stringify({ playbackPositionSec: -1 }) }),
      { params: Promise.resolve({ episodeId: "ep_1" }) },
    );
    expect(res.status).toBe(400);
  });
});

describe("DELETE /api/audio/[episodeId]", () => {
  it("deletes the user's own episode", async () => {
    const res = await DELETE(new Request("http://x"), { params: Promise.resolve({ episodeId: "ep_1" }) });
    expect(res.status).toBe(200);
    expect(dbMock.delete).toHaveBeenCalled();
  });
});

describe("GET /api/audio/[episodeId]/stream", () => {
  it("streams the full MP3 with Accept-Ranges", async () => {
    const res = await streamGET(new Request("http://x"), { params: Promise.resolve({ episodeId: "ep_1" }) });
    expect(res.status).toBe(200);
    expect(res.headers.get("Content-Type")).toBe("audio/mpeg");
    expect(res.headers.get("Accept-Ranges")).toBe("bytes");
    const bytes = Buffer.from(await res.arrayBuffer());
    expect(bytes.toString()).toBe("test-mp3-bytes");
  });

  it("honors a Range request for seeking", async () => {
    const res = await streamGET(new Request("http://x", { headers: { range: "bytes=5-9" } }), {
      params: Promise.resolve({ episodeId: "ep_1" }),
    });
    expect(res.status).toBe(206);
    expect(res.headers.get("Content-Range")).toBe("bytes 5-9/14");
    const bytes = Buffer.from(await res.arrayBuffer());
    expect(bytes.toString()).toBe("mp3-b");
  });

  it("returns 404 for an episode not owned by the user", async () => {
    (dbMock.query.audioEpisodes.findFirst as ReturnType<typeof vi.fn>).mockResolvedValue(null);
    const res = await streamGET(new Request("http://x"), { params: Promise.resolve({ episodeId: "ep_x" }) });
    expect(res.status).toBe(404);
  });
});
