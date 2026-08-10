"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { FileText, Library, Trash2 } from "lucide-react";

import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import type { Notebook } from "@/lib/ai/types";

export function NotebookList({ initial }: { initial: Notebook[] }) {
  const router = useRouter();
  const [notebooks, setNotebooks] = useState(initial);
  const [deleting, setDeleting] = useState<string | null>(null);

  async function remove(id: string) {
    setDeleting(id);
    try {
      const res = await fetch(`/api/notebooks/${id}`, { method: "DELETE" });
      if (!res.ok) throw new Error("delete failed");
      setNotebooks((prev) => prev.filter((n) => n.id !== id));
      router.refresh();
    } catch {
      // keep the card; the alert dialog already communicates failure states poorly — surface inline
    } finally {
      setDeleting(null);
    }
  }

  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {notebooks.map((notebook) => (
        <div
          key={notebook.id}
          className="glass group relative flex flex-col gap-3 rounded-3xl p-5 transition-all duration-150 hover:bg-[--glass-bg-strong]"
        >
          <Link href={`/notebooks/${notebook.id}`} className="absolute inset-0 z-0" aria-label={notebook.title} />
          <div className="bg-primary/10 text-primary flex size-10 items-center justify-center rounded-xl">
            <Library className="size-5" />
          </div>
          <div className="space-y-0.5">
            <h2 className="line-clamp-1 font-semibold">{notebook.title}</h2>
            {notebook.description && (
              <p className="text-muted-foreground line-clamp-2 text-sm">{notebook.description}</p>
            )}
          </div>
          <div className="text-muted-foreground mt-auto flex items-center gap-1.5 text-xs">
            <FileText className="size-3.5" />
            {notebook.sourceCount} source{notebook.sourceCount === 1 ? "" : "s"}
          </div>
          <AlertDialog>
            <AlertDialogTrigger asChild>
              <Button
                variant="ghost"
                size="icon"
                className="text-muted-foreground hover:text-destructive absolute top-3 right-3 z-10 size-8 opacity-0 transition-opacity group-hover:opacity-100"
                aria-label={`Delete ${notebook.title}`}
              >
                <Trash2 className="size-4" />
              </Button>
            </AlertDialogTrigger>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>Delete “{notebook.title}”?</AlertDialogTitle>
                <AlertDialogDescription>
                  This permanently deletes the notebook, its sources, and all cached AI answers.
                  This can&apos;t be undone.
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>Cancel</AlertDialogCancel>
                <AlertDialogAction
                  onClick={() => remove(notebook.id)}
                  disabled={deleting === notebook.id}
                  className={cn("bg-destructive text-white hover:bg-destructive/90")}
                >
                  {deleting === notebook.id ? "Deleting…" : "Delete"}
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </div>
      ))}
    </div>
  );
}
