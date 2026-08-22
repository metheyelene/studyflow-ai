import Link from "next/link";
import { headers } from "next/headers";
import { ArrowLeft, Check, Mail, Sparkles } from "lucide-react";

import { GlassCard } from "@/components/ui/glass";
import { auth } from "@/lib/auth";
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

export default async function CreatorPage() {
  const version = appVersion();
  const session = await auth.api
    .getSession({ headers: await headers() })
    .catch(() => null);

  return (
    <div className="mx-auto max-w-xl space-y-6">
      <div className="flex items-center gap-2">
        <Link
          href={session ? "/settings" : "/"}
          className="text-muted-foreground hover:text-foreground -ml-2 inline-flex items-center gap-1.5 px-2 py-1 text-sm transition-colors"
        >
          <ArrowLeft className="size-4" />
          {session ? "Settings" : "StudyFlow"}
        </Link>
      </div>

      {/* Creator card */}
      <GlassCard tone="primary" className="p-6 text-center sm:p-8">
        <div className="bg-foreground text-background mx-auto flex size-20 items-center justify-center">
          <span className="text-2xl font-black tracking-tight">MV</span>
        </div>

        <div className="mt-5">
          <h1 className="font-black text-xl uppercase tracking-tight">Mithil Viswas Kasi</h1>
          <p className="text-muted-foreground mt-0.5 text-sm">
            Creator &amp; Developer of StudyFlow AI
          </p>
          <p className="text-muted-foreground mx-auto mt-3 max-w-sm text-sm leading-relaxed">
            &ldquo;Built with the goal of making studying more organized, interactive, and
            intelligent.&rdquo;
          </p>
        </div>

        <div className="mt-5 space-y-3">
          <a
            href={MAILTO}
            className="text-foreground hover:text-swiss-red inline-flex items-center gap-1.5 text-sm font-bold uppercase tracking-wider"
          >
            <Mail className="size-4" />
            {CREATOR_EMAIL}
          </a>
          <div>
            <a
              href={MAILTO_FEEDBACK}
              className="bg-foreground text-background inline-flex h-10 items-center gap-2 px-5 text-sm font-bold uppercase tracking-wider transition-all duration-150 hover:bg-swiss-red active:translate-x-[2px] active:translate-y-[2px]"
            >
              <Sparkles className="size-4" />
              Contact Creator
            </a>
          </div>
        </div>
      </GlassCard>

      {/* About StudyFlow */}
      <GlassCard tone="primary" className="p-6">
        <h2 className="font-black uppercase tracking-tight text-lg">About StudyFlow</h2>
        <p className="text-muted-foreground mt-1.5 text-sm leading-relaxed">
          StudyFlow AI is an AI-powered study workspace designed to help students turn their
          learning material into a more organized and interactive study experience.
        </p>
        <ul className="mt-4 space-y-1.5">
          {ABOUT_FEATURES.map((feature) => (
            <li key={feature} className="flex items-center gap-2 text-sm">
              <span className="text-swiss-red font-bold">✓</span>
              {feature}
            </li>
          ))}
        </ul>
      </GlassCard>

      {/* Feedback */}
      <GlassCard tone="secondary" className="flex flex-col items-start gap-3 p-6 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h3 className="font-bold uppercase tracking-tight">Help improve StudyFlow</h3>
          <p className="text-muted-foreground mt-0.5 text-sm">
            Have an idea, found something that could be better, or discovered a bug? I&apos;d
            love to hear from you.
          </p>
        </div>
        <a
          href={MAILTO_FEEDBACK}
          className="border-2 border-border bg-card text-foreground hover:bg-foreground hover:text-background inline-flex h-9 shrink-0 items-center gap-2 px-4 text-sm font-bold uppercase tracking-wider transition-all duration-150"
        >
          <Mail className="size-4" />
          Send Feedback
        </a>
      </GlassCard>

      {/* Version + credits */}
      <div className="text-muted-foreground flex flex-col items-center gap-1 text-center text-xs">
        <p>
          StudyFlow AI · Version {version}
        </p>
        <p>
          Created by <span className="text-foreground font-bold uppercase tracking-wider">Mithil Viswas Kasi</span> ·{" "}
          Creator &amp; Developer
        </p>
      </div>
    </div>
  );
}
