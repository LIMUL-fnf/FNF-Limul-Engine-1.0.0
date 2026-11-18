#!/usr/bin/env python3
"""Merge the missing Darnell can animations into the LIVE atlas.

The live preload pack (assets/preload/images/characters/darnell.*) is a trimmed
V-Slice export: 81 subtextures, idle + 4 poses + laugh only. The full KA-DE pack
(example_mods/weekend1/images/characters/darnell.*) is the SAME art (pixel-identical,
verified frame by frame) plus Light Can / Kick Up / Knee Forward / Gets Pissed /
Flame Loops, but it sits in a mod folder that Psych never resolves at runtime
(weekend1 has runsGlobally:false and the songs load with currentModDirectory=''),
so playAnim('dad','lightCan') is a silent no-op in game.

Replacing the whole pair would also replace every hand-tuned per-anim offset and
change the frame counts (idle 14 -> 28 frames), so instead this script keeps the
live pack exactly as it renders today and appends only the three can groups.

Geometry: the KA-DE pack puts every group on one shared 643x665 canvas, so the
screen anchor of a frame is  position + offset - (frameX, frameY).  Matching the
idle anchor of the two packs gives one constant that converts a KA-DE offset into
our pack's origin convention; it is applied verbatim to the appended anims.
"""
import json
import re
import shutil
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

sys.stdout.reconfigure(errors='replace')

ROOT = Path(__file__).resolve().parent.parent
OUR_XML = ROOT / 'assets/preload/images/characters/darnell.xml'
OUR_PNG = ROOT / 'assets/preload/images/characters/darnell.png'
OUR_JSON = ROOT / 'assets/preload/characters/darnell.json'
SRC_XML = ROOT / 'example_mods/weekend1/images/characters/darnell.xml'
SRC_PNG = ROOT / 'example_mods/weekend1/images/characters/darnell.png'
SRC_JSON = ROOT / 'example_mods/weekend1/characters/darnell.json'

# the three groups the 2 Hot script asks for; 'Gets Pissed' and the flame loops
# stay out on purpose (40 + 32 extra frames for animations nothing plays today)
GROUPS = ['Light Can', 'Kick Up', 'Knee Forward']
GUTTER = 2
STAMP = time.strftime('%H%M%S')


def read_subtextures(path):
    txt = path.read_text(encoding='utf-8-sig')
    out = {}
    order = []
    for m in re.finditer(r'<SubTexture\b([^>*)]*)/?>', txt):
        attrs = dict(re.findall(r'(\w+)="([^"]+)"', m.group(1)))
        out[attrs['name']] = attrs
        order.append(attrs['name'])
    return out, order


def anchor(attrs, offset, position):
    """Where the drawn pixels land relative to the sprite origin."""
    fx = int(attrs.get('frameX', 0))
    fy = int(attrs.get('frameY', 0))
    return (position[0] + offset[0] - fx, position[1] + offset[1] - fy)


def json_anims(path):
    data = json.loads(path.read_text(encoding='utf-8-sig'))
    anims = data['animations']
    table = {}
    for entry in anims:
        table[entry['anim']] = entry
    return data, table


