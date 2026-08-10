"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Library, Plus } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

export function NotebookCreateDialog({ variant = "default" }: { variant?: "default" | "button" }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function create() {
    if (!title.trim() || busy) return;
    setBusy(true);
    setError(null);
    try {
      const res = await fetch("/api/notebooks", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: title.trim(), description: description.trim() || undefined }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "Failed to create notebook.");
      setOpen(false);
      setTitle("");
      setDescription("");
      router.push(`/notebooks/${data.notebook.id}`);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        {variant === "button" ? (
          <Button>
            <Plus className="size-4" /> Create notebook
          </Button>
        ) : (
          <Button>
            <Plus className="size-4" /> New notebook
          </Button>
        )}
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Library className="text-primary size-5" /> New notebook
          </DialogTitle>
          <DialogDescription>
            A private knowledge space. Add sources (notes, PDFs, docs), then ask questions and
            generate study material grounded in them.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="nb-title">Title</Label>
            <Input
              id="nb-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder='e.g. "VLSI Unit 3" or "Biology — Photosynthesis"'
              maxLength={120}
              autoFocus
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="nb-desc">Description (optional)</Label>
            <Textarea
              id="nb-desc"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="What is this notebook about?"
              rows={2}
              maxLength={300}
            />
          </div>
          {error && <p className="text-destructive text-sm">{error}</p>}
        </div>
        <DialogFooter>
          <Button variant="ghost" onClick={() => setOpen(false)} disabled={busy}>
            Cancel
          </Button>
          <Button onClick={create} disabled={!title.trim() || busy}>
            {busy ? "Creating…" : "Create notebook"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
