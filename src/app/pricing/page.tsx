import { headers } from "next/headers";
import Link from "next/link";
import { BookOpen } from "lucide-react";

import { FoundingCard } from "@/components/founding-card";
import { auth } from "@/lib/auth";
import { getFoundingStatusSafe, isFoundingMember } from "@/lib/founding";
import { PRICING } from "@/lib/plans";
import { PricingTable } from "./pricing-table";

const FAQS = [
  {
    q: "What happens when I reach the free AI limit?",
    a: "You\u2019ll see exactly how many actions you have left as you approach the limit. When you hit it, we explain when it resets (the 1st of every month) and what Premium includes \u2014 you\u2019re never locked out of your saved notes.",
  },
  {
    q: "Can I cancel anytime?",
    a: "Yes \u2014 cancel in one click from the billing page. You keep Premium until the end of the period you paid for, then drop back to Free automatically. No hoops.",
  },
  {
    q: "Is there a free trial?",
    a: "Not yet \u2014 we\u2019d rather show you the value than sign you up for something you\u2019ll forget about. Free gives you 20 AI actions a month, and Premium previews let you see what you\u2019d get before paying.",
  },
  {
    q: "What does Premium cost to operate?",
    a: "That\u2019s our job to manage, not yours \u2014 but you should know AI costs real money per request, which is why Premium has a generous 500-action monthly allowance rather than \u2018unlimited\u2019. Everything is explained in our plans documentation.",
  },
  {
    q: "Who\u2019s this for?",
    a: "Students preparing for exams. Free is genuinely useful on its own; Premium is for students who study from a lot of material and want summaries, quizzes, flashcards, and a plan that adapts to them.",
  },
];

export default async function PricingPage() {
  const [founding, session] = await Promise.all([
    getFoundingStatusSafe(),
    auth.api.getSession({ headers: await headers() }).catch(() => null),
  ]);
  const alreadyMember = session
    ? await isFoundingMember(session.user.id).catch(() => false)
    : false;

  return (
    <div className="text-foreground min-h-dvh">
      <header className="sticky top-0 z-20 mx-auto mt-3 w-full max-w-5xl px-4">
        <div className="border-2 border-border bg-background flex h-14 items-center justify-between px-4">
          <Link href="/" className="flex items-center gap-2 font-black uppercase tracking-tight text-sm">
            <div className="bg-foreground text-background flex size-8 items-center justify-center">
              <BookOpen className="size-4" />
            </div>
            StudyFlow
          </Link>
          <nav className="flex items-center gap-3 text-sm">
            <Link href="/login" className="text-muted-foreground hover:text-foreground font-bold uppercase tracking-wider">
              Log in
            </Link>
            <Link
              href="/signup"
              className="bg-foreground text-background px-4 py-1.5 font-bold uppercase tracking-wider text-xs"
            >
              Get started
            </Link>
          </nav>
        </div>
      </header>

      <main className="relative mx-auto max-w-5xl px-4 pt-12 pb-20">
        <div className="relative mx-auto max-w-xl text-center">
          <h1 className="font-black text-3xl uppercase tracking-tight">
            Simple, honest pricing
          </h1>
          <p className="text-muted-foreground mt-3">
            Free is genuinely useful. Premium turns one set of notes into
            summaries, flashcards, quizzes, weak-topic analysis, and a
            revision plan \u2014 priced so you save ~33% paying yearly.
          </p>
          <p className="text-muted-foreground mt-2 text-sm">
            Free &middot; $0 &mdash; Premium &middot; ${PRICING.monthlyUsd}/month or ${PRICING.yearlyUsd}/year
          </p>
        </div>

        <section className="mt-10">
          <FoundingCard
            claimed={founding.claimed}
            cap={founding.cap}
            remaining={founding.remaining}
            full={founding.full}
            alreadyMember={alreadyMember}
            isAuthed={!!session}
            available={founding.available}
          />
        </section>

        <PricingTable />

        <section className="mx-auto mt-16 max-w-2xl space-y-4">
          <h2 className="text-center font-black uppercase tracking-tight text-lg">Questions</h2>
          {FAQS.map((f) => (
            <details
              key={f.q}
              className="border-2 border-border bg-card px-5 py-4 [&_summary]:cursor-pointer"
            >
              <summary className="text-sm font-bold uppercase tracking-wider">{f.q}</summary>
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
            \u2014 we answer students directly.
          </p>
        </div>
      </main>
    </div>
  );
}
