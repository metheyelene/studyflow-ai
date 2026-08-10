# Deployment

StudyFlow AI deploys to **Vercel** with **GitHub Actions** as the CI gate.
The rule: **never deploy a known failing build** — CI must be green before
`main` reaches production.

## Pipeline overview

```
push to main / open PR
        │
        ▼
GitHub Actions (CI)              Vercel
  lint            ─┐
  typecheck        │   all green?            GitHub app deploys
  tests            ├──►  main ───────────────►  production (studyflow-ai.vercel.app)
  build            │   PR / branch ──────────►  preview URL per commit
  npm audit        │
  gitleaks         ─┘
```

- **CI** (`.github/workflows/ci.yml`): runs on every push to `main` and every
  PR. Jobs: `checks` (lint → typecheck → tests → build with placeholder env)
  and `security` (npm audit at the high gate + gitleaks secret scan).
- **Deploys**: handled by the Vercel GitHub integration, not by CI. CI
  protects `main`; the GitHub app ships it.

## One-time manual setup (already partly done)

| Step | Status | What to do |
|---|---|---|
| GitHub repo | ✅ done | `metheyelene/studyflow-ai` (private) |
| CI workflow | ✅ done | lint/typecheck/tests/build/audit/gitleaks — green |
| Vercel project | ✅ done | `studyflow-ai` created + linked |
| Vercel env vars | ✅ done | `DATABASE_URL*`, `BETTER_AUTH_SECRET` (production + preview) |
| **GitHub ↔ Vercel connection** | ⛔ **needs you** | See below |

### The one remaining step

Vercel deploys are currently **blocked** (deployment protection) because the
Vercel account has no GitHub login connection. Do this in your browser
(~2 minutes):

1. https://vercel.com → **Settings** (gear, bottom-left) → **Login Connections**
2. **Connect GitHub** → authorize → install the Vercel GitHub app
3. Tell your co-founder "GitHub is connected" — they'll run
   `vercel git connect metheyelene/studyflow-ai` and verify the first deploy.

Once connected, no manual deploys are needed — every push works automatically.

## Deploying manually (fallback, without the integration)

```bash
cd ~/studyflow-ai
npx vercel --prod          # production
npx vercel                 # preview (prints a URL)
```

Note: on this account, CLI-only deploys come back **BLOCKED** while
deployment protection is on without the GitHub connection. The integration
is the intended path.

## Environments

| Environment | Trigger | URL |
|---|---|---|
| Preview | Every PR / branch push | `https://<project>-<hash>-<team>.vercel.app` (SSO-protected until published) |
| Production | Push to `main` | `https://studyflow-ai.vercel.app` → your domain |

## Env vars at deploy time

Deployments snapshot env vars when they build. After changing a var in the
Vercel dashboard, redeploy (`git push` with an empty commit, or the CLI).

## Rollback

Vercel keeps every deployment. To roll back production: Vercel dashboard →
project → Deployments → find the last good one → **Promote to Production**.

## CI troubleshooting

| CI failure | Meaning | Fix |
|---|---|---|
| `npm ci` lockfile errors | Lockfile out of sync | `npm install`, commit `package-lock.json` |
| `npm audit` fails | High/critical advisory | Upgrade the affected package (see `docs/development.md`) |
| gitleaks flags a file | A secret was committed | Rotate it, remove it from history, never reuse |
| Build fails with `Invalid URL` | Bad env var value in CI/build | Check the env block in `.github/workflows/ci.yml` |
