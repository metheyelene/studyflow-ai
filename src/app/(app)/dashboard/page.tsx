import { headers } from "next/headers";
import Link from "next/link";
import { redirect } from "next/navigation";
import {
  ArrowRight,
  BookOpen,
  CalendarClock,
  FileText,
  Flame,
  GraduationCap,
  ListChecks,
  MessagesSquare,
  NotebookPen,
  Sparkles,
  Target,
  Timer,
} from "lucide-react";

import { and, count, eq, gte, isNotNull } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";
import { getFoundingStatusSafe } from "@/lib/founding";
import { getPlanForSession } from "@/lib/premium";
import { getAiUsage } from "@/lib/usage";
import { AiUsageWidget } from "@/components/ai-usage-widget";
import { FoundingCard } from "@/components/founding-card";
import { PremiumFeatureCard } from "@/components/premium-feature-card";
import { Card, CardContent } from "@/components/ui/card";
import { GlassCard } from "@/components/ui/glass";
import { Greeting } from "./greeting";

const QUICK_ACTIONS = [
  {
    icon: FileText,
    label: "Upload Notes",
    href: "/notebooks",
    hint: "PDF, DOCX, or paste",
  },
  {
    icon: Sparkles,
    label: "Create Summary",
    href: "/notebooks",
    hint: "AI from your sources",
  },
  {
    icon: BookOpen,
    label: "Flashcards",
    href: "/notebooks",
    hint: "Source-grounded",
  },
  {
    icon: ListChecks,
    label: "Generate Quiz",
    href: "/notebooks",
    hint: "Practice MCQs",
  },
  {
    icon: CalendarClock,
    label: "Study Plan",
    href: "/planner",
    hint: "From your exams",
  },
];

function daysUntil(date: Date): number {
  return Math.max(0, Math.ceil((date.getTime() - Date.now()) / (1000 * 60 * 60 * 24)));
}

