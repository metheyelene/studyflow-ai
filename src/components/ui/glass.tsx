import * as React from "react";

import { cn } from "@/lib/utils";

/**
 * Glass material system.
 *
 * Tones map to the four materials defined in docs/glass-ui-overhaul.md:
 * - primary  → content cards (glass)
 * - secondary→ widgets, more transparent (glass-subtle)
 * - floating → quick actions, elevated above the page (glass-float)
 * - modal    → dialogs / premium panels, strongest blur (glass-strong)
 *
 * Rule: never wrap text-heavy surfaces in glass where readability wins.
 */

const glassTones = {
  primary: "glass",
  secondary: "glass-subtle",
  floating: "glass-float",
  modal: "glass-strong",
} as const;

export type GlassTone = keyof typeof glassTones;

export function GlassCard({
  tone = "primary",
  className,
  ...props
}: React.ComponentProps<"div"> & { tone?: GlassTone }) {
  return (
    <div
      data-slot="glass-card"
      className={cn("rounded-2xl", glassTones[tone], className)}
      {...props}
    />
  );
}

export function GlassPill({
  selected = false,
  className,
  ...props
}: React.ComponentProps<"button"> & { selected?: boolean }) {
  return (
    <button
      type="button"
      data-slot="glass-pill"
      aria-pressed={selected}
      className={cn(
        "glass-subtle text-foreground inline-flex items-center gap-1.5 rounded-full px-3.5 py-1.5 text-sm font-medium whitespace-nowrap transition-all duration-150 ease-out-soft select-none",
        "hover:bg-[--glass-bg-strong] active:scale-[0.97]",
        "focus-visible:ring-ring focus-visible:ring-[3px] focus-visible:outline-none",
        selected &&
          "bg-primary text-primary-foreground border-transparent shadow-sm hover:bg-primary/90",
        className,
      )}
      {...props}
    />
  );
}
