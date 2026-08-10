// ─────────────────────────────────────────────────────────────────────
// Notes service — auth-checked CRUD + search. Every function re-checks
// ownership server-side; the client never trusts a note id. Supports
// subject assignment, favorites, archiving, and word counts. The notes
// system is plain-text by design (content is the extracted/pasted text);
// rich-text rendering is a documented future step.
// ─────────────────────────────────────────────────────────────────────
import { and, desc, eq, ilike, isNotNull, isNull, or } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { wordCount } from "@/lib/ai/text";

export class NoteNotFoundError extends Error {
  constructor() {
    super("Note not found.");
    this.name = "NoteNotFoundError";
  }
}

export interface NoteInput {
  title?: string;
  content?: string;
  subjectId?: string | null;
  favorite?: boolean;
  archived?: boolean;
}

const TITLE_MAX = 200;
const CONTENT_MAX = 200_000;

interface Sanitized {
  title?: string;
  content?: string;
  subjectId?: string | null;
  favorite?: boolean;
  archivedAt?: Date | null;
  wordCount?: number;
}

function sanitize(input: NoteInput): Sanitized {
  const out: Sanitized = {};
  if (input.title !== undefined) {
    out.title = input.title.trim().slice(0, TITLE_MAX) || "Untitled";
  }
  if (input.content !== undefined) {
    out.content = input.content.slice(0, CONTENT_MAX);
    out.wordCount = wordCount(out.content);
  }
  if (input.subjectId !== undefined) out.subjectId = input.subjectId || null;
  if (input.favorite !== undefined) out.favorite = input.favorite;
  if (input.archived !== undefined) out.archivedAt = input.archived ? new Date() : null;
  return out;
}

export async function createNote(userId: string, input: NoteInput) {
  const db = getDb();
  const content = (input.content ?? "").slice(0, CONTENT_MAX);
  const [note] = await db
    .insert(schema.notes)
    .values({
      userId,
      title: (input.title ?? "Untitled").trim().slice(0, TITLE_MAX) || "Untitled",
      content,
      subjectId: input.subjectId || null,
      favorite: input.favorite ?? false,
      wordCount: wordCount(content),
    })
    .returning();
  return note;
}

export interface ListNotesOptions {
  search?: string;
  subjectId?: string | null;
  favoriteOnly?: boolean;
  archived?: boolean;
  limit?: number;
}

export async function listNotes(userId: string, options: ListNotesOptions = {}) {
  const db = getDb();
  const conditions = [eq(schema.notes.userId, userId)];
  if (options.archived) {
    conditions.push(isNotNull(schema.notes.archivedAt));
  } else {
    conditions.push(isNull(schema.notes.archivedAt));
  }
  if (options.favoriteOnly) conditions.push(eq(schema.notes.favorite, true));
  if (options.subjectId !== undefined && options.subjectId !== null && options.subjectId !== "") {
    conditions.push(eq(schema.notes.subjectId, options.subjectId));
  }
  if (options.search && options.search.trim()) {
    const q = `%${options.search.trim()}%`;
    conditions.push(or(ilike(schema.notes.title, q), ilike(schema.notes.content, q))!);
  }

  return db.query.notes.findMany({
    where: and(...conditions),
    orderBy: (t) => [desc(t.favorite), desc(t.updatedAt)],
    limit: options.limit ?? 500,
  });
}

/** Auth-checked single-note fetch. */
export async function getNote(userId: string, noteId: string) {
  const db = getDb();
  const note = await db.query.notes.findFirst({
    where: and(eq(schema.notes.id, noteId), eq(schema.notes.userId, userId)),
  });
  if (!note) throw new NoteNotFoundError();
  return note;
}

export async function updateNote(userId: string, noteId: string, input: NoteInput) {
  const db = getDb();
  await getNote(userId, noteId); // auth check
  const values = sanitize(input);
  const [note] = await db
    .update(schema.notes)
    .set({ ...values, updatedAt: new Date() })
    .where(and(eq(schema.notes.id, noteId), eq(schema.notes.userId, userId)))
    .returning();
  return note;
}

export async function deleteNote(userId: string, noteId: string): Promise<void> {
  const db = getDb();
  await getNote(userId, noteId);
  await db
    .delete(schema.notes)
    .where(and(eq(schema.notes.id, noteId), eq(schema.notes.userId, userId)));
}

/** Lightweight counts for filter chips. */
export async function countNotes(userId: string): Promise<{ total: number; archived: number; favorites: number }> {
  const db = getDb();
  const rows = await db
    .select({ archivedAt: schema.notes.archivedAt, favorite: schema.notes.favorite })
    .from(schema.notes)
    .where(eq(schema.notes.userId, userId));
  return {
    total: rows.length,
    archived: rows.filter((r) => r.archivedAt !== null).length,
    favorites: rows.filter((r) => r.favorite).length,
  };
}
