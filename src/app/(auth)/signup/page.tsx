"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { BookOpen, Loader2 } from "lucide-react";

import { signUp } from "@/lib/auth-client";
import { friendlyAuthError } from "@/lib/auth-errors";
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
import { Separator } from "@/components/ui/separator";
import { GoogleButton } from "@/components/social-buttons";

export default function SignupPage() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const { error: authError } = await signUp.email({
        name,
        email,
        password,
      });
      if (authError) {
        setError(friendlyAuthError(authError));
        return;
      }
      // Session cookie is set — the app shell routes to onboarding.
      router.push("/dashboard");
      router.refresh();
    } catch (err) {
      setError(friendlyAuthError(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <Card>
      <CardHeader className="text-center">
        <div className="mb-2 flex justify-center">
          <div className="bg-primary text-primary-foreground flex size-11 items-center justify-center rounded-xl">
            <BookOpen className="size-5" />
          </div>
        </div>
        <CardTitle className="text-xl">Create your free account</CardTitle>
        <CardDescription>
          Turn your notes into your smartest study system.
        </CardDescription>
      </CardHeader>
      <CardContent>
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
            <Label htmlFor="name">Your name</Label>
            <Input
              id="name"
              type="text"
              autoComplete="name"
              placeholder="Alex Student"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </div>
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
          <div className="grid gap-2">
            <Label htmlFor="password">Password</Label>
            <Input
              id="password"
              type="password"
              autoComplete="new-password"
              placeholder="At least 8 characters"
              required
              minLength={8}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>
          <Button type="submit" disabled={loading} className="w-full">
            {loading && <Loader2 className="animate-spin" />}
            Create account
          </Button>
        </form>

        <div className="relative my-4">
          <div className="absolute inset-0 flex items-center">
            <Separator />
          </div>
          <div className="relative flex justify-center">
            <span className="bg-card text-muted-foreground px-2 text-xs">or</span>
          </div>
        </div>

        <GoogleButton />

        <p className="text-muted-foreground mt-4 text-center text-sm">
          Already have an account?{" "}
          <Link href="/login" className="text-foreground font-medium underline-offset-4 hover:underline">
            Log in
          </Link>
        </p>
      </CardContent>
    </Card>
  );
}
