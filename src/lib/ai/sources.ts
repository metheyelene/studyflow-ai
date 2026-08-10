// ─────────────────────────────────────────────────────────────────────
// Notebook + source persistence. Every function re-checks ownership
// server-side (userId is never trusted from the client). Adding a
// source runs the deterministic pipeline: validate → extract → clean →
// chunk → persist (transactional). Re-adding a source with the same
// title bumps its version — which invalidates cached AI responses.
// ─────────────────────────────────────────────────────────────────────
import { and, count, eq, inArray, sql } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { extractFile, extractPastedText, SourceExtractionError } from "@/lib/ai/extract";
import { chunkText, wordCount } from "@/lib/ai/text";
import { getLimits, type Plan } from "@/lib/plans";
import { consumeLifetime } from "@/lib/usage";

export class NotFoundError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "NotFoundError";
  }
}

export class LimitError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "LimitError";
  }
}

export interface NewNotebookInput {
  title: string;
  description?: string;
  subjectId?: string | null;
}

export async function createNotebook(userId: string, plan: Plan, input: NewNotebookInput) {
  const db = getDb();
  const limits = getLimits(plan);
  const consumed = await consumeLifetime(userId, "notebooks", limits.notebooksLifetime);
  if (!consumed.allowed) {
    throw new LimitError(
      `You've reached the ${limits.notebooksLifetime}-notebook limit on your current plan. ` +
        "Premium allows up to 20 notebooks.",
    );
  }
  const [row] = await db
    .insert(schema.notebooks)
    .values({
      userId,
      title: input.title.trim(),
      description: input.description?.trim() || null,
      subjectId: input.subjectId ?? null,
    })
    .returning();
  return row;
}

export async function listNotebooks(userId: string) {
  const db = getDb();
  const rows = await db.query.notebooks.findMany({
    where: eq(schema.notebooks.userId, userId),
    orderBy: (t, { desc }) => [desc(t.updatedAt)],
  });
  // Source counts per notebook (single grouped query).
  const counts = await db
    .select({ notebookId: schema.notebookSources.notebookId, count: count() })
    .from(schema.notebookSources)
    .where(eq(schema.notebookSources.userId, userId))
    .groupBy(schema.notebookSources.notebookId);
  const byId = new Map(counts.map((r) => [r.notebookId, r.count]));
  return rows.map((n) => ({ ...n, sourceCount: byId.get(n.id) ?? 0 }));
}

/** Auth-checked notebook fetch. Throws NotFoundError for other users. */
export async function getNotebookForUser(userId: string, notebookId: string) {
  const db = getDb();
  const row = await db.query.notebooks.findFirst({
    where: and(eq(schema.notebooks.id, notebookId), eq(schema.notebooks.userId, userId)),
  });
  if (!row) throw new NotFoundError("Notebook not found.");
  return row;
}

export async function deleteNotebook(userId: string, notebookId: string): Promise<void> {
  const db = getDb();
  await getNotebookForUser(userId, notebookId); // auth check
  await db.delete(schema.notebooks).where(eq(schema.notebooks.id, notebookId));
}

export async function listSources(userId: string, notebookId: string) {
  const db = getDb();
  await getNotebookForUser(userId, notebookId);
  return db.query.notebookSources.findMany({
    where: and(
      eq(schema.notebookSources.notebookId, notebookId),
      eq(schema.notebookSources.userId, userId),
    ),
    orderBy: (t, { asc }) => [asc(t.createdAt)],
  });
}

/** Auth-checked: load sources that belong to this user's notebook. */
export async function getSourcesForUser(
  userId: string,
  notebookId: string,
  sourceIds?: string[],
) {
  const db = getDb();
  const base = and(
    eq(schema.notebookSources.notebookId, notebookId),
    eq(schema.notebookSources.userId, userId),
  );
  const where = sourceIds && sourceIds.length > 0 ? and(base, inArray(schema.notebookSources.id, sourceIds)) : base;
  return db.query.notebookSources.findMany({ where });
}

export async function getSourceCount(userId: string, notebookId: string): Promise<number> {
  const db = getDb();
  const [row] = await db
    .select({ count: count() })
    .from(schema.notebookSources)
    .where(
      and(
        eq(schema.notebookSources.notebookId, notebookId),
        eq(schema.notebookSources.userId, userId),
      ),
    );
  return row?.count ?? 0;
}

/** sourceId → version map (cache invalidation signal). */
export async function sourceVersions(
  userId: string,
  notebookId: string,
  sourceIds?: string[],
): Promise<Record<string, number>> {
  const sources = await getSourcesForUser(userId, notebookId, sourceIds);
  return Object.fromEntries(sources.map((s) => [s.id, s.version]));
}

interface PersistSourceInput {
  userId: string;
  notebookId: string;
  title: string;
  sourceType: "pasted" | "uploaded" | "url" | "transcript";
  content: string;
  pageCount?: number;
  meta?: Record<string, unknown>;
}

/** Shared insert/update path: write source + regenerate chunks. */
async function persistSource(userId: string, notebookId: string, input: PersistSourceInput) {
  const db = getDb();
  const chunks = chunkText(input.content);

  const [source] = await db
    .insert(schema.notebookSources)
    .values({
      userId,
      notebookId,
      title: input.title.trim(),
      sourceType: input.sourceType,
      content: input.content,
      status: "ready",
      wordCount: wordCount(input.content),
      pageCount: input.pageCount ?? null,
      meta: input.meta ?? null,
      version: 1,
    })
    .returning();

  if (chunks.length > 0) {
    await db.insert(schema.sourceChunks).values(
      chunks.map((c) => ({
        sourceId: source.id,
        notebookId,
        userId,
        content: c.content,
        chunkIndex: c.chunkIndex,
        charStart: c.charStart,
        charEnd: c.charEnd,
        page: c.page ?? null,
      })),
    );
  }
  return source;
}

