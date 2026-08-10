import { Sparkles } from "lucide-react";

import { cn } from "@/lib/utils";

/** Small "Premium" pill used to mark paywalled features BEFORE users
 *  click them (docs/premium-conversion.md §4). */
export function PremiumBadge({ className }: { className?: string }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full bg-amber-500/15 px-2 py-0.5 text-[11px] font-semibold text-amber-600 dark:text-amber-400",
        className,
      )}
    >
      <Sparkles className="size-3" />
      Premium
    </span>
  );
}
