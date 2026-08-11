// Sentry client config — errors from the browser bundle. Inert (no init)
// when NEXT_PUBLIC_SENTRY_DSN is unset, so local dev and CI stay quiet.
import * as Sentry from "@sentry/nextjs";

const dsn = process.env.NEXT_PUBLIC_SENTRY_DSN;

if (dsn) {
  Sentry.init({
    dsn,
    // Sample a fraction of transactions — error capture is always on.
    tracesSampleRate: 0.1,
    // No session replay: costs money and would send page content we don't
    // need. Revisit only if a UX bug genuinely needs it.
    replaysSessionSampleRate: 0,
    replaysOnErrorSampleRate: 0,
  });
}
