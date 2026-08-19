#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

DARK_FLAG="${1:-}"
CAPTURE_PORT="${CAPTURE_PORT:-8765}"
mkdir -p .freebuff screenshots/play-store/tablet

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

echo "→ Capturing tablet screenshots..."
cd tool
if [ ! -d node_modules ]; then
  npm install --no-fund --no-audit
fi
node capture-tablet.js "http://127.0.0.1:${CAPTURE_PORT}" ${DARK_FLAG}

echo ""
echo "✓ Saved to mobile/screenshots/play-store/tablet/ (1920×1280 PNG)"
ls -1 ../screenshots/play-store/tablet/
