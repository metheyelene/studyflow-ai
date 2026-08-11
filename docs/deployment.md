# Deployment — Vercel + Neon

End-to-end guide for taking StudyFlow AI from this repo to a live production
backend the mobile app can talk to. **Steps marked MANUAL require your
account/credentials — do them yourself, never send secrets through chat.**

Everything below was verified against the current code (Next 16, better-auth
1.7, Drizzle + Neon, Flutter client).

> **Quickstart:** once you have the two Neon URLs and a Vercel login, the whole
> pipeline (§2–§7) runs as one script:
>
> ```bash
> cd ~/studyflow-ai
> bash scripts/deploy-production.sh   # or: NEON_POOLED_URL=... NEON_DIRECT_URL=... bash scripts/deploy-production.sh
> ```
>
> It validates the URLs, writes local `.env`, runs `npm run db:migrate`, pushes
> the Vercel env vars (Production + Preview), deploys twice (first for the URL,
> then with `BETTER_AUTH_URL`), runs the verification curls, and points the
> mobile `API_BASE_URL` GitHub variable at the result — then asks before
> pushing the release tag. Read §3 below for what the script sets and what it
> intentionally leaves to you.

---

## 0. The one-time requirements (you, in a browser)

| Step | Time | Notes |
|---|---|---|
| Vercel account | 1 min | https://vercel.com (GitHub login recommended) |
| Neon account | 1 min | https://neon.tech (free tier is fine to start) |
| `vercel` CLI login | 1 min | `npx vercel login` — browser confirmation |
| GitHub → Vercel connection | 2 min | optional but recommended, see §4 |

---

## 1. Create the Neon database (MANUAL)

1. https://neon.tech → **New project** → name `studyflow` → region nearest to
   your users (e.g. Singapore for India).
2. Neon shows **two** connection strings. Copy **both**:
   - **Pooled** (contains `-pooler`) → `DATABASE_URL`
   - **Direct** → `DATABASE_URL_DIRECT`
3. Keep the project open — you'll paste these into Vercel in §3.

> **Why two?** The pooled string is connection-pooled and serverless-safe for
> the app. The direct string is for one-shot migrations (`npm run db:migrate`).
> They are NOT interchangeable — swapping them "works by accident" locally but
> breaks under serverless load.

## 2. Local `.env` + first migration

Put the real values in local `.env` (already structured, see `.env.example`):

```bash
DATABASE_URL="postgresql://...-pooler...neon.tech/neondb?sslmode=require"
DATABASE_URL_DIRECT="postgresql://...neon.tech/neondb?sslmode=require"
BETTER_AUTH_SECRET=$(openssl rand -base64 32)   # generate once, reuse everywhere
BETTER_AUTH_URL="http://localhost:3000"          # dev value
```

Then apply the schema against the live database:

```bash
npm run db:migrate
```

The **same** `BETTER_AUTH_SECRET` must be used in local, Vercel preview, and
Vercel production — if they differ, sessions break on every redeploy.

## 3. Vercel environment variables (MANUAL)

Vercel dashboard → project (`studyflow-ai`) → **Settings → Environment
Variables**. Add to **Production** and **Preview** (mark Sensitive):

| Variable | Value |
|---|---|
| `DATABASE_URL` | Neon **pooled** URL (unquoted) |
| `DATABASE_URL_DIRECT` | Neon **direct** URL (unquoted) |
| `BETTER_AUTH_SECRET` | the exact value from §2 |
| `BETTER_AUTH_URL` | `https://<your-deployed-domain>` (see §4/§5) |
| `TRUSTED_ORIGINS_EXTRA` | only if the Flutter **web** build is served from a different origin (e.g. `https://studyflow-mobile.pages.dev`) — comma-separated. Not needed for native apps. |
| `AI_PROVIDER_ORDER` | `openai` (or `openai,anthropic`) |
| `OPENAI_API_KEY` | your key (only if OpenAI is in the order) |
| `EMAIL_VERIFICATION_REQUIRED` | `false` for now (true once email works) |
| `RESEND_API_KEY` | optional until password-reset emails are live |

Stripe (`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`,
`STRIPE_FOUNDING_PRICE_ID`, `APP_URL`) and `ADMIN_EMAILS` are needed once
payments/admin go live — add them before enabling those features.

> Deployments snapshot env vars at build time. After changing any var,
> redeploy (or Vercel will do it on the next push).

## 4. Connect GitHub → Vercel (recommended) or deploy with the CLI

### Option A — GitHub integration (automatic deploys)

