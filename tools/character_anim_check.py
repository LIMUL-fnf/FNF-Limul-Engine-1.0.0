"""Static reproduction of the in-game character offset tool, with the REAL flixel matching rules.

Motivation: the engine reads a character as
    frames = Paths.getSparrowAtlas(json.image)          # Character.hx:164
    animation.addByPrefix(anim.anim, anim.name, fps, loop)   # or addByIndices
so two independent things can silently fail:
  * the atlas key does not resolve (no png/xml) -> the whole character draws nothing,
  * the atlas resolves but the prefix is absent -> that one animation has 0 frames, which the
    offset tool prints as "singLEFT (ERROR!)" and gameplay shows as a frozen idle.
Paths.hx in this fork logs the first case into bin/logs/asset-issues.log, but nothing checks the
second one, and neither checker looked at whether json.image is a comma separated list -- which
Psych 0.6.3 does not split, so those keys can never resolve.

Usage: python tools/character_anim_check.py [--bin DIR]
"""

import argparse
import json
import pathlib
import re
import sys
import urllib.parse
from collections import OrderedDict

GAME_BIN = pathlib.Path(r'C:/Users/olafc/Downloads/FNF Limul Engine 1.0.0/export/release/windows/bin')
DEV_ROOT = GAME_BIN.parent.parent.parent.parent

# Paths.returnGraphic() plus the dev-tree folders whose files were packed into the exe at build
# time -- the game can see those even when bin/assets holds no loose copy.
SEARCH_DIRS = [GAME_BIN / 'assets' / 'images',
               GAME_BIN / 'mods' / 'images',
               GAME_BIN / 'assets' / 'data' / 'images',
               DEV_ROOT / 'assets' / 'preload' / 'images',
               DEV_ROOT / 'assets' / 'shared' / 'images',
               DEV_ROOT / 'example_mods' / 'preload' / 'images',
               DEV_ROOT / 'example_mods' / 'shared' / 'images',
               DEV_ROOT / 'example_mods' / 'images']

# Animations that have to keep playing; anything else is a one-shot.
LOOP_HINTS = ('idle', 'dance', 'loop', 'spin', 'scared', 'knifeidle', 'hairblow')


def packed_paths(manifest_dir):
    """The exe only knows what was packed at build time, but Paths.hx in this fork also reads
    bin/assets/*.png and bin/mods/images/*.png straight off disk, so disk presence counts."""
    out = set()
    if not manifest_dir.is_dir():
        return out
    for f in sorted(manifest_dir.glob('*.json')):
        try:
            blob = json.loads(f.read_text(encoding='utf-8')).get('assets') or ''
        except Exception:
            continue
        if not isinstance(blob, str):
            continue
        for m in re.finditer(r'y(\d+):', blob):
            n = int(m.group(1))
            s = m.end()
            raw = blob[s:s + n]
            if raw.startswith('assets%2F'):
                out.add(urllib.parse.unquote(raw))
    return out


def atlas_prefixes(xml_path):
    """Every SubTexture name in a sparrow atlas, in atlas order.

    FlxAnimationController.addByPrefix() matches by STARTSWITH and then sorts the hits NUMERICALLY
    by their trailing number (findByPrefix line 737 + FlxFrame.sort in byPrefixHelper line 724), so
    'BF NOTE LEFT0' is a valid prefix of 'BF NOTE LEFT0000'.
    addByIndices() does something else entirely: findSpriteFrame() (line 455) looks for a frame
    whose name starts with the prefix AND whose remaining text parses to the index, i.e. the
    numbers in `indices` are literal frame numbers, not positions in the filtered list. Zero
    padding is fine ('0007' -> 7); an index with no such frame is quietly dropped.
    """
    text = xml_path.read_text(encoding='utf-8', errors='replace')
    names = re.findall(r'<SubTexture\s+name="([^"]+)"', text)
    return names


def index_numbers(names, prefix):
    """Frame numbers addByIndices can actually reach for this prefix."""
    out = []
    for n in names:
        if not n.startswith(prefix):
            continue
        m = re.match(r'^\s*(\d+)\s*$', n[len(prefix):])
        if m:
            out.append(int(m.group(1)))
    return sorted(out)


def span(values):
    """Compact rendering of a number list, e.g. [0..4,9]."""
    values = sorted(set(values))
    if not values:
        return '[]'
    parts = []
    start = prev = values[0]
    for v in values[1:]:
        if v == prev + 1:
            prev = v
            continue
        parts.append(str(start) if start == prev else '%d..%d' % (start, prev))
        start = prev = v
    parts.append(str(start) if start == prev else '%d..%d' % (start, prev))
    return '[' + ','.join(parts) + ']'


def prefix_frames(names, prefix):
    """Frames sharing a prefix, in the order flixel walks them."""
    hits = [n for n in names if n.startswith(prefix)]
    def key(n):
        tail = re.search(r'(\d+)$', n)
        return int(tail.group(1)) if tail else 0
    return sorted(hits, key=key)


