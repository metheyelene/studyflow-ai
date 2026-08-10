import { headers } from "next/headers";
import { eq } from "drizzle-orm";

import { NotesWorkspace } from "@/components/notes/notes-workspace";
import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";
import { listNotes } from "@/lib/notes";

export const dynamic = "force-dynamic";

export default async function NotesPage() {
  const session = await auth.api.getSession({ headers: await headers() });
  const db = getDb();
  const userId = session?.user.id ?? "";

  const [notes, subjects] = await Promise.all([
    listNotes(userId, { archived: false }),
    db.query.subjects.findMany({
      where: eq(schema.subjects.userId, userId),
      orderBy: (t, { asc }) => [asc(t.name)],
    }),
  ]);

  return (
    <NotesWorkspace
      initialNotes={notes.map((n) => ({
        ...n,
        createdAt: n.createdAt.toISOString(),
        updatedAt: n.updatedAt.toISOString(),
        archivedAt: n.archivedAt ? n.archivedAt.toISOString() : null,
      }))}
      subjects={subjects.map((s) => ({ id: s.id, name: s.name, color: s.color }))}
    />
  );
}
