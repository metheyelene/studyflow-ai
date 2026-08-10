"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Loader2, LogOut, Trash2 } from "lucide-react";

import { authClient, signOut } from "@/lib/auth-client";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";

function initials(name: string): string {
  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0]!.toUpperCase())
    .join("");
}

export function UserMenu({
  name,
  email,
  compact = false,
}: {
  name: string;
  email: string;
  compact?: boolean;
}) {
  const router = useRouter();
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  async function handleDelete() {
    setDeleting(true);
    setDeleteError(null);
    try {
      const { error } = await authClient.deleteUser();
      if (error) {
        setDeleteError("We couldn't delete your account. Please try again.");
        setDeleting(false);
        return;
      }
      await signOut();
      router.push("/login");
      router.refresh();
    } catch {
      setDeleteError("We couldn't delete your account. Please try again.");
      setDeleting(false);
    }
  }

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            variant="ghost"
            className={compact ? "size-9 p-0" : "h-auto w-full justify-start gap-2 px-2 py-1.5"}
          >
            <Avatar className="size-8">
              <AvatarFallback>{initials(name)}</AvatarFallback>
            </Avatar>
            {!compact && (
              <span className="min-w-0 flex-1 text-left">
                <span className="block truncate text-sm font-medium">{name}</span>
                <span className="text-muted-foreground block truncate text-xs">
                  {email}
                </span>
              </span>
            )}
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-60">
          <DropdownMenuLabel>
            <div className="flex items-center justify-between gap-2">
              <span className="truncate">{name}</span>
              <Badge variant="secondary">Free plan</Badge>
            </div>
            <p className="text-muted-foreground truncate text-xs font-normal">
              {email}
            </p>
          </DropdownMenuLabel>
          <DropdownMenuSeparator />
          <DropdownMenuItem
            variant="destructive"
            onSelect={() => setConfirmOpen(true)}
          >
            <Trash2 />
            Delete account
          </DropdownMenuItem>
          <DropdownMenuItem
            variant="destructive"
            onSelect={async () => {
              await signOut();
              router.push("/login");
              router.refresh();
            }}
          >
            <LogOut />
            Sign out
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>

      <AlertDialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle className="flex items-center gap-2">
              <Trash2 className="text-destructive size-4" />
              Delete your account?
            </AlertDialogTitle>
            <AlertDialogDescription>
              This permanently deletes your account, notes, flashcards,
              quizzes, and all other data. This cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          {deleteError && (
            <p role="alert" className="bg-destructive/10 text-destructive rounded-md px-3 py-2 text-sm">
              {deleteError}
            </p>
          )}
          <AlertDialogFooter>
            <AlertDialogCancel disabled={deleting}>Cancel</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              disabled={deleting}
              onClick={(e) => {
                e.preventDefault();
                handleDelete();
              }}
            >
              {deleting && <Loader2 className="animate-spin" />}
              Delete my account
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}
