#!/usr/bin/env bash
#
# StudyFlow AI — one-shot production deployment
# =============================================
# Runs the five deploy steps from docs/deployment.md once you have:
#   1. a Neon project (two connection strings: pooled + direct)
#   2. a Vercel login (browser confirm) and the repo linked
#
# What it does (with safety checks at each step):
#   Step 1  Reads + validates the two Neon URLs (pooled must contain "-pooler")
#   Step 2  Writes them into local .env (other vars preserved), generates a
#           BETTER_AUTH_SECRET once, runs `npm run db:migrate`
#   Step 3  Pushes the Vercel env vars (Production + Preview) via the CLI
#   Step 4  Deploys, captures the URL, sets BETTER_AUTH_URL, redeploys,
#           then runs the verification curls (expect 200 / {} / 401)
#   Step 5  Points the mobile build at the API: sets the GitHub Actions
#           `API_BASE_URL` variable and (with your confirmation) pushes a
#           release tag that rebuilds the signed APK/AAB
#
# Idempotent: safe to re-run; it overwrites the keys it owns and leaves
# everything else in .env untouched.
#
# Usage:
#   NEON_POOLED_URL=... NEON_DIRECT_URL=... bash scripts/deploy-production.sh
#   (or just run it — it will prompt for the URLs)

set -euo pipefail

# ── colours / helpers ────────────────────────────────────────────────
info() { printf '\033[1;34m%s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }

ask() { # ask "question" [default]  → echoes the answer into REPLY
  local q="$1" d="${2:-}"
  if [ -n "$d" ]; then printf '%s [%s]: ' "$q" "$d"; else printf '%s: ' "$q"; fi
  IFS= read -r REPLY || true
  if [ -z "$REPLY" ] && [ -n "$d" ]; then REPLY="$d"; fi
}

# env_upsert FILE KEY VALUE — set or replace one KEY="VALUE" line,
# preserving every other line in the file.
env_upsert() {
  local file="$1" key="$2" value="$3"
  [ -f "$file" ] || touch "$file"
  local tmp; tmp="$(mktemp)"
  grep -v "^${key}=" "$file" > "$tmp" || true
  printf '%s="%s"\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$file"
}

# vercel_env_set NAME VALUE — replace the variable in both Production and
# Preview scopes (rm-then-add keeps this idempotent).
vercel_env_set() {
  local name="$1" value="$2"
  npx vercel env rm "$name" all --yes >/dev/null 2>&1 || true
  printf '%s' "$value" | npx vercel env add "$name" production >/dev/null
  printf '%s' "$value" | npx vercel env add "$name" preview >/dev/null
  ok "  vercel env: $name (production + preview)"
}

# ── preflight ────────────────────────────────────────────────────────
info "StudyFlow AI — production deployment"
info "------------------------------------"

command -v node >/dev/null 2>&1 || fail "Node.js is required (install via https://nodejs.org)."
command -v openssl >/dev/null 2>&1 || fail "openssl is required (ships with macOS/Linux; on Windows use Git Bash)."
[ -f package.json ] || fail "Run this from the repo root (~/studyflow-ai)."

info "→ Checking Vercel CLI login (browser confirm may be needed)"
if ! npx vercel whoami >/dev/null 2>&1; then
  warn "You are not logged in to Vercel. Run this once in a browser window:"
  echo "    npx vercel login"
  fail "Login first, then re-run this script."
fi

# ── Step 1 · Neon URLs ───────────────────────────────────────────────
info ""
info "Step 1/5 — Neon connection strings"
NEON_POOLED_URL="${NEON_POOLED_URL:-}"
NEON_DIRECT_URL="${NEON_DIRECT_URL:-}"
if [ -z "$NEON_POOLED_URL" ]; then
  ask "Paste the Neon POOLED URL (the one containing -pooler)" ""
  NEON_POOLED_URL="$REPLY"
fi
if [ -z "$NEON_DIRECT_URL" ]; then
  ask "Paste the Neon DIRECT URL" ""
  NEON_DIRECT_URL="$REPLY"
fi

case "$NEON_POOLED_URL" in
  postgresql://*) ;;
  *) fail "POOLED URL must start with postgresql:// — got: ${NEON_POOLED_URL:0:24}..." ;;
esac
case "$NEON_POOLED_URL" in
  *-pooler*) ok "  pooled URL looks right (contains -pooler)" ;;
  *) warn "  WARNING: pooled URL does not contain '-pooler' — double-check you pasted the right string" ;;
esac
case "$NEON_DIRECT_URL" in
  postgresql://*) ;;
  *) fail "DIRECT URL must start with postgresql://" ;;
esac
case "$NEON_DIRECT_URL" in
  *-pooler*) warn "  WARNING: direct URL contains '-pooler' — the doc says these two are NOT interchangeable" ;;
esac

# ── Step 2 · local .env + first migration ────────────────────────────
info ""
info "Step 2/5 — local .env + first migration"
ENV_FILE=".env"

