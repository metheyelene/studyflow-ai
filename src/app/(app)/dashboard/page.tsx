import { headers } from "next/headers";
import { redirect } from "next/navigation";
import {
  BookOpen,
  CalendarClock,
  FileText,
  Flame,
  ListChecks,
  Sparkles,
  Zap,
} from "lucide-react";

import { eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";
import { Card, CardContent } from "@/components/ui/card";

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

  const widgets = [
    {
      icon: Flame,
      title: "Study streak",
      value: `${profile.studyStreak} day${profile.studyStreak === 1 ? "" : "s"}`,
      hint: "Tracks daily study — arrives with notes",
    },
    {
      icon: CalendarClock,
      title: "Next exam",
      value: "—",
      hint: "Countdown appears here",
    },
    {
      icon: Zap,
      title: "AI actions left",
      value: "20 / 20",
      hint: "Usage metering arrives in Week 3",
    },
  ];

  const starters = [
    {
      icon: FileText,
      title: "Add your notes",
      desc: "Paste text or upload a PDF — your notes become study material.",
      when: "Week 2",
      href: "/app/notes",
    },
    {
      icon: Sparkles,
      title: "Generate summaries",
      desc: "Short, detailed, key concepts, definitions, and exam points.",
      when: "Week 3",
      href: "/app/notes",
    },
    {
      icon: BookOpen,
      title: "Make flashcards",
      desc: "Auto-generated front/back cards with flip and review.",
      when: "Week 3",
      href: "/app/flashcards",
    },
    {
      icon: ListChecks,
      title: "Take quizzes",
      desc: "MCQs with difficulty, score, and explanations.",
      when: "Week 3",
      href: "/app/quizzes",
    },
  ];

  return (
    <div className="mx-auto max-w-5xl space-y-8">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">
          Welcome back, {firstName}
        </h1>
        <p className="text-muted-foreground mt-1">
          {profile.course ? `${profile.course} · ` : ""}Ready to turn your notes
          into a study system?
        </p>
      </div>

      {/* Status widgets */}
      <div className="grid gap-4 sm:grid-cols-3">
        {widgets.map((w) => (
          <Card key={w.title}>
            <CardContent className="gap-1">
              <div className="text-muted-foreground flex items-center gap-2 text-sm">
                <w.icon className="size-4" />
                {w.title}
              </div>
              <p className="text-2xl font-semibold">{w.value}</p>
              <p className="text-muted-foreground text-xs">{w.hint}</p>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Feature starters */}
      <div>
        <h2 className="mb-3 text-lg font-medium">Get started</h2>
        <div className="grid gap-4 sm:grid-cols-2">
          {starters.map((s) => (
            <Card key={s.title} className="transition-colors hover:bg-accent/50">
              <CardContent className="gap-2">
                <div className="flex items-center justify-between">
                  <div className="bg-accent flex size-9 items-center justify-center rounded-lg">
                    <s.icon className="size-4" />
                  </div>
                  <span className="text-muted-foreground text-xs">{s.when}</span>
                </div>
                <p className="font-medium">{s.title}</p>
                <p className="text-muted-foreground text-sm">{s.desc}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </div>
  );
}
