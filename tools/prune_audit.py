#!/usr/bin/env python3
"""Prune audit for the Limul Engine runtime mod tree.

Resolution order in this fork is  mods/<currentMod>/... -> mods/... -> assets/...  for
every asset type (source/Paths.hx returnSound/returnImage/returnRawFile and the Lua/Song
folder loops in source/PlayState.hx). So every file that exists in BOTH bin/mods and one of
the project asset trees is a shadow: the mods copy wins, and a later edit to the asset-tree
copy is silently ignored until the shadow goes away.

Classifies, never touches:

    shadow_same      byte-identical to an asset-tree copy -> the code needs one, not two
    shadow_differs   mods copy has different bytes        -> compare mtimes before deleting
    mods_only        nothing in the asset trees           -> required, keep
    junk             .bak / .pre-* / _backup* / .ps104 / logs -> never read by the engine

usage: python tools/prune_audit.py            # summary
       python tools/prune_audit.py --list     # every file with its twin
"""
import hashlib
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIN = os.path.join(ROOT, "export", "release", "windows", "bin")
SEP = "/"

# Everything `lime build windows` copies into the runtime tree (Project.xml asset
# libraries). A mods path "songs/darnell/Inst-erect.ogg" is the same resource as the
# "songs" library key "darnell/Inst-erect.ogg", so each library needs its own prefix.
SOURCE_DIRS = [("assets/preload", ""), ("assets/songs", "songs/"), ("assets/shared", "shared/")]
SOURCE_DIRS += [("assets/week%d" % n, "week%d/" % n) for n in range(1, 8)]


def md5(path):
    h = hashlib.md5()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def index(root):
    out = {}
    for dirpath, dirnames, filenames in os.walk(root):
        for fn in filenames:
            full = os.path.join(dirpath, fn)
            out[os.path.relpath(full, root).replace(os.sep, SEP)] = full
    return out


def is_junk(rel):
    if rel.startswith("_backup") or rel.startswith("_erect-unused"):
        return True
    base = os.path.basename(rel)
    if ".bak" in base or ".pre-" in base or base.endswith(".ps104"):
        return True
    return base.endswith(".log")


def main():
    list_all = "--list" in sys.argv
    mods_dir = os.path.join(BIN, "mods")
    mods = index(mods_dir)
    sources = {}
    for d, prefix in SOURCE_DIRS:
        root = os.path.join(ROOT, d)
        if not os.path.isdir(root):
            continue
        for rel, full in index(root).items():
            sources.setdefault(prefix + rel, []).append((d + SEP + rel, full))

    groups = {"shadow_same": [], "shadow_differs": [], "mods_only": [], "junk": []}
    for rel, full in sorted(mods.items()):
        if is_junk(rel):
            groups["junk"].append((rel, "", ""))
            continue
        twins = sources.get(rel)
        if not twins:
            groups["mods_only"].append((rel, "", ""))
            continue
        same = None
        for label, src in twins:
            if md5(src) == md5(full):
                same = label
                break
        if same is not None:
            groups["shadow_same"].append((rel, same, ""))
        else:
            best = twins[0]
            newer = "mods" if os.stat(full).st_mtime > os.stat(best[1]).st_mtime else best[0]
            groups["shadow_differs"].append((rel, best[0], newer))

    for name in ("shadow_same", "shadow_differs", "mods_only", "junk"):
        items = groups[name]
        print("\n### %s: %d" % (name, len(items)))
        if not list_all and name == "shadow_same":
            for rel, twin, _ in items[:10]:
                print("    %-52s == %s" % (rel, twin))
            if len(items) > 10:
                print("    ... (+%d more)" % (len(items) - 10))
            continue
        for rel, twin, note in items:
            if name == "shadow_differs":
                print("    %-52s != %-30s newer: %s" % (rel, twin, note))
            elif name == "junk" or name == "mods_only":
                top = rel.split(SEP)[0]
                print("    " + rel if top not in ("songs", "sounds", "_backup-musthit-all",
                      "_backup-musthit", "_backup-ps104-events", "_erect-unused") or list_all
                      else "    [" + top + "] " + rel)
            else:
                print("    %-52s == %s" % (rel, twin))
    print("\ntotal runtime mods files: %d" % len(mods))
    return 0


if __name__ == "__main__":
    sys.exit(main())
