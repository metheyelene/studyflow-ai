import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { eq } from "drizzle-orm";

import Link from "next/link";
import { BadgeCheck, ChevronRight, Info, Sparkles } from "lucide-react";

import { ManageSubscriptionButton } from "@/components/manage-subscription-button";
import { GlassCard } from "@/components/ui/glass";
import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";
import { FOUNDING_TERMS } from "@/lib/founding";
import { PRICING } from "@/lib/plans";
import { SettingsForm } from "./settings-form";

export default async function SettingsPage() {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) redirect("/login");

  const db = getDb();
  const profile = await db.query.profiles.findFirst({
    where: eq(schema.profiles.userId, session.user.id),
  });
  const subjects = await db.query.subjects.findMany({
    where: eq(schema.subjects.userId, session.user.id),
  });

  const subscription = await db.query.subscriptions.findFirst({
    where: eq(schema.subscriptions.userId, session.user.id),
  });
  const isFounding = subscription?.plan === FOUNDING_TERMS.planStorage;
  const isActive = subscription?.status === "active" || subscription?.status === "trialing";

  return (
    <div className="mx-auto max-w-2xl space-y-8">
      <div>
        <h1 className="font-black text-2xl uppercase tracking-tight">Settings</h1>
        <p className="text-muted-foreground mt-1">
          Your profile, study preferences, and account actions.
        </p>
      </div>

      {/* Subscription */}
      <GlassCard tone="primary" className="p-6">
        <div className="flex items-start justify-between gap-4">
          <div className="flex items-start gap-3">
            <div
              className={`flex size-10 items-center justify-center ${
                isFounding && isActive
                  ? "bg-foreground text-background"
                  : "bg-secondary text-muted-foreground"
              }`}
            >
              {isFounding && isActive ? (
                <BadgeCheck className="size-5" />
              ) : (
                <Sparkles className="size-5" />
              )}
            </div>
            <div>
              <p className="text-sm font-bold uppercase tracking-wider">
                {isFounding && isActive
                  ? `${FOUNDING_TERMS.planLabel} · $${FOUNDING_TERMS.priceUsd}/month`
                  : isActive
                    ? `Premium · $${PRICING.monthlyUsd}/month`
                    : "Free plan"}
              </p>
              <p className="text-muted-foreground text-sm">
                {isFounding && isActive
                  ? "Status: Active — you keep founding-member pricing for as long as you stay subscribed."
                  : isActive
                    ? `Status: ${subscription?.status}. Cancel anytime; access continues to the end of the paid period.`
                    : "$0 — basic study tools with 20 AI actions a month."}
              </p>
            </div>
          </div>
        </div>
        <div className="mt-4 flex flex-wrap items-center gap-3">
          {isActive ? (
            <ManageSubscriptionButton />
          ) : (
            <Link
              href="/pricing"
              className="bg-foreground text-background inline-flex h-9 items-center gap-2 px-4 text-sm font-bold uppercase tracking-wider transition-all duration-150 hover:bg-swiss-red active:translate-x-[2px] active:translate-y-[2px]"
            >
              See plans
            </Link>
          )}
        </div>
      </GlassCard>

      <SettingsForm
        user={{ name: session.user.name, email: session.user.email }}
        profile={profile ?? null}
        subjects={subjects.map((s) => s.name)}
      />

      {/* About */}
      <GlassCard tone="secondary" className="p-6">
        <Link
          href="/about/creator"
          className="group flex items-center gap-3 transition-colors"
        >
          <div className="bg-secondary text-foreground flex size-10 shrink-0 items-center justify-center border-2 border-border">
            <Info className="size-5" />
          </div>
          <div className="min-w-0 flex-1">
            <p className="font-bold uppercase tracking-tight">About StudyFlow</p>
            <p className="text-muted-foreground text-sm">
              About the app and its creator
            </p>
          </div>
          <ChevronRight className="text-muted-foreground group-hover:text-foreground size-4 transition-colors" />
        </Link>
      </GlassCard>
    </div>
  );
}
