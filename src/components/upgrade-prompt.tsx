"use client";

import { Sparkles } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { PremiumBadge } from "@/components/premium-badge";

/**
 * Contextual upgrade prompt (docs/premium-conversion.md §4). Used after
 * a relevant action ("You're using quizzes frequently…") — never shown
 * randomly. `children` renders the premium value preview.
 */
export function UpgradePrompt({
  title,
  description,
  bullets = [],
  onUpgrade,
  onDecline,
  children,
}: {
  title: string;
  description: string;
  bullets?: string[];
  onUpgrade?: () => void;
  onDecline?: () => void;
  children?: React.ReactNode;
}) {
  return (
    <Card className="border-amber-500/30 bg-amber-500/[0.04]">
      <CardHeader className="pb-3">
        <div className="flex items-center gap-2">
          <PremiumBadge />
        </div>
        <CardTitle className="text-base">{title}</CardTitle>
        <CardDescription>{description}</CardDescription>
      </CardHeader>
      {children && <CardContent className="pb-3 pt-0">{children}</CardContent>}
      {bullets.length > 0 && (
        <CardContent className="pb-3 pt-0">
          <ul className="text-muted-foreground space-y-1 text-sm">
            {bullets.map((b) => (
              <li key={b} className="flex items-start gap-2">
                <Sparkles className="mt-0.5 size-3.5 shrink-0 text-amber-500" />
                {b}
              </li>
            ))}
          </ul>
        </CardContent>
      )}
      <CardFooter className="flex gap-2">
        {onUpgrade && (
          <Button size="sm" onClick={onUpgrade}>
            See Premium
          </Button>
        )}
        {onDecline && (
          <Button size="sm" variant="ghost" onClick={onDecline}>
            Not now
          </Button>
        )}
      </CardFooter>
    </Card>
  );
}
