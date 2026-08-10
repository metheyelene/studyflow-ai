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
  Sparkles,
  Timer,
} from "lucide-react";

import { and, eq, gte } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";
import { getPlanForSession } from "@/lib/premium";
import { getAiUsage } from "@/lib/usage";
import { AiUsageWidget } from "@/components/ai-usage-widget";
import { PremiumFeatureCard } from "@/components/premium-feature-card";
import { Card, CardContent } from "@/components/ui/card";
import { GlassCard } from "@/components/ui/glass";
import { Greeting } from "./greeting";

const QUICK_ACTIONS = [
  {
    icon: FileText,
    label: "Upload Notes",
    href: "/notes",
    hint: "PDF or text",
  },
  {
    icon: Sparkles,
    label: "Summarize",
    href: "/notes",
    hint: "AI in seconds",
  },
  {
    icon: BookOpen,
    label: "Flashcards",
    href: "/flashcards",
    hint: "Auto-generated",
  },
  {
    icon: ListChecks,
    label: "Quiz",
    href: "/quizzes",
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
  return Math.max(
    0,
    Math.ceil((date.getTime() - Date.now()) / (1000 * 60 * 60 * 24)),
  );
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

  const nextExam = await db.query.exams.findFirst({
    where: and(
      eq(schema.exams.userId, userId),
      gte(schema.exams.examDate, new Date()),
    ),
    orderBy: (e, { asc }) => [asc(e.examDate)],
  });

  const planContext = await getPlanForSession();
  const usage = planContext
    ? await getAiUsage(planContext.userId, planContext.plan)
    : null;

  const streakDays = profile.studyStreak ?? 0;
  const focusLine =
    usage && usage.used > 0
      ? `${usage.remaining} AI actions left this month.`
      : streakDays > 0
        ? `Day ${streakDays} of your streak — keep it going.`
        : "Upload your first note to start building a study system.";

  return (
    <div className="mx-auto max-w-5xl space-y-8">
      {/* Time-based greeting */}
      <Greeting firstName={firstName} />

      {/* Today's Focus — floating hero */}
      <GlassCard tone="floating" className="relative overflow-hidden p-6 md:p-8">
        <div
          aria-hidden
          className="bg-primary/10 absolute -top-24 -right-16 size-64 rounded-full blur-3xl"
        />
        <div className="relative flex flex-col items-start justify-between gap-6 sm:flex-row sm:items-center">
          <div className="max-w-md">
            <p className="text-muted-foreground text-sm font-medium uppercase tracking-wider">
              Today&apos;s Focus
            </p>
            <h2 className="mt-1 text-xl font-semibold md:text-2xl">
              {focusLine}
            </h2>
            <p className="text-muted-foreground mt-2 text-sm">
              {nextExam
                ? `${nextExam.title} is in ${daysUntil(nextExam.examDate)} days.`
                : "Add an exam and we'll build your countdown."}
            </p>
            <Link
              href="/notes"
              className="bg-primary text-primary-foreground mt-5 inline-flex h-9 items-center gap-2 rounded-md px-4 text-sm font-medium shadow-sm transition-all hover:bg-primary/90 active:scale-[0.98]"
            >
              Add your first note
              <ArrowRight className="size-4" />
            </Link>
          </div>

          {usage && (
            <div className="flex items-center gap-4">
              <ProgressRing
                percent={usage.percent}
                label={`${usage.used}/${usage.limit}`}
              />
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
            <span className="text-muted-foreground text-[11px]">
              {action.hint}
            </span>
          </Link>
        ))}
      </div>

      {/* Exam countdown — floating widget */}
      <GlassCard tone="floating" className="relative overflow-hidden p-6">
        <div
          aria-hidden
          className="bg-primary/15 absolute -top-20 right-0 size-56 rounded-full blur-3xl"
        />
        <div className="relative flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
          <div>
            <p className="text-muted-foreground text-xs font-medium uppercase tracking-wider">
              Next exam
            </p>
            {nextExam ? (
              <>
                <h3 className="mt-1 text-2xl font-semibold">
                  {nextExam.title}
                </h3>
                <p className="text-muted-foreground mt-1 text-sm">
                  {nextExam.examDate.toLocaleDateString(undefined, {
                    weekday: "long",
                    month: "long",
                    day: "numeric",
                  })}
                </p>
              </>
            ) : (
              <>
                <h3 className="mt-1 text-lg font-medium">No exams yet</h3>
                <p className="text-muted-foreground mt-1 text-sm">
                  Add one in Planner and we&apos;ll show a countdown here.
                </p>
              </>
            )}
          </div>
          {nextExam && (
            <div className="flex items-center gap-3">
              <p className="text-4xl font-semibold tracking-tight tabular-nums">
                {daysUntil(nextExam.examDate)}
              </p>
              <p className="text-muted-foreground text-sm leading-tight">
                days
                <br />
                to go
              </p>
            </div>
          )}
        </div>
      </GlassCard>

      {/* Status widgets */}
      <div className="grid gap-4 sm:grid-cols-3">
        <Card>
          <CardContent className="gap-1">
            <div className="text-muted-foreground flex items-center gap-2 text-sm">
              <Flame className="text-primary size-4" />
              Study streak
            </div>
            <p className="text-2xl font-semibold">
              {streakDays} day{streakDays === 1 ? "" : "s"}
            </p>
            <p className="text-muted-foreground text-xs">
              Tracks daily study — arrives with notes
            </p>
          </CardContent>
        </Card>
        {usage ? (
          <AiUsageWidget usage={usage} />
        ) : (
          <Card>
            <CardContent className="gap-1">
              <div className="text-muted-foreground flex items-center gap-2 text-sm">
                <Sparkles className="text-primary size-4" />
                AI usage
              </div>
              <p className="text-2xl font-semibold">—</p>
              <p className="text-muted-foreground text-xs">
                Appears once you start studying
              </p>
            </CardContent>
          </Card>
        )}
        <Card>
          <CardContent className="gap-1">
            <div className="text-muted-foreground flex items-center gap-2 text-sm">
              <CalendarClock className="text-primary size-4" />
              Quiz performance
            </div>
            <p className="text-2xl font-semibold">—</p>
            <p className="text-muted-foreground text-xs">
              Arrives with quizzes in Week 3
            </p>
          </CardContent>
        </Card>
      </div>

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

function ProgressRing({
  percent,
  label,
}: {
  percent: number;
  label: string;
}) {
  const r = 34;
  const c = 2 * Math.PI * r;
  const filled = Math.min(100, Math.max(0, percent));
  return (
    <div className="relative size-20 shrink-0">
      <svg viewBox="0 0 80 80" className="size-20 -rotate-90">
        <circle
          cx="40"
          cy="40"
          r={r}
          fill="none"
          strokeWidth="6"
          className="stroke-foreground/10"
        />
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
