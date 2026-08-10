"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { LucideIcon } from "lucide-react";

import { cn } from "@/lib/utils";

export interface NavItem {
  href: string;
  label: string;
  icon?: LucideIcon;
}

export function SidebarNav({
  items,
  horizontal = false,
}: {
  items: NavItem[];
  horizontal?: boolean;
}) {
  const pathname = usePathname();

  return (
    <nav
      className={cn(
        horizontal
          ? "flex gap-1 overflow-x-auto"
          : "flex flex-col gap-1",
      )}
    >
      {items.map((item) => {
        const active =
          pathname === item.href || pathname.startsWith(`${item.href}/`);
        const Icon = item.icon;
        return (
          <Link
            key={item.href}
            href={item.href}
            aria-current={active ? "page" : undefined}
            className={cn(
              "flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm font-medium whitespace-nowrap transition-all duration-150",
              "focus-visible:ring-ring focus-visible:ring-[3px] focus-visible:outline-none",
              active
                ? "glass-subtle text-foreground bg-primary/10 shadow-xs"
                : "text-muted-foreground hover:bg-[--glass-bg-subtle] hover:text-foreground",
            )}
          >
            {Icon && (
              <Icon
                className={cn(
                  "size-4 shrink-0 transition-colors",
                  active ? "text-primary" : "text-muted-foreground",
                )}
              />
            )}
            {item.label}
          </Link>
        );
      })}
    </nav>
  );
}
