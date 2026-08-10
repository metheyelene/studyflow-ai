"use client";

import { AlertTriangle, Zap } from "lucide-react";

import { Progress } from "@/components/ui/progress";
import { cn } from "@/lib/utils";
import type { AiUsage } from "@/lib/usage";

function formatReset(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

/**
 * Usage-limit UX (docs/premium-conversion.md §4):
 *   ok         → silent (just the number)
 *   warning    → subtle "you're at X%"
 *   critical   → "Y actions left this month" + one-line premium mention
 *   exhausted  → friendly reset explanation; never a cold lockout
 */
export function UsageMeter({
  usage,
  onUpgrade,
  showLabel = true,
}: {
  usage: AiUsage;
  onUpgrade?: () => void;
  showLabel?: boolean;
}) {
  const { used, limit, remaining, percent, state, resetsAt } = usage;

  const barColor =
    state === "exhausted"
      ? "bg-destructive"
      : state === "critical"
        ? "bg-amber-500"
        : undefined;

  return (
    <div className="space-y-1.5">
      <div className="flex items-center justify-between gap-2 text-xs">
        <span className="text-muted-foreground inline-flex items-center gap-1">
          <Zap className="size-3.5" />
          AI actions
        </span>
        <span className="font-medium">
          {used} / {limit}
          {showLabel && state === "warning" && (
            <span className="text-muted-foreground ml-1 font-normal">
              · {percent}% used
            </span>
          )}
        </span>
      </div>

      <Progress
        value={percent}
        className={cn(barColor && "[&>div]:bg-current", "text-amber-500")}
      />

      {state === "critical" && (
        <p className="flex items-center gap-1.5 text-amber-600 text-xs dark:text-amber-400">
          <AlertTriangle className="size-3.5" />
          {remaining} action{remaining === 1 ? "" : "s"} left this month.
          {onUpgrade && (
            <button
              onClick={onUpgrade}
              className="underline underline-offset-2 hover:opacity-80"
            >
              Premium gives you more.
            </button>
          )}
        </p>
      )}
      {state === "exhausted" && (
        <p className="text-muted-foreground text-xs">
          Free allowance used — resets on {formatReset(resetsAt)}.
          {onUpgrade && (
            <>
              {" "}
              <button
                onClick={onUpgrade}
                className="text-amber-600 underline underline-offset-2 hover:opacity-80 dark:text-amber-400"
              >
                See what Premium includes
              </button>
              .
            </>
          )}
        </p>
      )}
    </div>
  );
}
