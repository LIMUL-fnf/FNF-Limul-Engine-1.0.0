"""Re-map the broken characters onto the animation names their atlas XML really contains.

What the engine does with a character json (source/Character.hx:196-206 + flixel 5.5.0
FlxAnimationController):

    frames = Paths.getSparrowAtlas(json.image)        # ONE key, commas are NOT split
    addByPrefix(anim, name, fps, loop)   -> every SubTexture whose name startsWith(prefix),
                                           sorted by the number that ends the name
    addByIndices(anim, name, indices, "", fps, loop)
                        -> for every i, the frame whose name startsWith(prefix) and whose
                           remaining text parses to exactly i (findSpriteFrame, line 455)

So `indices` are literal frame numbers, not positions, and `fps: 0` freezes an animation because
its interval becomes 1/0. Every mapping in this file is validated against the real XML first: a
prefix that matches nothing, an index that reaches no frame, or a missing fps aborts that file
instead of writing a half-fixed definition.

Repaired here (see tools/character_anim_check.py for the report this was taken from):
  * pico-playable.json  -- `image` was a comma list, so the character had no atlas at all, and the
    six shoot/cock/intro prefixes came from a packer this engine cannot read,
  * darnell.json        -- the KA-DE names ('Idle', 'Pose Left', 'Gets Pissed0'...) exist nowhere;
    the live atlas prefixes everything with the character name,
  * pico-dead.json      -- 'Pico Death Stab' matches 0 frames; the atlas only has 'DEATH PICO',
  * pico-blazin.json / darnell-blazin.json -- they pointed at the FlxElate spritemap folders
    (picoBlazin/darnellBlazin) that 0.6.3 cannot load, and Darnell's fight anims additionally had
    fps 0. Both are now copies of the working Pico_Blazin.json / Darnell_Blazin.json definitions,
  * nene.json           -- its idle half used frame 0, which the 1-based atlas does not have, so
    the dance skipped a frame and hiccupped,
  * gf-dark.json        -- stray index 30 in danceLeft (the atlas stops at 29).

Usage:
    python tools/character_xml_remap.py                # dry run: print the plan
    python tools/character_xml_remap.py --write        # back up + apply + mirror every tree
    python tools/character_xml_remap.py --only darnell # filter, works with or without --write
"""

import argparse
import copy
import json
import pathlib
import re
import shutil
import sys
import time

ROOT = pathlib.Path(r'C:/Users/olafc/Downloads/FNF Limul Engine 1.0.0')
LIVE = ROOT / 'export/release/windows/bin/assets'
TREES = [LIVE,
         ROOT / 'export/release/windows/bin/mods',
         ROOT / 'assets/preload',
         ROOT / 'example_mods/weekend1',
         ROOT / 'export/debug/windows/bin/assets']

# getSparrowAtlas() search order used by tools/character_anim_check.py; the dev-tree folders are
# legitimate because their files were packed into the exe at build time.
ATLAS_SEARCH = [LIVE / 'images',
                ROOT / 'export/release/windows/bin/mods/images',
                ROOT / 'assets/preload/images',
                ROOT / 'assets/shared/images',
                ROOT / 'example_mods/weekend1/images',
                ROOT / 'example_mods/preload/images',
                ROOT / 'example_mods/shared/images']

class Tail:
    """Marker: keep the last N frame numbers of the matched prefix."""

    def __init__(self, n):
        self.n = n


TAIL = Tail
FILTER = object()        # marker: keep the current indices, minus the ones that reach nothing


def atlas_names(image_key):
    """SubTexture names of the sparrow atlas a character json points at, or None."""
    for d in ATLAS_SEARCH:
        xml = d / ('%s.xml' % image_key)
        if xml.is_file():
            return re.findall(r'<SubTexture\s+name="([^"]+)"',
                              xml.read_text(encoding='utf-8', errors='replace'))
    return None


def prefix_count(names, prefix):
    return len([n for n in names if n.startswith(prefix)])


def frame_numbers(names, prefix):
    """Frame numbers addByIndices can reach for this prefix (parseInt of the name tail)."""
    out = []
    for n in names:
        if not n.startswith(prefix):
            continue
        m = re.match(r'^\s*(\d+)\s*$', n[len(prefix):])
        if m:
            out.append(int(m.group(1)))
    return sorted(out)


