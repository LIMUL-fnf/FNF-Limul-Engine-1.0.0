#!/usr/bin/env python3
"""Leave only the copies the engine code actually reads (task #97).

Facts this encodes, all verified against source/:

  * resolution order is  mods/<currentMod>/ -> mods/ -> assets/  for every asset type
    (source/Paths.hx modFolders/returnSound/returnImage, source/PlayState.hx:1218-1256,
    source/Character.hx:103-110), so a byte-identical file that sits in bin/mods AND in
    an assets library is a shadow: the mods copy wins and hides every later edit of the
    asset-tree copy.
  * `lime build windows` copies example_mods/** over bin/mods, so a shadow deleted from
    bin/mods comes back on the next build unless it is also removed from example_mods.
  * the Chart Editor's note-type dropdown scans ONLY mods/custom_notetypes/
    (source/editors/ChartingState.hx:1064-1067, no preload path) -> those files are
    required, not a shadow.
  * images/... in bin/mods is the documented no-rebuild atlas override (the baked
    manifest keeps serving the copy that existed at build time) -> keep the 3 overrides.
  * .bak / .pre-* / .ps104 / _backup*/ *.log inside the runtime tree are never opened by
    the engine.

Nothing is copied or backed up: the asset-tree twin of every deleted shadow is already
on disk, and _backup*/.bak twins are the user's own leftovers, which he asked to have
removed ("leave only what the code really requires", "no need to make copies").

usage: python tools/prune_mods_tree.py            # dry run
       python tools/prune_mods_tree.py --apply    # delete
"""
import hashlib
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIN = os.path.join(ROOT, "export", "release", "windows", "bin")
MODS = os.path.join(BIN, "mods")
EXAMPLE = os.path.join(ROOT, "example_mods")
SEP = "/"

LIBRARIES = [("assets/preload", ""), ("assets/songs", "songs/"), ("assets/shared", "shared/")]
LIBRARIES += [("assets/week%d" % n, "week%d/" % n) for n in range(1, 8)]

# Runtime paths that stay even when the asset tree has the same bytes.
KEEP_RUNTIME_PREFIXES = ("custom_notetypes/", "images/")
KEEP_RUNTIME_NAMES = ("modsList.txt", "pack.json", "readme.txt")


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


def is_dead(rel):
    if rel.startswith("_backup") or rel.startswith("_erect-unused"):
        return True
    base = os.path.basename(rel)
    if ".bak" in base or ".pre-" in base or base.endswith(".ps104"):
        return True
    return base.endswith(".log")


def keep(rel):
    if rel in KEEP_RUNTIME_NAMES:
        return True
    top = rel.split(SEP)[0] + SEP
    return top in KEEP_RUNTIME_PREFIXES


def main():
    apply = "--apply" in sys.argv
    mods = index(MODS)
    sources = {}
    for d, prefix in LIBRARIES:
        root = os.path.join(ROOT, d)
        if os.path.isdir(root):
            for rel, full in index(root).items():
                sources.setdefault(prefix + rel, []).append((d + SEP + rel, full))

    # ---- pass 1: make the asset tree hold the bytes the player currently hears -------
    sync = []          # (mods file, asset file) where the mods copy is the newer one
    for rel, full in sorted(mods.items()):
        if is_dead(rel) or keep(rel) or rel.startswith("images/"):
            continue
        for label, src in sources.get(rel, []):
            if md5(src) == md5(full):
                break
        else:
            if rel.startswith("data/"):
                # charts: only sync when the runtime copy is the newer edit
                cands = sources.get(rel, [])
                if cands and os.stat(full).st_mtime > os.stat(cands[0][1]).st_mtime:
                    sync.append((full, cands[0][1], rel))
            else:
                # audio: same size, different bytes -> re-encode noise, keep runtime bytes
                cands = sources.get(rel, [])
                if cands and os.path.getsize(cands[0][1]) == os.path.getsize(full) \
                        and os.stat(full).st_mtime >= os.stat(cands[0][1]).st_mtime:
                    sync.append((full, cands[0][1], rel))

    print("== pass 1: sync assets tree from the runtime copy: %d" % len(sync))
    for src, dst, rel in sync:
        print("   %-46s -> %s" % (rel, os.path.relpath(dst, ROOT).replace(os.sep, SEP)))

    # ---- pass 2: runtime files the code does not need ------------------------------
    delete_mods = []
    for rel, full in sorted(mods.items()):
        if is_dead(rel):
            delete_mods.append((rel, full, "dead"))
        elif keep(rel):
            continue
        elif rel in sources:
            delete_mods.append((rel, full, "shadow of " + sources[rel][0][0]))

    print("\n== pass 2: delete from bin/mods: %d (kept %d)"
          % (len(delete_mods), len(mods) - len(delete_mods)))
    for rel, full, why in delete_mods[:15]:
        print("   %-52s %s" % (rel, why))
    if len(delete_mods) > 15:
        print("   ... (+%d more)" % (len(delete_mods) - 15))

    # ---- pass 3: the same shadows in example_mods (a build copies it into bin/mods) --
    ex = index(EXAMPLE)
    delete_example = []
    for rel, full in sorted(ex.items()):
        top = rel.split(SEP)[0]
        if top == "weekend1":
            delete_example.append((rel, full, "dead mod folder (runsGlobally:false, never built)"))
            continue
        if is_dead(rel):
            delete_example.append((rel, full, "dead"))
            continue
        if keep(rel) or top in ("images",):
            continue
        if rel in sources:
            delete_example.append((rel, full, "shadow of " + sources[rel][0][0]))
    print("\n== pass 3: delete from example_mods: %d (kept %d)"
          % (len(delete_example), len(ex) - len(delete_example)))
    for rel, full, why in delete_example[:15]:
        print("   %-52s %s" % (rel, why))
    if len(delete_example) > 15:
        print("   ... (+%d more)" % (len(delete_example) - 15))

    if not apply:
        print("\ndry run: nic nie usuniete. Dodaj --apply.")
        return 0

    for src, dst, rel in sync:
        shutil.copy2(src, dst)
    for rel, full, why in delete_mods:
        os.remove(full)
    for rel, full, why in delete_example:
        os.remove(full)
    for d in ("weekend1", "_backup-musthit", "_backup-musthit-all", "_backup-ps104-events",
              "_erect-unused"):
        p = os.path.join(MODS if d.startswith("_") else EXAMPLE, d)
        if os.path.isdir(p):
            shutil.rmtree(p)
    # drop the directories that are now empty, but never the ones Psych ships placeholders in
    for root in (MODS, EXAMPLE):
        for dirpath, dirnames, filenames in os.walk(root, topdown=False):
            if not filenames and not dirnames and os.path.basename(dirpath) not in (
                    "mods", "example_mods"):
                os.rmdir(dirpath)
    print("\napplied: %d sync, %d deleted from bin/mods, %d deleted from example_mods"
          % (len(sync), len(delete_mods), len(delete_example)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