def main():
    ours, our_order = read_subtextures(OUR_XML)
    src, _ = read_subtextures(SRC_XML)

    our_png = Image.open(OUR_PNG).convert('RGBA')
    src_png = Image.open(SRC_PNG).convert('RGBA')
    our_json, our_anims = json_anims(OUR_JSON)
    src_json, src_anims = json_anims(SRC_JSON)

    our_pos = tuple(our_json['position'])
    src_pos = tuple(src_json['position'])

    # --- the anchor constant, derived from the idle anim both packs share -------
    our_idle = next(n for n in our_order if n.startswith('Darnell Idle'))
    src_idle = sorted(n for n in src if n.startswith('Idle'))[0]
    a_ours = anchor(ours[our_idle], our_anims['idle']['offsets'], our_pos)
    a_src = anchor(src[src_idle], src_anims['idle']['offsets'], src_pos)
    delta = (a_ours[0] - a_src[0], a_ours[1] - a_src[1])
    print(f'idle anchor: ours {a_ours}  kade {a_src}  correction {delta}')

    # --- collect the frames to append -------------------------------------------
    add = []
    for grp in GROUPS:
        names = sorted(n for n in src if n.startswith(grp))
        if not names:
            raise SystemExit(f'group {grp} missing from the source atlas')
        for n in names:
            a = src[n]
            x, y = int(a['x']), int(a['y'])
            w, h = int(a['width']), int(a['height'])
            add.append((n, src_png.crop((x, y, x + w, y + h)), a))
    print(f'appending {len(add)} frames from {GROUPS}')

    # --- pack them without moving a single existing frame -----------------------
    # The old sheet is 92% full, but everything right of its bounding box and
    # everything below it is empty, so those two free rectangles take the new
    # frames first and only the leftover spills into the band under the sheet.
    right = max(int(a['x']) + int(a['width']) for a in ours.values())
    bottom = max(int(a['y']) + int(a['height']) for a in ours.values())
    sheet_w = our_png.width

    class Shelf:
        def __init__(self, x0, x1, y):
            self.x0, self.x1, self.y, self.h, self.cur = x0, x1, y, 0, x0

        def fits(self, w, h):
            return self.cur + w <= self.x1 and self.y + max(self.h, h) <= self.limit

        def put(self, w, h):
            pos = (self.cur, self.y)
            self.cur += w + GUTTER
            self.h = max(self.h, h)
            return pos

        limit = 10 ** 9

    placed = {}
    column = Shelf(right + GUTTER, sheet_w, 0)
    column.limit = bottom
    band = None
    for name, img, a in add:
        w, h = img.size
        if column.fits(w, h):
            placed[name] = column.put(w, h)
            continue
        if band is None:
            band = Shelf(0, sheet_w, bottom + GUTTER)
        if not band.fits(w, h):
            band.y += band.h + GUTTER
            band.cur, band.h = 0, 0
        placed[name] = band.put(w, h)

    need_y = max(y + img.size[1] for name, img, a in add for (x, y) in [placed[name]])
    sheet_h = max(our_png.height, need_y + GUTTER)
    sheet_h = ((sheet_h + 63) // 64) * 64
    print(f'free column x>={right} y<{bottom}; new sheet {sheet_w}x{sheet_h} '
          f'(was {our_png.width}x{our_png.height})')
    assert sheet_h <= 8192, 'atlas would exceed the 8192px texture budget'

    out_png = Image.new('RGBA', (sheet_w, sheet_h), (0, 0, 0, 0))
    out_png.paste(our_png, (0, 0))
    for name, img, a in add:
        out_png.paste(img, placed[name])

    # --- rewrite the xml: old entries verbatim, new ones appended ---------------
    header = OUR_XML.read_text(encoding='utf-8-sig').split('<SubTexture')[0]
    lines = [header.rstrip()]
    for n in our_order:
        a = ours[n]
        lines.append('\t<SubTexture ' + ' '.join(f'{k}="{v}"' for k, v in a.items()) + '/>')
    for name, img, a in add:
        new = dict(a)
        new['x'] = str(placed[name][0])
        new['y'] = str(placed[name][1])
        order = ['name', 'x', 'y', 'width', 'height', 'frameX', 'frameY', 'frameWidth', 'frameHeight']
        lines.append('\t<SubTexture ' + ' '.join(f'{k}="{new[k]}"' for k in order if k in new) + '/>')
    # close the atlas tag that the header split kept open
    lines[0] = lines[0].replace('<TextureAtlas imagePath="darnell.png">',
                                '<TextureAtlas imagePath="darnell.png">')
    new_xml = '\n'.join(lines) + '\n</TextureAtlas>\n'

    # --- json: append the three anims, offsets converted to our origin ----------
    added = []
    for grp, anim_id in [('Light Can', 'lightCan'), ('Kick Up', 'kickCan'), ('Knee Forward', 'kneeCan')]:
        if anim_id in our_anims:
            print(f'{anim_id} already present, skipped')
            continue
        ref = src_anims[anim_id]
        ox, oy = ref['offsets']
        entry = {
            'loop': ref.get('loop', False),
            'offsets': [ox + delta[0], oy + delta[1]],
            'anim': anim_id,
            'fps': ref.get('fps', 24),
            'name': ref['name'],
            'indices': ref.get('indices', []),
        }
        our_json['animations'].append(entry)
        added.append((anim_id, ref['name'], entry['offsets']))
    for a, n, off in added:
        print(f'  + {a:9s} -> {n:16s} offsets {off}')

    # --- backups + write ---------------------------------------------------------
    for p in (OUR_PNG, OUR_XML, OUR_JSON):
        shutil.copy2(p, p.with_suffix(p.suffix + f'.pre-darnell-anims-{STAMP}'))
    out_png.save(OUR_PNG)
    OUR_XML.write_text(new_xml, encoding='utf-8')
    OUR_JSON.write_text(json.dumps(our_json, indent='\t') + '\n', encoding='utf-8')
    print(f'wrote {OUR_PNG.name} / .xml / darnell.json (backups .pre-darnell-anims-{STAMP})')


if __name__ == '__main__':
    main()