1. Vercel dashboard → **Settings → Login Connections → Connect GitHub** →
   authorize the Vercel GitHub app.
2. Project → **Settings → Git** → connect `metheyelene/studyflow-ai`.
3. From then on: push to `main` → production deploy; every PR/branch → preview
   URL. No manual steps.

### Option B — CLI (works without the integration)

```bash
cd ~/studyflow-ai
npx vercel login          # browser confirm, once
npx vercel --prod         # production build + deploy
```

This repo is already linked (`.vercel/project.json` exists, gitignored), so
`npx vercel --prod` deploys straight to the `studyflow-ai` project. The CLI
prints the production URL at the end.

## 5. Custom domain (optional but recommended)

1. Buy a domain at any registrar (e.g. Namecheap, Cloudflare).
2. Vercel: project → **Settings → Domains** → add it → follow Vercel's DNS
   instructions (CNAME/ALIAS to `cname.vercel-dns.com`).
3. Vercel provisions HTTPS automatically. Once live, set `BETTER_AUTH_URL` to
   `https://your-domain.com` (in Vercel env + local `.env`) and redeploy.

## 6. Verify the deployment

From any machine (no auth needed):

```bash
curl -I https://<your-domain>/          # expect 200, StudyFlow HTML
curl -s https://<your-domain>/api/auth/get-session
#   expect: {}  (HTTP 200 = auth handler alive; no session = correct)
curl -s -o /dev/null -w "%{http_code}\n" https://<your-domain>/api/usage
#   expect: 401  (route alive, unauthenticated → 401, NOT 404)
```

Then the full live smoke test with a real account:
sign up → verify email (if enabled) → complete onboarding → create a notebook
→ upload/paste notes → run a summary/quiz. If sign-up 500s, the most likely
cause is a wrong `DATABASE_URL` (pooled vs direct) — check Vercel runtime logs.

## 7. Point the mobile app at the deployed backend

The Flutter app reads the API origin at **build time** from the
`API_BASE_URL` GitHub Actions **variable** (Settings → Secrets and variables →
Actions → Variables). It's currently set to the dev placeholder
(`http://127.0.0.1:3100`).

1. After the backend is live, set:
   ```
   API_BASE_URL = https://<your-domain>
   ```
2. Push a new release tag to rebuild the app bundle:
   ```bash
   git tag v1.0.1 && git push origin v1.0.1
   ```
3. The release workflow signs and attaches the APK/AAB with the new URL baked
   in. Download, install, and test the full sign-up flow on a real phone.

> **Why a build-time variable?** The app never talks to the backend through a
> runtime-configurable URL — that would let anyone repoint a downloaded APK at
> a malicious server and harvest credentials. Baking the URL into the signed
> build keeps the trust anchor with your keystore.

## 8. Environments summary

| Environment | URL | Env vars |
|---|---|---|
| Local dev | `http://localhost:3000` | `.env` (gitignored) |
| CI (GitHub Actions) | — | placeholders in `ci.yml` — build must not need a live DB |
| Preview (Vercel) | `https://studyflow-ai-<hash>.vercel.app` | Preview scope, copied from production |
| Production (Vercel) | your domain | Production scope — real values only |
| Mobile release | any Android/iOS device | baked in at build via `API_BASE_URL` variable |

## 9. Rollback

Vercel keeps every deployment: dashboard → project → **Deployments** → find
the last good one → **Promote to Production**. The mobile app is unaffected by
backend rollbacks (it always calls the same domain); only ship a new APK when
the backend change is intentional.

## 10. CI gate

`.github/workflows/ci.yml` runs lint → typecheck → tests → build + npm audit +
gitleaks on every push to `main` and each PR. **Never deploy a known failing
build**: if CI is red, fix it first — the Vercel integration deploys whatever
is on `main`.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `403 INVALID_ORIGIN` on sign-in | `BETTER_AUTH_URL` ≠ actual deployed origin, or Flutter web served from an origin not in `TRUSTED_ORIGINS_EXTRA` | Set both correctly, redeploy |
| Sign-up 500s in prod | `DATABASE_URL` is the direct (non-pooled) string, or migrations not run | Use pooled URL; run `npm run db:migrate` with the direct URL |
| Sessions break on redeploy | `BETTER_AUTH_SECRET` differs between environments | Use the one secret everywhere |
| `/api/*` returns 404 | Deployed an old build (before Phase 0 routes) | Redeploy from `main` |
| App opens but sign-in fails on phone | APK built with the placeholder `API_BASE_URL` | Set the GitHub Actions variable and push a new release tag |
