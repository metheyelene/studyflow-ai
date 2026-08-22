"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { ArrowRight, Check, Loader2, Sparkles } from "lucide-react";

import { trackEventAction } from "@/lib/analytics-actions";
import { FOUNDING_TERMS } from "@/lib/founding-constants";
import { Button } from "@/components/ui/button";
import { GlassCard } from "@/components/ui/glass";

const BENEFITS = [
  "AI Study Tutor",
  "Advanced PDF Intelligence",
  "Smart Study Mode",
  "Adaptive Quizzes",
  "Smart Flashcards",
  "Exam Simulation",
  "Advanced Progress Analytics",
  "500 AI actions / month",
];

type Status = "idle" | "loading" | "error" | "not_configured";

export function FoundingCard({
  claimed,
  cap,
  remaining,
  full,
  alreadyMember,
  isAuthed,
  available = true,
  compact = false,
}: {
  claimed: number;
  cap: number;
  remaining: number;
  full: boolean;
  alreadyMember: boolean;
  isAuthed: boolean;
  available?: boolean;
  compact?: boolean;
}) {
  const [status, setStatus] = useState<Status>("idle");
  const trackedView = useRef(false);

  useEffect(() => {
    if (!trackedView.current) {
      trackedView.current = true;
      void trackEventAction("founding_offer_viewed", { claimed, cap });
    }
  }, [claimed, cap]);

  if (full && !alreadyMember) {
    return (
      <GlassCard tone="primary" className="relative overflow-hidden p-6 text-center">
        <p className="font-bold uppercase tracking-tight text-sm">Founding memberships are now full</p>
        <p className="text-muted-foreground mx-auto mt-1 max-w-md text-sm">
          Thank you to our first {cap} members. Regular Premium is available
          below — founding members keep their $2/month price.
        </p>
      </GlassCard>
    );
  }

  async function startCheckout() {
    setStatus("loading");
    try {
      const res = await fetch("/api/billing/checkout", { method: "POST" });
      if (res.status === 503) {
        setStatus("not_configured");
        return;
      }
      if (res.status === 409) {
        setStatus("error");
        return;
      }
      const data = (await res.json()) as { url?: string };
      if (!data.url) throw new Error("no checkout url");
      window.location.href = data.url;
    } catch {
      setStatus("error");
    }
  }

  return (
    <GlassCard
      tone="floating"
      className="relative overflow-hidden p-6 md:p-8"
    >
      <div className="relative">
        <div className="flex flex-col items-start justify-between gap-4 sm:flex-row sm:items-center">
          <div className="flex items-center gap-3">
            <div className="bg-foreground text-background flex size-11 items-center justify-center">
              <Sparkles className="size-5" />
            </div>
            <div>
              <p className="text-xs font-bold uppercase tracking-wider">
                Founding Member Offer
              </p>
              <p className="text-lg font-black uppercase tracking-tight">
                Premium for ${FOUNDING_TERMS.priceUsd}/month
              </p>
            </div>
          </div>
          {!compact && available && (
            <p className="text-muted-foreground text-sm tabular-nums">
              {claimed} / {cap} founding memberships claimed
            </p>
          )}
        </div>

        <p className="text-muted-foreground mt-3 max-w-2xl text-sm">
          Be one of the first {cap} StudyFlow members and keep founding-member
          pricing for as long as you stay subscribed. Help shape the future of
          StudyFlow with full Premium access at a founding-member price.
        </p>

        {!compact && (
          <ul className="mt-4 grid gap-x-6 gap-y-1.5 sm:grid-cols-2">
            {BENEFITS.map((b) => (
              <li key={b} className="flex items-center gap-2 text-sm">
                <span className="text-swiss-red font-bold">✓</span>
                {b}
              </li>
            ))}
          </ul>
        )}

        <div className="mt-5 flex flex-col items-start gap-3 sm:flex-row sm:items-center">
          {alreadyMember ? (
            <p className="text-sm font-bold uppercase tracking-wider">
              You&apos;re a founding member — Premium is unlocked.
            </p>
          ) : isAuthed ? (
            <Button size="lg" onClick={startCheckout} disabled={status === "loading"}>
              {status === "loading" && <Loader2 className="animate-spin" />}
              Become a Founding Member — ${FOUNDING_TERMS.priceUsd}/mo
              {status !== "loading" && <ArrowRight />}
            </Button>
          ) : (
            <Button asChild size="lg">
              <Link href="/signup">
                Become a Founding Member
                <ArrowRight />
              </Link>
            </Button>
          )}

          {!full && available && (
            <p className="text-muted-foreground text-xs tabular-nums">
              {remaining} membership{remaining === 1 ? "" : "s"} remaining —
              updated live from the backend.
            </p>
          )}
          {!available && (
            <p className="text-muted-foreground text-xs">
              Availability is being checked — come back in a minute.
            </p>
          )}
        </div>

        {status === "not_configured" && (
          <p className="text-muted-foreground mt-3 max-w-md border-2 border-border bg-secondary px-3 py-2 text-xs">
            Checkout opens once billing is connected (Stripe keys). Your spot
            is not reserved — the count above is live.
          </p>
        )}
        {status === "error" && (
          <p className="text-muted-foreground mt-3 max-w-md border-2 border-border bg-secondary px-3 py-2 text-xs">
            This offer is now full or already claimed — regular Premium is
            available below.
          </p>
        )}

        <p className="text-muted-foreground mt-4 text-xs">
          ${FOUNDING_TERMS.priceUsd}/month, billed monthly. Recurring
          subscription — cancel anytime; the $2 price stays yours for as long
          as you stay subscribed. This is not a one-time purchase.
        </p>
      </div>
    </GlassCard>
  );
}
