"use client";

import { Suspense, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Loader2, ShieldCheck } from "lucide-react";

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

function ResetPasswordForm() {
  const searchParams = useSearchParams();
  const token = searchParams.get("token");

  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [loading, setLoading] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    if (password.length < 8) {
      setError("Your password needs to be at least 8 characters.");
      return;
    }
    if (password !== confirm) {
      setError("Those passwords don't match.");
      return;
    }
    if (!token) {
      setError("This reset link is missing its token. Request a new one.");
      return;
    }

    setLoading(true);
    try {
      const { error: authError } = await authClient.resetPassword({
        newPassword: password,
        token,
      });
      if (authError) {
        setError(
          "This link is invalid or has expired. Request a new reset link.",
        );
        return;
      }
      setDone(true);
    } catch {
      setError("Something went wrong. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  if (done) {
    return (
      <div className="grid gap-3 text-center">
        <div className="flex justify-center">
          <div className="bg-primary text-primary-foreground flex size-11 items-center justify-center rounded-xl">
            <ShieldCheck className="size-5" />
          </div>
        </div>
        <p className="text-sm">Your password has been updated.</p>
        <Button asChild className="mt-2">
          <Link href="/login">Log in with your new password</Link>
        </Button>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="grid gap-4">
      {error && (
        <p
          role="alert"
          className="bg-destructive/10 text-destructive rounded-md px-3 py-2 text-sm"
        >
          {error}
        </p>
      )}
      <div className="grid gap-2">
        <Label htmlFor="new-password">New password</Label>
        <Input
          id="new-password"
          type="password"
          autoComplete="new-password"
          placeholder="At least 8 characters"
          required
          minLength={8}
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
      </div>
      <div className="grid gap-2">
        <Label htmlFor="confirm-password">Confirm new password</Label>
        <Input
          id="confirm-password"
          type="password"
          autoComplete="new-password"
          placeholder="Repeat your new password"
          required
          value={confirm}
          onChange={(e) => setConfirm(e.target.value)}
        />
      </div>
      <Button type="submit" disabled={loading} className="w-full">
        {loading && <Loader2 className="animate-spin" />}
        Update password
      </Button>
    </form>
  );
}

export default function ResetPasswordPage() {
  return (
    <Card>
      <CardHeader className="text-center">
        <CardTitle className="text-xl">Choose a new password</CardTitle>
        <CardDescription>
          Pick a strong password you have not used before.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <Suspense fallback={null}>
          <ResetPasswordForm />
        </Suspense>
      </CardContent>
    </Card>
  );
}
