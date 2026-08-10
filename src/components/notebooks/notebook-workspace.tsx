"use client";

import { useState } from "react";
import Link from "next/link";
import { ArrowLeft, Library, MessageSquareText, PanelLeft, Wand2 } from "lucide-react";

import { ActionsPanel } from "@/components/notebooks/actions-panel";
import { ChatPanel } from "@/components/notebooks/chat-panel";
import { SourcePanel } from "@/components/notebooks/source-panel";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import type { Notebook, NotebookSource } from "@/lib/ai/types";

export function NotebookWorkspace({
  notebook,
  sources: initialSources,
}: {
  notebook: Notebook;
  sources: NotebookSource[];
}) {
  const [sources, setSources] = useState(initialSources);

  return (
    <div className="mx-auto flex h-[calc(100dvh-7rem)] max-w-7xl flex-col gap-4 md:h-[calc(100dvh-5rem)]">
      {/* Header */}
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild className="-ml-2 shrink-0">
          <Link href="/notebooks" aria-label="Back to notebooks">
            <ArrowLeft className="size-4" />
          </Link>
        </Button>
        <div className="bg-primary/10 text-primary flex size-9 shrink-0 items-center justify-center rounded-xl">
          <Library className="size-4" />
        </div>
        <div className="min-w-0">
          <h1 className="truncate font-semibold text-lg">{notebook.title}</h1>
          {notebook.description && (
            <p className="text-muted-foreground truncate text-xs">{notebook.description}</p>
          )}
        </div>
        <div className="ml-auto md:hidden">
          <Sheet>
            <SheetTrigger asChild>
              <Button variant="glass-secondary" size="sm">
                <PanelLeft className="size-3.5" /> Sources
              </Button>
            </SheetTrigger>
            <SheetContent side="bottom" className="max-h-[70dvh]">
              <SheetHeader>
                <SheetTitle>Sources</SheetTitle>
                <SheetDescription>Add and manage what StudyFlow AI answers from.</SheetDescription>
              </SheetHeader>
              <div className="min-h-0 flex-1">
                <SourcePanel notebookId={notebook.id} sources={sources} onChange={setSources} />
              </div>
            </SheetContent>
          </Sheet>
        </div>
      </div>

      <div className="grid min-h-0 flex-1 gap-4 md:grid-cols-[290px_1fr]">
        {/* Desktop sources panel */}
        <aside className="glass hidden min-h-0 rounded-3xl p-4 md:block">
          <SourcePanel notebookId={notebook.id} sources={sources} onChange={setSources} />
        </aside>

        {/* Main: chat + study tools */}
        <div className="glass flex min-h-0 flex-col rounded-3xl p-4">
          <Tabs defaultValue="ask" className="flex min-h-0 flex-1 flex-col">
            <TabsList className="self-start">
              <TabsTrigger value="ask" className="gap-1.5">
                <MessageSquareText className="size-3.5" /> Ask
              </TabsTrigger>
              <TabsTrigger value="tools" className="gap-1.5">
                <Wand2 className="size-3.5" /> Study tools
              </TabsTrigger>
            </TabsList>
            <TabsContent value="ask" className="min-h-0 flex-1 data-[state=active]:flex">
              <ChatPanel notebookId={notebook.id} />
            </TabsContent>
            <TabsContent value="tools" className="min-h-0 flex-1 data-[state=active]:flex">
              <ActionsPanel notebookId={notebook.id} />
            </TabsContent>
          </Tabs>
        </div>
      </div>
    </div>
  );
}
