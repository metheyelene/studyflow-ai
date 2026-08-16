// ─────────────────────────────────────────────────────────────────────
// Source-grounded study transformations. Every action retrieves the
// relevant excerpts from the notebook, generates structured output, and
// VALIDATES it before returning:
//   - quiz questions with <2 options or out-of-range correctIndex are dropped
//   - flashcards/questions that cite only fabricated markers are dropped
//     (never invent source support)
//   - citation markers are remapped to real chunk/source ids
// All actions are cached (key includes source versions, so replacing a
// source invalidates them). Each action consumes one AI action upstream
// in the API route.
// ─────────────────────────────────────────────────────────────────────
import { z } from "zod";

import { getCached, putCached, cacheKey as buildCacheKey } from "@/lib/ai/cache";
import { preferenceCacheSalt } from "@/lib/ai/preferences";
import { generate, generateJson, resolveModel } from "@/lib/ai/orchestrator";
import { hybridRetrieve, type RetrievableChunk } from "@/lib/ai/retrieval";
import { getSourcesForUser, loadChunks, sourceVersions } from "@/lib/ai/sources";
import { systemPrompt } from "@/lib/ai/prompts";

export type ActionName =
  | "summarize"
  | "explain"
  | "flashcards"
  | "quiz"
  | "studyGuide"
  | "faq"
  | "extract"
  | "outline"
  | "compare"
  | "mindMap";

export const ACTION_NAMES: ActionName[] = [
  "summarize",
  "explain",
  "flashcards",
  "quiz",
  "studyGuide",
  "faq",
  "extract",
  "outline",
  "compare",
  "mindMap",
];

export type ActionParams = Record<string, string | number | boolean | undefined>;

// ── zod output schemas ───────────────────────────────────────────────
const markerList = z.array(z.number().int().min(1).max(30)).optional().default([]);

const flashcardsSchema = z.object({
  cards: z
    .array(
      z.object({
        front: z.string().min(1),
        back: z.string().min(1),
        sourceMarkers: markerList,
      }),
    )
    .min(1)
    .max(30),
});

const quizSchema = z.object({
  title: z.string().min(1).optional(),
  questions: z
    .array(
      z.object({
        question: z.string().min(1),
        options: z.array(z.string().min(1)).min(2).max(6),
        correctIndex: z.number().int().min(0),
        explanation: z.string().min(1),
        sourceMarkers: markerList,
      }),
    )
    .min(1)
    .max(30),
});

const studyGuideSchema = z.object({
  keyConcepts: z.array(z.string().min(1)).min(1),
  definitions: z.array(z.object({ term: z.string().min(1), definition: z.string().min(1) })),
  formulas: z.array(z.object({ name: z.string().min(1), formula: z.string().min(1) })),
  revisionChecklist: z.array(z.string().min(1)),
  topics: z.array(z.string().min(1)),
});

const faqSchema = z.object({
  items: z.array(z.object({ question: z.string().min(1), answer: z.string().min(1) })).min(1).max(15),
});

const extractSchema = z.object({
  definitions: z.array(z.object({ term: z.string().min(1), definition: z.string().min(1) })),
  formulas: z.array(z.object({ name: z.string().min(1), formula: z.string().min(1) })),
  dates: z.array(z.string().min(1)),
  names: z.array(z.string().min(1)),
  keyFacts: z.array(z.string().min(1)),
});

const outlineSchema = z.object({
  title: z.string().min(1),
  sections: z.array(z.object({ heading: z.string().min(1), points: z.array(z.string().min(1)) })).min(1),
});

const mindMapSchema = z.object({
  topic: z.string().min(1),
  subtopics: z
    .array(z.object({ name: z.string().min(1), details: z.array(z.string().min(1)) }))
    .min(1)
    .max(12),
});

// ── action descriptors ───────────────────────────────────────────────
interface ActionDescriptor {
  tier: "simple" | "standard" | "complex";
  system: (params: ActionParams) => string;
  prompt: (params: ActionParams) => string;
}