export default async function DashboardPage() {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) redirect("/login");

  const db = getDb();
  const userId = session.user.id;

  const profile = await db.query.profiles.findFirst({
    where: eq(schema.profiles.userId, userId),
  });
  if (!profile?.onboardingCompleted) redirect("/onboarding");

  const firstName = session.user.name.split(" ")[0];

  // ── Real data across every section (all auth-scoped) ──────────────
  const [nextExam, upcomingExams, notesCount, notebooks, attempts, sourcesCount] = await Promise.all([
    db.query.exams.findFirst({
      where: and(eq(schema.exams.userId, userId), gte(schema.exams.examDate, new Date())),
      orderBy: (e, { asc }) => [asc(e.examDate)],
    }),
    db.query.exams.findMany({
      where: and(eq(schema.exams.userId, userId), gte(schema.exams.examDate, new Date())),
      orderBy: (e, { asc }) => [asc(e.examDate)],
      limit: 3,
    }),
    db
      .select({ count: count() })
      .from(schema.notes)
      .where(eq(schema.notes.userId, userId))
      .then((r) => r[0]?.count ?? 0),
    db.query.notebooks.findMany({
      where: eq(schema.notebooks.userId, userId),
      orderBy: (t, { desc }) => [desc(t.updatedAt)],
      limit: 3,
    }),
    db.query.quizAttempts.findMany({
      where: and(
        eq(schema.quizAttempts.userId, userId),
        isNotNull(schema.quizAttempts.completedAt),
      ),
      columns: { score: true, totalQuestions: true },
      limit: 200,
    }),
    db
      .select({ count: count() })
      .from(schema.notebookSources)
      .where(eq(schema.notebookSources.userId, userId))
      .then((r) => r[0]?.count ?? 0),
  ]);

  const planContext = await getPlanForSession();
  const usage = planContext ? await getAiUsage(planContext.userId, planContext.plan) : null;

  const founding = await getFoundingStatusSafe();
  const isFoundingMember = planContext?.subscriptionPlan === "founding_member";

  // ── Derived values ─────────────────────────────────────────────────
  const streakDays = profile.studyStreak ?? 0;
  const quizzesCompleted = attempts.length;
  const avgScorePct =
    quizzesCompleted > 0
      ? Math.round(
          (attempts.reduce((sum, a) => sum + (a.totalQuestions > 0 ? a.score / a.totalQuestions : 0), 0) /
            quizzesCompleted) *
            100,
        )
      : null;

  // Recommended activity — real, exam-first, then continuation, then start.
  let recommended: { title: string; body: string; href: string; cta: string };
  if (nextExam) {
    const d = daysUntil(nextExam.examDate);
    recommended = {
      title: `Focus on ${nextExam.title}`,
      body:
        d <= 3
          ? `${d} day${d === 1 ? "" : "s"} to go — this is prime revision time. Review your notes and run a practice quiz.`
          : `${d} days to go. Keep a steady pace — summarize your notes and quiz yourself weekly.`,
      href: "/planner",
      cta: "View countdown",
    };
  } else if (notebooks.length > 0) {
    recommended = {
      title: `Continue: ${notebooks[0].title}`,
      body: "Pick up where you left off — ask questions and turn this notebook into study material.",
      href: `/notebooks/${notebooks[0].id}`,
      cta: "Open notebook",
    };
  } else {
    recommended = {
      title: "Start your first notebook",
      body: "Paste your notes or upload a PDF — StudyFlow AI answers only from your material, with citations.",
      href: "/notebooks",
      cta: "Create notebook",
    };
  }

  const focusLine =
    usage && usage.used > 0
      ? `${usage.remaining} AI actions left this month.`
      : nextExam
        ? `${nextExam.title} is in ${daysUntil(nextExam.examDate)} days — make today count.`
        : streakDays > 0
          ? `Day ${streakDays} of your streak — keep it going.`
          : "Upload your first note to start building a study system.";

  return (
    <div className="mx-auto max-w-5xl space-y-8">
      {/* Time-based greeting */}
      <Greeting firstName={firstName} />

      {/* Today's Focus — floating hero */}
      <GlassCard tone="floating" className="relative overflow-hidden p-6 md:p-8">
        <div aria-hidden className="bg-primary/10 absolute -top-24 -right-16 size-64 rounded-full blur-3xl" />
        <div className="relative flex flex-col items-start justify-between gap-6 sm:flex-row sm:items-center">
          <div className="max-w-md">
            <p className="text-muted-foreground text-sm font-medium uppercase tracking-wider">
              Today&apos;s Focus
            </p>
            <h2 className="mt-1 text-xl font-semibold md:text-2xl">{focusLine}</h2>
            <p className="text-muted-foreground mt-2 text-sm">{recommended.body}</p>
            <Link
              href={recommended.href}
              className="bg-primary text-primary-foreground mt-5 inline-flex h-9 items-center gap-2 rounded-md px-4 text-sm font-medium shadow-sm transition-all hover:bg-primary/90 active:scale-[0.98]"
            >
              {recommended.cta}
              <ArrowRight className="size-4" />
            </Link>
          </div>

          {usage && (
            <div className="flex items-center gap-4">
              <ProgressRing percent={usage.percent} label={`${usage.used}/${usage.limit}`} />
              <div className="text-sm">
                <p className="text-muted-foreground">AI actions</p>
                <p className="font-medium">resets on the 1st</p>
              </div>
            </div>
          )}
        </div>
      </GlassCard>

      {/* Quick actions — floating glass buttons */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
        {QUICK_ACTIONS.map((action) => (
          <Link
            key={action.label}
            href={action.href}
            className="glass-float group flex flex-col items-center gap-2 rounded-2xl px-3 py-4 text-center transition-all duration-150 hover:-translate-y-0.5 hover:shadow-lg active:scale-[0.97]"
          >
            <action.icon className="text-primary size-5 transition-transform duration-150 group-hover:scale-110" />
            <span className="text-sm font-medium">{action.label}</span>
            <span className="text-muted-foreground text-[11px]">{action.hint}</span>
          </Link>
        ))}
      </div>

      {/* Today — recommended activity, upcoming exam, recent notebooks */}
      <div className="grid gap-4 lg:grid-cols-3">
        <GlassCard tone="primary" className="p-5 lg:col-span-2">
          <div className="text-muted-foreground flex items-center gap-2 text-xs font-semibold tracking-wider uppercase">
            <Target className="text-primary size-4" /> Recommended activity
          </div>
          <h3 className="mt-2 font-semibold">{recommended.title}</h3>
          <p className="text-muted-foreground mt-1 text-sm">{recommended.body}</p>
          <Link
            href={recommended.href}
            className="text-primary hover:underline mt-3 inline-flex items-center gap-1 text-sm font-medium"
          >
            {recommended.cta} <ArrowRight className="size-3.5" />
          </Link>
        </GlassCard>

        <GlassCard tone="primary" className="p-5">
          <div className="text-muted-foreground flex items-center gap-2 text-xs font-semibold tracking-wider uppercase">
            <CalendarClock className="text-primary size-4" /> Upcoming
          </div>
          {upcomingExams.length > 0 ? (
            <ul className="mt-3 space-y-2.5">
              {upcomingExams.map((exam) => (
                <li key={exam.id} className="flex items-center justify-between gap-2">
                  <div className="min-w-0">
                    <p className="truncate text-sm font-medium">{exam.title}</p>
                    <p className="text-muted-foreground text-xs">
                      {exam.examDate.toLocaleDateString(undefined, {
                        month: "short",
                        day: "numeric",
                      })}
                    </p>
                  </div>
                  <span className="bg-primary/10 text-primary rounded-full px-2 py-0.5 text-xs font-medium tabular-nums">
                    {daysUntil(exam.examDate)}d
                  </span>
                </li>
              ))}
            </ul>
          ) : (
            <div className="mt-3">
              <p className="text-sm">No exams yet</p>
              <p className="text-muted-foreground mt-0.5 text-xs">
                Add exams in Planner and we&apos;ll count down here.
              </p>
            </div>
          )}
          {notebooks.length > 0 && (
            <>
              <div className="text-muted-foreground mt-5 flex items-center gap-2 text-xs font-semibold tracking-wider uppercase">
                <NotebookPen className="text-primary size-4" /> Recent notebooks
              </div>
              <ul className="mt-2 space-y-1.5">
                {notebooks.map((nb) => (
                  <li key={nb.id}>
                    <Link
                      href={`/notebooks/${nb.id}`}
                      className="hover:text-foreground text-muted-foreground hover:bg-[--glass-bg-subtle] flex items-center justify-between gap-2 rounded-lg px-2 py-1.5 text-sm transition-colors"
                    >
                      <span className="truncate font-medium">{nb.title}</span>
                      <ArrowRight className="size-3.5 shrink-0" />
                    </Link>
                  </li>
                ))}
              </ul>
            </>
          )}
        </GlassCard>
      </div>

      {/* Progress — real stats */}
      <div>
        <h2 className="mb-3 text-lg font-medium">Your progress</h2>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <Card>
            <CardContent className="gap-1">
              <div className="text-muted-foreground flex items-center gap-2 text-sm">
                <Flame className="text-primary size-4" /> Study streak
              </div>
              <p className="text-2xl font-semibold">
                {streakDays} day{streakDays === 1 ? "" : "s"}
              </p>
              <p className="text-muted-foreground text-xs">Keep a daily study habit</p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="gap-1">
              <div className="text-muted-foreground flex items-center gap-2 text-sm">
                <ListChecks className="text-primary size-4" /> Quizzes completed
              </div>
              <p className="text-2xl font-semibold">{quizzesCompleted}</p>
              <p className="text-muted-foreground text-xs">
                {quizzesCompleted === 0
                  ? "Take a quiz in any notebook"
                  : "Across your notebooks"}
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="gap-1">
              <div className="text-muted-foreground flex items-center gap-2 text-sm">
                <Target className="text-primary size-4" /> Average quiz score
              </div>
              <p className="text-2xl font-semibold">
                {avgScorePct === null ? "—" : `${avgScorePct}%`}
              </p>
              <p className="text-muted-foreground text-xs">
                {avgScorePct === null ? "Appears after your first quiz" : "Across completed quizzes"}
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="gap-1">
              <div className="text-muted-foreground flex items-center gap-2 text-sm">
                <FileText className="text-primary size-4" /> Notes created
              </div>
              <p className="text-2xl font-semibold">{notesCount}</p>
              <p className="text-muted-foreground text-xs">
                {sourcesCount > 0
                  ? `+ ${sourcesCount} source${sourcesCount === 1 ? "" : "s"} indexed`
                  : "Notes & sources live in notebooks"}
              </p>
            </CardContent>
          </Card>
        </div>
      </div>

      {/* AI usage */}
      {usage ? (
        <AiUsageWidget usage={usage} />
      ) : (
        <Card>
          <CardContent className="gap-1">
            <div className="text-muted-foreground flex items-center gap-2 text-sm">
              <Sparkles className="text-primary size-4" /> AI usage
            </div>
            <p className="text-2xl font-semibold">—</p>
            <p className="text-muted-foreground text-xs">Appears once you start studying</p>
          </CardContent>
        </Card>
      )}

      {/* Founding-member offer — only while genuinely open */}
      {((founding.available && !founding.full) || isFoundingMember) && (
        <FoundingCard
          claimed={founding.claimed}
          cap={founding.cap}
          remaining={founding.remaining}
          full={founding.full}
          alreadyMember={isFoundingMember}
          isAuthed
          available={founding.available}
          compact
        />
      )}

      {/* Premium features — discovery without spam */}
      <div>
        <h2 className="mb-3 text-lg font-medium">Go further</h2>
        <div className="grid gap-4 sm:grid-cols-3">
          <PremiumFeatureCard
            icon={GraduationCap}
            title="Smart Study Mode"
            description="What to study, review, and quiz today — personalized from your material."
            preview="Day 1: Cell Biology — review flashcards, quiz weak topic: Mitochondria…"
          />
          <PremiumFeatureCard
            icon={MessagesSquare}
            title="AI Study Tutor"
            description="Ask anything about your notes. Get explanations, examples, and exam-focused answers."
            preview="Teach me glycolysis like I'm a beginner…"
          />
          <PremiumFeatureCard
            icon={Timer}
            title="Exam Simulation"
            description="A timed, mixed-topic exam from your own material, with a weak-area analysis after."
            preview="30 questions · 45 minutes · scored + explained"
          />
        </div>
      </div>
    </div>
  );
}

function ProgressRing({ percent, label }: { percent: number; label: string }) {
  const r = 34;
  const c = 2 * Math.PI * r;
  const filled = Math.min(100, Math.max(0, percent));
  return (
    <div className="relative size-20 shrink-0">
      <svg viewBox="0 0 80 80" className="size-20 -rotate-90">
        <circle cx="40" cy="40" r={r} fill="none" strokeWidth="6" className="stroke-foreground/10" />
        <circle
          cx="40"
          cy="40"
          r={r}
          fill="none"
          strokeWidth="6"
          strokeLinecap="round"
          strokeDasharray={c}
          strokeDashoffset={c * (1 - filled / 100)}
          className="stroke-primary transition-all duration-500"
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="text-sm font-semibold tabular-nums">{label}</span>
      </div>
    </div>
  );
}
