import {
  BookOpen,
  CalendarClock,
  FileText,
  LayoutDashboard,
  ListChecks,
  Settings,
} from "lucide-react";

import { MobileTabBar } from "@/components/mobile-tab-bar";
import { SidebarNav, type NavItem } from "@/components/sidebar-nav";
import { ThemeToggle } from "@/components/theme-toggle";
import { UserMenu } from "@/components/user-menu";

const NAV_ITEMS: NavItem[] = [
  { href: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
  { href: "/notes", label: "Notes", icon: FileText },
  { href: "/flashcards", label: "Flashcards", icon: BookOpen },
  { href: "/quizzes", label: "Quizzes", icon: ListChecks },
  { href: "/planner", label: "Planner", icon: CalendarClock },
  { href: "/settings", label: "Settings", icon: Settings },
];

function Logo({ compact = false }: { compact?: boolean }) {
  return (
    <div className="flex items-center gap-2">
      <div className="bg-primary text-primary-foreground flex size-8 shrink-0 items-center justify-center rounded-xl shadow-sm">
        <BookOpen className="size-4" />
      </div>
      {!compact && <span className="font-semibold">StudyFlow</span>}
    </div>
  );
}

export function AppShell({
  user,
  children,
}: {
  user: { name: string; email: string };
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-dvh">
      {/* Desktop — floating glass sidebar */}
      <aside className="glass sticky top-3 z-10 mt-3 mb-3 hidden h-[calc(100dvh-1.5rem)] w-60 shrink-0 flex-col rounded-2xl md:flex">
        <div className="flex h-14 items-center px-4">
          <Logo />
        </div>
        <div className="flex-1 overflow-y-auto p-3">
          <SidebarNav items={NAV_ITEMS} />
        </div>
        <div className="p-2">
          <UserMenu name={user.name} email={user.email} />
        </div>
      </aside>

      {/* Main column */}
      <div className="flex min-w-0 flex-1 flex-col">
        {/* Mobile — floating glass top bar */}
        <header className="glass-subtle sticky top-0 z-10 mx-3 mt-3 flex h-14 items-center justify-between gap-2 rounded-2xl px-4 md:hidden">
          <Logo compact />
          <div className="flex items-center gap-1">
            <ThemeToggle />
            <UserMenu name={user.name} email={user.email} compact />
          </div>
        </header>

        {/* Desktop — floating header (theme toggle) */}
        <header className="sticky top-0 z-10 hidden h-14 items-center justify-end px-6 md:flex">
          <ThemeToggle />
        </header>

        <main className="flex-1 p-4 pb-28 md:p-8 md:pb-8">{children}</main>

        <MobileTabBar />
      </div>
    </div>
  );
}
