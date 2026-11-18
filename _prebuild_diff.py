#!/usr/bin/env python3
"""Pre-build safety diff for Limul Engine.

`lime build windows` copies the project asset trees OVER the runtime tree in
export/release/windows/bin. Anything the player (or the in-game chart/character
editor) changed inside bin since the last build is silently reverted by that copy.

Pairings (from Project.xml):
    assets/preload/**   ->  bin/assets/**          (*.mp3 excluded on desktop)
    example_mods/**     ->  bin/mods/**
    assets/<library>/**  ->  bin/assets/<library>/**   (shared, songs, week2..week7)

Usage:
    python _prebuild_diff.py              # report only
    python _prebuild_diff.py --mirror     # copy bin -> project where bin is newer,
                                          # with a .pre-build-mirror-<hhmmss> backup
"""

import hashlib
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
BIN = os.path.join(ROOT, "export", "release", "windows", "bin")

PAIRS = [
    (os.path.join(ROOT, "assets", "preload"), os.path.join(BIN, "assets")),
    (os.path.join(ROOT, "example_mods"), os.path.join(BIN, "mods")),
]
for lib in ("shared", "songs", "videos") + tuple("week%d" % n for n in range(2, 8)):
    src = os.path.join(ROOT, "assets", lib)
    dst = os.path.join(BIN, "assets", lib)
    if os.path.isdir(src) and os.path.isdir(dst):
        PAIRS.append((src, dst))

SKIP_EXT = {".mp3"}  # Project.xml excludes *.mp3 on desktop, bin copy is stale by design
BACKUP_TAG = ".pre-build-mirror-%s" % __import__("time").strftime("%H%M%S")


def walk(root):
    out = {}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for fn in filenames:
            if os.path.splitext(fn)[1].lower() in SKIP_EXT:
                continue
            if fn.endswith(BACKUP_TAG) or ".pre-" in fn:
                continue
            full = os.path.join(dirpath, fn)
            out[os.path.relpath(full, root).replace("\\", "/")] = full
    return out


def md5(path):
    h = hashlib.md5()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    mirror = "--mirror" in sys.argv
    only_bin_total = []
    newer_bin_total = []

    for proj, run in PAIRS:
        if not os.path.isdir(run):
            print("SKIP (runtime dir missing): %s" % run)
            continue
        rel_proj, rel_run = os.path.relpath(proj, ROOT), os.path.relpath(run, ROOT)
        a, b = walk(proj), walk(run)
        keys = sorted(set(a) | set(b))
        only_b = [k for k in keys if k in b and k not in a]
        only_a = [k for k in keys if k in a and k not in b]
        diff = []
        for k in keys:
            if k in a and k in b:
                try:
                    if md5(a[k]) != md5(b[k]):
                        diff.append(k)
                except OSError:
                    diff.append(k)

        bin_newer, proj_newer, unknown = [], [], []
        for k in diff:
            ta, tb = os.path.getmtime(a[k]), os.path.getmtime(b[k])
            (bin_newer if tb > ta else proj_newer if ta > tb else unknown).append(k)

        print("== %s  <->  %s" % (rel_proj, rel_run))
        print("   tylko w runtime (nowe w binie, build ich NIE skasuje): %d" % len(only_b))
        for k in only_b[:20]:
            print("      + %s" % k)
        if len(only_b) > 20:
            print("      ... %d więcej" % (len(only_b) - 20))
        print("   tylko w projekcie (build je doda): %d" % len(only_a))
        for k in only_a[:10]:
            print("      + %s" % k)
        print("   RÓŻNI SIĘ: %d  (bin nowszy = UTRATA PO BUILDIE: %d, projekt nowszy: %d, równe mtime: %d)"
              % (len(diff), len(bin_newer), len(proj_newer), len(unknown)))
        for k in bin_newer:
            print("      !! bin nowszy: %s   (bin %s vs projekt %s)"
                  % (k, __import__("time").strftime("%H:%M", __import__("time").localtime(os.path.getmtime(b[k]))),
                     __import__("time").strftime("%H:%M", __import__("time").localtime(os.path.getmtime(a[k])))))
        for k in unknown:
            print("      ?? różne bajty, ten sam mtime: %s" % k)
        only_bin_total += [os.path.join(proj, k) for k in only_b]
        newer_bin_total += [(a[k], b[k]) for k in bin_newer] + [(a[k], b[k]) for k in unknown]
        print()

    if not mirror:
        print("--mirror kopiuj bin -> projekt przy %d plikach" % len(newer_bin_total))
        return

    for dst, src in newer_bin_total:
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.exists(dst):
            shutil.copy2(dst, dst + BACKUP_TAG)
        shutil.copy2(src, dst)
    print("ZMIROROWANE bin -> projekt: %d plików (backup %s)" % (len(newer_bin_total), BACKUP_TAG))


if __name__ == "__main__":
    main()