const DESCRIPTORS: Record<ActionName, ActionDescriptor> = {
  summarize: {
    tier: "standard",
    system: () => systemPrompt("sources"),
    prompt: (p) =>
      `Create a ${p.style === "exam" ? "concise exam-focused summary covering likely testable points" : p.style === "detailed" ? "detailed summary covering all key points, mechanisms, and examples" : "short summary of the most important points"} of the retrieved material. Use short paragraphs and bullets. End with 2–3 likely exam questions.`,
  },
  explain: {
    tier: "standard",
    system: () => systemPrompt("sources"),
    prompt: (p) =>
      `Explain "${p.concept}" at a ${p.level ?? "beginner"} level using ONLY the retrieved material as the basis. Define key terms in plain language, give one concrete example, and note what the sources do NOT cover (if anything).`,
  },
  flashcards: {
    tier: "standard",
    system: () => systemPrompt("sources") + "\n\nFor every card, set sourceMarkers to the excerpt numbers that support the front/back content.",
    prompt: (p) =>
      `Create ${p.count ?? 10} study flashcards from the retrieved material. Each card: a clear front (question or prompt) and a concise back (answer). Cards must test important, factual content actually present in the excerpts.`,
  },
  quiz: {
    tier: "standard",
    system: () => systemPrompt("sources") + "\n\nFor every question, set sourceMarkers to the excerpt numbers that support it.",
    prompt: (p) =>
      `Create ${p.count ?? 8} multiple-choice questions from the retrieved material (difficulty: ${p.difficulty ?? "medium"}). Every question must be answerable from the excerpts; 4 options each with exactly one correct answer. Include a short explanation and set sourceMarkers.`,
  },
  studyGuide: {
    tier: "standard",
    system: () => systemPrompt("sources"),
    prompt: () =>
      `Build a study guide from the retrieved material: key concepts, definitions, important formulas (if any), a revision checklist, and the main topics covered.`,
  },
  faq: {
    tier: "standard",
    system: () => systemPrompt("sources"),
    prompt: (p) =>
      `Generate ${p.count ?? 8} likely exam or study questions and their answers, all grounded in the retrieved material.`,
  },
  extract: {
    tier: "simple",
    system: () => systemPrompt("sources"),
    prompt: () =>
      `Extract from the retrieved material: definitions, formulas (if any), dates (if any), names (people, laws, methods — if any), and key facts. Only include items actually present in the excerpts; leave arrays empty when nothing fits.`,
  },
  outline: {
    tier: "simple",
    system: () => systemPrompt("sources"),
    prompt: () =>
      `Create a structured outline of the retrieved material: a title and sections with their key points, in the order the material presents them.`,
  },
  compare: {
    tier: "complex",
    system: () => systemPrompt("sources"),
    prompt: (p) =>
      `Compare "${p.target}" using the retrieved material. Cover similarities, differences, and how the concepts connect. Cite the excerpts that support each point. Be precise and note where the sources are silent.`,
  },
  mindMap: {
    tier: "standard",
    system: () => systemPrompt("sources"),
    prompt: () =>
      `Create a concept map of the retrieved material: the central topic, its main subtopics, and 2–4 short details per subtopic. Use the actual concepts from the excerpts.`,
  },
};

// ── shared pipeline ──────────────────────────────────────────────────
interface ActionContext {
  userId: string;
  notebookId: string;
  sourceIds?: string[];
}

interface SourceRef {
  chunkId: string;
  sourceId: string;
  sourceTitle: string;
  page?: number | null;
  marker: number;
}

async function retrieveContext(ctx: ActionContext, query: string, topK = 10) {
  const sources = await loadChunks(ctx.userId, ctx.notebookId, ctx.sourceIds ?? (await sourceIdsForNotebook(ctx)));
  if (sources.length === 0) {
    throw new Error("This notebook has no ready sources yet. Add a source first.");
  }
  const chunks: RetrievableChunk[] = sources.map((s) => ({
    id: s.id,
    sourceId: s.sourceId,
    notebookId: s.notebookId,
    content: s.content,
    chunkIndex: s.chunkIndex,
    page: s.page,
    sourceTitle: s.sourceTitle,
  }));
  const retrieved = await hybridRetrieve(query, chunks, { topK, sourceIds: ctx.sourceIds });
  // A short source can score zero against a generic generation query (e.g.
  // "main content and key concepts"). Fall back to the first chunks in
  // source order so generation still works when retrieval finds nothing.
  // Bounded by topK — never the whole document collection.
  if (retrieved.length === 0) {
    return chunks.slice(0, topK);
  }
  return retrieved;
}

