import { Sparkles } from "lucide-react";

import { cn } from "@/lib/utils";

export function PremiumBadge({ className }: { className?: string }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 border-2 border-swiss-red bg-swiss-red/10 px-2 py-0.5 text-[11px] font-bold uppercase tracking-wider text-swiss-red",
        className,
      )}
    >
      <Sparkles className="size-3" />
      Premium
    </span>
  );
}
