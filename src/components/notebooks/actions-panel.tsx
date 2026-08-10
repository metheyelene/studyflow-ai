"use client";

import { useState } from "react";
import {
  BookOpen,
  FileQuestion,
  GitBranch,
  HelpCircle,
  ListOrdered,
  ListTree,
  Loader2,
  NotebookPen,
  ScanSearch,
  Sparkles,
  Wand2,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import { ACTION_LABELS, type ActionName } from "@/lib/ai/types";

interface ActionResult<T = unknown> {
  action: string;
  data: T;
  provider: string;
  model: string;
  sourcesUsed: string[];
}

type ResultState =
  | { status: "idle" }
  | { status: "busy"; action: string }
  | { status: "error"; action: string; message: string }
  | { status: "done"; action: string; result: ActionResult };

const ACTIONS: { name: ActionName; icon: typeof Sparkles; needsInput?: boolean }[] = [
  { name: "summarize", icon: NotebookPen },
  { name: "explain", icon: Sparkles, needsInput: true },
  { name: "flashcards", icon: BookOpen },
  { name: "quiz", icon: FileQuestion },
  { name: "studyGuide", icon: ListOrdered },
  { name: "faq", icon: HelpCircle },
  { name: "outline", icon: ListTree },
  { name: "extract", icon: ScanSearch },
  { name: "compare", icon: GitBranch, needsInput: true },
  { name: "mindMap", icon: Wand2 },
];

export function ActionsPanel({ notebookId }: { notebookId: string }) {
  const [state, setState] = useState<ResultState>({ status: "idle" });
  const [customInput, setCustomInput] = useState<{ action: ActionName; value: string } | null>(null);

  async function run(action: ActionName, params: Record<string, string | number | undefined> = {}) {
    setState({ status: "busy", action });
    try {
      const res = await fetch(`/api/notebooks/${notebookId}/actions`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action, params }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "That action failed.");
      setState({ status: "done", action, result: data.result });
    } catch (err) {
      setState({ status: "error", action, message: err instanceof Error ? err.message : "That failed." });
    }
  }

  return (
    <div className="flex h-full min-h-0 flex-col gap-3">
      <h2 className="text-muted-foreground text-xs font-semibold tracking-wider uppercase">
        Study tools
      </h2>

      <div className="flex flex-wrap gap-1.5">
        {ACTIONS.map(({ name, icon: Icon, needsInput }) => (
          <Button
            key={name}
            variant="glass-secondary"
            size="sm"
            onClick={() => {
              if (needsInput) {
                setCustomInput(customInput?.action === name ? null : { action: name, value: "" });
              } else {
                void run(name);
              }
            }}
          >
            <Icon className="size-3.5" />
            {ACTION_LABELS[name]}
          </Button>
        ))}
      </div>

      {customInput && (
        <form
          className="glass-subtle flex gap-2 rounded-xl p-2"
          onSubmit={(e) => {
            e.preventDefault();
            const input = customInput.value.trim();
            if (!input) return;
            const params =
              customInput.action === "explain" ? { concept: input, level: "beginner" } : { target: input };
            setCustomInput(null);
            void run(customInput.action, params);
          }}
        >
          <Input
            value={customInput.value}
            onChange={(e) => setCustomInput({ ...customInput, value: e.target.value })}
            placeholder={customInput.action === "explain" ? "e.g. threshold voltage" : "e.g. Chapter 2 vs Chapter 5"}
            className="h-9 flex-1"
            autoFocus
          />
          <Button type="submit" size="sm" disabled={!customInput.value.trim()}>
            Run
          </Button>
        </form>
      )}

      <div className="flex-1 space-y-4 overflow-y-auto pr-1">
        {state.status === "idle" && (
          <div className="glass-subtle flex flex-col items-center gap-2 rounded-2xl px-4 py-10 text-center">
            <Wand2 className="text-primary size-6" />
            <p className="text-muted-foreground text-sm">
              Turn this notebook into summaries, flashcards, quizzes, a study guide, and more —
              every item grounded in and cited to your sources.
            </p>
          </div>
        )}

        {state.status === "busy" && (
          <div className="glass-subtle flex items-center gap-2 rounded-2xl px-4 py-6 text-sm">
            <Loader2 className="text-primary size-4 animate-spin" />
            Generating {ACTION_LABELS[state.action].toLowerCase()} from your sources…
          </div>
        )}

        {state.status === "error" && (
          <div className="glass-subtle text-destructive rounded-2xl px-4 py-4 text-sm">{state.message}</div>
        )}

        {state.status === "done" && <ResultView result={state.result} />}
      </div>
    </div>
  );
}

