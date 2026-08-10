import Link from "next/link";
import { ArrowRight, Sparkles } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { GlassCard } from "@/components/ui/glass";

export function ComingSoon({
  title,
  description,
  week,
}: {
  title: string;
  description: string;
  week: string;
}) {
  return (
    <div className="mx-auto max-w-3xl">
      <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
      <GlassCard className="relative mt-6 items-center justify-center gap-4 overflow-hidden px-6 py-16 text-center">
        <div
          aria-hidden
          className="bg-primary/10 absolute -top-20 left-1/2 size-64 -translate-x-1/2 rounded-full blur-3xl"
        />
        <div className="relative">
          <div className="bg-primary/10 text-primary mx-auto flex size-12 items-center justify-center rounded-2xl">
            <Sparkles className="size-5" />
          </div>
          <p className="mx-auto mt-4 max-w-md text-pretty">{description}</p>
          <div className="mt-4 flex justify-center">
            <Badge variant="secondary">Arriving in {week}</Badge>
          </div>
          <Button asChild variant="glass-secondary" className="mt-6">
            <Link href="/dashboard">
              Back to dashboard
              <ArrowRight />
            </Link>
          </Button>
        </div>
      </GlassCard>
    </div>
  );
}
