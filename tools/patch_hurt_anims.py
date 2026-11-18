"""Fix the can-impact flinch in all five weekend-1-* custom note types.

Why: every shim ends its incoming-can impact with tryAnim('boyfriend', HURT_ANIM) and HURT_ANIM is
the single string 'shootMISS'.  That is the name 1.0.4's PhillyStreets.hx:933 uses, but the live
character here is assets/preload/characters/pico-playable.json, whose animation list is

    idle singUP singDOWN singDOWNmiss singUPmiss singRIGHT singLEFT singRIGHTmiss singLEFTmiss
    hey CanHit cock shoot

There is no 'shootMISS' entry at all, and Psych's playAnim() on an unknown name is a silent no-op,
so Pico has been taking 0.25-0.35 health from a spray can with no reaction whatsoever.  The flinch
this fork actually ships is 'CanHit' (prefix "Pico Hit Can"), which tools/character_anim_check.py
confirms resolves against the live atlas.

The fix keeps both spellings as an ordered candidate list, so the same file is correct against the
0.6.3 character json here, against a 1.0.4-style json, and harmless for the Blazin cast (pico-blazin
has neither name -- its hit reactions are driven by the stage's own fight choreography).

Every copy is patched, not just the authored one: the game reads bin/assets, the Chart Editor reads
bin/mods, and example_mods is re-copied into bin/mods on every build, so leaving one behind
guarantees the bug comes back.

Usage: python tools/patch_hurt_anims.py [--check]
"""

import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(r'C:/Users/olafc/Downloads/FNF Limul Engine 1.0.0')
TREES = [
    ROOT / 'assets' / 'preload',
    ROOT / 'export' / 'release' / 'windows' / 'bin' / 'assets',
    ROOT / 'export' / 'release' / 'windows' / 'bin' / 'mods',
    ROOT / 'example_mods',
]
TYPES = ['cockgun', 'firegun', 'kickcan', 'kneecan', 'lightcan']

CONST_ANCHOR = re.compile(
    r"^local HURT_ANIM\s*=\s*'shootMISS'[^\n]*\n(?:[ \t]*--[^\n]*\n){2}", re.MULTILINE)
TRYANIM_ANCHOR = re.compile(
    r"local function tryAnim\(obj, name\)\n"
    r"[ \t]*playAnim\(obj, name, true\)\n"
    r"[ \t]*return currentAnim\(obj\) == name\n"
    r"end\n")
CALL_ANCHOR = re.compile(r"tryAnim\('boyfriend', HURT_ANIM\)")

CONST_NEW = """local HURT_ANIMS  = {'shootMISS', 'CanHit'}   -- ordered candidates, first one the
                                   -- character actually has wins. 'shootMISS' is the name 1.0.4's
                                   -- PhillyStreets.hx:933 plays; this fork's pico-playable.json does
                                   -- not define it at all -- its can flinch is 'CanHit' (prefix
                                   -- "Pico Hit Can", verified by tools/character_anim_check.py).
                                   -- playAnim() on a missing name is a silent no-op, so keeping both
                                   -- spellings is right on either engine. pico-blazin has neither:
                                   -- Blazin's hit reactions come from the stage fight choreography.
"""

TRYANIM_NEW = """
-- The same, but against a list of candidate names -- see HURT_ANIMS below.
local function tryAnims(obj, names)
    for i = 1, #names do
        if tryAnim(obj, names[i]) then return true end
    end
    return false
end
"""


def patch(text):
    """Returns (new_text, ok). ok is only true when every anchor matched exactly once."""
    # Already patched: recognise the finished shape instead of re-matching the old anchors.
    if 'local HURT_ANIMS' in text and 'tryAnims' in text and not re.search(r"\bHURT_ANIM\b", text):
        return text, True
    for pattern in (CONST_ANCHOR, TRYANIM_ANCHOR, CALL_ANCHOR):
        if len(pattern.findall(text)) != 1:
            return text, False
    text = CONST_ANCHOR.sub(CONST_NEW, text)
    text = TRYANIM_ANCHOR.sub(lambda m: m.group(0) + TRYANIM_NEW, text)
    text = CALL_ANCHOR.sub("tryAnims('boyfriend', HURT_ANIMS)", text)
    # Nothing may still reference the removed singular constant.
    if re.search(r"\bHURT_ANIM\b", text):
        return text, False
    return text, True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true', help='report only, write nothing')
    args = ap.parse_args()

    changed, clean, broken = 0, 0, 0
    for tree in TREES:
        for t in TYPES:
            path = tree / 'custom_notetypes' / ('weekend-1-%s.lua' % t)
            if not path.exists():
                print('MISSING  %s' % path)
                broken += 1
                continue
            raw = path.read_text(encoding='utf-8', newline='')
            new, ok = patch(raw)
            if not ok:
                print('ANCHOR-FAIL %s' % path)
                broken += 1
                continue
            if new == raw:
                clean += 1
                continue
            changed += 1
            print('PATCH      %s' % path)
            if not args.check:
                path.write_text(new, encoding='utf-8', newline='')

    print('\n%d patched, %d already clean, %d problems' % (changed, clean, broken))
    return 1 if broken else 0


if __name__ == '__main__':
    sys.exit(main())
