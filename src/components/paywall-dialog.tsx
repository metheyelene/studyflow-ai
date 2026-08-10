"use client";

import { useEffect } from "react";
import { Check, Sparkles, X } from "lucide-react";

import { PLAN_COPY, PRICING } from "@/lib/plans";
import { trackEventAction } from "@/lib/analytics-actions";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";

const PREMIUM_FEATURES = [
  "Advanced AI Study Tutor — deep conversations about your notes",
  "500 AI actions / month (vs 20 on free)",
  "Advanced PDF analysis — chapter summaries & key concepts",
  "Adaptive quizzes with weak-topic analysis",
  "Smart flashcards with review recommendations",
  "Smart Study Mode — what to study today, personalized",
  "Exam simulations from your material",
  "Progress analytics — strengths, gaps, consistency",
  "50 documents & 20 subjects (vs 3 and 1)",
];

const MONTHLY_EQUIVALENT = PRICING.yearlyUsd / 12;

/**
 * The paywall (docs/premium-conversion.md §4). Honest by construction:
 * benefits first, real prices, yearly savings shown as arithmetic,
 * cancellation rules stated, and a visible free escape hatch on every
 * screen. Never shown as a random popup — open it contextually.
 */
export function PaywallDialog({
  open,
  onOpenChange,
  onUpgrade,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onUpgrade: () => void;
}) {
  useEffect(() => {
    if (open) {
      void trackEventAction("paywall_viewed");
    }
  }, [open]);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[85dvh] overflow-y-auto sm:max-w-xl">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2 text-xl">
            <Sparkles className="size-5 text-amber-500" />
            Study smarter with deeper AI tools
          </DialogTitle>
          <DialogDescription>
            Everything you use on Free, plus the tools that turn one set of
            notes into a complete study system.
          </DialogDescription>
        </DialogHeader>

        <ul className="grid gap-2">
          {PREMIUM_FEATURES.map((f) => (
            <li key={f} className="text-sm flex items-start gap-2">
              <Check className="mt-0.5 size-4 shrink-0 text-emerald-500" />
              {f}
            </li>
          ))}
        </ul>

        <div className="bg-muted/50 grid gap-3 rounded-lg border p-4 sm:grid-cols-2">
          <div>
            <p className="text-muted-foreground text-xs font-medium uppercase tracking-wide">
              Monthly
            </p>
            <p className="mt-1 text-2xl font-semibold">
              ${PRICING.monthlyUsd.toFixed(2)}
              <span className="text-muted-foreground text-sm font-normal"> / month</span>
            </p>
          </div>
          <div className="rounded-md border border-emerald-500/30 bg-emerald-500/[0.06] p-3">
            <p className="text-muted-foreground text-xs font-medium uppercase tracking-wide">
              Yearly — save ~33%
            </p>
            <p className="mt-1 text-2xl font-semibold">
              ${PRICING.yearlyUsd.toFixed(2)}
              <span className="text-muted-foreground text-sm font-normal"> / year</span>
            </p>
            <p className="text-emerald-600 text-xs dark:text-emerald-400">
              ${MONTHLY_EQUIVALENT.toFixed(2)}/mo — {PLAN_COPY.premium.name} for the price of{" "}
              {PLAN_COPY.free.name} + a coffee.
            </p>
          </div>
        </div>

        <p className="text-muted-foreground text-xs">
          Billing is straightforward: pay monthly or yearly, cancel anytime
          from the billing page in one click, and keep Premium access until
          the end of your paid period. No hidden fees.
        </p>

        <div className="flex flex-col gap-2 sm:flex-row">
          <Button className="flex-1" onClick={onUpgrade}>
            <Sparkles className="size-4" />
            Go Premium
          </Button>
          <Button variant="outline" className="flex-1" onClick={() => onOpenChange(false)}>
            <X className="size-4" />
            Keep using free
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
