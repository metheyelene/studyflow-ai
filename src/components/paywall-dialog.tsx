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
            <Sparkles className="text-swiss-red size-5" />
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
              <span className="text-swiss-red font-bold mt-0.5">✓</span>
              {f}
            </li>
          ))}
        </ul>

        <div className="bg-secondary grid gap-3 border-2 border-border p-4 sm:grid-cols-2">
          <div>
            <p className="text-muted-foreground text-xs font-bold uppercase tracking-wider">
              Monthly
            </p>
            <p className="mt-1 text-2xl font-black">
              ${PRICING.monthlyUsd.toFixed(2)}
              <span className="text-muted-foreground text-sm font-normal"> / month</span>
            </p>
          </div>
          <div className="border-2 border-swiss-red bg-swiss-red/10 p-3">
            <p className="text-muted-foreground text-xs font-bold uppercase tracking-wider">
              Yearly — save ~33%
            </p>
            <p className="mt-1 text-2xl font-black">
              ${PRICING.yearlyUsd.toFixed(2)}
              <span className="text-muted-foreground text-sm font-normal"> / year</span>
            </p>
            <p className="text-swiss-red text-xs font-bold">
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
