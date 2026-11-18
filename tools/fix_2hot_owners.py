#!/usr/bin/env python3
"""Fix the 2 Hot can/gun notetype shims: their playAnim calls passed `{boyfriend, dad}`.

This engine never pushes `boyfriend`/`dad` as Lua globals (FunkinLua.hx's set() list has
score, misses, health, inGameOver, ... but no characters), so both entries evaluated to nil,
the table constructor collapsed to `{}` and `play()` -- which iterates `ipairs(owners)` --
never tried a single animation. The can still flew and still did damage, the fighters just
never moved, which is exactly what tools/lua_api_check.py flags as UNKNOWN boyfriend/dad.

owners are Lua object NAME strings: tryAnim()/setProperty() take 'boyfriend' and 'dad'.

Patches every copy in all four mirror trees and keeps a backup of each original.
Usage: python tools/fix_2hot_owners.py [--dry-run]
"""
import pathlib
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
BIN = ROOT / 'export/release/windows/bin'
TREES = [
    BIN / 'mods/custom_notetypes',
    BIN / 'assets/custom_notetypes',
    ROOT / 'assets/preload/custom_notetypes',
    ROOT / 'example_mods/custom_notetypes',
]
TYPES = ['cockgun', 'firegun', 'kickcan', 'kneecan', 'lightcan']

REPLACES = [
    ("{boyfriend, dad}", "{'boyfriend', 'dad'}"),
    ("{dad, boyfriend}", "{'dad', 'boyfriend'}"),
]
NOTE = (
    "-- Limul Engine: owners are the object NAME strings ('boyfriend', 'dad'), never bare\n"
    "-- globals -- this engine does not push the characters into the Lua environment, so\n"
    "-- `{boyfriend, dad}` evaluated to an empty table and no animation was ever tried.\n"
)
ANCHOR = 'local function play(candidates, owners)'

STAMP = time.strftime('%y%m%d-%H%M%S')
BACKUP = ROOT / f'_backup_2hot_owners_{STAMP}'


def main(argv):
    dry = '--dry-run' in argv
    changed = 0
    for tree in TREES:
        for name in TYPES:
            path = tree / f'weekend-1-{name}.lua'
            if not path.exists():
                print(f'MISSING    {path.relative_to(ROOT)}')
                continue
            text = path.read_text(encoding='utf-8')
            new = text
            for old, repl in REPLACES:
                new = new.replace(old, repl)
            if ANCHOR in new and NOTE not in new:
                new = new.replace(ANCHOR, NOTE + ANCHOR, 1)
            if new == text:
                continue
            if not dry:
                rel = pathlib.Path(*tree.parts[-3:]) / path.name
                dest = BACKUP / rel
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(path.read_bytes())
                with open(path, 'w', encoding='utf-8', newline='\n') as handle:
                    handle.write(new)
            changed += 1
            print(f'{"would patch" if dry else "patched   "} {path.relative_to(ROOT)}')
    print(f'{changed} files, backups in {BACKUP.name}' if not dry else f'{changed} files would change')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
