#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────────────
# StudyFlow AI — Play Store screenshot capture
#
# Builds the Flutter web app in CAPTURE_MODE (seeded sample data, no
# backend needed), serves it, and drives real Chrome at a phone viewport
# to save 1080×1920 screenshots into mobile/screenshots/play-store/.
#
# Requires: Flutter SDK, Chrome, Node (playwright-core in mobile/tool).
#
# Usage:
#   ./capture-screenshots.sh           # light theme
#   ./capture-screenshots.sh --dark    # dark theme
#
# The 8 recommended Play Store shots are captured; placeholders still
# show honest empty states until those features ship (see the script
# header of capture-screenshots.js for the shot list).
# ───────────────────────────────────────────────────────────────────────
set -euo pipefail
cd "$(dirname "$0")/.."          # mobile/

DARK_FLAG="${1:-}"
# Use our own port variable — never inherit the ambient PORT env.
CAPTURE_PORT="${CAPTURE_PORT:-8765}"
mkdir -p .freebuff screenshots

export PATH="/opt/homebrew/bin:$PATH"

echo "→ Building Flutter web (CAPTURE_MODE)..."
flutter build web --dart-define=CAPTURE_MODE=true --release

echo "→ Serving build/web on :${CAPTURE_PORT}..."
python3 - <<PY &
import http.server, functools, os, sys

ROOT = os.path.abspath("build/web")

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)
    # Flutter web SPA: any path that isn't a real file serves index.html.
    def do_GET(self):
        candidate = os.path.join(ROOT, self.path.lstrip("/"))
        if self.path == "/" or not os.path.isfile(candidate):
            self.path = "/index.html"
        super().do_GET()

http.server.ThreadingHTTPServer(("127.0.0.1", $CAPTURE_PORT), Handler).serve_forever()
PY
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null || true' EXIT

for i in $(seq 1 30); do
  if curl -sf -o /dev/null "http://127.0.0.1:${CAPTURE_PORT}/"; then break; fi
  sleep 1
done

echo "→ Capturing screenshots..."
cd tool
if [ ! -d node_modules ]; then
  echo "  installing playwright-core…"
  npm install --no-fund --no-audit
fi
node capture-screenshots.js "http://127.0.0.1:${CAPTURE_PORT}" ${DARK_FLAG}

echo ""
echo "✓ Saved to mobile/screenshots/play-store/ (1080×1920 PNG)"
ls -1 ../screenshots/play-store/