async function sourceIdsForNotebook(ctx: ActionContext): Promise<string[]> {
  // loadChunks([]) means "no chunks" by contract, so resolve the ready
  // source ids directly — otherwise every action/chat without explicit
  // sourceIds resolves to no sources at all.
  const sources = await getSourcesForUser(ctx.userId, ctx.notebookId);
  return sources.filter((s) => s.status === "ready").map((s) => s.id);
}

function buildContext(retrieved: RetrievableChunk[], maxExcerptChars = 900): { context: string; refs: Map<number, SourceRef> } {
  const blocks: string[] = [];
  const refs = new Map<number, SourceRef>();
  retrieved.forEach((chunk, i) => {
    const marker = i + 1;
    const excerpt = chunk.content.slice(0, maxExcerptChars);
    const pageNote = chunk.page ? ` (page ${chunk.page})` : "";
    blocks.push(`[${marker}] ${chunk.sourceTitle}${pageNote}\n<untrusted_source ${marker}>\n${excerpt}\n</untrusted_source>`);
    refs.set(marker, {
      chunkId: chunk.id,
      sourceId: chunk.sourceId,
      sourceTitle: chunk.sourceTitle,
      page: chunk.page,
      marker,
    });
  });
  return { context: blocks.join("\n\n"), refs };
}

/** Map sourceMarkers → real refs; drop items with only fabricated markers. */
function resolveMarkers<T extends { sourceMarkers?: number[] }>(items: T[], refs: Map<number, SourceRef>): Array<T & { sources: SourceRef[] }> {
  const out: Array<T & { sources: SourceRef[] }> = [];
  for (const item of items) {
    const sources: SourceRef[] = [];
    for (const m of item.sourceMarkers ?? []) {
      const ref = refs.get(m);
      if (ref) sources.push(ref);
    }
    if (sources.length === 0) continue; // discard unsupported items
    const { sourceMarkers: _drop, ...rest } = item;
    void _drop;
    out.push({ ...(rest as T), sources });
  }
  return out;
}

// ── public actions ───────────────────────────────────────────────────
export interface ActionResult<D> {
  action: ActionName;
  data: D;
  provider: string;
  model: string;
  costUsd: string;
  sourcesUsed: string[];
  cacheKey?: string;
}

export async function runAction<D>(
  action: ActionName,
  ctx: ActionContext,
  params: ActionParams,
): Promise<ActionResult<D>> {
  // Text actions share the same pipeline but return plain text.
  if (action === "summarize" || action === "explain" || action === "compare") {
    return (await runTextAction(action, ctx, params)) as unknown as ActionResult<D>;
  }
  const descriptor = DESCRIPTORS[action];
  const query =
    typeof params.target === "string"
      ? String(params.target)
      : "main content and key concepts";

  const retrieved = await retrieveContext(ctx, query);
  if (retrieved.length === 0) {
    throw new Error("No relevant content found in this notebook for that action.");
  }
  const { context, refs } = buildContext(retrieved);

  const model = resolveModel(descriptor.tier).model;
  const key = buildCacheKey({
    userId: ctx.userId,
    notebookId: ctx.notebookId,
    sourceIds: ctx.sourceIds ?? [],
    sourceVersions: await sourceVersions(ctx.userId, ctx.notebookId, ctx.sourceIds),
    question: `${action}:${JSON.stringify(params)}`,
    mode: "sources",
    feature: action,
    model,
    preferences: await preferenceCacheSalt(ctx.userId),
  });

  const cached = await getCached<D>(ctx.userId, ctx.notebookId, key);
  if (cached) {
    return { action, data: cached, provider: "cache", model, costUsd: "0", sourcesUsed: [], cacheKey: key };
  }

  const prompt = `${descriptor.prompt(params)}\n\nRETRIEVED EXCERPTS FROM THE USER'S SOURCES:\n${context}`;
  const generated = await generateJson({
    feature: action,
    tier: descriptor.tier,
    system: descriptor.system(params),
    prompt,
    temperature: 0.4,
    maxOutputTokens: 2048,
    schema: schemaFor(action),
    log: { userId: ctx.userId },
    userId: ctx.userId,
  });

  const data = validateOutput(action, generated.data as never, refs) as unknown as D;
  await putCached(ctx.userId, ctx.notebookId, key, data);
  const sourcesUsed = [...new Set([...refs.values()].map((r) => r.sourceId))];
  return {
    action,
    data,
    provider: generated.provider,
    model: generated.model,
    costUsd: generated.costUsd,
    sourcesUsed,
    cacheKey: key,
  };
}

