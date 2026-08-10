"use client";

import { useState } from "react";
import Link from "next/link";
import { KeyRound, Loader2 } from "lucide-react";

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

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const { error: authError } = await authClient.requestPasswordReset({
        email,
        redirectTo: "/reset-password",
      });
      if (authError) {
        setError(
          "We couldn't send a reset link right now. Please try again in a minute.",
        );
        return;
      }
      setSent(true);
    } catch {
      setError(
        "We couldn't send a reset link right now. Please try again in a minute.",
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <Card>
      <CardHeader className="text-center">
        <div className="mb-2 flex justify-center">
          <div className="bg-primary text-primary-foreground flex size-11 items-center justify-center rounded-xl">
            <KeyRound className="size-5" />
          </div>
        </div>
        <CardTitle className="text-xl">Reset your password</CardTitle>
        <CardDescription>
          Enter your email and we will send you a reset link.
        </CardDescription>
      </CardHeader>
      <CardContent>
        {sent ? (
          <div className="grid gap-3 text-center">
            <p className="text-sm">
              If an account exists for that email, a reset link is on its way.
            </p>
            <p className="text-muted-foreground text-xs">
              (In development, the link is printed to the server console.)
            </p>
            <Button asChild variant="outline" className="mt-2">
              <Link href="/login">Back to log in</Link>
            </Button>
          </div>
        ) : (
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
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                autoComplete="email"
                placeholder="you@university.edu"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
            <Button type="submit" disabled={loading} className="w-full">
              {loading && <Loader2 className="animate-spin" />}
              Send reset link
            </Button>
            <p className="text-muted-foreground text-center text-sm">
              Remembered it?{" "}
              <Link href="/login" className="text-foreground font-medium hover:underline">
                Log in
              </Link>
            </p>
          </form>
        )}
      </CardContent>
    </Card>
  );
}
