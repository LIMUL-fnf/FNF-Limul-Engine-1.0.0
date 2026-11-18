#!/usr/bin/env python3
"""Static audit of the Blazin' fight choreography in stages/phillyBlazin.lua.

playAnim() and the primitive lookup tables fail *silently* in Psych 0.6.3: a name the
character does not have leaves it in its previous animation, and a note type that is missing
from the PICO_HIT / PICO_MISS / DARN_HIT / DARN_MISS maps makes both fighters shrug and keep
idling. Neither shows up as a Lua error, so both are checked here instead of in the song.

Validates, in order:
  1. every `a='<anim>'` in PICO_P / DARN_P exists in that character's json `anim` list
     (entries marked alt=true resolve to <name>1 / <name>2, so the base name is not required);
  2. every value of the four note-type -> primitive maps is either a key of the matching
     primitive table or one of the four pseudo-actions handled in picoAct()/darnAct();
  3. every `prim(pico, PICO_P, '<key>')` / `prim(darn, DARN_P, '<key>')` written inline in the
     callbacks is a key of that table;
  4. every custom note type that actually occurs in the blazin charts is a key of both maps on
     both sides (and has a custom_notetypes/<type>.lua marker, or the editor will not list it).

The tables are matched by their fixed one-entry-per-line layout in this file; if they are ever
reformatted the script reports MISSING rather than passing quietly.

Usage: python tools/blazin_anim_check.py
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
BIN = ROOT / 'export/release/windows/bin/assets'
STAGE = BIN / 'stages/phillyBlazin.lua'
SONG_DIRS = [
    BIN / 'data/blazin',
    ROOT / 'export/release/windows/bin/mods/data/blazin',
]
NOTETYPES = [
    BIN / 'custom_notetypes',
    ROOT / 'export/release/windows/bin/mods/custom_notetypes',
]

# pseudo primitives: picoAct()/darnAct() intercept these before prim() ever sees them
ACTIONS = {'tauntConditional', 'pissedConditional', 'punchHighCant', 'hitHighCant'}

# (map, chart type) the JS Engine deliberately leaves empty, with the source that says so.
GAPS = {
    ('DARN_HIT', 'picouppercutprep'):
        'DarnellBlazinHandler.hx:74-76 "Continue whatever animation was playing before" '
        '(playIdleAnim is commented out)',
}

PRIM_TABLES = {'PICO_P': 'pico-blazin', 'DARN_P': 'darnell-blazin'}
MAP_TABLES = {'PICO_HIT': 'PICO_P', 'PICO_MISS': 'PICO_P',
              'DARN_HIT': 'DARN_P', 'DARN_MISS': 'DARN_P'}
CHART_MAPS = {'PICO_HIT': 'boyfriend', 'PICO_MISS': 'boyfriend',
              'DARN_HIT': 'dad', 'DARN_MISS': 'dad'}

problems = 0


def fail(message):
    global problems
    problems += 1
    print('   BAD  ' + message)


def table_body(text, name):
    match = re.search(r'^local ' + name + r' = \{\n(.*?)^\}', text, re.S | re.M)
    if not match:
        fail(f'MISSING TABLE {name} (layout changed? this script expects one entry per line)')
        return None
    return match.group(1)


def anim_names(character):
    data = json.loads((BIN / 'characters' / f'{character}.json').read_text(encoding='utf-8'))
    return {entry['anim'] for entry in data['animations'] if 'anim' in entry}


def prims(text):
    """name -> {key: (anim, alt)} for PICO_P / DARN_P."""
    out = {}
    for name, character in PRIM_TABLES.items():
        body = table_body(text, name)
        if body is None:
            continue
        known = anim_names(character)
        entries = {}
        for line in body.splitlines():
            match = re.match(r"\t(\w+)\s*=\s*\{(.*)\},", line)
            if not match:
                if line.strip():
                    fail(f'{name}: unparsed entry {line.strip()[:60]!r}')
                continue
            key, fields = match.group(1), match.group(2)
            anim = re.search(r"a='(\w+)'", fields)
            if not anim:
                fail(f'{name}.{key} has no a= animation')
                continue
            alt = 'alt=true' in fields
            entries[key] = anim.group(1)
            needed = [f'{anim.group(1)}1', f'{anim.group(1)}2'] if alt else [anim.group(1)]
            for candidate in needed:
                if candidate not in known:
                    fail(f'{name}.{key} plays {candidate!r}, {character} does not have it')
        # and the other direction, so an anim nobody can reach is visible too
        unreachable = sorted(known - set(entries.values()) -
                             {'firstDeath', 'deathLoop', 'deathConfirm', 'taunt-loop',
                              'uppercut-loop', 'punchHigh1', 'punchHigh2', 'punchLow1',
                              'punchLow2'})
        if unreachable:
            print(f'   note {name}: never played by the fight -> {", ".join(unreachable)}')
        out[name] = entries
    return out


def maps(text, prims_by_name):
    """name -> {chart type: primitive} for the four note-type maps, each entry checked."""
    out = {}
    for name, prim_name in MAP_TABLES.items():
        body = table_body(text, name)
        if body is None:
            continue
        keys = set(prims_by_name.get(prim_name, {}))
        entries = {}
        for line in body.splitlines():
            for match in re.finditer(r"(\w+)='(\w+)'", line):
                entries[match.group(1)] = match.group(2)
        for chart_type, prim in entries.items():
            if prim not in keys and prim not in ACTIONS:
                fail(f'{name}.{chart_type} -> {prim!r}: not a {prim_name} key nor an action')
        out[name] = entries
        print(f'   ok   {name}: {len(entries)} chart types')
    return out


def inline_prims(text, prims_by_name):
    for match in re.finditer(r"prim\((pico|darn), (PICO_P|DARN_P), '(\w+)'\)", text):
        if match.group(3) not in prims_by_name.get(match.group(2), {}):
            fail(f"inline prim() key {match.group(3)!r} is not in {match.group(2)}")


def chart_types_present():
    """Types actually used by the blazin charts, with the weekend-1- prefix stripped."""
    found = {}
    for folder in SONG_DIRS:
        for chart in sorted(folder.glob('blazin*.json')):
            if chart.name.endswith('.bak') or '.pre-' in chart.name:
                continue
            data = json.loads(chart.read_text(encoding='utf-8'))
            # these charts are the {"song": {...}} wrapped flavour that Song.parseJSONshit() takes
            if isinstance(data.get('song'), dict):
                data = data['song']
            for section in data.get('notes', []):
                for note in section.get('sectionNotes', []):
                    note_type = (note[3] if len(note) > 3 else None) or ''
                    if note_type.startswith('weekend-1-'):
                        key = note_type[len('weekend-1-'):]
                        found.setdefault(key, set()).add(chart.name)
    return found


def marker_exists(chart_type):
    full = 'weekend-1-' + chart_type
    return any((folder / f'{full}.lua').exists() for folder in NOTETYPES)


def main():
    text = STAGE.read_text(encoding='utf-8')
    prims_by_name = prims(text)
    maps_by_name = maps(text, prims_by_name)
    inline_prims(text, prims_by_name)

    present = chart_types_present()
    print(f'   {len(present)} custom note types occur in the blazin charts')
    for chart_type, charts in sorted(present.items()):
        for name, entries in maps_by_name.items():
            if chart_type in entries:
                continue
            gap = GAPS.get((name, chart_type))
            if gap:
                print(f'   ok   {name}.{chart_type} left empty on purpose -- {gap}')
                continue
            fail(f'{name} has no entry for chart type {chart_type!r} '
                 f'(used by {", ".join(sorted(charts))}) -> both fighters keep idling')
        if not marker_exists(chart_type):
            fail(f'custom_notetypes/weekend-1-{chart_type}.lua is missing -> '
                 f'Chart Editor will not list the type')
    for name, entries in maps_by_name.items():
        dead = sorted(set(entries) - set(present))
        if dead:
            print(f'   note {name}: {len(dead)} type(s) no chart uses '
                  f'({", ".join(dead)}) -- kept for hand-made charts')

    print(f'{problems} problem(s)')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
