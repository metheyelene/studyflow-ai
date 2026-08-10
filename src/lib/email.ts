// ─────────────────────────────────────────────────────────────────────
// Pluggable email sender.
//
// Production: uses the Resend API when RESEND_API_KEY is set
// (https://resend.com — create an API key + verify your domain).
// Development: logs the email to the server console so flows like
// password reset are testable without any provider configured.
//
// To use a different provider later, replace the Resend branch — the
// callers (auth.ts hooks) only depend on sendEmail().
// ─────────────────────────────────────────────────────────────────────

interface EmailMessage {
  to: string;
  subject: string;
  html: string;
  text?: string;
}

export async function sendEmail({ to, subject, html, text }: EmailMessage) {
  const apiKey = process.env.RESEND_API_KEY;

  if (!apiKey) {
    // Dev fallback — never send real mail without a provider configured.
    console.log(
      `\n[email:dev] To: ${to}\n[email:dev] Subject: ${subject}\n[email:dev] ${html.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim()}\n`,
    );
    return;
  }

  const from = process.env.EMAIL_FROM ?? "StudyFlow <no-reply@studyflow.ai>";

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [to],
      subject,
      html,
      ...(text ? { text } : {}),
    }),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`Email send failed (${res.status}): ${body.slice(0, 200)}`);
  }
}

/** A simple readable HTML email shell for transactional mail. */
export function emailLayout(title: string, bodyHtml: string): string {
  return `
    <div style="font-family:system-ui,sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#18181b;">
      <div style="font-size:20px;font-weight:700;margin-bottom:16px;">📚 StudyFlow AI</div>
      <div style="background:#f4f4f5;border-radius:12px;padding:20px;">
        <h1 style="font-size:16px;margin:0 0 8px;">${title}</h1>
        ${bodyHtml}
      </div>
      <p style="color:#71717a;font-size:12px;margin-top:16px;">
        You received this email because you have an account with StudyFlow AI.
        If this wasn't you, you can safely ignore it.
      </p>
    </div>`;
}
