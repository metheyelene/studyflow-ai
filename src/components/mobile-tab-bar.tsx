"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { BarChart3, FileText, Home, Library, User } from "lucide-react";
import type { LucideIcon } from "lucide-react";

import { cn } from "@/lib/utils";

const TAB_ITEMS: { href: string; label: string; icon: LucideIcon }[] = [
  { href: "/dashboard", label: "Home", icon: Home },
  { href: "/notebooks", label: "Notebooks", icon: Library },
  { href: "/notes", label: "Notes", icon: FileText },
  { href: "/quizzes", label: "Progress", icon: BarChart3 },
  { href: "/settings", label: "Profile", icon: User },
];

export function MobileTabBar() {
  const pathname = usePathname();

  return (
    <nav aria-label="Primary" className="fixed inset-x-0 bottom-0 z-20 md:hidden">
      <div className="border-2 border-border bg-background mx-3 mb-[calc(env(safe-area-inset-bottom)+0.75rem)] flex items-center justify-around px-2 py-1.5">
        {TAB_ITEMS.map((item) => {
          const active =
            pathname === item.href || pathname.startsWith(`${item.href}/`);
          const Icon = item.icon;
          return (
            <Link
              key={item.href}
              href={item.href}
              aria-current={active ? "page" : undefined}
              className={cn(
                "flex min-w-16 flex-col items-center gap-0.5 px-3 py-1.5 transition-all duration-150",
                active
                  ? "bg-foreground text-background"
                  : "text-muted-foreground hover:text-foreground",
              )}
            >
              <Icon className="size-5" />
              <span className="text-[10px] font-bold uppercase tracking-wider">{item.label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