def rng(start, stop):
    """Inclusive literal frame-number range, for writing into `indices`."""
    return list(range(start, stop + 1))


# ---------------------------------------------------------------- the plan
# anim -> dict(name=prefix, indices=list | TAIL(N) | FILTER | None, fps=int, loop=bool)
# indices None  -> the key is emptied, so the engine uses addByPrefix over the whole animation.
PLAN = {
    # The comma list never resolved to an atlas. Pico_Playable.xml holds every gameplay animation;
    # the three intro ones live in Pico_Intro.xml, which pico-intro.json already owns, and no live
    # script asks pico-playable for them.
    'pico-playable.json': {
        'image': 'characters/Pico_Playable',
        'anims': {
            'idle':          dict(name='Pico Idle Dance', indices=None),
            'singUP':        dict(name='pico Up note0', indices=None),
            'singDOWN':      dict(name='Pico Down Note0', indices=None),
            'singLEFT':      dict(name='Pico NOTE LEFT0', indices=None),
            'singRIGHT':     dict(name='Pico Note Right0', indices=None),
            'singUPmiss':    dict(name='pico Up note miss', indices=None),
            'singDOWNmiss':  dict(name='Pico Down Note MISS', indices=None),
            'singLEFTmiss':  dict(name='Pico NOTE LEFT miss', indices=None),
            'singRIGHTmiss': dict(name='Pico Note Right Miss', indices=None),
            'shoot':         dict(name='Pico Shoot Hip Full0', indices=None),
            'shootMISS':     dict(name='Pico Hit Can0', indices=None),
            'cock':          dict(name='Pico Reload0', indices=None),
        },
        'drop': ['intro1', 'cockCutscene', 'intro2'],
    },

    # 2 Hot / Lit Up / Darnell: the live atlas prefixes his poses with his own name (and mixes
    # case), which the converted json lost. The flame-loop holds of the KA-DE file do not exist at
    # all, so they become the held tail of the matching note pose.
    'darnell.json': {
        'image': 'characters/darnell',
        'anims': {
            'idle':          dict(name='Darnell Idle', indices=None),
            'singLEFT':      dict(name='darnell pose left', indices=None),
            'singDOWN':      dict(name='Darnell Pose Down', indices=None),
            'singUP':        dict(name='Darnell pose up', indices=None),
            'singRIGHT':     dict(name='Darnell pose right', indices=None),
            'singLEFT-hold': dict(name='darnell pose left', indices=TAIL(5)),
            'singDOWN-hold': dict(name='Darnell Pose Down', indices=TAIL(5)),
            'singUP-hold':   dict(name='Darnell pose up', indices=TAIL(5)),
            'singRIGHT-hold': dict(name='Darnell pose right', indices=TAIL(5)),
            'laughCutscene': dict(name='darnell laugh', indices=None),
            'lightCan':      dict(name='Light Can0', indices=None),
            'kickCan':       dict(name='Kick Up0', indices=None),
            'kneeCan':       dict(name='Knee Forward0', indices=None),
            # No 'Gets Pissed' footage exists in this atlas; the laugh is the only taunt in it, so
            # 'pissed' becomes an alias instead of a permanently dead animation.
            'pissed':        dict(name='darnell laugh', indices=None),
        },
        'drop': [],
    },

    # Pico's death strip: the atlas has exactly one animation name and 99 frames. The ranges match
    # pico-blazin-dead.json, which already uses that atlas correctly (fall 0..46, loop 47..63).
    'pico-dead.json': {
        'image': 'characters/Pico_Death',
        'anims': {
            'firstDeath': dict(name='DEATH PICO', indices=rng(0, 46)),
            'deathLoop':  dict(name='DEATH PICO', indices=rng(47, 63), loop=True),
        },
        'drop': [],
    },

    # The Blazin fighters pointed at FlxElate spritemap folders (Animation.json + spritemap1.png)
    # that 0.6.3 cannot read at all, so both were invisible; Darnell's additionally had fps 0,
    # which freezes an animation even with the right frames. The spriter atlases Pico_Blazin.xml /
    # Darnell_Blazin.xml hold every fighting anim, and the capitalised jsons of the same names are
    # already correct -> copy their animation lists verbatim.
    'pico-blazin.json': {'copy_from': 'Pico_Blazin.json'},
    'darnell-blazin.json': {'copy_from': 'Darnell_Blazin.json'},

    # Nene's idle is numbered 1..30, so the first half asked for a frame 0 that does not exist:
    # 14 frames on the left against 15 on the right, which is the hiccup in her dance.
    'nene.json': {
        'image': 'characters/Nene',
        'anims': {
            'danceLeft':     dict(name='Idle', indices=rng(1, 15)),
            'danceRight':    dict(name='Idle', indices=rng(16, 30)),
            # same 1-based numbering: drop the unreachable 0, keep the authored repeats
            'laughCutscene': dict(indices=FILTER),
            'combo100':      dict(indices=FILTER),
        },
        'drop': [],
    },

    # danceLeft asked for frame 30 of a 0..29 strip; harmless but it is a lie in the file.
    'gf-dark.json': {
        'image': 'characters/gf_dark',
        'anims': {
            'danceLeft':  dict(name='GF Dancing Beat', indices=rng(0, 14)),
            'danceRight': dict(name='GF Dancing Beat', indices=rng(15, 29)),
        },
        'drop': [],
    },
}


