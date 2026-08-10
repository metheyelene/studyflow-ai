"use client";

import { useActionState, useState } from "react";
import { Download, KeyRound, Loader2, Save } from "lucide-react";

import { authClient } from "@/lib/auth-client";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

import { EDUCATION_LEVELS, exportDataAction, updateProfileAction } from "./actions";

const TIMEZONES = [
  "America/New_York",
  "America/Chicago",
  "America/Denver",
  "America/Los_Angeles",
  "America/Sao_Paulo",
  "Europe/London",
  "Europe/Paris",
  "Europe/Berlin",
  "Africa/Lagos",
  "Africa/Nairobi",
  "Asia/Dubai",
  "Asia/Kolkata",
  "Asia/Singapore",
  "Asia/Shanghai",
  "Asia/Tokyo",
  "Australia/Sydney",
  "Pacific/Auckland",
];

export function SettingsForm({
  user,
  profile,
  subjects,
}: {
  user: { name: string; email: string };
  profile: {
    course: string | null;
    educationLevel: string | null;
    timezone: string | null;
    goal: string | null;
    dailyStudyMinutes: number;
  } | null;
  subjects: string[];
}) {
  const [state, formAction, pending] = useActionState(updateProfileAction, {});
  const [pw, setPw] = useState({ current: "", next: "" });
  const [pwMsg, setPwMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [pwPending, setPwPending] = useState(false);
  const [exporting, setExporting] = useState(false);

  async function handlePassword(e: React.FormEvent) {
    e.preventDefault();
    setPwMsg(null);
    if (pw.next.length < 8) {
      setPwMsg({ ok: false, text: "New password needs at least 8 characters." });
      return;
    }
    setPwPending(true);
    try {
      const { error } = await authClient.changePassword({
        currentPassword: pw.current,
        newPassword: pw.next,
        revokeOtherSessions: true,
      });
      if (error) {
        setPwMsg({ ok: false, text: "Current password is incorrect." });
      } else {
        setPwMsg({ ok: true, text: "Password updated." });
        setPw({ current: "", next: "" });
      }
    } catch {
      setPwMsg({ ok: false, text: "Something went wrong. Please try again." });
    } finally {
      setPwPending(false);
    }
  }

  async function handleExport() {
    setExporting(true);
    try {
      const result = await exportDataAction();
      if ("error" in result && result.error) {
        alert(result.error);
        return;
      }
      const blob = new Blob([JSON.stringify(result.data, null, 2)], {
        type: "application/json",
      });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `studyflow-export-${new Date().toISOString().slice(0, 10)}.json`;
      a.click();
      URL.revokeObjectURL(url);
    } finally {
      setExporting(false);
    }
  }

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Profile</CardTitle>
          <CardDescription>
            How StudyFlow addresses you and how you study.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form action={formAction} className="grid gap-4">
            {state.error && (
              <p role="alert" className="bg-destructive/10 text-destructive rounded-md px-3 py-2 text-sm">
                {state.error}
              </p>
            )}
            {state.ok && (
              <p className="bg-primary/10 text-primary rounded-md px-3 py-2 text-sm">
                Profile saved.
              </p>
            )}
            <div className="grid gap-2">
              <Label htmlFor="name">Display name</Label>
              <Input
                id="name"
                name="name"
                defaultValue={user.name}
                required
                maxLength={100}
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="course">What are you studying?</Label>
              <Input
                id="course"
                name="course"
                defaultValue={profile?.course ?? ""}
                placeholder="e.g. Medicine, Biology, Law"
                maxLength={120}
              />
            </div>
            <div className="grid gap-2">
              <Label>Education level</Label>
              <Select name="educationLevel" defaultValue={profile?.educationLevel ?? undefined}>
                <SelectTrigger>
                  <SelectValue placeholder="Select…" />
                </SelectTrigger>
                <SelectContent>
                  {EDUCATION_LEVELS.map((l) => (
                    <SelectItem key={l.value} value={l.value}>
                      {l.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="grid gap-2">
              <Label htmlFor="minutes">Daily study time (minutes)</Label>
              <Input
                id="minutes"
                name="dailyStudyMinutes"
                type="number"
                min={5}
                max={480}
                defaultValue={profile?.dailyStudyMinutes ?? 60}
                required
              />
            </div>
            <div className="grid gap-2">
              <Label>Timezone</Label>
              <Select name="timezone" defaultValue={profile?.timezone ?? undefined}>
                <SelectTrigger>
                  <SelectValue placeholder="Select…" />
                </SelectTrigger>
                <SelectContent>
                  {TIMEZONES.map((tz) => (
                    <SelectItem key={tz} value={tz}>
                      {tz}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="grid gap-2">
              <Label htmlFor="goal">What do you want help with?</Label>
              <Input
                id="goal"
                name="goal"
                defaultValue={profile?.goal ?? ""}
                placeholder="e.g. Summaries, flashcards, staying on schedule"
                maxLength={200}
              />
            </div>
            {subjects.length > 0 && (
              <div className="text-muted-foreground flex flex-wrap gap-1.5 text-xs">
                Subjects:
                {subjects.map((s) => (
                  <span key={s} className="bg-accent rounded-full px-2 py-0.5">
                    {s}
                  </span>
                ))}
              </div>
            )}
            <Button type="submit" disabled={pending} className="justify-self-start">
              {pending ? <Loader2 className="animate-spin" /> : <Save className="size-4" />}
              Save profile
            </Button>
          </form>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <KeyRound className="size-4" />
            Change password
          </CardTitle>
          <CardDescription>
            You will be logged out on other devices.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handlePassword} className="grid gap-4">
            {pwMsg && (
              <p
                role="alert"
                className={
                  pwMsg.ok
                    ? "bg-primary/10 text-primary rounded-md px-3 py-2 text-sm"
                    : "bg-destructive/10 text-destructive rounded-md px-3 py-2 text-sm"
                }
              >
                {pwMsg.text}
              </p>
            )}
            <div className="grid gap-2">
              <Label htmlFor="current-pw">Current password</Label>
              <Input
                id="current-pw"
                type="password"
                autoComplete="current-password"
                required
                value={pw.current}
                onChange={(e) => setPw((p) => ({ ...p, current: e.target.value }))}
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="new-pw">New password</Label>
              <Input
                id="new-pw"
                type="password"
                autoComplete="new-password"
                placeholder="At least 8 characters"
                required
                minLength={8}
                value={pw.next}
                onChange={(e) => setPw((p) => ({ ...p, next: e.target.value }))}
              />
            </div>
            <Button type="submit" disabled={pwPending} className="justify-self-start" variant="outline">
              {pwPending && <Loader2 className="animate-spin" />}
              Update password
            </Button>
          </form>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Your data</CardTitle>
          <CardDescription>
            Download everything we store for your account as JSON.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button
            type="button"
            variant="outline"
            disabled={exporting}
            onClick={handleExport}
          >
            {exporting ? <Loader2 className="animate-spin" /> : <Download className="size-4" />}
            Export my data
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
