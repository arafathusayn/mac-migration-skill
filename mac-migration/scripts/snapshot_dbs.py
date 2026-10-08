#!/usr/bin/env python3
"""Consistent snapshots of live SQLite databases (run on the OLD Mac).

SQLite's online backup API produces a transactionally consistent copy even while an app keeps writing,
which a plain file copy of a WAL-mode database does not. Snapshots are written to
<out>/<path relative to $HOME> so they can be rsynced into the same place on the new Mac and installed
with install-db-snapshots.sh. Each snapshot is integrity-checked.

Usage:
  snapshot_dbs.py [--out DIR] PATH_OR_GLOB [PATH_OR_GLOB ...]
Examples:
  snapshot_dbs.py ~/.codex/*.sqlite '~/.config/someapp/**/*.db'
  snapshot_dbs.py --out ~/mac-migration/db-snapshots ~/.local/share/someapp/state.db
Globs are expanded here (quote them); '**' is recursive. Files under folders named 'packages' are skipped.
Exit status is 1 if any snapshot failed or did not pass PRAGMA integrity_check.
"""
import argparse
import glob
import os
import sqlite3
import sys

HOME = os.path.expanduser("~")


def expand(patterns):
    seen = []
    for pat in patterns:
        pat = os.path.expanduser(pat)
        matches = glob.glob(pat, recursive=True) if any(c in pat for c in "*?[") else [pat]
        for p in sorted(matches):
            if os.path.isfile(p) and "/packages/" not in p and p not in seen:
                seen.append(p)
    return seen


def snapshot(src, out_root):
    rel = os.path.relpath(src, HOME)
    dst = os.path.join(out_root, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    tmp = dst + ".partial"
    if os.path.exists(tmp):
        os.remove(tmp)
    s = sqlite3.connect(f"file:{src}?mode=ro", uri=True, timeout=30)
    d = sqlite3.connect(tmp)
    with d:
        s.backup(d)
    s.close()
    ok = d.execute("PRAGMA integrity_check").fetchone()[0]
    d.close()
    for suffix in ("-wal", "-shm"):
        if os.path.exists(tmp + suffix):
            raise RuntimeError(f"snapshot left a {suffix} file behind")
    os.replace(tmp, dst)
    return rel, os.path.getsize(dst), ok


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=os.path.join(HOME, "mac-migration", "db-snapshots"))
    ap.add_argument("paths", nargs="+")
    a = ap.parse_args()
    srcs = expand(a.paths)
    if not srcs:
        print("no databases matched")
        return 1
    bad = 0
    for src in srcs:
        try:
            rel, size, ok = snapshot(src, a.out)
            print(f"{size // 1024:>9} KB  {ok:<4} {rel}")
            bad += ok != "ok"
        except Exception as e:  # keep going, report at the end
            bad += 1
            print(f"{'ERROR':>9}     {os.path.relpath(src, HOME)}: {e}")
    print(f"snapshots: {len(srcs)}, problems: {bad}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
