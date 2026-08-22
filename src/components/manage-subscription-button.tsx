"use client";

import { useState } from "react";
import { ExternalLink, Loader2 } from "lucide-react";

import { Button } from "@/components/ui/button";

export function ManageSubscriptionButton() {
  const [state, setState] = useState<"idle" | "loading" | "unavailable">(
    "idle",
  );

  async function openPortal() {
    setState("loading");
    try {
      const res = await fetch("/api/billing/portal", { method: "POST" });
      if (res.status === 503) {
        setState("unavailable");
        return;
      }
      const data = (await res.json()) as { url?: string };
      if (!data.url) throw new Error("no portal url");
      window.location.href = data.url;
    } catch {
      setState("unavailable");
    }
  }

  if (state === "unavailable") {
    return (
      <p className="text-muted-foreground text-xs">
        Subscription management opens once billing is connected. Until then,
        email us to cancel — one reply, no hoops.
      </p>
    );
  }

  return (
    <Button variant="glass-secondary" onClick={openPortal} disabled={state === "loading"}>
      {state === "loading" && <Loader2 className="animate-spin" />}
      Manage subscription
      {state !== "loading" && <ExternalLink className="size-4" />}
    </Button>
  );
}
