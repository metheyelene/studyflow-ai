#!/usr/bin/env python3
"""Run the StudyFlow Next.js dev backend detached on :3100.

Daemonizes via double-fork so it survives the parent shell's process
group. Run: python3 .freebuff/run_backend.py
"""
import os
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "backend-3100.log")


def daemonize():
    if os.fork() > 0:
        os._exit(0)
    os.setsid()
    if os.fork() > 0:
        os._exit(0)
    sys.stdout.flush()
    sys.stderr.flush()
    with open(LOG, "ab", 0) as f:
        os.dup2(f.fileno(), sys.stdout.fileno())
        os.dup2(f.fileno(), sys.stderr.fileno())


def main():
    os.chdir(ROOT)
    subprocess.Popen(
        ["npm", "run", "dev", "--", "-p", "3100"],
        stdin=subprocess.DEVNULL,
    )


if __name__ == "__main__":
    daemonize()
    main()
