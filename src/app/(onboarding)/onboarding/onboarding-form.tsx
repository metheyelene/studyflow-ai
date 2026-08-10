"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { CalendarPlus, Loader2, Trash2 } from "lucide-react";

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
import { cn } from "@/lib/utils";

import { completeOnboarding, GOAL_OPTIONS } from "./actions";

interface ExamRow {
  name: string;
  date: string;
}

export function OnboardingForm({ name }: { name: string }) {
  const router = useRouter();
  const [course, setCourse] = useState("");
  const [subjects, setSubjects] = useState("");
  const [exams, setExams] = useState<ExamRow[]>([{ name: "", date: "" }]);
  const [dailyMinutes, setDailyMinutes] = useState("60");
  const [goals, setGoals] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  function toggleGoal(value: string) {
    setGoals((prev) =>
      prev.includes(value)
        ? prev.filter((g) => g !== value)
        : [...prev, value],
    );
  }

  function updateExam(index: number, field: keyof ExamRow, value: string) {
    setExams((prev) =>
      prev.map((row, i) => (i === index ? { ...row, [field]: value } : row)),
    );
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);

    const result = await completeOnboarding({
      course,
      subjects,
      exams: exams.filter((ex) => ex.date),
      dailyMinutes,
      goals,
    });

    if ("error" in result) {
      setError(result.error);
      setLoading(false);
      return;
    }

    router.push("/app/dashboard");
    router.refresh();
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-xl">Set up your study flow, {name.split(" ")[0]}</CardTitle>
        <CardDescription>
          Five quick questions — takes about 30 seconds.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="grid gap-6">
          {error && (
            <p
              role="alert"
              className="bg-destructive/10 text-destructive rounded-md px-3 py-2 text-sm"
            >
              {error}
            </p>
          )}

          <div className="grid gap-2">
            <Label htmlFor="course">What are you studying?</Label>
            <Input
              id="course"
              placeholder="e.g. Medicine, Biology, Law, Computer Science"
              value={course}
              onChange={(e) => setCourse(e.target.value)}
              required
            />
          </div>

          <div className="grid gap-2">
            <Label htmlFor="subjects">Your subjects (comma-separated)</Label>
            <Input
              id="subjects"
              placeholder="e.g. Anatomy, Physiology, Biochemistry"
              value={subjects}
              onChange={(e) => setSubjects(e.target.value)}
              required
            />
          </div>

          <div className="grid gap-2">
            <Label>When are your exams?</Label>
            <div className="grid gap-2">
              {exams.map((exam, index) => (
                <div key={index} className="flex items-end gap-2">
                  <div className="grid flex-1 gap-1.5">
                    <Input
                      placeholder="Exam name (optional)"
                      value={exam.name}
                      onChange={(e) =>
                        updateExam(index, "name", e.target.value)
                      }
                      aria-label={`Exam ${index + 1} name`}
                    />
                  </div>
                  <div className="grid w-44 gap-1.5">
                    <Input
                      type="date"
                      value={exam.date}
                      onChange={(e) =>
                        updateExam(index, "date", e.target.value)
                      }
                      required
                      aria-label={`Exam ${index + 1} date`}
                    />
                  </div>
                  {exams.length > 1 && (
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      aria-label={`Remove exam ${index + 1}`}
                      onClick={() =>
                        setExams((prev) =>
                          prev.filter((_, i) => i !== index),
                        )
                      }
                    >
                      <Trash2 className="size-4" />
                    </Button>
                  )}
                </div>
              ))}
            </div>
            {exams.length < 3 && (
              <Button
                type="button"
                variant="outline"
                size="sm"
                className="justify-self-start"
                onClick={() =>
                  setExams((prev) => [...prev, { name: "", date: "" }])
                }
              >
                <CalendarPlus className="size-4" />
                Add another exam
              </Button>
            )}
          </div>

          <div className="grid gap-2">
            <Label htmlFor="minutes">How much time can you study each day?</Label>
            <div className="flex items-center gap-2">
              <Input
                id="minutes"
                type="number"
                min={5}
                max={480}
                value={dailyMinutes}
                onChange={(e) => setDailyMinutes(e.target.value)}
                className="w-28"
                required
              />
              <span className="text-muted-foreground text-sm">minutes</span>
            </div>
          </div>

          <div className="grid gap-2">
            <Label>What do you want help with?</Label>
            <div className="flex flex-wrap gap-2">
              {GOAL_OPTIONS.map((goal) => (
                <button
                  key={goal.value}
                  type="button"
                  onClick={() => toggleGoal(goal.value)}
                  aria-pressed={goals.includes(goal.value)}
                  className={cn(
                    "rounded-full border px-3 py-1.5 text-sm transition-colors",
                    goals.includes(goal.value)
                      ? "bg-primary text-primary-foreground border-primary"
                      : "hover:bg-accent",
                  )}
                >
                  {goal.label}
                </button>
              ))}
            </div>
          </div>

          <Button type="submit" disabled={loading} className="w-full" size="lg">
            {loading && <Loader2 className="animate-spin" />}
            Build my dashboard
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
