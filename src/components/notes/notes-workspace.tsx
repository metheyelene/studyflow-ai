"use client";

import { useMemo, useState } from "react";
import { Archive, Loader2, Plus, Search, Star } from "lucide-react";

import { NoteEditor } from "@/components/notes/note-editor";
import { Button } from "@/components/ui/button";
import { GlassPill } from "@/components/ui/glass";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { cn } from "@/lib/utils";
import type { Note, NoteSubject } from "@/lib/notes-types";

type View = "all" | "favorites" | "archived";

export function NotesWorkspace({
  initialNotes,
  subjects,
}: {
  initialNotes: Note[];
  subjects: NoteSubject[];
}) {
  const [notes, setNotes] = useState<Note[]>(initialNotes);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [view, setView] = useState<View>("all");
  const [subjectFilter, setSubjectFilter] = useState<string>("all");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const selected = notes.find((n) => n.id === selectedId) ?? null;

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return notes
      .filter((n) => {
        if (view === "archived" && !n.archivedAt) return false;
        if (view !== "archived" && n.archivedAt) return false;
        if (view === "favorites" && !n.favorite) return false;
        if (subjectFilter !== "all" && n.subjectId !== subjectFilter) return false;
        if (q && !n.title.toLowerCase().includes(q) && !n.content.toLowerCase().includes(q)) return false;
        return true;
      })
      .sort((a, b) => Number(b.favorite) - Number(a.favorite) || b.updatedAt.localeCompare(a.updatedAt));
  }, [notes, search, view, subjectFilter]);

  async function createNote() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/notes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: "Untitled", content: "" }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "Failed to create the note.");
      const note: Note = data.note;
      setNotes((prev) => [note, ...prev]);
      setSelectedId(note.id);
      setView("all");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong.");
    } finally {
      setLoading(false);
    }
  }

  function updateNoteLocal(updated: Note) {
    setNotes((prev) => prev.map((n) => (n.id === updated.id ? updated : n)));
  }

  const subjectName = (id: string | null) => subjects.find((s) => s.id === id)?.name;

  return (
    <div className="mx-auto flex h-[calc(100dvh-7rem)] max-w-6xl flex-col gap-4 md:h-[calc(100dvh-5rem)]">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="font-semibold text-2xl tracking-tight">Notes</h1>
          <p className="text-muted-foreground mt-1 text-sm">
            {notes.length} note{notes.length === 1 ? "" : "s"} · autosaves as you type
          </p>
        </div>
        <Button onClick={createNote} disabled={loading}>
          {loading ? <Loader2 className="size-4 animate-spin" /> : <Plus className="size-4" />}
          New note
        </Button>
      </div>

      {error && <p className="text-destructive text-sm">{error}</p>}

      <div className="flex min-h-0 flex-1 flex-col gap-4 md:grid md:grid-cols-[320px_1fr]">
        {/* List pane — hidden on mobile while a note is open */}
        <div
          className={cn(
            "glass flex min-h-0 flex-col rounded-3xl p-3",
            selected ? "hidden md:flex" : "flex min-h-[40dvh] md:min-h-0",
          )}
        >
          <div className="relative">
            <Search className="text-muted-foreground absolute top-1/2 left-3 size-4 -translate-y-1/2" />
            <Input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search notes…"
              className="pl-9"
            />
          </div>

          <div className="mt-2.5 flex flex-wrap items-center gap-1.5">
            <GlassPill selected={view === "all"} onClick={() => setView("all")}>
              All
            </GlassPill>
            <GlassPill selected={view === "favorites"} onClick={() => setView("favorites")}>
              <Star className="size-3.5" /> Favorites
            </GlassPill>
            <GlassPill selected={view === "archived"} onClick={() => setView("archived")}>
              <Archive className="size-3.5" /> Archived
            </GlassPill>
          </div>

          {subjects.length > 0 && (
            <Select value={subjectFilter} onValueChange={setSubjectFilter}>
              <SelectTrigger className="mt-2.5 h-8 w-full text-xs">
                <SelectValue placeholder="All subjects" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All subjects</SelectItem>
                {subjects.map((s) => (
                  <SelectItem key={s.id} value={s.id}>
                    {s.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}

          <div className="mt-3 flex-1 space-y-1.5 overflow-y-auto pr-0.5">
            {filtered.length === 0 ? (
              <div className="glass-subtle mt-2 rounded-2xl px-4 py-8 text-center text-sm text-muted-foreground">
                {notes.length === 0
                  ? "No notes yet. Create your first one — it autosaves as you type."
                  : "Nothing matches those filters."}
              </div>
            ) : (
              filtered.map((note) => (
                <button
                  key={note.id}
                  onClick={() => setSelectedId(note.id)}
                  className={cn(
                    "w-full rounded-xl px-3 py-2.5 text-left transition-colors",
                    selectedId === note.id
                      ? "glass-strong"
                      : "glass-subtle hover:bg-[--glass-bg-strong]",
                  )}
                >
                  <div className="flex items-center justify-between gap-2">
                    <p className="truncate text-sm font-medium">
                      {note.favorite && <Star className="text-amber-500 mr-1 inline size-3.5 fill-amber-500" />}
                      {note.title || "Untitled"}
                    </p>
                    {note.archivedAt && <Archive className="text-muted-foreground size-3.5 shrink-0" />}
                  </div>
                  <p className="text-muted-foreground line-clamp-1 mt-0.5 text-xs">
                    {note.content.trim() ? note.content : "Empty note"}
                  </p>
                  <div className="text-muted-foreground mt-1 flex items-center gap-2 text-[10px]">
                    {note.subjectId && (
                      <span className="bg-primary/10 text-primary rounded-full px-1.5 py-px">
                        {subjectName(note.subjectId)}
                      </span>
                    )}
                    <span>{new Date(note.updatedAt).toLocaleDateString(undefined, { month: "short", day: "numeric" })}</span>
                  </div>
                </button>
              ))
            )}
          </div>
        </div>

        {/* Editor pane — full width on mobile when a note is open */}
        <div className={cn("glass min-h-0 rounded-3xl p-4", selected ? "flex min-h-[60dvh] md:min-h-0 md:flex" : "hidden md:flex")}>
          {selected ? (
            <NoteEditor
              key={selected.id}
              note={selected}
              subjects={subjects}
              onUpdate={updateNoteLocal}
              onDelete={() => {
                setNotes((prev) => prev.filter((n) => n.id !== selected.id));
                setSelectedId(null);
              }}
              onSelectNote={setSelectedId}
            />
          ) : (
            <div className="flex h-full flex-col items-center justify-center gap-2 text-center">
              <div className="bg-primary/10 text-primary flex size-12 items-center justify-center rounded-2xl">
                <Search className="size-6" />
              </div>
              <p className="font-medium">Select a note to edit</p>
              <p className="text-muted-foreground max-w-xs text-sm">
                Pick a note from the list, or create a new one. Everything autosaves.
              </p>
            </div>
          )}
        </div>
      </div>

    </div>
  );
}
