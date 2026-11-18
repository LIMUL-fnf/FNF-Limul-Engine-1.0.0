#!/usr/bin/env python3
"""Turn the 26 Blazin' fight note-type shims into inert markers.

The fight itself is choreographed by assets/stages/phillyBlazin.lua (port of the JS Engine
PicoBlazinHandler / DarnellBlazinHandler). The .lua files still have to exist, because
Psych 0.6.3 uses the file name as the note-type string for the Chart Editor dropdown
(ChartingState.hx) and loads the same path at gameplay (PlayState.hx) -- but a callback in
them would run after the stage script and overwrite the move the stage picked.

The five 2 Hot types (cockgun / firegun / kickcan / kneecan / lightcan) are NOT touched:
they are single-character props, not fight steps.
"""
import datetime
import pathlib
import shutil

ROOT = pathlib.Path(r'C:\Users\olafc\Downloads\FNF Limul Engine 1.0.0')

TREES = [
    ROOT / 'export/release/windows/bin/mods/custom_notetypes',
    ROOT / 'export/release/windows/bin/assets/custom_notetypes',
    ROOT / 'assets/preload/custom_notetypes',
    ROOT / 'example_mods/custom_notetypes',
]

LABELS = {
    'blockhigh': 'Pico guards a high punch',
    'blocklow': 'Pico guards a low punch',
    'blockspin': 'Pico guards a spin',
    'dodgehigh': 'Pico dodges a high punch',
    'dodgelow': 'Pico dodges a low punch',
    'dodgespin': 'Pico dodges a spin',
    'hithigh': 'Darnell lands a high punch',
    'hitlow': 'Darnell lands a low punch',
    'hitspin': 'Darnell lands a spin',
    'punchhigh': 'Pico throws a high punch',
    'punchhighblocked': 'Pico high punch, Darnell guards it',
    'punchhighdodged': 'Pico high punch, Darnell slips it',
    'punchhighspin': 'Pico high punch, Darnell spins out',
    'punchlow': 'Pico throws a low punch',
    'punchlowblocked': 'Pico low punch, Darnell guards it',
    'punchlowdodged': 'Pico low punch, Darnell slips it',
    'punchlowspin': 'Pico low punch, Darnell spins out',
    'picouppercut': 'Pico lands the uppercut',
    'picouppercutprep': 'Pico winds up the uppercut',
    'darnelluppercut': 'Darnell lands the uppercut',
    'darnelluppercutprep': 'Darnell winds up the uppercut',
    'idle': 'Both fighters breathe',
    'fakeout': 'Pico fakes a punch, Darnell flinches',
    'reversefakeout': 'Darnell fakes, Pico holds',
    'taunt': 'Pico taunts, Darnell answers',
    'tauntforce': 'Pico taunts, Darnell gets pissed for sure',
}

TEMPLATE = """-- weekend-1-{key}.lua -- {label}.
--
-- Chart string: 'weekend-1-{key}'   (sectionNotes[i][3])
--
-- WHY THIS FILE IS EMPTY ON PURPOSE. Psych 0.6.3 has no note-type registry: the type IS the
-- file name. ChartingState.hx (~line 1064) builds the Chart Editor dropdown by listing
-- custom_notetypes/*.lua, and PlayState.hx (~line 1211) loads the same path back at
-- gameplay, so deleting this file would drop the type from the editor and leave every chart
-- that already uses it with a plain sing animation.
--
-- It animates nothing because it cannot. '{key}' is one step of the Blazin' fight, and a
-- step is not one animation: Pico and Darnell move together, the camera shakes, and the
-- attacker swaps draw order with the defender. callOnLuas (PlayState.hx ~5399) hands EVERY
-- loaded script EVERY callback, so whichever file tried to own this would either duplicate
-- the move across the other 25 scripts or have to guess what the other fighter is doing.
-- noteMissPress is worse still: it arrives with a direction and no note type at all.
--
-- The choreography therefore lives in stages/phillyBlazin.lua, ported from FNF-JS-Engine
-- 1.51.1 source/stages/objects/PicoBlazinHandler.hx and DarnellBlazinHandler.hx (dispatch:
-- PhillyBlazin.hx:229-258). Adding a callback here would run AFTER that script for the same
-- note and overwrite the move it picked -- which is exactly the bug this file used to have.
"""

stamp = datetime.datetime.now().strftime('%y%m%d-%H%M%S')
backup = ROOT / f'_backup_blazin_shims_{stamp}'

changed, missing = [], []
for key in sorted(LABELS):
    name = f'weekend-1-{key}.lua'
    for tree in TREES:
        path = tree / name
        if not path.exists():
            missing.append(str(path))
            continue
        text = path.read_text(encoding='utf-8')
        if 'goodNoteHit' not in text:
            continue  # already an inert marker
        rel = pathlib.Path(*tree.parts[-3:])          # e.g. export/release/windows/bin/mods/custom_notetypes
        dest = backup / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(text, encoding='utf-8')
        with open(path, 'w', encoding='utf-8', newline='\n') as handle:
            handle.write(TEMPLATE.format(key=key, label=LABELS[key]))
        changed.append(str(path))

print(f'rewrote {len(changed)} files')
for line in changed:
    print('  ', line.replace(str(ROOT), '.'))
if missing:
    print(f'MISSING {len(missing)}:')
    for line in missing:
        print('  ', line.replace(str(ROOT), '.'))
print('backups ->', str(backup).replace(str(ROOT), '.'))
