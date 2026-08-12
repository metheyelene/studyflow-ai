// ─────────────────────────────────────────────────────────────────────
// StudyFlow AI domain schema (Drizzle / Postgres).
// Auth tables (user/session/account/verification) live in auth-schema.ts
// and are merged into the schema in db/index.ts.
//
// Conventions:
//  - text ids, generated with crypto.randomUUID() at insert time
//  - timestamps with timezone
//  - every user-owned table has userId FK -> user.id (cascade delete)
//  - hot query paths get indexes (see index() calls)
// ─────────────────────────────────────────────────────────────────────
import { sql } from "drizzle-orm";
import {
  boolean,
  index,
  integer,
  jsonb,
  pgEnum,
  pgTable,
  text,
  timestamp,
  unique,
} from "drizzle-orm/pg-core";
import { user } from "./auth-schema";

const id = (name = "id") =>
  text(name)
    .primaryKey()
    .$defaultFn(() => crypto.randomUUID());
const now = () => new Date();

// ── enums ────────────────────────────────────────────────────────────
export const sourceTypeEnum = pgEnum("source_type", [
  "pasted",
  "uploaded",
  "generated",
]);
export const documentStatusEnum = pgEnum("document_status", [
  "processing",
  "ready",
  "failed",
]);
export const difficultyEnum = pgEnum("difficulty", [
  "easy",
  "medium",
  "hard",
]);
export const subscriptionStatusEnum = pgEnum("subscription_status", [
  "active",
  "trialing",
  "past_due",
  "canceled",
  "unpaid",
  "incomplete",
]);
export const aiStatusEnum = pgEnum("ai_status", ["success", "error"]);

// ── profiles ─────────────────────────────────────────────────────────
// One row per user, created during onboarding. Holds personalization +
// streak data (streak is computed, this caches the current value).
export const profiles = pgTable(
  "profiles",
  {
    userId: text("user_id")
      .primaryKey()
      .references(() => user.id, { onDelete: "cascade" }),
    course: text("course"), // "what are you studying?"
    educationLevel: text("education_level"), // high-school | undergrad | postgrad | professional | other
    timezone: text("timezone"), // IANA name, e.g. "Asia/Kolkata"
    goal: text("goal"), // what they want help with
    dailyStudyMinutes: integer("daily_study_minutes").notNull().default(30),
    onboardingCompleted: boolean("onboarding_completed").notNull().default(false),
    studyStreak: integer("study_streak").notNull().default(0),
    lastStudyDate: timestamp("last_study_date", { withTimezone: true }),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .notNull()
      .defaultNow()
      .$onUpdate(() => now()),
  },
  (t) => [index("profiles_user_idx").on(t.userId)],
);

// ── subjects ─────────────────────────────────────────────────────────
export const subjects = pgTable(
  "subjects",
  {
    id: id(),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    name: text("name").notNull(),
    color: text("color").notNull().default("#6366f1"),
    icon: text("icon"),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .notNull()
      .defaultNow()
      .$onUpdate(() => now()),
  },
  (t) => [
    index("subjects_user_idx").on(t.userId),
    unique("subjects_user_name_unique").on(t.userId, t.name),
  ],
);

// ── notes ────────────────────────────────────────────────────────────
// content holds the plain text (pasted, or extracted from a document).
// favorite + archivedAt support the notes workspace (Phase 6).
export const notes = pgTable(
  "notes",
  {
    id: id(),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    subjectId: text("subject_id").references(() => subjects.id, {
      onDelete: "set null",
    }),
    title: text("title").notNull(),
    content: text("content").notNull(),
    sourceType: sourceTypeEnum("source_type").notNull().default("pasted"),
    wordCount: integer("word_count"),
    favorite: boolean("favorite").notNull().default(false),
    archivedAt: timestamp("archived_at", { withTimezone: true }),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .notNull()
      .defaultNow()
      .$onUpdate(() => now()),
  },
  (t) => [
    index("notes_user_updated_idx").on(t.userId, t.updatedAt),
    index("notes_user_archived_idx").on(t.userId, t.archivedAt),
  ],
);

