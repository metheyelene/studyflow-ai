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
      <h1 className="font-black text-2xl uppercase tracking-tight">{title}</h1>
      <GlassCard className="relative mt-6 items-center justify-center gap-4 overflow-hidden border-2 border-border px-6 py-16 text-center">
        <div className="relative">
          <div className="bg-foreground text-background mx-auto flex size-12 items-center justify-center">
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