def resolve_image(game_bin, packed, key):
    """Return (png_ok, xml_ok, where, xml_path). Mirrors Paths.returnGraphic + getSparrowAtlas."""
    png = xml = None
    for d in SEARCH_DIRS:
        if png is None and (d / ('%s.png' % key)).is_file():
            png = d / ('%s.png' % key)
        if xml is None and (d / ('%s.xml' % key)).is_file():
            xml = d / ('%s.xml' % key)
    packed_png = any(p in packed for p in ('assets/images/%s.png' % key,
                                           'assets/shared/images/%s.png' % key,
                                           'assets/preload/images/%s.png' % key))
    packed_xml = any(p in packed for p in ('assets/images/%s.xml' % key,
                                           'assets/shared/images/%s.xml' % key,
                                           'assets/preload/images/%s.xml' % key))
    png_ok = png is not None or packed_png
    xml_ok = xml is not None or packed_xml
    where = []
    if png is not None or xml is not None:
        where.append(str((xml or png).parent).replace('\\', '/').split('FNF Limul Engine 1.0.0/')[-1])
    if packed_png or packed_xml:
        where.append('packed')
    return png_ok, xml_ok, ','.join(where) or '-', xml


def check_character(game_bin, packed, json_path):
    problems = []
    infos = []
    try:
        data = json.loads(json_path.read_text(encoding='utf-8'))
    except Exception as exc:
        return ['unparsable json: %s' % exc], infos, {}
    image_field = data.get('image')
    if image_field is None:
        return ['no "image" field (not a character file?)'], infos, {}
    keys = [k.strip() for k in str(image_field).split(',')]
    if len(keys) > 1:
        problems.append('image is a comma list %r -- Psych 0.6.3 never splits it: the whole string '
                        'is one atlas key, getSparrowAtlas() fails and the character has NO '
                        'graphics (parts that do exist on disk: %s)'
                        % (image_field, ', '.join(k for k in keys
                                                  if resolve_image(game_bin, packed, k)[1])))

    all_names = []
    for key in keys:
        png_ok, xml_ok, where, xml_path = resolve_image(game_bin, packed, key)
        if not png_ok or not xml_ok:
            problems.append('atlas %s -> png=%s xml=%s (%s)' % (key, png_ok, xml_ok, where))
            continue
        if xml_path is not None:
            all_names += atlas_prefixes(xml_path)
        else:
            infos.append('atlas %s is packed only (%s); its SubTexture names cannot be read, so '
                         'prefixes are not verified' % (key, where))

    stats = {}
    for anim in data.get('animations', []):
        name = anim.get('anim')
        prefix = anim.get('name')
        indices = anim.get('indices') or []
        fps = anim.get('fps')
        loop = anim.get('loop')
        if not all_names:
            continue
        frames = prefix_frames(all_names, prefix)
        if not frames:
            problems.append('anim %r -> prefix %r matches 0 SubTextures ("ERROR!" in the '
                            'offset tool, frozen idle in game)' % (name, prefix))
        elif indices:
            reachable = index_numbers(all_names, prefix)
            missing = [i for i in indices if i not in reachable]
            if missing and len(set(missing)) == len(set(indices)):
                problems.append('anim %r -> every index of %s matches no frame of %r (atlas has '
                                '%s) -> EMPTY animation' % (name, span(indices), prefix,
                                                             span(reachable)))
            elif missing:
                infos.append('anim %r -> %d of %d indices match nothing (%s); flixel drops those '
                             'frames silently' % (name, len(set(missing)), len(set(indices)),
                                                   span(missing)))
        if fps is None or (isinstance(fps, (int, float)) and fps <= 0):
            problems.append('anim %r -> fps=%r, frame interval 1/%r means the animation can '
                            'never advance' % (name, fps, fps))
        # PlayState re-triggers idle/dance on every beat, so loop=false there is normal (it is what
        # the stock Psych files ship). Only an animation whose name says "loop" has to loop.
        if loop is False and 'loop' in str(name).lower():
            problems.append('anim %r -> loop=false on a *-loop animation, the fight choreography '
                            'stops after one pass' % name)
        stats[name] = (prefix, len(indices), len(frames))
    return problems, infos, stats


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('--bin', default=str(GAME_BIN))
    ap.add_argument('--only', default='', help='substring filter on the character json name')
    args = ap.parse_args(argv)
    game_bin = pathlib.Path(args.bin)
    packed = packed_paths(game_bin / 'manifest')
    print('packed asset paths in the exe: %d' % len(packed))

    dirs = [game_bin / 'assets' / 'characters', game_bin / 'mods' / 'characters']
    files = []
    for d in dirs:
        if d.is_dir():
            # *.pre-xmlmap-* / *.bak / *.pre-* files are my own snapshots, not live definitions
            files += [f for f in sorted(d.glob('*.json'))
                      if '.pre-' not in f.name and '.bak' not in f.name]
    if args.only:
        files = [f for f in files if args.only.lower() in f.name.lower()]

    bad = 0
    for f in files:
        problems, infos, stats = check_character(game_bin, packed, f)
        tag = 'FAIL' if problems else 'ok  '
        print('%s %s  (%d anims)' % (tag, f.relative_to(game_bin), len(stats)))
        for p in problems:
            print('      - %s' % p)
        for i in infos:
            print('      . %s' % i)
        if problems:
            bad += 1
    print('\n%d/%d character jsons have a problem' % (bad, len(files)))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