def build(new_data, names, plan, source_animations=None):
    """Return (data, changes, problems) for one character json."""
    changes, problems = [], []
    data = copy.deepcopy(new_data)
    if source_animations is not None:
        data['animations'] = copy.deepcopy(source_animations)
        changes.append('animations copied verbatim from the reference definition (%d anims)'
                       % len(source_animations))

    anim_map = plan.get('anims', {})
    drop = plan.get('drop', [])
    kept = []
    for anim in data.get('animations', []):
        name = anim.get('anim')
        if name in drop:
            changes.append('drop %-16s (its frames are in another atlas, nothing calls it)' % name)
            continue
        kept.append(anim)
        spec = anim_map.get(name)
        if spec is None:
            continue
        prefix = spec.get('name', anim.get('name'))
        hits = prefix_count(names, prefix)
        if hits == 0:
            problems.append('anim %r -> prefix %r matches 0 SubTextures in the atlas'
                            % (name, prefix))
            continue
        if 'indices' not in spec:
            pass
        elif spec['indices'] is None:
            if anim.get('indices'):
                changes.append('idx  %-16s %s -> [] (whole %r, %d frames)'
                               % (name, _brief(anim['indices']), prefix, hits))
            anim['indices'] = []
        elif spec['indices'] is FILTER:
            reachable = frame_numbers(names, prefix)
            bad = [i for i in anim.get('indices', []) if i not in reachable]
            if bad:
                changes.append('idx  %-16s drops unreachable %s (atlas has %s)'
                               % (name, _brief(bad), _brief(reachable)))
                anim['indices'] = [i for i in anim['indices'] if i in reachable]
        else:
            wanted = spec['indices']
            if isinstance(wanted, Tail):
                numbers = frame_numbers(names, prefix)
                wanted = numbers[-wanted.n:] if numbers else []
            reachable = frame_numbers(names, prefix)
            missing = [i for i in wanted if i not in reachable]
            if missing:
                problems.append('anim %r -> indices %s reach no frame of %r (atlas has %s)'
                                % (name, _brief(missing), prefix, _brief(reachable)))
                continue
            if anim.get('indices') != wanted or anim.get('name') != prefix:
                changes.append('idx  %-16s %s -> %s  (%d frames)'
                               % (name, _brief(anim.get('indices') or []), _brief(wanted), hits))
            anim['indices'] = wanted
        if anim.get('name') != prefix:
            changes.append('map  %-16s %r -> %r  (%d frames)'
                           % (name, anim.get('name'), prefix, hits))
            anim['name'] = prefix
        if 'fps' in spec:
            if anim.get('fps') != spec['fps']:
                changes.append('fps  %-16s %r -> %r' % (name, anim.get('fps'), spec['fps']))
                anim['fps'] = spec['fps']
        elif anim.get('fps') is None or anim.get('fps') == 0:
            problems.append('anim %r has fps=%r and the plan gives no replacement' % (name,
                                                                                     anim.get('fps')))
        if 'loop' in spec and anim.get('loop') != spec['loop']:
            changes.append('loop %-16s %r -> %r' % (name, anim.get('loop'), spec['loop']))
            anim['loop'] = spec['loop']
        if 'offsets' not in anim:
            anim['offsets'] = [0, 0]
    data['animations'] = kept
    return data, changes, problems


