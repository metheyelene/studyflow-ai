import Link from "next/link";
import { ArrowLeft, Check, Mail, Sparkles } from "lucide-react";

import { GlassCard } from "@/components/ui/glass";
import { appVersion } from "@/lib/version";

export const dynamic = "force-dynamic";

const CREATOR_EMAIL = "mithilviswask@gmail.com";
const FEEDBACK_SUBJECT = encodeURIComponent("StudyFlow AI — Feedback");
const MAILTO = `mailto:${CREATOR_EMAIL}`;
const MAILTO_FEEDBACK = `mailto:${CREATOR_EMAIL}?subject=${FEEDBACK_SUBJECT}`;

const ABOUT_FEATURES = [
  "Source-grounded AI study assistance",
  "Smart notes",
  "Flashcards",
  "Quizzes",
  "Study planning",
  "Progress tracking",
];

export default function CreatorPage() {
  const version = appVersion();

  return (
    <div className="mx-auto max-w-xl space-y-6">
      <div className="flex items-center gap-2">
        <Link
          href="/settings"
          className="text-muted-foreground hover:text-foreground -ml-2 inline-flex items-center gap-1.5 rounded-lg px-2 py-1 text-sm transition-colors"
        >
          <ArrowLeft className="size-4" />
          Settings
        </Link>
      </div>

      {/* Creator card */}
      <GlassCard
        tone="primary"
        className="animate-in fade-in-0 slide-in-from-bottom-3 duration-500 ease-out-soft motion-reduce:animate-none p-6 text-center sm:p-8"
      >
        <div
          className="bg-primary/15 text-primary animate-in fade-in-0 zoom-in-90 duration-500 ease-out-soft motion-reduce:animate-none mx-auto flex size-20 items-center justify-center rounded-full shadow-sm"
          style={{ animationDelay: "80ms" }}
        >
          <span className="text-2xl font-semibold tracking-wide">MV</span>
        </div>

        <div
          className="animate-in fade-in-0 duration-500 ease-out-soft motion-reduce:animate-none mt-5"
          style={{ animationDelay: "140ms" }}
        >
          <h1 className="text-xl font-semibold tracking-tight">Mithil Viswas Kasi</h1>
          <p className="text-muted-foreground mt-0.5 text-sm">
            Creator &amp; Developer of StudyFlow AI
          </p>
          <p className="text-muted-foreground mx-auto mt-3 max-w-sm text-sm leading-relaxed">
            “Built with the goal of making studying more organized, interactive, and
            intelligent.”
          </p>
        </div>

        <div
          className="animate-in fade-in-0 duration-500 ease-out-soft motion-reduce:animate-none mt-5 space-y-3"
          style={{ animationDelay: "200ms" }}
        >
          <a
            href={MAILTO}
            className="text-primary hover:underline inline-flex items-center gap-1.5 text-sm font-medium"
          >
            <Mail className="size-4" />
            {CREATOR_EMAIL}
          </a>
          <div>
            <a
              href={MAILTO_FEEDBACK}
              className="bg-primary text-primary-foreground inline-flex h-10 items-center gap-2 rounded-xl px-5 text-sm font-medium shadow-sm transition-all hover:bg-primary/90 active:scale-[0.98]"
            >
              <Sparkles className="size-4" />
              Contact Creator
            </a>
          </div>
        </div>
      </GlassCard>

      {/* About StudyFlow */}
      <GlassCard
        tone="primary"
        className="animate-in fade-in-0 slide-in-from-bottom-3 duration-500 ease-out-soft motion-reduce:animate-none p-6"
        style={{ animationDelay: "260ms" }}
      >
        <h2 className="font-semibold text-lg">About StudyFlow</h2>
        <p className="text-muted-foreground mt-1.5 text-sm leading-relaxed">
          StudyFlow AI is an AI-powered study workspace designed to help students turn their
          learning material into a more organized and interactive study experience.
        </p>
        <ul className="mt-4 space-y-1.5">
          {ABOUT_FEATURES.map((feature) => (
            <li key={feature} className="flex items-center gap-2 text-sm">
              <Check className="text-primary size-4 shrink-0" />
              {feature}
            </li>
          ))}
        </ul>
      </GlassCard>

      {/* Feedback */}
      <GlassCard
        tone="secondary"
        className="animate-in fade-in-0 slide-in-from-bottom-3 duration-500 ease-out-soft motion-reduce:animate-none flex flex-col items-start gap-3 p-6 sm:flex-row sm:items-center sm:justify-between"
        style={{ animationDelay: "320ms" }}
      >
        <div>
          <h3 className="font-medium">Help improve StudyFlow</h3>
          <p className="text-muted-foreground mt-0.5 text-sm">
            Have an idea, found something that could be better, or discovered a bug? I&apos;d
            love to hear from you.
          </p>
        </div>
        <a
          href={MAILTO_FEEDBACK}
          className="glass-float text-foreground hover:bg-[--glass-bg-strong] inline-flex h-9 shrink-0 items-center gap-2 rounded-xl px-4 text-sm font-medium transition-all active:scale-[0.97]"
        >
          <Mail className="size-4" />
          Send Feedback
        </a>
      </GlassCard>

      {/* Version + credits */}
      <div
        className="animate-in fade-in-0 duration-500 ease-out-soft motion-reduce:animate-none text-muted-foreground flex flex-col items-center gap-1 text-center text-xs"
        style={{ animationDelay: "380ms" }}
      >
        <p>
          StudyFlow AI · Version {version}
        </p>
        <p>
          Created by <span className="text-foreground font-medium">Mithil Viswas Kasi</span> ·{" "}
          Creator &amp; Developer
        </p>
      </div>
    </div>
  );
}
