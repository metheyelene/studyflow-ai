import Link from "next/link";
import {
  ArrowRight,
  BookOpen,
  CalendarClock,
  Check,
  FileText,
  ListChecks,
  MessageCircleQuestion,
  Sparkles,
} from "lucide-react";

import { headers } from "next/headers";

import { FoundingCard } from "@/components/founding-card";
import { ThemeToggle } from "@/components/theme-toggle";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { auth } from "@/lib/auth";
import { getFoundingStatusSafe } from "@/lib/founding";
import { PRICING, PLAN_COPY } from "@/lib/plans";

const features = [
  {
    icon: FileText,
    title: "AI summaries",
    desc: "Short, detailed, key concepts, definitions, and exam-focused points — generated from your own notes.",
  },
  {
    icon: BookOpen,
    title: "Flashcards",
    desc: "Front/back cards auto-generated from your material, with flip animation and progress tracking.",
  },
  {
    icon: ListChecks,
    title: "Quizzes",
    desc: "Practice MCQs with difficulty selection, instant scoring, and explanations for every answer.",
  },
  {
    icon: MessageCircleQuestion,
    title: "Ask your notes",
    desc: "Questions about your material, answered with citations back to the source text.",
  },
  {
    icon: CalendarClock,
    title: "Study planner",
    desc: "A realistic plan built from your exam dates, subjects, and how much time you actually have.",
  },
  {
    icon: Sparkles,
    title: "Exam countdown",
    desc: "Your upcoming exams and the days remaining — a deadline you can see.",
  },
];

const steps = [
  {
    n: "01",
    title: "Add your notes",
    desc: "Paste text or upload a PDF. Extraction happens on our server — your file stays yours.",
  },
  {
    n: "02",
    title: "Pick a study mode",
    desc: "Summaries, flashcards, quizzes, or questions — generated from your material in seconds.",
  },
  {
    n: "03",
    title: "Practice & track",
    desc: "Review cards, retake quizzes, watch your streak grow as your exam approaches.",
  },
];

const faqs = [
  {
    q: "Is my data private?",
    a: "Your notes are only used to generate your study material. We don't sell data, we don't show ads, and you can delete your account and everything in it at any time.",
  },
  {
    q: "What AI models do you use?",
    a: "The service is provider-agnostic — we route to the model that fits each task and cost budget. We never expose keys, and every generation is logged so we can keep costs honest.",
  },
  {
    q: "Can I cancel anytime?",
    a: "Yes. Cancel in one click from Settings, and you keep access until the end of your paid period. No hoops, no retention calls.",
  },
  {
    q: "What if it's not for me?",
    a: "Then it's not for you — no hard feelings. The free plan is genuinely useful, and we'd rather hear what to fix than keep your money.",
  },
];

