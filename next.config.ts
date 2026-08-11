import { withSentryConfig } from "@sentry/nextjs";
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Pin the project root. Without this, Turbopack can resolve the root
  // to a parent directory that contains a stray package-lock.json
  // (the user's home dir has one), serving the wrong files.
  turbopack: {
    root: process.cwd(),
  },
};

export default withSentryConfig(nextConfig, {
  // Source-map upload is a no-op until SENTRY_ORG / SENTRY_PROJECT /
  // SENTRY_AUTH_TOKEN are set (see docs/deployment.md). `silent` keeps
  // the build log clean when they aren't.
  org: process.env.SENTRY_ORG,
  project: process.env.SENTRY_PROJECT,
  authToken: process.env.SENTRY_AUTH_TOKEN,
  silent: !process.env.SENTRY_AUTH_TOKEN,
  widenClientFileUpload: true,
  telemetry: false,
});
