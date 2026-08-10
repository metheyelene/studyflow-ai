"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Archive, ArchiveRestore, ArrowLeft, Check, Loader2, Star, Trash2, TriangleAlert } from "lucide-react";

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
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { cn } from "@/lib/utils";
import type { Note, NoteSubject } from "@/lib/notes-types";

type SaveState = "saved" | "saving" | "error";

const SAVE_DEBOUNCE_MS = 700;

export function NoteEditor({
  note,
  subjects,
  onUpdate,
  onDelete,
  onSelectNote,
}: {
  note: Note;
  subjects: NoteSubject[];
  onUpdate: (note: Note) => void;
  onDelete: (noteId: string) => void;
  onSelectNote: (id: string | null) => void;
}) {
  const [title, setTitle] = useState(note.title);
  const [content, setContent] = useState(note.content);
  const [saveState, setSaveState] = useState<SaveState>("saved");
  const [lastSaved, setLastSaved] = useState<Date | null>(null);
  const busyRef = useRef(false);

  // The workspace remounts this editor per note (key={id}), so initial
  // state is always in sync with the note being edited — no reset effect.

  const save = useCallback(
    async (payload: {
      title?: string;
      content?: string;
      subjectId?: string | null;
      favorite?: boolean;
      archived?: boolean;
    }) => {
      if (busyRef.current) return;
      busyRef.current = true;
      setSaveState("saving");
      try {
        const res = await fetch(`/api/notes/${note.id}`, {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error ?? "Save failed.");
        onUpdate(data.note as Note);
        setSaveState("saved");
        setLastSaved(new Date());
      } catch {
        setSaveState("error");
      } finally {
        busyRef.current = false;
      }
    },
    [note.id, onUpdate],
  );

  // Debounced autosave for text edits. saveState is set to "saving" in
  // the onChange handlers (user events), never in the effect.
  useEffect(() => {
    if (title === note.title && content === note.content) return;
    const timer = setTimeout(() => {
      void save({ title, content });
    }, SAVE_DEBOUNCE_MS);
    return () => clearTimeout(timer);
  }, [title, content, note.title, note.content, save]);

  const words = content.trim() ? content.trim().split(/\s+/).length : 0;

  return (
    <div className="flex h-full min-h-0 flex-col gap-3">
      {/* Title + actions */}
      <div className="flex items-start gap-2">
        <button
          onClick={() => onSelectNote(null)}
          className="text-muted-foreground hover:text-foreground -ml-1 rounded-lg p-1.5 md:hidden"
          aria-label="Back to notes"
        >
          <ArrowLeft className="size-5" />
        </button>
        <input
          value={title}
          onChange={(e) => {
            setTitle(e.target.value);
            setSaveState("saving");
          }}
          placeholder="Note title"
          aria-label="Note title"
          className="min-w-0 flex-1 bg-transparent text-xl font-semibold tracking-tight placeholder:text-muted-foreground/50 focus:outline-none"
        />
        <button
          onClick={() => void save({ favorite: !note.favorite })}
          className={cn(
            "rounded-lg p-2 transition-colors",
            note.favorite ? "text-amber-500" : "text-muted-foreground hover:text-amber-500",
          )}
          aria-label={note.favorite ? "Remove from favorites" : "Add to favorites"}
        >
          <Star className={cn("size-5", note.favorite && "fill-amber-500")} />
        </button>
        <Button
          variant="ghost"
          size="icon"
          onClick={() => void save({ archived: !note.archivedAt })}
          className="text-muted-foreground hover:text-foreground"
          aria-label={note.archivedAt ? "Unarchive" : "Archive"}
        >
          {note.archivedAt ? <ArchiveRestore className="size-4" /> : <Archive className="size-4" />}
        </Button>
        <AlertDialog>
          <AlertDialogTrigger asChild>
            <Button
              variant="ghost"
              size="icon"
              className="text-muted-foreground hover:text-destructive"
              aria-label="Delete note"
            >
              <Trash2 className="size-4" />
            </Button>
          </AlertDialogTrigger>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>Delete “{note.title || "Untitled"}”?</AlertDialogTitle>
              <AlertDialogDescription>
                This permanently deletes the note. This can&apos;t be undone.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>Cancel</AlertDialogCancel>
              <AlertDialogAction
                className="bg-destructive text-white hover:bg-destructive/90"
                onClick={async () => {
                  await fetch(`/api/notes/${note.id}`, { method: "DELETE" }).catch(() => {});
                  onDelete(note.id);
                }}
              >
                Delete
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      </div>

      {/* Meta row */}
      <div className="flex flex-wrap items-center gap-2">
        {subjects.length > 0 ? (
          <Select
            value={note.subjectId ?? "none"}
            onValueChange={(v) => void save({ subjectId: v === "none" ? null : v })}
          >
            <SelectTrigger className="h-8 w-44 text-xs">
              <SelectValue placeholder="No subject" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="none">No subject</SelectItem>
              {subjects.map((s) => (
                <SelectItem key={s.id} value={s.id}>
                  {s.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        ) : (
          <span className="text-muted-foreground text-xs">Add subjects in onboarding or Settings</span>
        )}
        {note.archivedAt && (
          <span className="glass-subtle text-muted-foreground inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs">
            <Archive className="size-3" /> Archived
          </span>
        )}
      </div>

      {/* Content */}
      <textarea
        value={content}
        onChange={(e) => {
          setContent(e.target.value);
          setSaveState("saving");
        }}
        placeholder="Start writing… your work autosaves."
        aria-label="Note content"
        className="min-h-0 flex-1 resize-none bg-transparent text-[15px] leading-relaxed placeholder:text-muted-foreground/50 focus:outline-none"
      />

      {/* Footer: save status + stats */}
      <div className="text-muted-foreground flex items-center justify-between border-t border-[--glass-border] pt-2.5 text-xs">
        <div className="flex items-center gap-1.5">
          {saveState === "saving" && (
            <>
              <Loader2 className="size-3.5 animate-spin" /> Saving…
            </>
          )}
          {saveState === "saved" && (
            <>
              <Check className="size-3.5 text-emerald-500" />
              {lastSaved ? `Saved ${lastSaved.toLocaleTimeString()}` : "Saved"}
            </>
          )}
          {saveState === "error" && (
            <>
              <TriangleAlert className="text-destructive size-3.5" /> Not saved
              <button onClick={() => void save({ title, content })} className="hover:text-foreground underline">
                Retry
              </button>
            </>
          )}
        </div>
        <div className="flex items-center gap-3">
          <span>{words} words</span>
          <span>{content.length.toLocaleString()} chars</span>
        </div>
      </div>
    </div>
  );
}
