import {
  BookOpen,
  CalendarClock,
  FileText,
  LayoutDashboard,
  Library,
  ListChecks,
  Settings,
} from "lucide-react";

import { MobileTabBar } from "@/components/mobile-tab-bar";
import { SidebarNav, type NavItem } from "@/components/sidebar-nav";
import { ThemeToggle } from "@/components/theme-toggle";
import { UserMenu } from "@/components/user-menu";

const NAV_ITEMS: NavItem[] = [
  { href: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
  { href: "/notebooks", label: "Notebooks", icon: Library },
  { href: "/notes", label: "Notes", icon: FileText },
  { href: "/flashcards", label: "Flashcards", icon: BookOpen },
  { href: "/quizzes", label: "Quizzes", icon: ListChecks },
  { href: "/planner", label: "Planner", icon: CalendarClock },
  { href: "/settings", label: "Settings", icon: Settings },
];

function Logo({ compact = false }: { compact?: boolean }) {
  return (
    <div className="flex items-center gap-2">
      <div className="bg-foreground text-background flex size-8 shrink-0 items-center justify-center">
        <BookOpen className="size-4" />
      </div>
      {!compact && <span className="font-black uppercase tracking-tight text-sm">StudyFlow</span>}
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
      {/* Desktop — Swiss sidebar */}
      <aside className="border-r-2 border-border bg-background sticky top-0 z-10 hidden h-dvh w-60 shrink-0 flex-col md:flex">
        <div className="flex h-14 items-center border-b-2 border-border px-4">
          <Logo />
        </div>
        <div className="flex-1 overflow-y-auto p-3">
          <SidebarNav items={NAV_ITEMS} />
        </div>
        <div className="border-t-2 border-border p-2">
          <UserMenu name={user.name} email={user.email} />
        </div>
      </aside>

      {/* Main column */}
      <div className="flex min-w-0 flex-1 flex-col">
        {/* Mobile — Swiss top bar */}
        <header className="border-b-2 border-border bg-background sticky top-0 z-10 flex h-14 items-center justify-between gap-2 px-4 md:hidden">
          <Logo compact />
          <div className="flex items-center gap-1">
            <ThemeToggle />
            <UserMenu name={user.name} email={user.email} compact />
          </div>
        </header>

        {/* Desktop — sticky header (theme toggle) */}
        <header className="border-b-2 border-border sticky top-0 z-10 hidden h-14 items-center justify-end bg-background px-6 md:flex">
          <ThemeToggle />
        </header>

        <main className="flex-1 p-4 pb-28 md:p-8 md:pb-8">{children}</main>

        <MobileTabBar />
      </div>
    </div>
  );
}
