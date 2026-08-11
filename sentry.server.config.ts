// Sentry server config — errors from Next.js server runtime (API routes,
// server components, build-time crashes). Inert without a DSN.
import * as Sentry from "@sentry/nextjs";

// Server DSN may differ from the public one; falls back to it when unset.
const dsn = process.env.SENTRY_DSN ?? process.env.NEXT_PUBLIC_SENTRY_DSN;

if (dsn) {
  Sentry.init({
    dsn,
    // Sample a fraction of transactions; all errors are always captured.
    tracesSampleRate: 0.1,
  });
}
