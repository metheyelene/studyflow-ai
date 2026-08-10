"use client";

import * as React from "react";
import { AlertCircle, BookOpen, Trash2 } from "lucide-react";

import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Progress } from "@/components/ui/progress";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-4">
      <h2 className="border-b pb-2 text-sm font-semibold tracking-wide text-muted-foreground uppercase">
        {title}
      </h2>
      {children}
    </section>
  );
}

function Demo({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex flex-wrap items-center gap-3">{children}</div>
  );
}

export default function DesignSystemPage() {
  return (
    <div className="mx-auto max-w-3xl space-y-12 py-10">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold tracking-tight">Design System</h1>
        <p className="text-muted-foreground text-sm">
          StudyFlow AI style guide. Every component here uses the design tokens
          in <code className="bg-muted rounded px-1 py-0.5">src/app/globals.css</code> — toggle
          the theme in the top-right corner to review both modes.
        </p>
      </header>

      <Section title="Typography">
        <div className="space-y-1">
          <p className="text-4xl font-semibold tracking-tight">Display — Turn notes into a study system</p>
          <p className="text-2xl font-semibold tracking-tight">Heading — Dashboard</p>
          <p className="text-lg font-medium">Subheading — Welcome back, Alex</p>
          <p className="text-base">Body — This is regular body text for reading notes and descriptions.</p>
          <p className="text-sm text-muted-foreground">Muted — Helper text, hints, and secondary information.</p>
          <p className="text-xs text-muted-foreground">Caption — Timestamps and small labels.</p>
        </div>
      </Section>

      <Section title="Buttons">
        <Demo>
          <Button>Primary</Button>
          <Button variant="secondary">Secondary</Button>
          <Button variant="outline">Outline</Button>
          <Button variant="ghost">Ghost</Button>
          <Button variant="destructive">Destructive</Button>
          <Button variant="link">Link</Button>
          <Button size="sm">Small</Button>
          <Button size="lg">Large</Button>
          <Button disabled>Disabled</Button>
        </Demo>
      </Section>

      <Section title="Cards & badges">
        <div className="grid gap-4 sm:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle>Card title</CardTitle>
              <CardDescription>A description of what this card contains.</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="flex items-center gap-2">
                <Badge>Default</Badge>
                <Badge variant="secondary">Secondary</Badge>
                <Badge variant="outline">Outline</Badge>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <div className="bg-primary text-primary-foreground flex size-9 items-center justify-center rounded-lg">
                  <BookOpen className="size-4" />
                </div>
                With icon tile
              </CardTitle>
            </CardHeader>
            <CardContent className="flex items-center gap-3">
              <Avatar>
                <AvatarFallback>AS</AvatarFallback>
              </Avatar>
              <div>
                <p className="text-sm font-medium">Alex Student</p>
                <p className="text-muted-foreground text-xs">alex@university.edu</p>
              </div>
            </CardContent>
          </Card>
        </div>
      </Section>

      <Section title="Form controls">
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-2">
            <Label htmlFor="ds-input">Input</Label>
            <Input id="ds-input" placeholder="you@university.edu" />
          </div>
          <div className="space-y-2">
            <Label htmlFor="ds-textarea">Textarea</Label>
            <Textarea id="ds-textarea" placeholder="Paste your notes here…" />
          </div>
          <div className="space-y-2">
            <Label>Select</Label>
            <Select>
              <SelectTrigger className="w-full">
                <SelectValue placeholder="Pick a subject" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="anatomy">Anatomy</SelectItem>
                <SelectItem value="physiology">Physiology</SelectItem>
                <SelectItem value="biochemistry">Biochemistry</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="flex items-center justify-between rounded-md border px-3 py-2">
            <Label htmlFor="ds-switch">Reminder emails</Label>
            <Switch id="ds-switch" />
          </div>
        </div>
      </Section>

      <Section title="Alerts">
        <div className="space-y-3">
          <Alert variant="default">
            <AlertTitle>Heads up</AlertTitle>
            <AlertDescription>This is an informational message.</AlertDescription>
          </Alert>
          <Alert variant="info">
            <AlertTitle>New feature</AlertTitle>
            <AlertDescription>Summaries are coming in Week 3.</AlertDescription>
          </Alert>
          <Alert variant="warning">
            <AlertTitle>Almost out of AI actions</AlertTitle>
            <AlertDescription>You have 2 left this month.</AlertDescription>
          </Alert>
          <Alert variant="destructive">
            <AlertTitle>Something went wrong</AlertTitle>
            <AlertDescription>Please try again in a minute.</AlertDescription>
          </Alert>
        </div>
      </Section>

      <Section title="Dialogs">
        <Demo>
          <Dialog>
            <DialogTrigger asChild>
              <Button variant="outline">Open dialog</Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Create a note</DialogTitle>
                <DialogDescription>
                  Give your note a title and pick a subject.
                </DialogDescription>
              </DialogHeader>
              <div className="grid gap-3">
                <div className="grid gap-1.5">
                  <Label htmlFor="dlg-title">Title</Label>
                  <Input id="dlg-title" placeholder="Cell Biology — Lecture 4" />
                </div>
                <div className="grid gap-1.5">
                  <Label>Subject</Label>
                  <Select>
                    <SelectTrigger>
                      <SelectValue placeholder="Choose…" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="biology">Biology</SelectItem>
                      <SelectItem value="chem">Chemistry</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <DialogFooter>
                <Button type="button">Create note</Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>

          <AlertDialog>
            <AlertDialogTrigger asChild>
              <Button variant="destructive">Delete (confirm)</Button>
            </AlertDialogTrigger>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle className="flex items-center gap-2">
                  <AlertCircle className="text-destructive size-4" />
                  Delete this note?
                </AlertDialogTitle>
                <AlertDialogDescription>
                  This permanently removes the note and all its generated
                  flashcards. This cannot be undone.
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>Cancel</AlertDialogCancel>
                <AlertDialogAction className="bg-destructive text-destructive-foreground hover:bg-destructive/90">
                  <Trash2 className="size-4" />
                  Delete
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </Demo>
      </Section>

      <Section title="Tabs">
        <Tabs defaultValue="summary">
          <TabsList>
            <TabsTrigger value="summary">Summary</TabsTrigger>
            <TabsTrigger value="cards">Flashcards</TabsTrigger>
            <TabsTrigger value="quiz">Quiz</TabsTrigger>
          </TabsList>
          <TabsContent value="summary" className="text-muted-foreground rounded-md border p-4 text-sm">
            Summary content goes here.
          </TabsContent>
          <TabsContent value="cards" className="text-muted-foreground rounded-md border p-4 text-sm">
            Flashcard content goes here.
          </TabsContent>
          <TabsContent value="quiz" className="text-muted-foreground rounded-md border p-4 text-sm">
            Quiz content goes here.
          </TabsContent>
        </Tabs>
      </Section>

      <Section title="Progress & tooltips">
        <div className="space-y-4">
          <div className="space-y-1.5">
            <div className="flex justify-between text-xs">
              <span className="text-muted-foreground">AI actions used</span>
              <span className="font-medium">18 / 20</span>
            </div>
            <Progress value={90} />
          </div>
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="outline">Hover me</Button>
              </TooltipTrigger>
              <TooltipContent>Tooltips explain icons and actions.</TooltipContent>
            </Tooltip>
          </TooltipProvider>
        </div>
      </Section>

      <Section title="Skeleton & empty state">
        <div className="grid gap-4 sm:grid-cols-2">
          <Card>
            <CardContent className="space-y-3 pt-6">
              <Skeleton className="size-9 rounded-lg" />
              <Skeleton className="h-4 w-3/4" />
              <Skeleton className="h-4 w-1/2" />
              <Skeleton className="h-9 w-full rounded-md" />
            </CardContent>
          </Card>
          <Card>
            <CardContent className="flex flex-col items-center gap-2 py-8 text-center">
              <div className="bg-accent flex size-10 items-center justify-center rounded-lg">
                <BookOpen className="size-5" />
              </div>
              <p className="text-sm font-medium">No notes yet</p>
              <p className="text-muted-foreground max-w-[22ch] text-xs">
                Upload or paste your first note to start studying.
              </p>
              <Button size="sm" className="mt-1">
                Add a note
              </Button>
            </CardContent>
          </Card>
        </div>
      </Section>

      <Separator />
      <p className="text-muted-foreground pb-8 text-center text-xs">
        Design tokens: <code className="bg-muted rounded px-1 py-0.5">globals.css</code> · Spec:{" "}
        <code className="bg-muted rounded px-1 py-0.5">docs/ui-design-week1.md</code>
      </p>
    </div>
  );
}
