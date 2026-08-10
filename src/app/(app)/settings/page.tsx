import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { eq } from "drizzle-orm";

import { getDb, schema } from "@/db";
import { auth } from "@/lib/auth";
import { SettingsForm } from "./settings-form";

export default async function SettingsPage() {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) redirect("/login");

  const db = getDb();
  const profile = await db.query.profiles.findFirst({
    where: eq(schema.profiles.userId, session.user.id),
  });
  const subjects = await db.query.subjects.findMany({
    where: eq(schema.subjects.userId, session.user.id),
  });

  return (
    <div className="mx-auto max-w-2xl space-y-8">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Settings</h1>
        <p className="text-muted-foreground mt-1">
          Your profile, study preferences, and account actions.
        </p>
      </div>

      <SettingsForm
        user={{ name: session.user.name, email: session.user.email }}
        profile={profile ?? null}
        subjects={subjects.map((s) => s.name)}
      />
    </div>
  );
}
