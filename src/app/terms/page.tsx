import type { Metadata } from "next";
import Link from "next/link";
import { BookOpen } from "lucide-react";

import { GlassCard } from "@/components/ui/glass";

export const metadata: Metadata = {
  title: "Terms of Service — StudyFlow AI",
  description:
    "The terms that govern your use of StudyFlow AI — accounts, subscriptions, AI content, and fair use.",
};

const CONTACT_EMAIL = "mithilviswask@gmail.com";

const SECTIONS = [
  {
    h: "1. Acceptance of these terms",
    body: [
      "By creating an account or using StudyFlow AI (“the Service”), you agree to these Terms of Service. If you do not agree, please do not use the Service.",
      "You must be at least 13 years old to use the Service. If you are under 18, you confirm you have the consent of a parent or guardian.",
    ],
  },
  {
    h: "2. The Service",
    body: [
      "StudyFlow AI is an AI-powered study workspace: you upload or paste your own notes and material, and the Service generates summaries, flashcards, quizzes, study plans, and answers grounded in that material.",
      "The Service is provided “as is” and may change over time — features may be added, changed, or removed, and we will make a reasonable effort to communicate material changes.",
    ],
  },
  {
    h: "3. Your account",
    body: [
      "You are responsible for keeping your account credentials secure and for everything done through your account. If you believe your account has been compromised, contact us immediately.",
      "You must provide accurate information when creating an account. We may suspend or terminate accounts that violate these terms or the law.",
    ],
  },
  {
    h: "4. Your content",
    body: [
      "You retain ownership of the notes, documents, and material you upload (“your content”). You grant us a limited license to store, process, and use your content solely to provide the Service to you.",
      "You confirm that you own, or have the right to use, everything you upload — for example, your own lecture notes or documents you are permitted to use.",
      "The AI-generated outputs (summaries, flashcards, quizzes, answers) are generated from your content and may be incorrect. See Section 8.",
    ],
  },
  {
    h: "5. Free and Premium plans",
    body: [
      "The Service offers a Free plan and a paid Premium plan. Features and usage limits for each plan are described on the pricing page and in the app; they may change as the product evolves, and we will describe any change to paid plans reasonably clearly before it takes effect.",
      "There is a limited “Founding Member” offer: Premium at a founding-member price for the first 35 successful paying members, as described on the pricing page. This offer ends once 35 memberships have been claimed and is not available to new users after that point.",
    ],
  },
  {
    h: "6. Subscriptions, billing, and cancellation",
    body: [
      "Premium is a recurring subscription billed in advance (monthly or yearly, depending on the option you choose). You will always see the amount and billing frequency before you confirm payment.",
      "You can cancel at any time from your account/subscription page. You keep Premium access until the end of the period you already paid for, then your account returns to the Free plan. There are no cancellation hoops or penalties.",
      "Payments are processed by our payment provider. We never see or store your card number. If a payment fails, we will attempt to notify you; continued non-payment may result in your account returning to the Free plan.",
      "Refunds: [REFUND POLICY — decide and document here. Suggested default for an honest product: “If you are unhappy, contact us within the first N days and we will consider a refund — we would rather make it right than keep your money.”]",
      "If the founding-member price changes in the future, we will clearly disclose the change before it affects you, and you can cancel at any time.",
    ],
  },
  {
    h: "7. Acceptable use",
    body: [
      "Do not use the Service to: upload unlawful or infringing material; attempt to disrupt, overload, or gain unauthorized access to the Service or its systems; create multiple accounts to abuse free limits or the founding-member offer; or use the Service in any way that violates applicable law.",
      "You may not copy, resell, or redistribute the Service itself (as opposed to content generated for your own study use).",
    ],
  },
  {
    h: "8. AI content and no guarantee of outcomes",
    body: [
      "AI-generated content — summaries, flashcards, quizzes, and answers — is generated automatically and can be wrong, incomplete, or misleading. You are responsible for verifying important information (for example, before an exam) against your own material and trusted sources.",
      "The Service never promises specific grades, exam results, or academic outcomes. It is a study tool, not a guarantee of success.",
      "Generated answers drawn from your material are intended to be grounded in your sources, but they are still AI output — treat them accordingly.",
    ],
  },
  {
    h: "9. Intellectual property",
    body: [
      "The Service itself — the StudyFlow software, design, and brand — is owned by StudyFlow AI and its creator. Except for your content and AI outputs generated for your use, nothing in these terms grants you rights to the Service's underlying software or branding.",
    ],
  },
  {
    h: "10. Disclaimers and limitation of liability",
    body: [
      "The Service is provided “as is” and “as available” without warranties of any kind, express or implied, to the maximum extent permitted by law.",
      "To the maximum extent permitted by law, StudyFlow AI and its creator are not liable for indirect, incidental, special, or consequential damages, or for any loss of data or study material, arising from your use of the Service.",
      "Nothing in these terms limits liability that cannot be limited by law.",
    ],
  },
  {
    h: "11. Termination",
    body: [
      "You may stop using the Service at any time and delete your account, which removes your study material from the Service (subject to backups and legal retention).",
      "We may suspend or terminate access for violations of these terms or the law. If we terminate your paid subscription for cause, we will refund the unused portion of any period already paid.",
    ],
  },
  {
    h: "12. Changes to these terms",
    body: [
      "We may update these terms as the Service evolves. Material changes will be posted on this page with an updated effective date, and we will make a reasonable effort to notify you. Continued use of the Service after changes take effect means you accept the updated terms.",
    ],
  },
  {
    h: "13. Governing law and contact",
    body: [
      "These terms are governed by the laws of [JURISDICTION — decide and document here; suggested: your country/state of residence]. [Dispute resolution option — e.g., “We will first try to resolve any dispute informally — email us and we will respond within a reasonable time.”]",
      `Questions about these terms: ${CONTACT_EMAIL}.`,
    ],
  },
];

export default function TermsPage() {
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
              Terms of Service
            </h1>
            <p className="text-muted-foreground mt-2 text-sm">
              Effective date:{" "}
              <span className="text-foreground font-medium">[EFFECTIVE DATE — set before publishing]</span>
              {" "}· Last updated: [DATE]
            </p>
            <div className="bg-amber-500/10 border-amber-500/30 text-amber-300 mt-4 rounded-xl border px-4 py-3 text-sm">
              <strong>Review needed before publishing.</strong> This is a draft. The
              bracketed decisions — refund policy, governing law, dispute resolution —
              are business/legal choices that must be made and reviewed before the app
              goes public.
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
          <Link href="/privacy" className="underline underline-offset-4">
            Privacy Policy
          </Link>
        </p>
      </main>
    </div>
  );
}
