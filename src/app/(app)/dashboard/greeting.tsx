"use client";

import { useSyncExternalStore } from "react";

const emptySubscribe = () => () => {};

function greetingFor(date: Date): string {
  const h = date.getHours();
  return h < 5
    ? "Good night"
    : h < 12
      ? "Good morning"
      : h < 18
        ? "Good afternoon"
        : "Good evening";
}

// Cached once per client session so the snapshot is stable across reads.
let clientGreeting: string | null = null;

function getSnapshot(): string {
  if (clientGreeting === null) {
    clientGreeting = greetingFor(new Date());
  }
  return clientGreeting;
}

export function Greeting({ firstName }: { firstName: string }) {
  // Server snapshot is null (falls back to the generic heading); after
  // hydration React swaps in the time-based greeting with no mismatch.
  const greeting = useSyncExternalStore(emptySubscribe, getSnapshot, () => null);

  return (
    <div>
      <h1 className="text-2xl font-semibold tracking-tight md:text-3xl">
        {greeting ?? "Welcome back"}, {firstName}
      </h1>
      <p className="text-muted-foreground mt-1">Ready to study?</p>
    </div>
  );
}
