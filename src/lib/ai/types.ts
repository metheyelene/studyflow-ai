// Client-safe types shared between the notebook UI and API responses.
// No server-only imports here — safe for "use client" components.

export interface Notebook {
  id: string;
  userId: string;
  subjectId: string | null;
  title: string;
  description: string | null;
  createdAt: string;
  updatedAt: string;
  sourceCount: number;
}

export interface NotebookSource {
  id: string;
  notebookId: string;
  userId: string;
  title: string;
  sourceType: "pasted" | "uploaded" | "url" | "transcript";
  content: string;
  status: "processing" | "ready" | "failed";
  errorMessage: string | null;
  wordCount: number | null;
  pageCount: number | null;
  version: number;
  createdAt: string;
  updatedAt: string;
}

export interface Citation {
  marker: number;
  chunkId: string;
  sourceId: string;
  sourceTitle: string;
  page?: number | null;
  excerpt: string;
}

export interface ChatMessage {
  role: "user" | "assistant";
  content: string;
  citations?: Citation[];
  provider?: string;
  model?: string;
  grounded?: boolean;
  error?: boolean;
}

export type AiMode = "sources" | "study";

export type ActionName =
  | "summarize"
  | "explain"
  | "flashcards"
  | "quiz"
  | "studyGuide"
  | "faq"
  | "extract"
  | "outline"
  | "compare"
  | "mindMap";

export const ACTION_LABELS: Record<string, string> = {
  summarize: "Summarize",
  explain: "Explain",
  flashcards: "Flashcards",
  quiz: "Quiz",
  studyGuide: "Study guide",
  faq: "FAQ",
  extract: "Extract",
  outline: "Outline",
  compare: "Compare",
  mindMap: "Mind map",
};