def _brief(numbers):
    numbers = list(numbers or [])
    if len(numbers) > 8:
        return '%s..%s (%d)' % (numbers[0], numbers[-1], len(numbers))
    return str(numbers)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('--write', action='store_true')
    ap.add_argument('--only', default='')
    args = ap.parse_args(argv)

    stamp = time.strftime('%y%m%d-%H%M%S')
    blocked = done = 0
    for fname, plan in PLAN.items():
        if args.only and args.only.lower() not in fname.lower():
            continue
        src = LIVE / 'characters' / fname
        if not src.is_file():
            print('SKIP %s (not in the live tree)' % fname)
            continue
        data = json.loads(src.read_text(encoding='utf-8'))

        source_animations = None
        image = plan.get('image') or data.get('image')
        if 'copy_from' in plan:
            ref_path = LIVE / 'characters' / plan['copy_from']
            if not ref_path.is_file():
                print('FAIL %s: reference %s is gone' % (fname, plan['copy_from']))
                blocked += 1
                continue
            ref = json.loads(ref_path.read_text(encoding='utf-8'))
            source_animations = ref['animations']
            image = ref.get('image') or image
            plan = dict(plan)
            plan.setdefault('anims', {})
        names = atlas_names(image)
        if names is None:
            print('FAIL %s: atlas %r has no XML to validate against' % (fname, image))
            blocked += 1
            continue

        new_data, changes, problems = build(data, names, plan, source_animations)
        if problems:
            print('\n=== %s   atlas %s (%d SubTextures)' % (fname, image, len(names)))
            for pr in problems:
                print('    !! refusing to write: %s' % pr)
            blocked += 1
            continue
        if not changes:
            print('ok   %s  (already correct)' % fname)
            continue

        trees = [t / 'characters' / fname for t in TREES if (t / 'characters' / fname).is_file()]
        print('\n=== %s   atlas %s (%d SubTextures)   %d tree copy/copies  %s'
              % (fname, image, len(names), len(trees), '[WRITING]' if args.write else '[dry run]'))
        for c in changes:
            print('    %s' % c)
        if image != data.get('image'):
            print('    image %r -> %r' % (data.get('image'), image))

        # Every tree is patched from ITS OWN file, so position/camera/healthicon values the user
        # edits in one tree are never overwritten by another tree's copy.
        for t in trees:
            tree_data = json.loads(t.read_text(encoding='utf-8'))
            tree_source = source_animations
            if 'copy_from' in plan:
                ref_here = t.parent / plan['copy_from']
                if ref_here.is_file():
                    tree_source = json.loads(ref_here.read_text(encoding='utf-8'))['animations']
            out, tree_changes, tree_problems = build(tree_data, names, plan, tree_source)
            if tree_problems:
                for pr in tree_problems:
                    print('    !! %s: refusing to write: %s' % (t.parent.parent, pr))
                blocked += 1
                continue
            out['image'] = image if (plan.get('image') or source_animations) else tree_data.get('image')
            text = json.dumps(out, indent='\t', ensure_ascii=False) + '\n'
            if args.write:
                shutil.copy2(t, t.with_name('%s.pre-xmlmap-%s%s' % (t.stem, stamp, t.suffix)))
                t.write_text(text, encoding='utf-8', newline='\n')
            print('    %s %-38s (%d edits)' % ('written' if args.write else 'planned',
                                               str(t.parent.parent.relative_to(ROOT)),
                                               len(tree_changes)))
        done += 1

    print('\n%d character(s) %s, %d blocked' % (done, 'updated' if args.write else 'planned',
                                                blocked))
    return 1 if blocked else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
