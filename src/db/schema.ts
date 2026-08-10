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
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .notNull()
      .defaultNow()
      .$onUpdate(() => now()),
  },
  (t) => [index("notes_user_updated_idx").on(t.userId, t.updatedAt)],
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