export default async function LandingPage() {
  const [founding, session] = await Promise.all([
    getFoundingStatusSafe(),
    auth.api.getSession({ headers: await headers() }).catch(() => null),
  ]);

  return (
    <div className="flex min-h-dvh flex-col">
      {/* Nav — floating glass */}
      <header className="sticky top-0 z-20 mx-auto mt-3 w-full max-w-5xl px-4">
        <div className="glass-subtle flex h-14 items-center justify-between rounded-2xl px-4">
          <div className="flex items-center gap-2">
            <div className="bg-primary text-primary-foreground flex size-8 items-center justify-center rounded-xl shadow-sm">
              <BookOpen className="size-4" />
            </div>
            <span className="font-semibold">StudyFlow</span>
          </div>
          <nav className="hidden items-center gap-6 text-sm md:flex">
            <Link href="#how" className="text-muted-foreground hover:text-foreground">
              How it works
            </Link>
            <Link href="#features" className="text-muted-foreground hover:text-foreground">
              Features
            </Link>
            <Link href="#pricing" className="text-muted-foreground hover:text-foreground">
              Pricing
            </Link>
            <Link href="#faq" className="text-muted-foreground hover:text-foreground">
              FAQ
            </Link>
          </nav>
          <div className="flex items-center gap-2">
            <ThemeToggle />
            <Button asChild variant="ghost" size="sm">
              <Link href="/login">Log in</Link>
            </Button>
            <Button asChild size="sm">
              <Link href="/signup">Get started</Link>
            </Button>
          </div>
        </div>
      </header>

      {/* Hero */}
      <section className="relative mx-auto flex w-full max-w-5xl flex-col items-center px-4 pt-20 pb-16 text-center md:pt-28">
        <div
          aria-hidden
          className="bg-primary/15 absolute top-1/2 left-1/2 size-[34rem] -translate-x-1/2 -translate-y-1/2 rounded-full blur-3xl"
        />
        <div className="relative">
          <Badge variant="secondary" className="mb-6">
            AI study tools for students
          </Badge>
          <h1 className="mx-auto max-w-2xl text-4xl font-semibold tracking-tight text-balance md:text-6xl">
            Turn your notes into your smartest study system.
          </h1>
          <p className="text-muted-foreground mx-auto mt-6 max-w-xl text-lg text-pretty">
            Upload or paste your notes and get AI summaries, flashcards, quizzes,
            and a study plan in seconds — built for students preparing for exams.
          </p>
          <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row">
            <Button asChild size="lg">
              <Link href="/signup">
                Start free — no card needed
                <ArrowRight />
              </Link>
            </Button>
            <Button asChild variant="glass-secondary" size="lg">
              <Link href="#how">See how it works</Link>
            </Button>
          </div>
        </div>

        {/* App preview mock */}
        <div className="mt-14 w-full max-w-3xl">
          <div className="glass rounded-3xl p-6">
            <div className="flex items-center justify-between border-b border-border/60 pb-4">
              <div>
                <p className="text-sm font-medium">Cell Biology — Exam in 12 days</p>
                <p className="text-muted-foreground text-xs">Notes · 2,400 words</p>
              </div>
              <Badge variant="secondary">Free plan · 18/20 AI actions</Badge>
            </div>
            <div className="grid gap-3 pt-4 sm:grid-cols-3">
              <div className="glass-subtle rounded-xl p-4">
                <p className="text-xs text-muted-foreground">Summary</p>
                <p className="mt-1 text-sm">
                  Short · Detailed · Key concepts
                </p>
              </div>
              <div className="glass-subtle rounded-xl p-4">
                <p className="text-xs text-muted-foreground">Flashcards</p>
                <p className="mt-1 text-sm">20 cards generated</p>
              </div>
              <div className="glass-subtle rounded-xl p-4">
                <p className="text-xs text-muted-foreground">Quiz</p>
                <p className="mt-1 text-sm">8/10 on last attempt</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* How it works */}
      <section id="how" className="border-t border-border/60">
        <div className="mx-auto max-w-5xl px-4 py-16">
          <h2 className="text-center text-2xl font-semibold tracking-tight md:text-3xl">
            Three steps from notes to exam-ready
          </h2>
          <div className="mt-10 grid gap-4 md:grid-cols-3">
            {steps.map((step) => (
              <div key={step.n} className="glass rounded-2xl p-6">
                <span className="text-primary font-mono text-sm">
                  {step.n}
                </span>
                <h3 className="mt-2 font-medium">{step.title}</h3>
                <p className="text-muted-foreground mt-1 text-sm">{step.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Features */}
      <section id="features" className="mx-auto max-w-5xl px-4 py-16">
        <h2 className="text-center text-2xl font-semibold tracking-tight md:text-3xl">
          Everything you need to study smarter
        </h2>
        <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((f) => (
            <div key={f.title} className="glass rounded-2xl p-6">
              <div className="bg-accent flex size-10 items-center justify-center rounded-xl">
                <f.icon className="text-primary size-5" />
              </div>
              <h3 className="mt-4 font-medium">{f.title}</h3>
              <p className="text-muted-foreground mt-1 text-sm">{f.desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Founding member offer */}
      <section id="founding" className="mx-auto max-w-5xl px-4 py-16">
        <FoundingCard
          claimed={founding.claimed}
          cap={founding.cap}
          remaining={founding.remaining}
          full={founding.full}
          alreadyMember={false}
          isAuthed={!!session}
          available={founding.available}
          compact
        />
      </section>

      {/* Pricing */}
      <section id="pricing" className="border-t border-border/60">
        <div className="mx-auto max-w-5xl px-4 py-16">
          <h2 className="text-center text-2xl font-semibold tracking-tight md:text-3xl">
            Simple, honest pricing
          </h2>
          <p className="text-muted-foreground mt-2 text-center">
            Start free. Upgrade only if it&apos;s actually useful to you.
          </p>
          <div className="mx-auto mt-10 grid max-w-3xl gap-4 md:grid-cols-2">
            <div className="glass rounded-2xl p-6">
              <h3 className="font-medium">{PLAN_COPY.free.name}</h3>
              <p className="mt-2 text-3xl font-semibold">$0</p>
              <p className="text-muted-foreground text-sm">Forever</p>
              <ul className="mt-5 space-y-2 text-sm">
                {PLAN_COPY.free.features.map((f) => (
                  <li key={f} className="flex items-center gap-2">
                    <Check className="text-muted-foreground size-4" />
                    {f}
                  </li>
                ))}
              </ul>
              <Button asChild variant="glass-secondary" className="mt-6 w-full">
                <Link href="/signup">Start free</Link>
              </Button>
            </div>
            <div className="glass-float relative rounded-2xl p-6">
              <div
                aria-hidden
                className="bg-primary/10 absolute -top-12 right-0 size-40 rounded-full blur-3xl"
              />
              <div className="relative flex items-center justify-between">
                <h3 className="font-medium">{PLAN_COPY.premium.name}</h3>
                <Badge>Most popular</Badge>
              </div>
              <p className="relative mt-2 text-3xl font-semibold">
                ${PRICING.monthlyUsd}
                <span className="text-muted-foreground text-sm font-normal">
                  /month
                </span>
              </p>
              <p className="text-muted-foreground relative text-sm">
                or ${PRICING.yearlyUsd}/year — about 2 months free
              </p>
              <ul className="relative mt-5 space-y-2 text-sm">
                {PLAN_COPY.premium.features.map((f) => (
                  <li key={f} className="flex items-center gap-2">
                    <Check className="text-primary size-4" />
                    {f}
                  </li>
                ))}
              </ul>
              <Button asChild className="relative mt-6 w-full">
                <Link href="/signup">Go premium</Link>
              </Button>
            </div>
          </div>
          <p className="text-muted-foreground mx-auto mt-6 max-w-md text-center text-xs">
            Cancel anytime in Settings — you keep access until the end of your
            paid period. No fake discounts, no hidden fees.
          </p>
        </div>
      </section>

      {/* FAQ */}
      <section id="faq" className="mx-auto max-w-3xl px-4 py-16">
        <h2 className="text-center text-2xl font-semibold tracking-tight md:text-3xl">
          Questions, answered honestly
        </h2>
        <div className="mt-8 space-y-3">
          {faqs.map((f) => (
            <details key={f.q} className="glass rounded-2xl px-5 py-4">
              <summary className="cursor-pointer font-medium">{f.q}</summary>
              <p className="text-muted-foreground mt-2 text-sm">{f.a}</p>
            </details>
          ))}
        </div>
      </section>

      {/* CTA */}
      <section className="border-t border-border/60">
        <div className="mx-auto max-w-3xl px-4 py-16 text-center">
          <h2 className="text-2xl font-semibold tracking-tight md:text-3xl">
            Your next exam is closer than you think.
          </h2>
          <p className="text-muted-foreground mt-3">
            Upload one set of notes and see what it can do. Two minutes, free.
          </p>
          <Button asChild size="lg" className="mt-6">
            <Link href="/signup">
              Get started free
              <ArrowRight />
            </Link>
          </Button>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-border/60">
        <div className="mx-auto flex max-w-5xl flex-col items-center justify-between gap-3 px-4 py-8 text-sm md:flex-row">
          <div className="flex items-center gap-2">
            <div className="bg-primary text-primary-foreground flex size-6 items-center justify-center rounded-lg">
              <BookOpen className="size-3.5" />
            </div>
            <span className="font-medium">StudyFlow AI</span>
          </div>
          <p className="text-muted-foreground text-xs">
            Built by one person. No fake reviews, no hype — just a study tool.
          </p>
        </div>
      </footer>
    </div>
  );
}