function ResultView({ result }: { result: ActionResult }) {
  const data = result.data as Record<string, unknown>;

  if (typeof data.text === "string") {
    return (
      <div className="glass rounded-2xl px-4 py-4">
        <ResultHeader action={result.action} />
        <div className="text-muted-foreground whitespace-pre-wrap text-sm leading-relaxed">{data.text}</div>
      </div>
    );
  }

  if (result.action === "quiz") {
    const questions = data.questions as Array<{
      question: string;
      options: string[];
      correctIndex: number;
      explanation?: string;
    }>;
    return (
      <div className="space-y-3">
        <ResultHeader action={result.action} />
        {questions?.map((q, qi) => (
          <div key={qi} className="glass rounded-2xl px-4 py-3">
            <p className="font-medium text-sm">
              {qi + 1}. {q.question}
            </p>
            <ul className="mt-2 space-y-1">
              {q.options.map((opt, oi) => (
                <li
                  key={oi}
                  className={cn(
                    "rounded-lg px-3 py-1.5 text-sm",
                    oi === q.correctIndex
                      ? "bg-primary/15 text-primary font-medium"
                      : "text-muted-foreground",
                  )}
                >
                  {oi === q.correctIndex ? "✓ " : ""}
                  {opt}
                </li>
              ))}
            </ul>
            {q.explanation && (
              <p className="text-muted-foreground mt-2 border-t border-[--glass-border] pt-2 text-xs">
                {q.explanation}
              </p>
            )}
          </div>
        ))}
      </div>
    );
  }

  if (result.action === "flashcards") {
    const cards = data.cards as Array<{ front: string; back: string }>;
    return (
      <div className="space-y-3">
        <ResultHeader action={result.action} />
        <div className="grid gap-2 sm:grid-cols-2">
          {cards?.map((card, i) => (
            <div key={i} className="glass rounded-2xl px-4 py-3">
              <p className="font-medium text-sm">{card.front}</p>
              <p className="text-muted-foreground mt-1.5 text-sm">{card.back}</p>
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (result.action === "studyGuide") {
    const g = data as { keyConcepts?: string[]; definitions?: { term: string; definition: string }[]; formulas?: { name: string; formula: string }[]; revisionChecklist?: string[]; topics?: string[] };
    return (
      <div className="space-y-4">
        <ResultHeader action={result.action} />
        <GuideSection title="Key concepts" items={g.keyConcepts} />
        <GuideSection
          title="Definitions"
          items={g.definitions?.map((d) => `${d.term} — ${d.definition}`)}
        />
        <GuideSection title="Formulas" items={g.formulas?.map((f) => `${f.name}: ${f.formula}`)} />
        <GuideSection title="Revision checklist" items={g.revisionChecklist} />
        <GuideSection title="Topics" items={g.topics} />
      </div>
    );
  }

  if (result.action === "faq") {
    const items = data.items as Array<{ question: string; answer: string }>;
    return (
      <div className="space-y-3">
        <ResultHeader action={result.action} />
        {items?.map((item, i) => (
          <div key={i} className="glass rounded-2xl px-4 py-3">
            <p className="font-medium text-sm">{item.question}</p>
            <p className="text-muted-foreground mt-1 text-sm">{item.answer}</p>
          </div>
        ))}
      </div>
    );
  }

  if (result.action === "outline") {
    const o = data as { title?: string; sections?: { heading: string; points: string[] }[] };
    return (
      <div className="space-y-3">
        <ResultHeader action={result.action} />
        {o.title && <h3 className="font-semibold">{o.title}</h3>}
        {o.sections?.map((s, i) => (
          <div key={i} className="glass rounded-2xl px-4 py-3">
            <p className="font-medium text-sm">{s.heading}</p>
            <ul className="text-muted-foreground mt-1 space-y-0.5 text-sm">
              {s.points.map((p, pi) => (
                <li key={pi}>• {p}</li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    );
  }

  if (result.action === "mindMap") {
    const m = data as { topic?: string; subtopics?: { name: string; details: string[] }[] };
    return (
      <div className="space-y-3">
        <ResultHeader action={result.action} />
        <div className="glass bg-primary/5 rounded-2xl px-4 py-3">
          <p className="font-semibold">{m.topic}</p>
          <div className="mt-2 space-y-2">
            {m.subtopics?.map((s, i) => (
              <div key={i} className="border-l-2 border-primary/30 pl-3">
                <p className="text-sm font-medium">└ {s.name}</p>
                {s.details.length > 0 && (
                  <p className="text-muted-foreground mt-0.5 text-xs">{s.details.join(" · ")}</p>
                )}
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  // extract and anything else: render as a generic key/value list
  return (
    <div className="space-y-3">
      <ResultHeader action={result.action} />
      {Object.entries(data).map(([key, value]) => {
        if (typeof value === "string") {
          return (
            <p key={key} className="glass rounded-2xl px-4 py-2.5 text-sm">
              <span className="font-medium capitalize">{key}: </span>
              {value}
            </p>
          );
        }
        if (Array.isArray(value) && value.every((v) => typeof v === "string")) {
          return <GuideSection key={key} title={key} items={value as string[]} />;
        }
        return null;
      })}
    </div>
  );
}

function GuideSection({ title, items }: { title: string; items?: string[] }) {
  if (!items || items.length === 0) return null;
  return (
    <div className="glass rounded-2xl px-4 py-3">
      <h3 className="mb-1 text-xs font-semibold tracking-wider text-muted-foreground uppercase">{title}</h3>
      <ul className="text-muted-foreground space-y-0.5 text-sm">
        {items.map((item, i) => (
          <li key={i}>• {item}</li>
        ))}
      </ul>
    </div>
  );
}

function ResultHeader({ action }: { action: string }) {
  return (
    <div className="mb-3 flex items-center justify-between">
      <h3 className="text-sm font-semibold tracking-wide">{ACTION_LABELS[action] ?? action}</h3>
      <span className="text-muted-foreground text-[10px]">from your sources</span>
    </div>
  );
}
