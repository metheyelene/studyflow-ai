// Client-safe types shared between the notes UI and API responses.
// No server-only imports — safe for "use client" components.

export interface Note {
  id: string;
  userId: string;
  subjectId: string | null;
  title: string;
  content: string;
  sourceType: "pasted" | "uploaded" | "generated";
  wordCount: number | null;
  favorite: boolean;
  archivedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface NoteSubject {
  id: string;
  name: string;
  color: string;
}
