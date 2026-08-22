import * as React from "react";

import { cn } from "@/lib/utils";

/**
 * Swiss Card system.
 *
 * Tones map to visual hierarchy:
 * - primary  → content cards (border + white bg)
 * - secondary→ widgets (border + muted bg)
 * - floating → elevated cards (border + white bg)
 * - modal    → dialogs / panels (border + white bg, strongest)
 */

const swissTones = {
  primary: "border-2 border-border bg-card",
  secondary: "border-2 border-border bg-secondary",
  floating: "border-2 border-border bg-card",
  modal: "border-2 border-border bg-card",
} as const;

export type GlassTone = keyof typeof swissTones;

export function GlassCard({
  tone = "primary",
  className,
  ...props
}: React.ComponentProps<"div"> & { tone?: GlassTone }) {
  return (
    <div
      data-slot="glass-card"
      className={cn("transition-colors duration-150", swissTones[tone], className)}
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
        "inline-flex items-center gap-1.5 border-2 border-border bg-secondary px-3.5 py-1.5 text-sm font-medium whitespace-nowrap transition-all duration-150 select-none",
        "hover:border-foreground hover:bg-foreground hover:text-background",
        "focus-visible:ring-ring focus-visible:ring-[3px] focus-visible:outline-none",
        selected &&
          "bg-foreground text-background border-foreground",
        className,
      )}
      {...props}
    />
  );
}
