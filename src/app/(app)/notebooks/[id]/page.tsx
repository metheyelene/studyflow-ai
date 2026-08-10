import { headers } from "next/headers";
import { notFound } from "next/navigation";

import { NotebookWorkspace } from "@/components/notebooks/notebook-workspace";
import { auth } from "@/lib/auth";
import { getNotebookForUser, listSources } from "@/lib/ai/sources";

export const dynamic = "force-dynamic";

export default async function NotebookPage({ params }: { params: Promise<{ id: string }> }) {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) notFound();

  const { id } = await params;
  let notebook;
  let sources;
  try {
    notebook = await getNotebookForUser(session.user.id, id);
    sources = await listSources(session.user.id, id);
  } catch {
    notFound();
  }

  return (
    <NotebookWorkspace
      notebook={{
        ...notebook!,
        sourceCount: sources!.length,
        createdAt: notebook!.createdAt.toISOString(),
        updatedAt: notebook!.updatedAt.toISOString(),
      }}
      sources={sources!.map((s) => ({
        ...s,
        createdAt: s.createdAt.toISOString(),
        updatedAt: s.updatedAt.toISOString(),
      }))}
    />
  );
}
