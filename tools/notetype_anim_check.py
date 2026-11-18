"""Every animation name the custom note types ask for, checked against the character jsons.

Motivation: playAnim() on a name a character does not define is a silent no-op -- no trace, no
warning, the fighter just keeps idling. That is how the can flinch stayed broken (tools/patch_hurt_anims.py):
five note types asked for 'shootMISS', which pico-playable.json has never defined, and everything
around it kept working so nothing looked wrong. Blazin adds another 30-odd note types driving
pico-blazin / darnell-blazin, so the same failure can hide in any of them.

What it collects from each note-type script:
  * local <NAME_ANIMS> = {'a', 'b'}      -- the candidate tables
  * <something>_ANIM = 'a'               -- single-name constants
  * playAnim/tryAnim('obj', 'a')         -- direct calls
  * playAnim('obj', VAR) where VAR is one of the constants above (resolved)

Then it prints, for each name, which of the Weekend 1 characters actually define it. A name owned by
no character at all is a bug; a name owned by only one side is worth reading in context (a can flinch
belongs to the player, a punch to the opponent), so it is reported but not failed.

usage: python tools/notetype_anim_check.py [--chars pico-playable,darnell,...] [--verbose]
"""

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(r'C:/Users/olafc/Downloads/FNF Limul Engine 1.0.0')
PRELOAD = ROOT / 'assets' / 'preload'
# Every live script folder that can call playAnim(), not just the note types: the Blazin fight
# choreography lives in stages/phillyBlazin.lua and Nene's knife states in characters/nene.lua,
# and a wrong name there is the same silent no-op.
DEFAULT_INCLUDES = ['custom_notetypes/*.lua', 'stages/*.lua', 'data/*/*.lua', 'characters/*.lua',
                    'scripts/*.lua', 'weeks/*.lua']

# playAnim/tryAnim are called as (tag, animName). Only tags that are fighters matter here: a stage
# sprite ('cars1', 'Spraycan1', 'reloadEffect') registers its own animations in the same file with
# addAnimationByPrefix, and json-prefix-vs-atlas problems are tools/character_anim_check.py's job.
# Mixing the two kinds in here would bury the finding this tool exists to catch.
CALL_RE = re.compile(r"\b(?:playAnim|tryAnim)\(\s*'([^']+)'\s*,\s*'([^']+)'\s*(?!\.\.)")
FIGHTER_TAGS = {'boyfriend', 'dad', 'gf', 'player', 'opponent', 'bf'}
TABLE_RE = re.compile(r"^local\s+\w*ANIMS?\w*\s*=\s*\{([^}]*)\}", re.MULTILINE)
CONST_RE = re.compile(r"^local\s+(\w*ANIM\w*)\s*=\s*'([^']+)'", re.MULTILINE)
STRING_RE = re.compile(r"'([^']*)'")


def character_anims(names):
    """anim-name -> sorted list of characters that define it

    `names` = None means every character json in the preload tree, which is what the default run
    wants: a name no character anywhere defines is dead code, while a name only one fighter owns is
    perfectly normal (a can flinch belongs to Pico, a kick to Darnell).
    """
    if names is None:
        paths = sorted((PRELOAD / 'characters').glob('*.json'))
    else:
        paths = []
        for char in names:
            path = PRELOAD / 'characters' / (char + '.json')
            if not path.exists():
                print('!! no character json for %s' % char, file=sys.stderr)
                continue
            paths.append(path)
    table = {}
    for path in paths:
        data = json.loads(path.read_text(encoding='utf-8-sig'))
        for anim in data.get('animations', []):
            table.setdefault(anim['anim'], []).append(path.stem)
    for owners in table.values():
        owners.sort()
    return table


def collect(path, fighter_tags):
    """-> list of (group, name, line) triples this script asks for.

    `group` ties the candidates of one list together: tryAnim-style lists are tried in order and the
    first name the character owns wins, so an unresolvable member is only a bug when the whole group
    fails. Single literals (playAnim/tryAnim calls, *_ANIM constants) form their own group.
    """
    text = path.read_text(encoding='utf-8')
    found = []
    for match in CALL_RE.finditer(text):
        if match.group(1) not in fighter_tags:
            continue
        found.append(('call:%d' % match.start(), match.group(2), line_of(text, match.start())))
    for match in TABLE_RE.finditer(text):
        line = line_of(text, match.start())
        group = 'table:' + re.sub(r'^local\s+', '', match.group(0).split('=')[0].strip())
        for item in STRING_RE.findall(match.group(1)):
            found.append((group, item, line))
    for match in CONST_RE.finditer(text):
        var, value = match.group(1), match.group(2)
        start = match.start()
        found.append(('const:%d' % start, value, line_of(text, start)))
        # ... and anything passed to tryAnims('obj', VAR) resolves to this same constant's table
        for call in re.finditer(r"\btryAnims\(\s*'[^']*'\s*,\s*%s\)" % re.escape(var), text):
            table = table_of(text, var)
            if table is None:
                continue
            group = 'table:' + var
            for item in STRING_RE.findall(table):
                found.append((group, item, line_of(text, call.start())))
    return found


def table_of(text, var):
    match = re.search(r"^local\s+%s\s*=\s*(\{[^}]*\})" % re.escape(var), text, re.MULTILINE)
    return match.group(1) if match else None


def line_of(text, pos):
    return text.count('\n', 0, pos) + 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--chars', default='all', help='comma-separated character json names, or "all"')
    ap.add_argument('--include', default=','.join(DEFAULT_INCLUDES),
                    help='comma-separated globs, relative to assets/preload')
    ap.add_argument('--verbose', action='store_true',
                    help='also list names owned by exactly one character (noisy with --chars all)')
    args = ap.parse_args()
    wanted = None if args.chars == 'all' else [c.strip() for c in args.chars.split(',') if c.strip()]

    anim_table = character_anims(wanted)
    jsons = sorted(p.stem for p in (PRELOAD / 'characters').glob('*.json'))
    fighter_tags = FIGHTER_TAGS | (set(wanted) if wanted else set(jsons))
    scope = 'all %d character jsons' % len(jsons) if wanted is None else ', '.join(wanted)
    print('checking %d distinct anim names across %s\n' % (len(anim_table), scope))

    dead, one_sided, scripts = [], [], 0
    report_owned = wanted is not None or args.verbose
    for pattern in [p.strip() for p in args.include.split(',') if p.strip()]:
        for path in sorted(PRELOAD.glob(pattern)):
            scripts += 1
            groups = {}
            for group, name, line in collect(path, fighter_tags):
                groups.setdefault(group, []).append((name, line))
            for entries in groups.values():
                resolved = [(n, l) for (n, l) in entries if n in anim_table]
                if not resolved:
                    for name, line in entries:
                        dead.append((path.name, line, name))
                    continue
                # A candidate list needs exactly one live name; the rest are portability spellings.
                for name, line in resolved:
                    if report_owned and len(anim_table[name]) == 1:
                        one_sided.append((path.name, line, name, anim_table[name][0]))

    for f, line, name in dead:
        print('DEAD ANIM    %-38s:%-4s %r is defined by NO character json' % (f, line, name))
    for f, line, name, owner in one_sided:
        print('single-owner %-34s:%-4s %r -> only %s' % (f, line, name, owner))

    print('\n%d scripts, %d names owned by nobody, %d owned by exactly one character'
          % (scripts, len(dead), len(one_sided)))
    return 1 if dead else 0


if __name__ == '__main__':
    sys.exit(main())