// ── documents ────────────────────────────────────────────────────────
// A file upload (PDF etc.). The file lives in Cloudflare R2 under
// storageKey; text is extracted server-side into the linked note.
export const documents = pgTable(
  "documents",
  {
    id: id(),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    noteId: text("note_id").references(() => notes.id, {
      onDelete: "set null",
    }),
    filename: text("filename").notNull(),
    mimeType: text("mime_type").notNull(),
    sizeBytes: integer("size_bytes").notNull().default(0),
    storageKey: text("storage_key").notNull().unique(),
    status: documentStatusEnum("status").notNull().default("processing"),
    errorMessage: text("error_message"),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [index("documents_user_idx").on(t.userId)],
);

// ── flashcards ───────────────────────────────────────────────────────
export const flashcardDecks = pgTable(
  "flashcard_decks",
  {
    id: id(),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    noteId: text("note_id").references(() => notes.id, {
      onDelete: "set null",
    }),
    subjectId: text("subject_id").references(() => subjects.id, {
      onDelete: "set null",
    }),
    notebookId: text("notebook_id").references(() => notebooks.id, {
      onDelete: "set null",
    }),
    title: text("title").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .notNull()
      .defaultNow()
      .$onUpdate(() => now()),
  },
  (t) => [index("decks_user_idx").on(t.userId)],
);

export const flashcards = pgTable(
  "flashcards",
  {
    id: id(),
    deckId: text("deck_id")
      .notNull()
      .references(() => flashcardDecks.id, { onDelete: "cascade" }),
    front: text("front").notNull(),
    back: text("back").notNull(),
    order: integer("order").notNull().default(0),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [index("flashcards_deck_idx").on(t.deckId)],
);

export const flashcardReviews = pgTable(
  "flashcard_reviews",
  {
    id: id(),
    cardId: text("card_id")
      .notNull()
      .references(() => flashcards.id, { onDelete: "cascade" }),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    rating: integer("rating").notNull(), // 1 (again) … 5 (easy)
    reviewedAt: timestamp("reviewed_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [index("reviews_user_time_idx").on(t.userId, t.reviewedAt)],
);

// ── quizzes ──────────────────────────────────────────────────────────
export const quizzes = pgTable(
  "quizzes",
  {
    id: id(),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    noteId: text("note_id").references(() => notes.id, {
      onDelete: "set null",
    }),
    notebookId: text("notebook_id").references(() => notebooks.id, {
      onDelete: "set null",
    }),
    title: text("title").notNull(),
    difficulty: difficultyEnum("difficulty").notNull().default("medium"),
    questionCount: integer("question_count").notNull().default(10),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [index("quizzes_user_idx").on(t.userId)],
);

export const quizQuestions = pgTable(
  "quiz_questions",
  {
    id: id(),
    quizId: text("quiz_id")
      .notNull()
      .references(() => quizzes.id, { onDelete: "cascade" }),
    question: text("question").notNull(),
    options: jsonb("options").notNull().$type<string[]>(),
    correctIndex: integer("correct_index").notNull(),
    explanation: text("explanation"),
    order: integer("order").notNull().default(0),
  },
  (t) => [index("quiz_questions_quiz_idx").on(t.quizId)],
);

export const quizAttempts = pgTable(
  "quiz_attempts",
  {
    id: id(),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    quizId: text("quiz_id")
      .notNull()
      .references(() => quizzes.id, { onDelete: "cascade" }),
    score: integer("score").notNull().default(0),
    totalQuestions: integer("total_questions").notNull().default(0),
    answers: jsonb("answers").$type<number[]>(),
    startedAt: timestamp("started_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    completedAt: timestamp("completed_at", { withTimezone: true }),
  },
  (t) => [index("attempts_user_completed_idx").on(t.userId, t.completedAt)],
);

// ── exams & study plans ──────────────────────────────────────────────
export const exams = pgTable(
  "exams",
  {
    id: id(),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    subjectId: text("subject_id").references(() => subjects.id, {
      onDelete: "set null",
    }),
    title: text("title").notNull(),
    examDate: timestamp("exam_date", { withTimezone: true }).notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [index("exams_user_date_idx").on(t.userId, t.examDate)],
);

export const studyPlans = pgTable(
  "study_plans",
  {
    id: id(),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    examId: text("exam_id").references(() => exams.id, {
      onDelete: "set null",
    }),
    planJson: jsonb("plan_json").notNull().$type<unknown>(),
    version: integer("version").notNull().default(1),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [index("plans_user_idx").on(t.userId)],
);

// ── subscriptions ────────────────────────────────────────────────────
// Mirrors Stripe state. Premium access is derived from this table
// server-side — never from a client-side flag.
export const subscriptions = pgTable(
  "subscriptions",
  {
    id: id(),
    userId: text("user_id")
      .notNull()
      .unique()
      .references(() => user.id, { onDelete: "cascade" }),
    stripeCustomerId: text("stripe_customer_id").unique(),
    stripeSubscriptionId: text("stripe_subscription_id").unique(),
    status: subscriptionStatusEnum("status").notNull().default("incomplete"),
    plan: text("plan").notNull().default("premium"),
    currentPeriodEnd: timestamp("current_period_end", { withTimezone: true }),
    cancelAtPeriodEnd: boolean("cancel_at_period_end").notNull().default(false),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .notNull()
      .defaultNow()
      .$onUpdate(() => now()),
  },
  (t) => [
    index("subscriptions_status_idx").on(t.status),
    index("subscriptions_user_status_idx").on(t.userId, t.status),
  ],
);

// ── founding members ─────────────────────────────────────────────────
// Permanent claim records for the first-35 founding-member offer
// (docs/founding-members.md). A row is created ONLY after the payment
// webhook confirms a successful subscription, and it is NEVER deleted:
// a claimed slot is permanently consumed, even if the member later
// cancels (status flips to "canceled").
export const foundingMembers = pgTable(
  "founding_members",
  {
    id: id(),
    userId: text("user_id")
      .notNull()
      .unique()
      .references(() => user.id, { onDelete: "cascade" }),
    subscriptionId: text("subscription_id")
      .notNull()
      .unique()
      .references(() => subscriptions.id, { onDelete: "cascade" }),
    status: text("status").notNull().default("active"), // active | canceled
    claimedAt: timestamp("claimed_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [index("founding_members_status_idx").on(t.status)],
);

// Single-row atomic counter: the SOURCE OF TRUTH for how many founding
// slots are claimed. `cap` lives in the database so the limit is not
// buried in code. Allocation is an atomic conditional UPDATE — Postgres
// row-locks this row, so concurrent claims can never exceed `cap`.
export const foundingMemberCounter = pgTable(
  "founding_member_counter",
  {
    id: integer("id").primaryKey(),
    claimed: integer("claimed").notNull().default(0),
    cap: integer("cap").notNull().default(35),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .notNull()
      .defaultNow()
      .$onUpdate(() => now()),
  },
);

// ── notebooks (source-grounded AI) ───────────────────────────────────
// A notebook is an isolated knowledge space: one or more sources the
// user added, which the AI answers from. See docs/source-grounded-ai.md.
export const notebooks = pgTable(
  "notebooks",
  {
    id: id(),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    subjectId: text("subject_id").references(() => subjects.id, {
      onDelete: "set null",
    }),
    title: text("title").notNull(),
    description: text("description"),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .notNull()
      .defaultNow()
      .$onUpdate(() => now()),
  },
  (t) => [index("notebooks_user_updated_idx").on(t.userId, t.updatedAt)],
);

export const notebookSourceTypeEnum = pgEnum("notebook_source_type", [
  "pasted",
  "uploaded",
  "url",
  "transcript",
]);

export const notebookSourceStatusEnum = pgEnum("notebook_source_status", [
  "processing",
  "ready",
  "failed",
]);

// A single source inside a notebook. `content` is the extracted plain
// text (cleaned). `version` increments when the user replaces the file,
// invalidating cached AI responses (the cache key includes it).
export const notebookSources = pgTable(
  "notebook_sources",
  {
    id: id(),
    notebookId: text("notebook_id")
      .notNull()
      .references(() => notebooks.id, { onDelete: "cascade" }),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    title: text("title").notNull(),
    sourceType: notebookSourceTypeEnum("source_type").notNull().default("pasted"),
    content: text("content").notNull().default(""),
    status: notebookSourceStatusEnum("status").notNull().default("processing"),
    errorMessage: text("error_message"),
    wordCount: integer("word_count"),
    pageCount: integer("page_count"),
    meta: jsonb("meta").$type<Record<string, unknown>>(),
    version: integer("version").notNull().default(1),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .notNull()
      .defaultNow()
      .$onUpdate(() => now()),
  },
  (t) => [
    index("sources_notebook_idx").on(t.notebookId),
    index("sources_user_idx").on(t.userId),
  ],
);

// Retrieval units. charStart/charEnd and page let citations point back
// into the original material; `embedding` is intentionally omitted in
// the MVP (keyword-first retrieval — see docs/source-grounded-ai.md).
export const sourceChunks = pgTable(
  "source_chunks",
  {
    id: id(),
    sourceId: text("source_id")
      .notNull()
      .references(() => notebookSources.id, { onDelete: "cascade" }),
    notebookId: text("notebook_id")
      .notNull()
      .references(() => notebooks.id, { onDelete: "cascade" }),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    content: text("content").notNull(),
    chunkIndex: integer("chunk_index").notNull().default(0),
    charStart: integer("char_start").notNull().default(0),
    charEnd: integer("char_end").notNull().default(0),
    page: integer("page"), // from the source's page markers, when known
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [
    index("chunks_source_idx").on(t.sourceId),
    index("chunks_notebook_idx").on(t.notebookId),
  ],
);

// AI response cache. Key = hash(notebook, sourceIds sorted, source
// versions, question, action, mode, model). Invalidated implicitly: any
// source change bumps the version, which changes the key. Cleanup
// deletes entries older than CACHE_TTL_DAYS.
export const aiCache = pgTable(
  "ai_cache",
  {
    id: id(),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    notebookId: text("notebook_id")
      .notNull()
      .references(() => notebooks.id, { onDelete: "cascade" }),
    key: text("key").notNull().unique(),
    payload: jsonb("payload").notNull().$type<unknown>(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [index("ai_cache_user_time_idx").on(t.userId, t.createdAt)],
);

// ── usage metering ───────────────────────────────────────────────────
// Monthly counter per user per feature. The row's `limit` is the
// entitlement at the time the period started (free vs premium), so
// upgrading mid-month doesn't retroactively change the count.
export const usage = pgTable(
  "usage",
  {
    id: id(),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    feature: text("feature").notNull(), // e.g. "ai_actions", "documents", "quizzes"
    period: text("period").notNull(), // e.g. "2026-08"
    count: integer("count").notNull().default(0),
    limit: integer("limit").notNull().default(0),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .notNull()
      .defaultNow()
      .$onUpdate(() => now()),
  },
  (t) => [
    unique("usage_user_feature_period_unique").on(t.userId, t.feature, t.period),
  ],
);

// ── AI request log ───────────────────────────────────────────────────
// Every AI call records provider/model/tokens/cost so we can watch
// unit economics per user (the revenue dashboard requirement).
export const aiRequests = pgTable(
  "ai_requests",
  {
    id: id(),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    provider: text("provider").notNull(),
    model: text("model").notNull(),
    feature: text("feature").notNull(), // summary | flashcards | quiz | qa | planner
    inputTokens: integer("input_tokens").notNull().default(0),
    outputTokens: integer("output_tokens").notNull().default(0),
    costUsd: text("cost_usd").notNull().default("0"), // decimal string, computed by provider
    status: aiStatusEnum("status").notNull().default("success"),
    errorCode: text("error_code"),
    latencyMs: integer("latency_ms"),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [
    index("ai_requests_user_time_idx").on(t.userId, t.createdAt),
    index("ai_requests_time_idx").on(t.createdAt),
  ],
);

// ── analytics events ─────────────────────────────────────────────────
// Privacy-conscious: minimal personal data, events only. The admin
// dashboard reads from this table directly.
export const analyticsEvents = pgTable(
  "analytics_events",
  {
    id: id(),
    userId: text("user_id").references(() => user.id, {
      onDelete: "set null",
    }), // nullable: pre-auth events
    eventName: text("event_name").notNull(),
    properties: jsonb("properties").$type<Record<string, unknown>>(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [
    index("events_name_time_idx").on(t.eventName, t.createdAt),
    index("events_user_time_idx").on(t.userId, t.createdAt),
  ],
);

export { sql };
