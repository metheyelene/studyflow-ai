import * as React from "react";
import { AlertCircle, Info, TriangleAlert } from "lucide-react";

import { cn } from "@/lib/utils";

const ALERT_ICONS = {
  default: Info,
  info: Info,
  destructive: AlertCircle,
  warning: TriangleAlert,
} as const;

type AlertVariant = keyof typeof ALERT_ICONS;

const ALERT_CLASSES: Record<AlertVariant, string> = {
  default: "border-border text-foreground",
  info: "border-sky-500/30 bg-sky-500/10 text-sky-700 dark:text-sky-300",
  destructive:
    "border-destructive/30 bg-destructive/10 text-destructive",
  warning: "border-amber-500/30 bg-amber-500/10 text-amber-700 dark:text-amber-300",
};

export function Alert({
  variant = "default",
  className,
  children,
}: {
  variant?: AlertVariant;
  className?: string;
  children: React.ReactNode;
}) {
  const Icon = ALERT_ICONS[variant];
  return (
    <div
      role="alert"
      className={cn(
        "flex items-start gap-3 rounded-md border px-4 py-3 text-sm",
        ALERT_CLASSES[variant],
        className,
      )}
    >
      <Icon className="mt-0.5 size-4 shrink-0" />
      <div className="min-w-0 flex-1">{children}</div>
    </div>
  );
}

export function AlertTitle({
  className,
  ...props
}: React.HTMLAttributes<HTMLHeadingElement>) {
  return (
    <h5
      className={cn("mb-1 font-medium leading-none tracking-tight", className)}
      {...props}
    />
  );
}

export function AlertDescription({
  className,
  ...props
}: React.HTMLAttributes<HTMLParagraphElement>) {
  return (
    <div
      className={cn("text-sm opacity-90 [&_p]:leading-relaxed", className)}
      {...props}
    />
  );
}
