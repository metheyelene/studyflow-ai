#!/usr/bin/env python3
"""Serve the Flutter web build (build/web) with SPA fallback on :3200.

Daemonizes via double-fork so it survives the parent shell's process
group. Run: python3 .freebuff/serve_flutter_web.py
"""
import http.server
import os
import socketserver
import sys

BUILD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mobile", "build", "web")
PORT = 3200
LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "flutter-web-3200.log")


class SPA(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=BUILD, **kw)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self):
        p = self.path.split("?")[0].lstrip("/")
        if p == "" or os.path.isfile(os.path.join(BUILD, p)):
            return super().do_GET()
        self.path = "/"
        return super().do_GET()


def daemonize():
    # First fork.
    if os.fork() > 0:
        os._exit(0)
    os.setsid()
    # Second fork.
    if os.fork() > 0:
        os._exit(0)
    sys.stdout.flush()
    sys.stderr.flush()
    with open(LOG, "ab", 0) as f:
        os.dup2(f.fileno(), sys.stdout.fileno())
        os.dup2(f.fileno(), sys.stderr.fileno())


def main():
    os.chdir(BUILD)
    socketserver.TCPServer.allow_reuse_address = True
    httpd = socketserver.TCPServer(("127.0.0.1", PORT), SPA)
    httpd.serve_forever()


if __name__ == "__main__":
    daemonize()
    main()
