"use client";

import { useRef, useState } from "react";
import { FileText, FileUp, Loader2, Paperclip, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { NotebookSource } from "@/lib/ai/types";

const ACCEPT = ".pdf,.docx,.txt,.md,.markdown";

export function SourcePanel({
  notebookId,
  sources,
  onChange,
}: {
  notebookId: string;
  sources: NotebookSource[];
  onChange: (sources: NotebookSource[]) => void;
}) {
  const [pasteOpen, setPasteOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pasteTitle, setPasteTitle] = useState("");
  const [pasteText, setPasteText] = useState("");
  const fileRef = useRef<HTMLInputElement>(null);

  async function upload(file: File) {
    setBusy(true);
    setError(null);
    try {
      const form = new FormData();
      form.append("file", file);
      const res = await fetch(`/api/notebooks/${notebookId}/sources`, { method: "POST", body: form });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "Upload failed.");
      onChange([...sources, data.source]);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Upload failed.");
    } finally {
      setBusy(false);
      if (fileRef.current) fileRef.current.value = "";
    }
  }

  async function paste() {
    if (!pasteTitle.trim() || !pasteText.trim() || busy) return;
    setBusy(true);
    setError(null);
    try {
      const res = await fetch(`/api/notebooks/${notebookId}/sources`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: pasteTitle.trim(), text: pasteText }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "Failed to add source.");
      onChange([...sources, data.source]);
      setPasteOpen(false);
      setPasteTitle("");
      setPasteText("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to add source.");
    } finally {
      setBusy(false);
    }
  }

  async function remove(sourceId: string) {
    const res = await fetch(`/api/notebooks/${notebookId}/sources/${sourceId}`, { method: "DELETE" });
    if (res.ok) onChange(sources.filter((s) => s.id !== sourceId));
  }

  return (
    <div className="flex h-full flex-col gap-3">
      <div className="flex items-center justify-between">
        <h2 className="text-muted-foreground text-xs font-semibold tracking-wider uppercase">
          Sources · {sources.length}
        </h2>
        <div className="flex gap-1.5">
          <Button variant="glass-secondary" size="sm" onClick={() => setPasteOpen(true)}>
            <Paperclip className="size-3.5" /> Paste
          </Button>
          <Button variant="glass-secondary" size="sm" onClick={() => fileRef.current?.click()} disabled={busy}>
            {busy ? <Loader2 className="size-3.5 animate-spin" /> : <FileUp className="size-3.5" />}
            Upload
          </Button>
          <input
            ref={fileRef}
            type="file"
            accept={ACCEPT}
            className="hidden"
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) void upload(f);
            }}
          />
        </div>
      </div>

      {error && <p className="text-destructive rounded-lg bg-destructive/10 px-3 py-2 text-xs">{error}</p>}

      <div className="flex-1 space-y-2 overflow-y-auto">
        {sources.length === 0 ? (
          <div className="glass-subtle flex flex-col items-center gap-2 rounded-2xl px-4 py-8 text-center">
            <FileText className="text-muted-foreground size-6" />
            <p className="text-muted-foreground text-sm">
              No sources yet. Paste your notes or upload a PDF — StudyFlow AI will index it and
              answer only from what&apos;s here.
            </p>
          </div>
        ) : (
          sources.map((source) => (
            <div key={source.id} className="glass-subtle group flex items-start gap-2.5 rounded-xl px-3 py-2.5">
              <div className="bg-primary/10 text-primary mt-0.5 flex size-7 shrink-0 items-center justify-center rounded-lg">
                <FileText className="size-3.5" />
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium">{source.title}</p>
                <p className="text-muted-foreground text-xs">
                  {source.status === "ready" ? (
                    <>
                      {source.wordCount?.toLocaleString() ?? 0} words
                      {source.pageCount ? ` · ${source.pageCount} pages` : ""}
                      {source.version > 1 ? ` · v${source.version}` : ""}
                    </>
                  ) : source.status === "failed" ? (
                    <span className="text-destructive">Failed — {source.errorMessage}</span>
                  ) : (
                    "Processing…"
                  )}
                </p>
              </div>
              <button
                onClick={() => remove(source.id)}
                className="text-muted-foreground hover:text-destructive rounded-md p-1 opacity-0 transition-opacity group-hover:opacity-100"
                aria-label={`Remove ${source.title}`}
              >
                <Trash2 className="size-3.5" />
              </button>
            </div>
          ))
        )}
      </div>

      <Dialog open={pasteOpen} onOpenChange={setPasteOpen}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>Paste a source</DialogTitle>
            <DialogDescription>
              Class notes, lecture text, or anything copyable. Re-adding a source with the same
              title replaces it (and refreshes cached answers).
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="src-title">Title</Label>
              <Input
                id="src-title"
                value={pasteTitle}
                onChange={(e) => setPasteTitle(e.target.value)}
                placeholder="e.g. Lecture 3 — Cell respiration"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="src-text">Content</Label>
              <Textarea
                id="src-text"
                value={pasteText}
                onChange={(e) => setPasteText(e.target.value)}
                rows={10}
                placeholder="Paste the study material here…"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setPasteOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button onClick={paste} disabled={!pasteTitle.trim() || !pasteText.trim() || busy}>
              {busy ? "Adding…" : "Add source"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