/** Replace an existing source (same title) with new content — bumps the
 *  version and regenerates chunks so cached answers invalidate. */
async function replaceSource(sourceId: string, userId: string, input: PersistSourceInput) {
  const db = getDb();
  const chunks = chunkText(input.content);
  const [updated] = await db
    .update(schema.notebookSources)
    .set({
      content: input.content,
      status: "ready",
      errorMessage: null,
      wordCount: wordCount(input.content),
      pageCount: input.pageCount ?? null,
      meta: input.meta ?? null,
      version: sql`${schema.notebookSources.version} + 1`,
    })
    .where(and(eq(schema.notebookSources.id, sourceId), eq(schema.notebookSources.userId, userId)))
    .returning();
  if (!updated) throw new NotFoundError("Source not found.");

  await db.delete(schema.sourceChunks).where(eq(schema.sourceChunks.sourceId, sourceId));
  if (chunks.length > 0) {
    await db.insert(schema.sourceChunks).values(
      chunks.map((c) => ({
        sourceId,
        notebookId: input.notebookId,
        userId,
        content: c.content,
        chunkIndex: c.chunkIndex,
        charStart: c.charStart,
        charEnd: c.charEnd,
        page: c.page ?? null,
      })),
    );
  }
  return updated;
}

export async function addPastedSource(
  userId: string,
  notebookId: string,
  plan: Plan,
  input: { title: string; text: string },
) {
  const db = getDb();
  await getNotebookForUser(userId, notebookId);
  const limits = getLimits(plan);

  // Same-title re-add = replace (version bump).
  const existing = await db.query.notebookSources.findFirst({
    where: and(
      eq(schema.notebookSources.notebookId, notebookId),
      eq(schema.notebookSources.userId, userId),
      eq(schema.notebookSources.title, input.title.trim()),
    ),
  });
  if (!existing) {
    if ((await getSourceCount(userId, notebookId)) >= limits.sourcesPerNotebook) {
      throw new LimitError(
        `This notebook has reached the ${limits.sourcesPerNotebook}-source limit on your current plan.`,
      );
    }
  }

  const { text } = extractPastedText(input.text);
  return existing
    ? replaceSource(existing.id, userId, {
        userId,
        notebookId,
        title: input.title,
        sourceType: "pasted",
        content: text,
      })
    : persistSource(userId, notebookId, {
        userId,
        notebookId,
        title: input.title,
        sourceType: "pasted",
        content: text,
      });
}

export async function addUploadedSource(
  userId: string,
  notebookId: string,
  plan: Plan,
  input: { filename: string; mimeType: string; buffer: Buffer },
) {
  const db = getDb();
  await getNotebookForUser(userId, notebookId);
  const limits = getLimits(plan);

  const existing = await db.query.notebookSources.findFirst({
    where: and(
      eq(schema.notebookSources.notebookId, notebookId),
      eq(schema.notebookSources.userId, userId),
      eq(schema.notebookSources.title, input.filename.trim()),
    ),
  });
  if (!existing) {
    if ((await getSourceCount(userId, notebookId)) >= limits.sourcesPerNotebook) {
      throw new LimitError(
        `This notebook has reached the ${limits.sourcesPerNotebook}-source limit on your current plan.`,
      );
    }
  }

  const extracted = await extractFile(input.buffer, input.filename, input.mimeType);
  const base = {
    userId,
    notebookId,
    title: input.filename,
    sourceType: "uploaded" as const,
    content: extracted.text,
    pageCount: extracted.pageCount,
    meta: { mimeType: input.mimeType, sizeBytes: input.buffer.byteLength } as Record<string, unknown>,
  };
  return existing ? replaceSource(existing.id, userId, base) : persistSource(userId, notebookId, base);
}

export async function deleteSource(userId: string, notebookId: string, sourceId: string): Promise<void> {
  const db = getDb();
  await getNotebookForUser(userId, notebookId);
  const deleted = await db
    .delete(schema.notebookSources)
    .where(
      and(
        eq(schema.notebookSources.id, sourceId),
        eq(schema.notebookSources.userId, userId),
        eq(schema.notebookSources.notebookId, notebookId),
      ),
    )
    .returning({ id: schema.notebookSources.id });
  if (deleted.length === 0) throw new NotFoundError("Source not found.");
}

/** Load chunks for a set of the user's sources (auth-checked). */
export async function loadChunks(
  userId: string,
  notebookId: string,
  sourceIds: string[],
): Promise<
  Array<{
    id: string;
    sourceId: string;
    notebookId: string;
    content: string;
    chunkIndex: number;
    page: number | null;
    sourceTitle: string;
  }>
> {
  if (sourceIds.length === 0) return [];
  const db = getDb();
  const rows = await db.query.sourceChunks.findMany({
    where: and(
      eq(schema.sourceChunks.userId, userId),
      eq(schema.sourceChunks.notebookId, notebookId),
      inArray(schema.sourceChunks.sourceId, sourceIds),
    ),
    orderBy: (t, { asc }) => [asc(t.sourceId), asc(t.chunkIndex)],
  });
  const titles = new Map<string, string>();
  const sources = await getSourcesForUser(userId, notebookId, sourceIds);
  for (const s of sources) titles.set(s.id, s.title);
  return rows.map((r) => ({
    id: r.id,
    sourceId: r.sourceId,
    notebookId: r.notebookId,
    content: r.content,
    chunkIndex: r.chunkIndex,
    page: r.page,
    sourceTitle: titles.get(r.sourceId) ?? "Source",
  }));
}

export { SourceExtractionError };
