import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";

import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap text-sm font-bold uppercase tracking-wider transition-all duration-150 disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4 shrink-0 [&_svg]:shrink-0 outline-none focus-visible:border-swiss-red focus-visible:ring-2 focus-visible:ring-swiss-red focus-visible:ring-offset-2 aria-invalid:border-destructive",
  {
    variants: {
      variant: {
        default:
          "bg-foreground text-background border-2 border-foreground hover:bg-swiss-red hover:border-swiss-red active:translate-x-[2px] active:translate-y-[2px]",
        destructive:
          "bg-swiss-red text-white border-2 border-swiss-red hover:bg-foreground hover:border-foreground focus-visible:ring-destructive/20",
        outline:
          "border-2 border-border bg-background text-foreground hover:bg-foreground hover:text-background active:translate-x-[2px] active:translate-y-[2px]",
        secondary: "bg-secondary text-secondary-foreground border-2 border-border hover:bg-foreground hover:text-background",
        ghost: "hover:bg-secondary text-foreground",
        glass:
          "border-2 border-border bg-card text-foreground hover:bg-foreground hover:text-background active:translate-x-[2px] active:translate-y-[2px]",
        "glass-secondary":
          "border-2 border-border bg-secondary text-foreground hover:bg-foreground hover:text-background active:translate-x-[2px] active:translate-y-[2px]",
        link: "text-foreground underline-offset-4 hover:underline",
      },
      size: {
        default: "h-9 px-4 py-2 has-[>svg]:px-3",
        sm: "h-8 gap-1.5 px-3 has-[>svg]:px-2.5",
        lg: "h-11 px-6 has-[>svg]:px-4",
        icon: "size-9",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  },
);

function Button({
  className,
  variant,
  size,
  asChild = false,
  ...props
}: React.ComponentProps<"button"> &
  VariantProps<typeof buttonVariants> & {
    asChild?: boolean;
  }) {
  const Comp = asChild ? Slot : "button";

  return (
    <Comp
      data-slot="button"
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  );
}

export { Button, buttonVariants };
