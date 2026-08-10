"use client";

import { useRef, useState } from "react";
import { ArrowUp, Loader2, ShieldCheck, Sparkles } from "lucide-react";

import { GlassPill } from "@/components/ui/glass";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";
import type { AiMode, ChatMessage, Citation } from "@/lib/ai/types";

interface Trailer {
  citations: Citation[];
  stripped: number[];
  provider: string;
  model: string;
}

const TRAILER_MARKER = "__SF_CITATIONS__";

export function ChatPanel({ notebookId }: { notebookId: string }) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState("");
  const [mode, setMode] = useState<AiMode>("sources");
  const [streaming, setStreaming] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  async function send(override?: string) {
    const question = (override ?? input).trim();
    if (!question || streaming) return;
    const userMsg: ChatMessage = { role: "user", content: question };
    const history = messages.map((m) => ({ role: m.role, content: m.content }));
    setMessages((prev) => [...prev, userMsg, { role: "assistant", content: "" }]);
    setInput("");
    setStreaming(true);

    try {
      const res = await fetch(`/api/notebooks/${notebookId}/chat`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ question, mode, history }),
      });
      if (!res.ok || !res.body) {
        const data = await res.json().catch(() => null);
        const errorMsg = data?.error ?? "Something went wrong. Try again.";
        setMessages((prev) => [
          ...prev.slice(0, -1),
          { role: "assistant", content: errorMsg, error: true },
        ]);
        return;
      }

      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let text = "";
      let trailer: Trailer | null = null;

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        const chunk = decoder.decode(value, { stream: true });
        const markerIdx = chunk.indexOf(TRAILER_MARKER);
        if (markerIdx >= 0) {
          text += chunk.slice(0, markerIdx);
          try {
            trailer = JSON.parse(chunk.slice(markerIdx + TRAILER_MARKER.length)) as Trailer;
          } catch {
            trailer = null;
          }
        } else {
          text += chunk;
        }
        setMessages((prev) => {
          const next = [...prev];
          const last = next[next.length - 1];
          if (last && last.role === "assistant") {
            next[next.length - 1] = {
              ...last,
              content: text,
              citations: trailer?.citations,
              provider: trailer?.provider,
              model: trailer?.model,
              grounded: (trailer?.citations.length ?? 0) > 0,
            };
          }
          return next;
        });
        if (scrollRef.current) {
          scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
        }
      }
    } catch {
      setMessages((prev) => [
        ...prev.slice(0, -1),
        { role: "assistant", content: "Couldn't reach the AI service. Check your connection and try again.", error: true },
      ]);
    } finally {
      setStreaming(false);
    }
  }

  return (
    <div className="flex h-full min-h-0 flex-col gap-3">
      {/* Mode toggle */}
      <div className="flex items-center gap-2">
        <GlassPill selected={mode === "sources"} onClick={() => setMode("sources")}>
          <ShieldCheck className="size-3.5" /> Sources only
        </GlassPill>
        <GlassPill selected={mode === "study"} onClick={() => setMode("study")}>
          <Sparkles className="size-3.5" /> Study assistant
        </GlassPill>
        {mode === "sources" && (
          <span className="text-muted-foreground hidden text-xs sm:inline">
            Answers only from your sources — never outside knowledge.
          </span>
        )}
      </div>

      {/* Messages */}
      <div ref={scrollRef} className="flex-1 space-y-4 overflow-y-auto pr-1">
        {messages.length === 0 && (
          <div className="glass-subtle flex h-full flex-col items-center justify-center gap-2 rounded-2xl px-6 text-center">
            <Sparkles className="text-primary size-7" />
            <p className="font-medium">Ask anything about your sources</p>
            <p className="text-muted-foreground max-w-sm text-sm">
              Try: “Summarize the key concepts” · “What does it say about X?” · “Quiz me on this”
            </p>
          </div>
        )}

        {messages.map((msg, i) =>
          msg.role === "user" ? (
            <div key={i} className="flex justify-end">
              <div className="bg-primary text-primary-foreground max-w-[85%] rounded-2xl rounded-br-md px-4 py-2.5 text-sm shadow-sm">
                {msg.content}
              </div>
            </div>
          ) : (
            <div key={i} className="flex justify-start">
              <div
                className={cn(
                  "glass max-w-[92%] rounded-2xl rounded-bl-md px-4 py-3 text-sm leading-relaxed",
                  msg.error && "border-destructive/40 text-destructive",
                )}
              >
                {msg.content === "" && streaming ? (
                  <span className="flex items-center gap-2 text-muted-foreground">
                    <Loader2 className="size-3.5 animate-spin" /> Thinking from your sources…
                  </span>
                ) : (
                  <AnswerText content={msg.content} citations={msg.citations} />
                )}
                {msg.citations && msg.citations.length > 0 && (
                  <div className="mt-3 flex flex-wrap gap-1.5 border-t border-[--glass-border] pt-2.5">
                    {msg.citations.map((c) => (
                      <details key={c.marker} className="group">
                        <summary className="glass-subtle hover:bg-[--glass-bg-strong] cursor-pointer list-none rounded-full px-2.5 py-1 text-xs font-medium select-none">
                          [{c.marker}] {c.sourceTitle}
                          {c.page ? ` · p.${c.page}` : ""}
                        </summary>
                        <div className="glass-subtle absolute z-10 mt-1.5 max-w-xs rounded-xl p-3 text-xs">
                          “{c.excerpt.length > 220 ? `${c.excerpt.slice(0, 220)}…` : c.excerpt}”
                        </div>
                      </details>
                    ))}
                  </div>
                )}
                {msg.provider && !msg.error && (
                  <p className="text-muted-foreground mt-2 text-[10px]">
                    {msg.grounded ? "Grounded in your sources" : "General explanation"} · {msg.model}
                  </p>
                )}
              </div>
            </div>
          ),
        )}
      </div>

      {/* Input */}
      <form
        className="glass-subtle flex items-end gap-2 rounded-2xl p-2"
        onSubmit={(e) => {
          e.preventDefault();
          void send();
        }}
      >
        <Textarea
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder={mode === "sources" ? "Ask your sources…" : "Ask, or get a general explanation…"}
          rows={1}
          className="max-h-32 min-h-10 flex-1 resize-none border-0 bg-transparent shadow-none focus-visible:ring-0"
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              void send();
            }
          }}
        />
        <button
          type="submit"
          disabled={!input.trim() || streaming}
          className="bg-primary text-primary-foreground hover:bg-primary/90 flex size-9 shrink-0 items-center justify-center rounded-xl transition-all disabled:opacity-40"
          aria-label="Send"
        >
          {streaming ? <Loader2 className="size-4 animate-spin" /> : <ArrowUp className="size-4" />}
        </button>
      </form>
    </div>
  );
}

/** Render answer text with [n] citation markers as superscripts. */
function AnswerText({ content, citations }: { content: string; citations?: Citation[] }) {
  const parts = content.split(/(\[\d{1,2}\])/g);
  const byMarker = new Map(citations?.map((c) => [c.marker, c]) ?? []);
  return (
    <div className="whitespace-pre-wrap">
      {parts.map((part, i) => {
        const m = /^\[(\d{1,2})\]$/.exec(part);
        if (m && byMarker.has(Number(m[1]))) {
          return (
            <sup key={i} className="text-primary ml-0.5 font-semibold no-underline">
              {m[0]}
            </sup>
          );
        }
        return <span key={i}>{part}</span>;
      })}
    </div>
  );
}