# Reuse an existing secret so local/preview/production sessions match.
EXISTING_SECRET=""
if [ -f "$ENV_FILE" ]; then
  EXISTING_SECRET="$(grep -E '^BETTER_AUTH_SECRET="?[^"]' "$ENV_FILE" | head -1 | sed 's/^BETTER_AUTH_SECRET="*//; s/"$//')" || true
fi
if [ -z "$EXISTING_SECRET" ]; then
  EXISTING_SECRET="$(openssl rand -base64 32)"
  info "  generated a new BETTER_AUTH_SECRET (keep it — reuse everywhere)"
else
  ok "  reusing the existing BETTER_AUTH_SECRET"
fi

env_upsert "$ENV_FILE" "DATABASE_URL" "$NEON_POOLED_URL"
env_upsert "$ENV_FILE" "DATABASE_URL_DIRECT" "$NEON_DIRECT_URL"
env_upsert "$ENV_FILE" "BETTER_AUTH_SECRET" "$EXISTING_SECRET"
ok "  .env updated: DATABASE_URL, DATABASE_URL_DIRECT, BETTER_AUTH_SECRET"

info "→ npm run db:migrate (applies the schema via the DIRECT URL)"
npm run db:migrate
ok "  migrations applied"

# ── Step 3 · Vercel environment variables ────────────────────────────
info ""
info "Step 3/5 — Vercel environment variables (Production + Preview)"
vercel_env_set "DATABASE_URL" "$NEON_POOLED_URL"
vercel_env_set "DATABASE_URL_DIRECT" "$NEON_DIRECT_URL"
vercel_env_set "BETTER_AUTH_SECRET" "$EXISTING_SECRET"
vercel_env_set "EMAIL_VERIFICATION_REQUIRED" "false"
vercel_env_set "AI_PROVIDER_ORDER" "openai"

ask "OpenAI API key (optional — paste or press Enter to skip):" ""
if [ -n "$REPLY" ]; then
  vercel_env_set "OPENAI_API_KEY" "$REPLY"
fi
ask "Resend API key for password-reset emails (optional — Enter to skip):" ""
if [ -n "$REPLY" ]; then
  vercel_env_set "RESEND_API_KEY" "$REPLY"
fi

# ── Step 4 · deploy + verify ─────────────────────────────────────────
info ""
info "Step 4/5 — deploy, set BETTER_AUTH_URL, redeploy, verify"

info "→ npx vercel --prod (first deploy)"
DEPLOY_OUT="$(npx vercel --prod --yes 2>&1 | tee /dev/tty)"
DEPLOY_URL="$(printf '%s' "$DEPLOY_OUT" | grep -oE 'https://[a-z0-9-]+\.vercel\.app' | head -1 || true)"
if [ -z "$DEPLOY_URL" ]; then
  ask "Could not detect the deploy URL from the output — paste it (https://...vercel.app):" ""
  DEPLOY_URL="$REPLY"
fi
ok "  production URL: $DEPLOY_URL"

info "→ setting BETTER_AUTH_URL and redeploying"
vercel_env_set "BETTER_AUTH_URL" "$DEPLOY_URL"
npx vercel --prod --yes >/dev/null 2>&1
ok "  redeployed with BETTER_AUTH_URL"

info "→ verification (no auth needed)"
V_URL="$DEPLOY_URL"
EXPECT_HTML="$(curl -s -o /dev/null -w '%{http_code}' "$V_URL/")"
EXPECT_SESSION="$(curl -s "$V_URL/api/auth/get-session")"
EXPECT_USAGE="$(curl -s -o /dev/null -w '%{http_code}' "$V_URL/api/usage")"
echo "  GET $V_URL/                → $EXPECT_HTML   (want 200)"
echo "  GET $V_URL/api/auth/get-session → ${EXPECT_SESSION:0:40}  (want {} — 200)"
echo "  GET $V_URL/api/usage       → $EXPECT_USAGE   (want 401)"
[ "$EXPECT_HTML" = "200" ] || warn "  WARNING: home did not return 200 — check Vercel runtime logs"
[ "$EXPECT_USAGE" = "401" ] || warn "  WARNING: /api/usage did not return 401 — a 404 means an old build was deployed"

ok ""
ok "Backend is live at $DEPLOY_URL"

# ── Step 5 · point the mobile app at it ──────────────────────────────
info ""
info "Step 5/5 — point the mobile release at the API"
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  info "→ gh variable set API_BASE_URL (GitHub Actions build-time variable)"
  gh variable set API_BASE_URL --repo metheyelene/studyflow-ai --body "$DEPLOY_URL"
  ok "  API_BASE_URL = $DEPLOY_URL"
else
  warn "  gh CLI not available/authenticated — set the variable manually:"
  echo "    GitHub → Settings → Secrets and variables → Actions → Variables"
  echo "    API_BASE_URL = $DEPLOY_URL"
fi

info "→ Optional: trigger a signed release rebuild (bakes the URL into the APK)"
CURRENT_TAG="$(git tag --sort=-v:refname | head -1 || true)"
SUGGESTED="v1.0.1"
if [ -n "$CURRENT_TAG" ]; then
  SUGGESTED="$(printf '%s' "$CURRENT_TAG" | awk -F. '{print $1"."$2"."($3+1)}')"
fi
ask "Push release tag $SUGGESTED to rebuild the APK/AAB? [y/N]" "N"
if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
  git tag "$SUGGESTED"
  git push origin "$SUGGESTED"
  ok "  tag $SUGGESTED pushed — CI will attach the signed APK/AAB to the release"
else
  info "  Skipped. When ready:  git tag $SUGGESTED && git push origin $SUGGESTED"
fi

info ""
ok "Done. Remaining MANUAL items (only you can do):"
info "  • Vercel dashboard → project → Settings → Environment Variables: mark secrets as Sensitive"
info "  • Custom domain + set BETTER_AUTH_URL to it (docs/deployment.md §5), then redeploy"
info "  • Stripe vars + ADMIN_EMAILS before enabling payments/admin"
info "  • Real-device test of sign-up → notebook → source → AI chat against $DEPLOY_URL"
