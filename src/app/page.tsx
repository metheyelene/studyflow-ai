import Link from "next/link";
import {
  ArrowRight,
  BookOpen,
  CalendarClock,
  FileText,
  ListChecks,
  MessageCircleQuestion,
} from "lucide-react";

import { headers } from "next/headers";

import { ThemeToggle } from "@/components/theme-toggle";
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
      {/* ── NAVIGATION ─────────────────────────────────────────── */}
      <header className="swiss-border-thick sticky top-0 z-20 border-b-4 border-t-0 border-x-0 border-border bg-background">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-6">
          <div className="flex items-center gap-3">
            <div className="bg-foreground text-background flex size-8 items-center justify-center">
              <BookOpen className="size-4" />
            </div>
            <span className="text-xl font-black tracking-tight uppercase">
              StudyFlow
            </span>
          </div>
          <nav className="hidden items-center gap-8 text-sm font-bold uppercase tracking-widest md:flex">
            <Link
              href="#how"
              className="text-muted-foreground hover:text-foreground transition-colors duration-150"
            >
              How it works
            </Link>
            <Link
              href="#features"
              className="text-muted-foreground hover:text-foreground transition-colors duration-150"
            >
              Features
            </Link>
            <Link
              href="#pricing"
              className="text-muted-foreground hover:text-foreground transition-colors duration-150"
            >
              Pricing
            </Link>
            <Link
              href="#faq"
              className="text-muted-foreground hover:text-foreground transition-colors duration-150"
            >
              FAQ
            </Link>
          </nav>
          <div className="flex items-center gap-3">
            <ThemeToggle />
            <Link
              href="/login"
              className="text-sm font-bold uppercase tracking-widest text-muted-foreground hover:text-foreground transition-colors duration-150"
            >
              Log in
            </Link>
            <Link
              href="/signup"
              className="swiss-btn text-xs"
            >
              Get started
            </Link>
          </div>
        </div>
      </header>

      {/* ── HERO ───────────────────────────────────────────────── */}
      <section className="swiss-border-thick border-b-4 relative">
        <div className="mx-auto max-w-7xl">
          <div className="grid grid-cols-1 lg:grid-cols-5">
            {/* Left: Typography */}
            <div className="lg:col-span-3 p-8 md:p-16 lg:p-24">
              <p className="swiss-section-label mb-6">AI study tools for students</p>
              <h1 className="text-5xl md:text-7xl lg:text-8xl xl:text-9xl font-black tracking-tighter leading-[0.9] uppercase">
                Turn your
                <br />
                notes into
                <br />
                <span className="text-swiss-red">your smartest</span>
                <br />
                study system.
              </h1>
              <p className="text-muted-foreground mt-8 max-w-lg text-lg leading-relaxed">
                Upload or paste your notes and get AI summaries, flashcards, quizzes,
                and a study plan in seconds — built for students preparing for exams.
              </p>
              <div className="mt-10 flex flex-col gap-4 sm:flex-row">
                <Link href="/signup" className="swiss-btn">
                  Start free — no card needed
                  <ArrowRight className="size-4" />
                </Link>
                <Link href="#how" className="swiss-btn swiss-btn-secondary">
                  See how it works
                </Link>
              </div>
            </div>

            {/* Right: Geometric Composition */}
            <div className="swiss-border-thick border-l-4 bg-secondary swiss-grid-pattern relative hidden lg:flex items-center justify-center p-16">
              <div className="relative w-full h-full">
                {/* Large circle */}
                <div className="absolute top-[10%] left-[5%] size-48 border-4 border-foreground bg-swiss-red/10" />
                {/* Rectangle */}
                <div className="absolute top-[30%] right-[10%] w-40 h-56 bg-foreground" />
                {/* Small square */}
                <div className="absolute bottom-[20%] left-[20%] size-24 bg-swiss-red" />
                {/* Lines */}
                <div className="absolute top-[60%] left-0 right-0 h-1 bg-foreground" />
                <div className="absolute top-0 bottom-0 left-[45%] w-1 bg-foreground" />
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── HOW IT WORKS ───────────────────────────────────────── */}
      <section id="how" className="swiss-border-thick border-b-4">
        <div className="mx-auto max-w-7xl">
          <div className="grid grid-cols-1 lg:grid-cols-4">
            {/* Section Label */}
            <div className="swiss-border-thick border-r-4 border-b-4 lg:border-b-0 bg-swiss-red p-8 flex items-center">
              <p className="text-white text-sm font-bold uppercase tracking-widest">
                How it works
              </p>
            </div>

            {/* Steps */}
            <div className="lg:col-span-3 grid grid-cols-1 md:grid-cols-3">
              {steps.map((step, i) => (
                <div
                  key={step.n}
                  className={`p-8 md:p-12 ${i < 2 ? "swiss-border-thick border-r-4 border-b-4 md:border-b-0" : "border-b-4 lg:border-b-0 border-foreground"}`}
                >
                  <span className="text-swiss-red text-6xl md:text-7xl font-black">
                    {step.n}
                  </span>
                  <h3 className="mt-6 text-xl font-black uppercase tracking-tight">
                    {step.title}
                  </h3>
                  <p className="text-muted-foreground mt-3 text-sm leading-relaxed">
                    {step.desc}
                  </p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ── FEATURES ───────────────────────────────────────────── */}
      <section id="features" className="swiss-border-thick border-b-4">
        <div className="mx-auto max-w-7xl">
          {/* Section Header */}
          <div className="swiss-border-thick border-b-4 p-8 md:p-12">
            <p className="swiss-section-label mb-4">02. Features</p>
            <h2 className="text-4xl md:text-5xl lg:text-6xl font-black tracking-tighter uppercase">
              Everything you need
              <br />
              to study smarter
            </h2>
          </div>

          {/* Feature Grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
            {features.map((f, i) => (
              <div
                key={f.title}
                className={`swiss-card group ${i < features.length - 1 ? "swiss-border-thick border-r-4 border-b-4 md:border-b-0" : "border-b-4 lg:border-b-0 border-foreground"}`}
              >
                <div className="bg-swiss-red text-white flex size-10 items-center justify-center mb-4">
                  <f.icon className="size-5" />
                </div>
                <h3 className="text-lg font-black uppercase tracking-tight">
                  {f.title}
                </h3>
                <p className="text-muted-foreground mt-2 text-sm leading-relaxed">
                  {f.desc}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── PRICING ────────────────────────────────────────────── */}
      <section id="pricing" className="swiss-border-thick border-b-4">
        <div className="mx-auto max-w-7xl">
          {/* Section Header */}
          <div className="swiss-border-thick border-b-4 p-8 md:p-12">
            <p className="swiss-section-label mb-4">03. Pricing</p>
            <h2 className="text-4xl md:text-5xl lg:text-6xl font-black tracking-tighter uppercase">
              Simple, honest
              <br />
              pricing
            </h2>
            <p className="text-muted-foreground mt-4 max-w-lg">
              Start free. Upgrade only if it&apos;s actually useful to you.
            </p>
          </div>

          {/* Pricing Grid */}
          <div className="grid grid-cols-1 lg:grid-cols-2">
            {/* Free */}
            <div className="swiss-card swiss-border-thick border-r-4 border-b-4 lg:border-b-0">
              <p className="swiss-section-label">Free</p>
              <p className="mt-6 text-6xl md:text-7xl font-black">$0</p>
              <p className="text-muted-foreground mt-2">Forever</p>
              <ul className="mt-8 space-y-3">
                {PLAN_COPY.free.features.map((f) => (
                  <li key={f} className="flex items-center gap-3 text-sm">
                    <span className="text-swiss-red font-bold">✓</span>
                    {f}
                  </li>
                ))}
              </ul>
              <Link href="/signup" className="swiss-btn swiss-btn-secondary mt-8 w-full">
                Start free
              </Link>
            </div>

            {/* Premium */}
            <div className="swiss-card swiss-border-thick border-foreground bg-foreground text-background">
              <div className="flex items-center justify-between">
                <p className="swiss-section-label text-background/70">Premium</p>
                <span className="bg-swiss-red text-white px-3 py-1 text-xs font-bold uppercase tracking-widest">
                  Most popular
                </span>
              </div>
              <p className="mt-6 text-6xl md:text-7xl font-black">
                ${PRICING.monthlyUsd}
                <span className="text-2xl">/mo</span>
              </p>
              <p className="text-background/70 mt-2">
                or ${PRICING.yearlyUsd}/year — about 2 months free
              </p>
              <ul className="mt-8 space-y-3">
                {PLAN_COPY.premium.features.map((f) => (
                  <li key={f} className="flex items-center gap-3 text-sm">
                    <span className="text-swiss-red font-bold">✓</span>
                    {f}
                  </li>
                ))}
              </ul>
              <Link
                href="/signup"
                className="mt-8 w-full inline-flex items-center justify-center gap-2 px-6 py-3 font-bold text-sm uppercase tracking-widest border-2 border-swiss-red bg-swiss-red text-white hover:bg-white hover:text-swiss-red hover:border-swiss-red transition-all duration-150"
              >
                Go premium
              </Link>
            </div>
          </div>

          {/* Pricing note */}
          <div className="swiss-border-thick border-t-4 p-8 text-center">
            <p className="text-muted-foreground text-sm">
              Cancel anytime in Settings — you keep access until the end of your
              paid period. No fake discounts, no hidden fees.
            </p>
          </div>
        </div>
      </section>

      {/* ── FAQ ─────────────────────────────────────────────────── */}
      <section id="faq" className="swiss-border-thick border-b-4">
        <div className="mx-auto max-w-7xl">
          {/* Section Header */}
          <div className="swiss-border-thick border-b-4 p-8 md:p-12">
            <p className="swiss-section-label mb-4">04. FAQ</p>
            <h2 className="text-4xl md:text-5xl lg:text-6xl font-black tracking-tighter uppercase">
              Questions,
              <br />
              answered honestly
            </h2>
          </div>

          {/* FAQ List */}
          <div>
            {faqs.map((f, i) => (
              <details
                key={f.q}
                className={`swiss-border-thick border-b-4 group ${i === faqs.length - 1 ? "border-b-0" : ""}`}
              >
                <summary className="cursor-pointer p-6 md:p-8 flex items-center justify-between hover:bg-secondary transition-colors duration-150">
                  <span className="font-bold uppercase tracking-tight text-lg pr-4">
                    {f.q}
                  </span>
                  <span className="text-swiss-red text-2xl font-bold shrink-0 group-open:rotate-45 transition-transform duration-150">
                    +
                  </span>
                </summary>
                <div className="px-6 md:px-8 pb-6 md:pb-8">
                  <p className="text-muted-foreground leading-relaxed">{f.a}</p>
                </div>
              </details>
            ))}
          </div>
        </div>
      </section>

      {/* ── CTA ────────────────────────────────────────────────── */}
      <section className="swiss-border-thick border-b-4 bg-foreground text-background">
        <div className="mx-auto max-w-7xl p-8 md:p-16 lg:p-24 text-center">
          <h2 className="text-4xl md:text-5xl lg:text-7xl font-black tracking-tighter uppercase">
            Your next exam is
            <br />
            closer than you think.
          </h2>
          <p className="text-background/70 mt-6 max-w-lg mx-auto text-lg">
            Upload one set of notes and see what it can do. Two minutes, free.
          </p>
          <Link
            href="/signup"
            className="mt-8 inline-flex items-center gap-2 px-8 py-4 font-bold text-sm uppercase tracking-widest border-2 border-swiss-red bg-swiss-red text-white hover:bg-white hover:text-swiss-red transition-all duration-150"
          >
            Get started free
            <ArrowRight className="size-4" />
          </Link>
        </div>
      </section>

      {/* ── FOOTER ─────────────────────────────────────────────── */}
      <footer className="swiss-border-thick border-b-4 border-x-4 border-t-4">
        <div className="mx-auto max-w-7xl">
          <div className="grid grid-cols-1 md:grid-cols-4">
            {/* Brand */}
            <div className="swiss-border-thick border-r-4 border-b-4 md:border-b-0 p-8">
              <div className="flex items-center gap-3 mb-4">
                <div className="bg-foreground text-background flex size-8 items-center justify-center">
                  <BookOpen className="size-4" />
                </div>
                <span className="text-xl font-black tracking-tight uppercase">
                  StudyFlow
                </span>
              </div>
              <p className="text-muted-foreground text-sm">
                Built by one person. No fake reviews, no hype — just a study tool.
              </p>
              <Link
                href="/about/creator"
                className="text-sm font-bold mt-4 inline-block hover:text-swiss-red transition-colors duration-150"
              >
                Made by Mithil
              </Link>
            </div>

            {/* Links */}
            <div className="swiss-border-thick border-r-4 border-b-4 md:border-b-0 p-8">
              <p className="swiss-section-label mb-4">Product</p>
              <ul className="space-y-2 text-sm">
                <li><Link href="#features" className="hover:text-swiss-red transition-colors duration-150">Features</Link></li>
                <li><Link href="#pricing" className="hover:text-swiss-red transition-colors duration-150">Pricing</Link></li>
                <li><Link href="#how" className="hover:text-swiss-red transition-colors duration-150">How it works</Link></li>
              </ul>
            </div>

            {/* Legal */}
            <div className="swiss-border-thick border-r-4 border-b-4 md:border-b-0 p-8">
              <p className="swiss-section-label mb-4">Legal</p>
              <ul className="space-y-2 text-sm">
                <li><Link href="/privacy" className="hover:text-swiss-red transition-colors duration-150">Privacy</Link></li>
                <li><Link href="/terms" className="hover:text-swiss-red transition-colors duration-150">Terms</Link></li>
              </ul>
            </div>

            {/* Account */}
            <div className="p-8">
              <p className="swiss-section-label mb-4">Account</p>
              <ul className="space-y-2 text-sm">
                <li><Link href="/login" className="hover:text-swiss-red transition-colors duration-150">Log in</Link></li>
                <li><Link href="/signup" className="hover:text-swiss-red transition-colors duration-150">Sign up</Link></li>
              </ul>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}
