"use client";

import Link from "next/link";
import { ArrowRight } from "lucide-react";

import { PremiumBadge } from "@/components/premium-badge";
import { Card, CardContent } from "@/components/ui/card";
import { trackEventAction } from "@/lib/analytics-actions";

/**
 * Premium feature discovery card (docs/premium-conversion.md §4).
 * Renders a short explanation of the feature; the whole card links to
 * /pricing and records premium_feature_viewed — so we learn which
 * features actually interest users.
 */
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
            <div className="bg-amber-500/10 flex size-9 items-center justify-center rounded-lg">
              <Icon className="size-4 text-amber-500" />
            </div>
            <PremiumBadge />
          </div>
          <p className="font-medium">{title}</p>
          <p className="text-muted-foreground text-sm">{description}</p>
          {preview && (
            <p className="text-muted-foreground border-border rounded-md border px-3 py-2 text-xs italic">
              {preview}
            </p>
          )}
          <p className="text-amber-600 inline-flex items-center gap-1 text-xs font-medium dark:text-amber-400">
            See what it does <ArrowRight className="size-3" />
          </p>
        </CardContent>
      </Card>
    </Link>
  );
}