function schemaFor(action: ActionName): z.ZodType {
  switch (action) {
    case "flashcards":
      return flashcardsSchema;
    case "quiz":
      return quizSchema;
    case "studyGuide":
      return studyGuideSchema;
    case "faq":
      return faqSchema;
    case "extract":
      return extractSchema;
    case "outline":
      return outlineSchema;
    case "mindMap":
      return mindMapSchema;
    default:
      // Text actions are generated as plain text by the route.
      return z.any();
  }
}

/** Drop structurally invalid items (never surface garbage to students). */
function validateOutput(action: ActionName, data: unknown, refs: Map<number, SourceRef>): unknown {
  if (action === "quiz") {
    const q = data as z.infer<typeof quizSchema>;
    q.questions = q.questions
      .map((question, index) => {
        const valid =
          question.options.length >= 2 &&
          question.correctIndex >= 0 &&
          question.correctIndex < question.options.length &&
          question.question.trim().length > 0;
        return valid ? { ...question, order: index } : null;
      })
      .filter((x): x is NonNullable<typeof x> => x !== null);
    q.questions = resolveMarkers(q.questions, refs).map(({ sources, ...rest }) => ({
      ...rest,
      sourceChunkIds: sources.map((s) => s.chunkId),
    }));
    return q;
  }
  if (action === "flashcards") {
    const f = data as z.infer<typeof flashcardsSchema>;
    f.cards = resolveMarkers(f.cards, refs).map(({ sources, ...rest }) => ({
      ...rest,
      sourceChunkIds: sources.map((s) => s.chunkId),
    }));
    return f;
  }
  return data;
}

// Text actions (summarize/explain/compare) return plain text.
export async function runTextAction(
  action: "summarize" | "explain" | "compare",
  ctx: ActionContext,
  params: ActionParams,
): Promise<ActionResult<{ text: string }>> {
  const descriptor = DESCRIPTORS[action];
  const query =
    typeof params.target === "string"
      ? String(params.target)
      : action === "explain" && typeof params.concept === "string"
        ? String(params.concept)
        : "main content and key concepts";

  const retrieved = await retrieveContext(ctx, query, action === "compare" ? 12 : 8);
  if (retrieved.length === 0) {
    throw new Error("No relevant content found in this notebook for that action.");
  }
  const { context, refs } = buildContext(retrieved);

  const model = resolveModel(descriptor.tier).model;
  const key = buildCacheKey({
    userId: ctx.userId,
    notebookId: ctx.notebookId,
    sourceIds: ctx.sourceIds ?? [],
    sourceVersions: await sourceVersions(ctx.userId, ctx.notebookId, ctx.sourceIds),
    question: `${action}:${JSON.stringify(params)}`,
    mode: "sources",
    feature: action,
    model,
    preferences: await preferenceCacheSalt(ctx.userId),
  });

  const cached = await getCached<{ text: string }>(ctx.userId, ctx.notebookId, key);
  if (cached) {
    return { action, data: cached, provider: "cache", model, costUsd: "0", sourcesUsed: [], cacheKey: key };
  }

  const prompt = `${descriptor.prompt(params)}\n\nRETRIEVED EXCERPTS FROM THE USER'S SOURCES:\n${context}`;
  const generated = await generate({
    feature: action,
    tier: descriptor.tier,
    system: descriptor.system(params),
    prompt,
    temperature: 0.4,
    maxOutputTokens: 1500,
    log: { userId: ctx.userId },
    userId: ctx.userId,
  });

  // Strip fabricated citation markers, keep valid ones.
  const valid = new Set(refs.keys());
  const cleaned = generated.text.replace(/\[(\d{1,2})\]/g, (m, n: string) =>
    valid.has(Number(n)) ? m : "",
  );

  const data = { text: cleaned };
  await putCached(ctx.userId, ctx.notebookId, key, data);
  return {
    action,
    data,
    provider: generated.provider,
    model: generated.model,
    costUsd: generated.costUsd,
    sourcesUsed: [...new Set([...refs.values()].map((r) => r.sourceId))],
    cacheKey: key,
  };
}
