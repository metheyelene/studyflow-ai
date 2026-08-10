import Link from "next/link";
import { BookOpen } from "lucide-react";

import { PRICING } from "@/lib/plans";
import { PricingTable } from "./pricing-table";

const FAQS = [
  {
    q: "What happens when I reach the free AI limit?",
    a: "You'll see exactly how many actions you have left as you approach the limit. When you hit it, we explain when it resets (the 1st of every month) and what Premium includes — you're never locked out of your saved notes.",
  },
  {
    q: "Can I cancel anytime?",
    a: "Yes — cancel in one click from the billing page. You keep Premium until the end of the period you paid for, then drop back to Free automatically. No hoops.",
  },
  {
    q: "Is there a free trial?",
    a: "Not yet — we'd rather show you the value than sign you up for something you'll forget about. Free gives you 20 AI actions a month, and Premium previews let you see what you'd get before paying.",
  },
  {
    q: "What does Premium cost to operate?",
    a: "That's our job to manage, not yours — but you should know AI costs real money per request, which is why Premium has a generous 500-action monthly allowance rather than 'unlimited'. Everything is explained in our plans documentation.",
  },
  {
    q: "Who's this for?",
    a: "Students preparing for exams. Free is genuinely useful on its own; Premium is for students who study from a lot of material and want summaries, quizzes, flashcards, and a plan that adapts to them.",
  },
];

export default function PricingPage() {
  return (
    <div className="bg-background text-foreground min-h-dvh">
      <header className="mx-auto flex h-16 max-w-5xl items-center justify-between px-4">
        <Link href="/" className="flex items-center gap-2 font-semibold">
          <div className="bg-primary text-primary-foreground flex size-8 items-center justify-center rounded-lg">
            <BookOpen className="size-4" />
          </div>
          StudyFlow
        </Link>
        <nav className="flex items-center gap-3 text-sm">
          <Link href="/login" className="text-muted-foreground hover:text-foreground">
            Log in
          </Link>
          <Link
            href="/signup"
            className="bg-primary text-primary-foreground rounded-full px-4 py-1.5 font-medium"
          >
            Get started
          </Link>
        </nav>
      </header>

      <main className="mx-auto max-w-5xl px-4 pt-10 pb-20">
        <div className="mx-auto max-w-xl text-center">
          <h1 className="text-3xl font-semibold tracking-tight">
            Simple, honest pricing
          </h1>
          <p className="text-muted-foreground mt-3">
            Free is genuinely useful. Premium turns one set of notes into
            summaries, flashcards, quizzes, weak-topic analysis, and a
            revision plan — priced so you save ~33% paying yearly.
          </p>
          <p className="text-muted-foreground mt-2 text-sm">
            Free · $0 — Premium · ${PRICING.monthlyUsd}/month or ${PRICING.yearlyUsd}/year
          </p>
        </div>

        <PricingTable />

        <section className="mx-auto mt-16 max-w-2xl space-y-4">
          <h2 className="text-center text-lg font-semibold">Questions</h2>
          {FAQS.map((f) => (
            <details
              key={f.q}
              className="border-border rounded-lg border px-4 py-3 [&_summary]:cursor-pointer"
            >
              <summary className="text-sm font-medium">{f.q}</summary>
              <p className="text-muted-foreground mt-2 text-sm">{f.a}</p>
            </details>
          ))}
        </section>

        <div className="mt-16 text-center">
          <p className="text-muted-foreground text-sm">
            Questions or feedback?{" "}
            <Link href="/login" className="underline underline-offset-4">
              Get in touch
            </Link>{" "}
            — we answer students directly.
          </p>
        </div>
      </main>
    </div>
  );
}
