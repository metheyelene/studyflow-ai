import { BookOpen } from "lucide-react";

import { SidebarNav, type NavItem } from "@/components/sidebar-nav";
import { ThemeToggle } from "@/components/theme-toggle";
import { UserMenu } from "@/components/user-menu";

const NAV_ITEMS: NavItem[] = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/notes", label: "Notes" },
  { href: "/flashcards", label: "Flashcards" },
  { href: "/quizzes", label: "Quizzes" },
  { href: "/planner", label: "Planner" },
  { href: "/settings", label: "Settings" },
];

function Logo({ compact = false }: { compact?: boolean }) {
  return (
    <div className="flex items-center gap-2">
      <div className="bg-primary text-primary-foreground flex size-8 shrink-0 items-center justify-center rounded-lg">
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
      {/* Desktop sidebar */}
      <aside className="bg-background sticky top-0 hidden h-dvh w-60 shrink-0 flex-col border-r md:flex">
        <div className="flex h-14 items-center border-b px-4">
          <Logo />
        </div>
        <div className="flex-1 overflow-y-auto p-3">
          <SidebarNav items={NAV_ITEMS} />
        </div>
        <div className="border-t p-2">
          <UserMenu name={user.name} email={user.email} />
        </div>
      </aside>

      {/* Main column */}
      <div className="flex min-w-0 flex-1 flex-col">
        {/* Mobile top bar */}
        <header className="bg-background/80 sticky top-0 z-10 flex h-14 items-center justify-between gap-2 border-b px-4 backdrop-blur md:hidden">
          <Logo compact />
          <div className="flex items-center gap-1">
            <ThemeToggle />
            <UserMenu name={user.name} email={user.email} compact />
          </div>
        </header>
        {/* Mobile nav strip */}
        <div className="border-b px-3 py-2 md:hidden">
          <SidebarNav items={NAV_ITEMS} horizontal />
        </div>

        {/* Desktop header (theme toggle) */}
        <header className="hidden h-14 items-center justify-end border-b px-6 md:flex">
          <ThemeToggle />
        </header>

        <main className="flex-1 p-4 md:p-8">{children}</main>
      </div>
    </div>
  );
}
