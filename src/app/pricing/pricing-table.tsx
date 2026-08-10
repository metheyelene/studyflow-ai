"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Check, Minus } from "lucide-react";

import { PRICING } from "@/lib/plans";
import { trackEventAction } from "@/lib/analytics-actions";
import { Button } from "@/components/ui/button";

interface Row {
  feature: string;
  free: string | boolean;
  premium: string | boolean;
}

const ROWS: Row[] = [
  { feature: "Paste unlimited notes", free: true, premium: true },
  { feature: "Basic summaries (short, key concepts)", free: true, premium: true },
  { feature: "AI Study Tutor (chat with your notes)", free: "5 msgs/mo preview", premium: "Deep conversations" },
  { feature: "Flashcards", free: "100 cards/mo", premium: "Smart review + weak-card priority" },
  { feature: "Quizzes", free: "Up to 10 questions", premium: "Adaptive, weak-topic, exam mode" },
  { feature: "Study planner", free: "Basic", premium: "Smart — adapts to your progress" },
  { feature: "PDF analysis", free: "Text → notes", premium: "Chapter summaries + topic extraction" },
  { feature: "Progress analytics", free: "Streak basics", premium: "Strengths, gaps, consistency" },
  { feature: "Exam simulation", free: false, premium: "Timed, mixed topics, analysis" },
  { feature: "Smart Study Mode — what to study today", free: false, premium: true },
  { feature: "AI actions / month", free: "20", premium: "500" },
  { feature: "Documents", free: "3", premium: "50" },
  { feature: "Subjects", free: "1", premium: "20" },
];

export function PricingTable() {
  const [yearly, setYearly] = useState(true);

  useEffect(() => {
    void trackEventAction("pricing_viewed");
  }, []);

  const price = yearly ? PRICING.yearlyUsd : PRICING.monthlyUsd;
  const perMonth = yearly ? (PRICING.yearlyUsd / 12).toFixed(2) : PRICING.monthlyUsd.toFixed(2);

  return (
    <div className="mx-auto mt-10 max-w-3xl">
      {/* Billing toggle */}
      <div className="mb-6 flex items-center justify-center gap-3 text-sm">
        <span className={yearly ? "text-muted-foreground" : "font-medium"}>Monthly</span>
        <button
          onClick={() => setYearly((v) => !v)}
          role="switch"
          aria-checked={yearly}
          className="bg-primary relative h-6 w-11 rounded-full transition-colors"
        >
          <span
            className={`bg-background absolute top-0.5 size-5 rounded-full transition-transform ${
              yearly ? "translate-x-[22px]" : "translate-x-0.5"
            }`}
          />
        </button>
        <span className={!yearly ? "text-muted-foreground" : "font-medium"}>
          Yearly
          <span className="ml-1.5 rounded-full bg-emerald-500/15 px-2 py-0.5 text-xs font-semibold text-emerald-600 dark:text-emerald-400">
            Save ~33%
          </span>
        </span>
      </div>

      <div className="overflow-hidden rounded-xl border">
        {/* Header row */}
        <div className="grid grid-cols-[1.4fr_1fr_1.4fr] gap-2 border-b bg-muted/40 p-4 text-sm">
          <span className="font-medium">What you get</span>
          <span className="text-center font-medium">Free</span>
          <span className="text-center font-medium">Premium</span>
        </div>

        {ROWS.map((row) => (
          <div
            key={row.feature}
            className="grid grid-cols-[1.4fr_1fr_1.4fr] items-center gap-2 border-b px-4 py-2.5 text-sm last:border-b-0"
          >
            <span>{row.feature}</span>
            <Cell value={row.free} />
            <Cell value={row.premium} highlight />
          </div>
        ))}

        {/* CTA row */}
        <div className="grid grid-cols-[1.4fr_1fr_1.4fr] gap-2 border-t bg-muted/40 p-4 text-sm">
          <span className="flex items-center text-xs text-muted-foreground">
            {yearly
              ? `Yearly = $${perMonth}/month billed annually`
              : `Monthly = $${perMonth}/month`}
          </span>
          <span className="text-center">
            <Button asChild variant="outline" size="sm">
              <Link href="/signup">Start free</Link>
            </Button>
          </span>
          <span className="text-center">
            <Button asChild size="sm">
              <Link href="/signup">Get Premium — ${price.toFixed(2)}</Link>
            </Button>
          </span>
        </div>
      </div>

      <p className="text-muted-foreground mt-3 text-center text-xs">
        Yearly price: ${PRICING.yearlyUsd} ($
        {(PRICING.yearlyUsd / 12).toFixed(2)}/mo) vs monthly ${PRICING.monthlyUsd} — you save $
        {((PRICING.monthlyUsd * 12 - PRICING.yearlyUsd).toFixed(2))} a year. Cancel anytime; keep
        access to the end of your period.
      </p>
    </div>
  );
}

function Cell({ value, highlight }: { value: string | boolean; highlight?: boolean }) {
  if (value === true) {
    return (
      <span className={`flex justify-center ${highlight ? "" : "text-muted-foreground"}`}>
        <Check className={`size-4 ${highlight ? "text-emerald-500" : ""}`} />
      </span>
    );
  }
  if (value === false) {
    return (
      <span className="flex justify-center text-muted-foreground">
        <Minus className="size-4" />
      </span>
    );
  }
  return (
    <span className={`text-center ${highlight ? "font-medium" : "text-muted-foreground"}`}>
      {value}
    </span>
  );
}
