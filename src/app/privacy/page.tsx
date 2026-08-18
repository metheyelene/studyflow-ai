import type { Metadata } from "next";
import Link from "next/link";
import { BookOpen } from "lucide-react";

import { GlassCard } from "@/components/ui/glass";

export const metadata: Metadata = {
  title: "Privacy Policy — StudyFlow AI",
  description:
    "How StudyFlow AI collects, uses, and protects your data. Honest, plain-English privacy for students.",
};

const CONTACT_EMAIL = "mithilviswask@gmail.com";

const SECTIONS = [
  {
    h: "1. Who we are",
    body: [
      "StudyFlow AI (“StudyFlow”, “we”, “our”, “us”) is an AI-powered study workspace built to help students turn their learning material into a more organized and interactive study experience.",
      "This policy explains what information we collect when you use StudyFlow (the website, web app, and mobile apps), why we collect it, and how you can control it.",
    ],
  },
  {
    h: "2. Information we collect",
    body: [
      "Account information. When you sign up we collect your name and email address. A password is set by you and stored in encrypted form — we never store it in plain text.",
      "Your study material. The core of the product: the notes, documents, and text you upload or paste, plus the summaries, flashcards, quizzes, study plans, and chat conversations we generate from them.",
      "Onboarding and preference data. Your education level, subjects, upcoming exams, study goals, and study preferences, used to personalize the experience.",
      "Usage information. Basic analytics events (such as signup, first notebook created, quiz completed) so we can understand what students actually find useful. These events are tied to your account and are not sold.",
      "Subscription and payment status. Whether you are on the Free or Premium plan and, for paying users, the status of your subscription. We never see or store your card details — payments are processed by our payment provider.",
      "Technical data. Standard server logs (IP address, browser/device type, timestamps) needed to run and secure the service.",
    ],
  },
  {
    h: "3. How we use your information",
    body: [
      "To provide the service — most importantly, to generate summaries, flashcards, quizzes, and answers from your own material.",
      "To send essential emails — password reset links and, when enabled, email verification. We do not send marketing spam.",
      "To improve the product through aggregated, non-identifying analytics.",
      "To keep the service safe — preventing abuse, enforcing our Terms, and complying with legal obligations.",
    ],
  },
  {
    h: "4. AI processing of your material",
    body: [
      "When you upload or paste notes and ask StudyFlow to summarize, quiz, or answer, the relevant content is sent to the AI provider(s) we use to generate the response.",
      "This processing happens server-side through our own backend — your documents are never mixed with another user's material, and AI answers are grounded in your sources where the feature is used.",
      "We choose providers that we believe handle data responsibly, but processing by the AI provider is governed by that provider's own terms. If you do not want your material sent to an AI provider, you can use StudyFlow's non-AI features or delete the material.",
    ],
  },
  {
    h: "5. Who we share data with",
    body: [
      "We do not sell your data, and we do not show ads.",
      "We share information only with the service providers required to run StudyFlow: hosting and database infrastructure, the AI provider(s) that generate content, an email provider for password resets, and a payment processor for subscriptions. Each provider is bound by contract to use data only to provide that service.",
      "We may disclose information if required by law, or to protect the rights and safety of StudyFlow, our users, or the public.",
    ],
  },
  {
    h: "6. Where data is stored",
    body: [
      "Your data is stored on cloud infrastructure operated by our hosting and database providers. Uploaded documents are stored in object storage with access restricted to your account and the systems that process them.",
      "Data in transit is encrypted with HTTPS. We apply industry-standard safeguards, but no method of transmission or storage is 100% secure — we take reasonable measures and encourage you to keep your password private.",
    ],
  },
  {
    h: "7. How long we keep data",
    body: [
      "We keep your data for as long as your account is active, so you can return to your notebooks.",
      "If you delete your account, we delete your study material and associated data, subject to backups and legal retention requirements.",
    ],
  },
  {
    h: "8. Your rights and choices",
    body: [
      "You can update your profile and preferences at any time from Settings.",
      "You can export or delete your data from Settings, and delete your account entirely — which removes your study material from the service.",
      "You can unsubscribe from non-essential emails and adjust notification preferences. Essential account emails (e.g. password resets) cannot be turned off.",
      "Depending on where you live (for example, the EU/EEA), you may have additional rights under data protection law, including access, correction, erasure, restriction, and portability. Contact us using the details below and we will respond within the timeframes required by law.",
    ],
  },
  {
    h: "9. Children's privacy",
    body: [
      "StudyFlow is designed for students, which we treat as being at least 13 years old. We do not knowingly collect personal information from children under 13.",
      "If you believe a child under 13 has provided us personal information, contact us and we will delete it.",
    ],
  },
  {
    h: "10. Changes to this policy",
    body: [
      "If we make material changes, we will update this page and note the effective date below. If changes significantly affect how we use your data, we will make a reasonable effort to notify you (for example, by email or an in-app notice) before they take effect.",
    ],
  },
  {
    h: "11. Contact",
    body: [
      `Questions, concerns, or requests about this policy or your data: ${CONTACT_EMAIL}.`,
    ],
  },
];

export default function PrivacyPage() {
  return (
    <div className="text-foreground min-h-dvh">
      <header className="sticky top-0 z-20 mx-auto mt-3 w-full max-w-3xl px-4">
        <div className="glass-subtle flex h-14 items-center justify-between rounded-2xl px-4">
          <Link href="/" className="flex items-center gap-2 font-semibold">
            <div className="bg-primary text-primary-foreground flex size-8 items-center justify-center rounded-xl shadow-sm">
              <BookOpen className="size-4" />
            </div>
            StudyFlow
          </Link>
          <nav className="flex items-center gap-3 text-sm">
            <Link href="/login" className="text-muted-foreground hover:text-foreground">
              Log in
            </Link>
            <Link
              href="/signup"
              className="bg-primary text-primary-foreground rounded-full px-4 py-1.5 font-medium shadow-sm"
            >
              Get started
            </Link>
          </nav>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-4 pt-10 pb-24">
        <div className="relative">
          <div
            aria-hidden
            className="bg-primary/10 absolute -top-16 left-1/2 size-72 -translate-x-1/2 rounded-full blur-3xl"
          />
          <div className="relative">
            <h1 className="text-3xl font-semibold tracking-tight">
              Privacy Policy
            </h1>
            <p className="text-muted-foreground mt-2 text-sm">
              Effective date:{" "}
              <span className="text-foreground font-medium">August 18, 2026</span>
              {" "}· Last updated: August 18, 2026
            </p>
            <div className="text-muted-foreground mt-4 rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm">
              <strong className="text-foreground">About this policy.</strong> This policy
              describes what StudyFlow does today. It is reviewed as the product evolves;
              material changes are announced under “Changes to this policy”.
            </div>
          </div>
        </div>

        <div className="mt-8 space-y-4">
          {SECTIONS.map((s) => (
            <GlassCard key={s.h} tone="secondary" className="p-6">
              <h2 className="font-semibold text-lg">{s.h}</h2>
              {s.body.map((p, i) => (
                <p
                  key={i}
                  className="text-muted-foreground mt-2 text-sm leading-relaxed [&_a]:text-primary [&_a]:underline"
                >
                  {p}
                </p>
              ))}
            </GlassCard>
          ))}
        </div>

        <p className="text-muted-foreground mt-10 text-center text-xs">
          StudyFlow AI · Questions? Email {CONTACT_EMAIL} ·{" "}
          <Link href="/terms" className="underline underline-offset-4">
            Terms of Service
          </Link>
        </p>
      </main>
    </div>
  );
}
