import { headers } from "next/headers";
import { Library } from "lucide-react";

import { NotebookCreateDialog } from "@/components/notebooks/notebook-create-dialog";
import { NotebookList } from "@/components/notebooks/notebook-list";
import { auth } from "@/lib/auth";
import { listNotebooks } from "@/lib/ai/sources";

export const dynamic = "force-dynamic";

export default async function NotebooksPage() {
  const session = await auth.api.getSession({ headers: await headers() });
  const rows = session ? await listNotebooks(session.user.id) : [];
  const notebooks = rows.map((n) => ({
    ...n,
    createdAt: n.createdAt.toISOString(),
    updatedAt: n.updatedAt.toISOString(),
  }));

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="font-black text-2xl uppercase tracking-tight">Notebooks</h1>
          <p className="text-muted-foreground mt-1 text-sm">
            Your private knowledge spaces. Add sources, ask questions, and turn them into study
            material — answers are grounded in your own notes.
          </p>
        </div>
        <NotebookCreateDialog />
      </div>

      {notebooks.length === 0 ? (
        <div className="border-2 border-border bg-secondary flex flex-col items-center gap-4 px-6 py-16 text-center">
          <div className="bg-foreground text-background flex size-14 items-center justify-center">
            <Library className="size-7" />
          </div>
          <div className="space-y-1">
            <h2 className="font-bold uppercase tracking-tight text-lg">Create your first notebook</h2>
            <p className="text-muted-foreground mx-auto max-w-md text-sm">
              Paste your class notes or upload a PDF, then ask StudyFlow AI anything about them —
              with citations back to the source.
            </p>
          </div>
          <NotebookCreateDialog variant="button" />
        </div>
      ) : (
        <NotebookList initial={notebooks} />
      )}
    </div>
  );
}
