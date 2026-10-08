#!/usr/bin/env python3
"""PII scan for this repository (complements gitleaks, which looks for secrets).

Two layers:
  1. Generic detectors that run everywhere (CI included): e-mail addresses, IPv4 and MAC addresses,
     macOS home paths with a real user name, `<name>.local` host names, phone numbers.
  2. A private deny-list of personal terms (names, employers, project names, account handles, network
     names) in `.pii-denylist` at the repo root — one term per line, case-insensitive, `#` comments.
     The file is git-ignored on purpose: committing it would publish the very terms it protects.

Allowed exceptions live in `.pii-allowlist` (committed): one regular expression per line; any match
of a detector inside an allowed span is ignored.

Usage:
  python3 tools/pii_scan.py            # scan tracked + untracked (not ignored) files
  python3 tools/pii_scan.py --staged   # scan the staged versions of staged files (pre-commit hook)
  python3 tools/pii_scan.py FILE ...   # scan specific files
Exit status 1 when anything is found.
"""
import ipaddress
import os
import re
import subprocess
import sys

ROOT = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip() or os.getcwd()
SKIP_EXT = {".png", ".jpg", ".jpeg", ".gif", ".ico", ".pdf", ".zip", ".gz", ".skill"}
SKIP_FILES = {"LICENSE"}

EMAIL = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
IPV4 = re.compile(r"(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?![\w.])")
MAC = re.compile(r"\b(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b")
HOME = re.compile(r"/Users/([A-Za-z0-9._-]+)")
LOCAL_HOST = re.compile(r"\b([A-Za-z0-9][A-Za-z0-9-]*)\.local\b")
PHONE = re.compile(r"(?<![\w])\+\d[\d -]{8,16}\d\b")

SAFE_EMAIL_DOMAINS = ("example.com", "example.org", "example.net", "users.noreply.github.com")
SAFE_IPS = {"127.0.0.1", "0.0.0.0", "255.255.255.255", "1.1.1.1", "8.8.8.8"}
DOC_NETS = [ipaddress.ip_network(n) for n in ("192.0.2.0/24", "198.51.100.0/24", "203.0.113.0/24")]
SAFE_HOME_USERS = {"Shared", "user", "username", "you", "me", "USER", "$USER", "${USER}", "name"}
SAFE_LOCAL_HOSTS = {"host", "new-mac", "old-mac", "newmac", "oldmac", "mac", "your-mac", "Name", "name", "hostname"}


def load_lines(name):
    p = os.path.join(ROOT, name)
    if not os.path.exists(p):
        return []
    with open(p, encoding="utf-8") as f:
        return [l.strip() for l in f if l.strip() and not l.lstrip().startswith("#")]


# deny-list terms match at the start of a word ("acme" hits "Acme", "acme-corp", "acmeuser" but not "dacme")
DENY = [(t, re.compile(r"(?<![A-Za-z0-9])" + re.escape(t), re.IGNORECASE)) for t in load_lines(".pii-denylist")]
ALLOW = [re.compile(r) for r in load_lines(".pii-allowlist")]


def allowed(line, start, end):
    return any(m.start() <= start and end <= m.end() for rx in ALLOW for m in rx.finditer(line))


def findings_in(text):
    out = []
    for n, line in enumerate(text.splitlines(), 1):
        def add(kind, m):
            if not allowed(line, m.start(), m.end()):
                out.append((n, kind, m.group(0)))
        for m in EMAIL.finditer(line):
            if not m.group(0).lower().endswith(SAFE_EMAIL_DOMAINS):
                add("email", m)
        for m in IPV4.finditer(line):
            try:
                ip = ipaddress.ip_address(m.group(0))
            except ValueError:
                continue  # version numbers like 2026.8.2100.0
            if m.group(0) not in SAFE_IPS and not any(ip in net for net in DOC_NETS):
                add("ip-address", m)
        for m in MAC.finditer(line):
            add("mac-address", m)
        for m in HOME.finditer(line):
            if m.group(1) not in SAFE_HOME_USERS and not m.group(1).startswith(("<", "$")):
                add("home-path", m)
        for m in LOCAL_HOST.finditer(line):
            if m.group(1) not in SAFE_LOCAL_HOSTS:
                add("local-hostname", m)
        for m in PHONE.finditer(line):
            add("phone-number", m)
        for _term, rx in DENY:
            for m in rx.finditer(line):
                add("denylist", m)
    return out


def git_lines(*args):
    r = subprocess.run(["git", "-C", ROOT, *args], capture_output=True, text=True)
    return [l for l in r.stdout.splitlines() if l]


def main(argv):
    staged = "--staged" in argv
    files = [a for a in argv if a != "--staged"]
    if staged:
        files = git_lines("diff", "--cached", "--name-only", "--diff-filter=ACMR")
    elif not files:
        files = git_lines("ls-files", "-co", "--exclude-standard")
    total = 0
    for f in files:
        if os.path.basename(f) in SKIP_FILES or os.path.splitext(f)[1].lower() in SKIP_EXT:
            continue
        if os.path.basename(f) in (".pii-denylist", ".pii-allowlist"):
            continue
        if staged:
            text = subprocess.run(["git", "-C", ROOT, "show", f":{f}"], capture_output=True, text=True).stdout
        else:
            path = f if os.path.isabs(f) else os.path.join(ROOT, f)
            try:
                with open(path, encoding="utf-8") as fh:
                    text = fh.read()
            except (UnicodeDecodeError, FileNotFoundError, IsADirectoryError):
                continue
        for n, kind, match in findings_in(text):
            total += 1
            print(f"{f}:{n}: {kind}: {match}")
    deny_note = f"{len(DENY)} private deny-list terms" if DENY else "no .pii-denylist (generic detectors only)"
    print(f"pii-scan: {total} finding(s) in {len(files)} file(s); {deny_note}")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
