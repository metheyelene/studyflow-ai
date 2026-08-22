"use client";

import Link from "next/link";
import { ArrowRight } from "lucide-react";

import { PremiumBadge } from "@/components/premium-badge";
import { Card, CardContent } from "@/components/ui/card";
import { trackEventAction } from "@/lib/analytics-actions";

export function PremiumFeatureCard({
  icon: Icon,
  title,
  description,
  preview,
}: {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  description: string;
  preview?: string;
}) {
  return (
    <Link
      href="/pricing"
      onClick={() => void trackEventAction("premium_feature_viewed", { feature: title })}
      className="block transition-opacity hover:opacity-90"
    >
      <Card className="h-full">
        <CardContent className="gap-2">
          <div className="flex items-center justify-between">
            <div className="bg-swiss-red/10 flex size-9 items-center justify-center">
              <Icon className="size-4 text-swiss-red" />
            </div>
            <PremiumBadge />
          </div>
          <p className="font-bold uppercase tracking-tight">{title}</p>
          <p className="text-muted-foreground text-sm">{description}</p>
          {preview && (
            <p className="text-muted-foreground border-2 border-border bg-secondary px-3 py-2 text-xs italic">
              {preview}
            </p>
          )}
          <p className="text-swiss-red inline-flex items-center gap-1 text-xs font-bold uppercase tracking-wider">
            See what it does <ArrowRight className="size-3" />
          </p>
        </CardContent>
      </Card>
    </Link>
  );
}
