#!/usr/bin/env python3
"""Static patcher for the 2hot can/gun choreography (no game launch).

Three fixes, mirrored over every asset tree so a rebuild cannot undo them:

1. HURT_ANIM 'CanHit' -> 'shootMISS' in the five weekend-1-* custom note types.
   assets/characters/pico-playable.json maps shootMISS to the 'Pico Hit Can0' frames.
   'CanHit' is the KA-DE/V-Slice name and does not exist in this definition, so
   tryAnim('boyfriend', HURT_ANIM) silently failed and Pico never flinched when a can
   landed on him. Same fix for the two playAnim('boyfriend', 'CanHit') calls in
   data/2hot/script.lua.

2. data/2hot/script.lua no longer duplicates the note-type shims. It gates every note
   whose type is one of the five weekend-1-* types through isShimmed(noteType) and, for
   those, keeps ONLY what no shim can drive: the Spraycan1/Spraycan2 stage pile, the
   reloadEffect silhouette, the shootBlack muzzle flash and the spraypaintExplosionEZ
   cloud. The shims own the fighter animations, the sounds, the projectiles and the
   health. Before this, one note fired two animations, two sounds, two projectiles and
   took 0.5 + 0.35 health, and the PicoBullet<n> sprites were created at x=2150 and
   never moved again because onStepHit only tweens the newest one.

3. assets/characters/darnell.json: the four singX-hold animations are renamed
   singX-loop. Character.hx:308 only ever looks up "<curAnim>-loop"; "-hold" is the
   Psych 1.0.4 spelling and is dead code here, which is why Darnell snapped back to idle
   in the middle of every sustain while all 14 other characters loop.

Also refreshes the stale example_mods/weekend1 copies of the Darnell definition and
atlas so the mirror trees agree with the live ones.
"""

import hashlib
import os
import shutil
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAMP = time.strftime('%y%m%d-%H%M%S')
BACKUP = os.path.join(ROOT, '_backup_canhurt_' + STAMP)

NOTETYPE_TREES = [
    'assets/preload/custom_notetypes',
    'example_mods/custom_notetypes',
    'export/release/windows/bin/assets/custom_notetypes',
    'export/release/windows/bin/mods/custom_notetypes',
]
NOTETYPES = [
    'weekend-1-lightcan.lua',
    'weekend-1-kickcan.lua',
    'weekend-1-kneecan.lua',
    'weekend-1-cockgun.lua',
    'weekend-1-firegun.lua',
]
SCRIPT_TREES = [
    'assets/preload/data/2hot/script.lua',
    'example_mods/weekend1/data/2hot/script.lua',
    'export/release/windows/bin/assets/data/2hot/script.lua',
]
# Live Darnell definition; the other two are mirrors overwritten from it.
CHAR_LIVE = 'export/release/windows/bin/assets/characters/darnell.json'
CHAR_MIRRORS = [
    'assets/preload/characters/darnell.json',
    'example_mods/weekend1/characters/darnell.json',
]
# Stale copies of the Nov-2 atlas rebuild (bin + preload + mods override already match).
ATLAS_SRC = 'export/release/windows/bin/assets/images/characters/darnell.'
ATLAS_DST = ['example_mods/weekend1/images/characters/darnell.']

report = []


def path(*parts):
    return os.path.join(ROOT, *parts)


def backup(rel):
    src = path(rel)
    if not os.path.isfile(src):
        return
    dst = os.path.join(BACKUP, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)


def read(rel):
    with open(path(rel), encoding='utf-8') as handle:
        return handle.read()


def write(rel, text):
    backup(rel)
    with open(path(rel), 'w', encoding='utf-8', newline='') as handle:
        handle.write(text)
    report.append(rel)


def replace(rel, old, new, label):
    """Patch one file, requiring every anchor to match exactly once."""
    text = read(rel)
    for needle in (old if isinstance(old, list) else [old]):
        count = text.count(needle)
        if count != 1:
            raise SystemExit('ABORT %s: anchor used %d times, expected 1\n%s' % (rel, count, needle[:120]))
    if isinstance(old, list):
        for needle, piece in zip(old, new):
            text = text.replace(needle, piece, 1)
    else:
        text = text.replace(old, new, 1)
    write(rel, text)
    print('  ok  %-62s %s' % (rel, label))


# ------------------------------------------------------------------ 1. HURT_ANIM
OLD_HURT = "local HURT_ANIM   = 'CanHit'      -- pico-playable has it; anything else just keeps its anim"
NEW_HURT = ("local HURT_ANIM   = 'shootMISS'   -- assets/characters/pico-playable.json maps shootMISS to the\n"
            "                                   -- 'Pico Hit Can0' frames. 'CanHit' is the V-Slice/KA-DE spelling\n"
            "                                   -- and is not an anim of this character, so the flinch was a no-op.")

OLD_DOC = ("-- WHY IT DOES NOT DOUBLE UP IN 2HOT. assets/data/2hot/script.lua used to run the same bit off\n"
           "-- lane numbers and step windows. That logic is switched off there (CAN_LOGIC_IN_SHIMS) so this\n"
           "-- script is the only thing that throws cans, fires bullets and takes health.")
NEW_DOC = ("-- WHY IT DOES NOT DOUBLE UP IN 2HOT. assets/data/2hot/script.lua used to run the same bit off\n"
           "-- lane numbers and step windows. It now routes those notes through its isShimmed(noteType) gate,\n"
           "-- which keeps only what a shim cannot reach (Spraycan1/Spraycan2, reloadEffect, shootBlack,\n"
           "-- spraypaintExplosionEZ) and gives this script the fighters, the sounds, the projectiles and the\n"
           "-- health. Any other chart that uses these types has no script at all, so this is the only place\n"
           "-- the behaviour lives.")

print('[1] HURT_ANIM + header doc in the five custom note types')
for tree in NOTETYPE_TREES:
    for name in NOTETYPES:
        rel = tree + '/' + name
        if not os.path.isfile(path(rel)):
            print('  --  %s (missing)' % rel)
            continue
        replace(rel, [OLD_HURT, OLD_DOC], [NEW_HURT, NEW_DOC], 'shootMISS')

# ------------------------------------------------------------------ 2. script.lua gate
HELPER_ANCHOR = ('local isGameOver = false\n'
                 'local darnellAnim = false\n'
                 'local picoAnim = false\n'
                 'local bullet = 0\n'
                 'local reload = false\n')
HELPER_NEW = HELPER_ANCHOR + """
-- Limul Engine: the five weekend-1-* custom note types in assets/custom_notetypes/ fire on the
-- very same notes this script used to drive from a lane number inside a step window. Both running
-- meant two animations, two sounds, two projectiles and 0.5 + 0.35 health for one note, plus a
-- PicoBullet<n> sprite per cockgun left at x=2150 forever (onStepHit only tweens the newest id).
-- For those types this script keeps ONLY what the shims cannot reach: the Spraycan1/Spraycan2 pile
-- that stages/phillyStreets.lua creates, the reloadEffect silhouette, the shootBlack muzzle flash
-- and the spraypaintExplosionEZ cloud. Everything else belongs to the note type.
local SHIMMED = {
	['weekend-1-lightcan'] = true, ['weekend-1-kickcan'] = true, ['weekend-1-kneecan'] = true,
	['weekend-1-cockgun'] = true, ['weekend-1-firegun'] = true
}

local function isShimmed(noteType)
	return type(noteType) == 'string' and SHIMMED[noteType] == true
end
"""

OLD_OPP = """function opponentNoteHit(id, direction, noteType, isSustainNote)
	if direction == 1 and darnellAnim then
		playAnim('dad', 'lightCan', false);
		setProperty('dad.specialAnim', true);
	end
	if direction == 2 and darnellAnim then
		playAnim('dad', 'kickCan', false);
		setProperty('dad.specialAnim', true);
		playAnim('Spraycan1', 'start', false);
		setProperty('Spraycan1.alpha', 1);
	end
	if direction == 3 and darnellAnim then
		playAnim('dad', 'kneeCan', false);
		playAnim('Spraycan1', 'start1', false);
		setProperty('dad.specialAnim', true);
	end
end"""

NEW_OPP = """function opponentNoteHit(id, direction, noteType, isSustainNote)
	if not darnellAnim then return end
	local shimmed = isShimmed(noteType)
	if direction == 1 and not shimmed then
		playAnim('dad', 'lightCan', false);
		setProperty('dad.specialAnim', true);
	end
	if direction == 2 then
		if not shimmed then
			playAnim('dad', 'kickCan', false);
			setProperty('dad.specialAnim', true);
		end
		playAnim('Spraycan1', 'start', false);
		setProperty('Spraycan1.alpha', 1);
	end
	if direction == 3 then
		if not shimmed then
			playAnim('dad', 'kneeCan', false);
			setProperty('dad.specialAnim', true);
		end
		playAnim('Spraycan1', 'start1', false);
	end
end"""

OLD_GOOD = """function goodNoteHit(id, direction, noteType, isSustainNote)
	if direction == 1 and picoAnim then
		reload = true
		bullet = bullet +1
		playAnim('boyfriend', 'cock', false);
		playAnim('reloadEffect', 'cock', false);
		setProperty('boyfriend.specialAnim', true);
		setProperty('reloadEffectScale.x', 1)
		doTweenX('reloadEffectScale', 'reloadEffectScale', 1.1, 0.3, 'linear')
		setProperty('reloadEffect.alpha', 0.5);
		doTweenAlpha('reloadEffect', 'reloadEffect', 0, 0.3, 'linear')
		playSound('Gun_Prep', 1);
		makeAnimatedLuaSprite('PicoBullet'..bullet, 'PicoBullet', 2150, 850);
		addAnimationByPrefix('PicoBullet'..bullet, 'Bullet', 'Bullet', 24, false);
		addAnimationByPrefix('PicoBullet'..bullet, 'Pop', 'Pop', 24, false);
		playAnim('PicoBullet'..bullet, 'Pop', false);
		scaleObject('PicoBullet'..bullet, 1, 1);
		setScrollFactor('PicoBullet'..bullet, 1, 1);
		addLuaSprite('PicoBullet'..bullet, false);
	end
	if direction == 0 and picoAnim and reload then
		reload = false
		playAnim('boyfriend', 'shoot', false);
		setProperty('boyfriend.specialAnim', true);
		playAnim('Spraycan1', 'shooted', false);
		playAnim('Spraycan2', 'i', false);
		setProperty('Spraycan1.alpha', 0);
		playSound('shot'..getRandomInt(1,3), 1);
		setProperty('shootBlack.alpha', 1);
		doTweenAlpha('shootBlack', 'shootBlack', 0, 1, 'linear')
	elseif direction == 0 and picoAnim and not reload then
		health = getProperty('health')
		playAnim('boyfriend', 'CanHit', false);
		setProperty('boyfriend.specialAnim', true);
		playAnim('Spraycan1', 'missed', false);
		setProperty('Spraycan1.alpha', 0);
		playAnim('spraypaintExplosionEZ', 'explosion', false);
		setProperty('health', health -0.5);
		playSound('Pico_Bonk', 1);
	end
end"""

NEW_GOOD = """function goodNoteHit(id, direction, noteType, isSustainNote)
	if not picoAnim then return end
	local shimmed = isShimmed(noteType)
	if direction == 1 then
		reload = true
		-- reloadEffect: the 'Pico Reload' frames drawn as a separate sprite, which the
		-- cockpit gun note type has no idea exists. reload itself stays outside the gate so a
		-- cockgun note still arms the firegun branch below.
		playAnim('reloadEffect', 'cock', false);
		setProperty('reloadEffectScale.x', 1)
		doTweenX('reloadEffectScale', 'reloadEffectScale', 1.1, 0.3, 'linear')
		setProperty('reloadEffect.alpha', 0.5);
		doTweenAlpha('reloadEffect', 'reloadEffect', 0, 0.3, 'linear')
		if not shimmed then
			bullet = bullet +1
			playAnim('boyfriend', 'cock', false);
			setProperty('boyfriend.specialAnim', true);
			playSound('Gun_Prep', 1);
			makeAnimatedLuaSprite('PicoBullet'..bullet, 'PicoBullet', 2150, 850);
			addAnimationByPrefix('PicoBullet'..bullet, 'Bullet', 'Bullet', 24, false);
			addAnimationByPrefix('PicoBullet'..bullet, 'Pop', 'Pop', 24, false);
			playAnim('PicoBullet'..bullet, 'Pop', false);
			scaleObject('PicoBullet'..bullet, 1, 1);
			setScrollFactor('PicoBullet'..bullet, 1, 1);
			addLuaSprite('PicoBullet'..bullet, false);
		end
	end
	if direction == 0 and reload then
		reload = false
		if not shimmed then
			playAnim('boyfriend', 'shoot', false);
			setProperty('boyfriend.specialAnim', true);
			playSound('shot'..getRandomInt(1,3), 1);
		end
		playAnim('Spraycan1', 'shooted', false);
		playAnim('Spraycan2', 'i', false);
		setProperty('Spraycan1.alpha', 0);
		setProperty('shootBlack.alpha', 1);
		doTweenAlpha('shootBlack', 'shootBlack', 0, 1, 'linear')
	elseif direction == 0 and not reload then
		if not shimmed then
			health = getProperty('health')
			playAnim('boyfriend', 'shootMISS', false);
			setProperty('boyfriend.specialAnim', true);
			setProperty('health', health -0.5);
			playSound('Pico_Bonk', 1);
		end
		playAnim('Spraycan1', 'missed', false);
		setProperty('Spraycan1.alpha', 0);
		playAnim('spraypaintExplosionEZ', 'explosion', false);
	end
end"""

OLD_MISS = """function noteMiss(id, direction, noteType, isSustainNote)
	if direction == 0 and picoAnim then
		reload = false
		health = getProperty('health')
		playAnim('boyfriend', 'CanHit', false);
		setProperty('boyfriend.specialAnim', true);
		playAnim('Spraycan1', 'missed', false);
		setProperty('Spraycan1.alpha', 0);
		playAnim('spraypaintExplosionEZ', 'explosion', false);
		setProperty('health', health -0.5);
		playSound('Pico_Bonk', 1);
	end
end"""

NEW_MISS = """function noteMiss(id, direction, noteType, isSustainNote)
	if direction == 0 and picoAnim then
		reload = false
		if not isShimmed(noteType) then
			health = getProperty('health')
			playAnim('boyfriend', 'shootMISS', false);
			setProperty('boyfriend.specialAnim', true);
			setProperty('health', health -0.5);
			playSound('Pico_Bonk', 1);
		end
		playAnim('Spraycan1', 'missed', false);
		setProperty('Spraycan1.alpha', 0);
		playAnim('spraypaintExplosionEZ', 'explosion', false);
	end
end"""

print('[2] isShimmed() gate in data/2hot/script.lua')
for rel in SCRIPT_TREES:
    if not os.path.isfile(path(rel)):
        print('  --  %s (missing)' % rel)
        continue
    replace(rel, [HELPER_ANCHOR, OLD_OPP, OLD_GOOD, OLD_MISS],
            [HELPER_NEW, NEW_OPP, NEW_GOOD, NEW_MISS], 'gated')

# ------------------------------------------------------------------ 3. darnell.json
print('[3] singX-hold -> singX-loop in the live Darnell definition')
OLD_KEYS = ["\"anim\": \"singLEFT-hold\"", "\"anim\": \"singDOWN-hold\"",
            "\"anim\": \"singUP-hold\"", "\"anim\": \"singRIGHT-hold\""]
NEW_KEYS = ["\"anim\": \"singLEFT-loop\"", "\"anim\": \"singDOWN-loop\"",
            "\"anim\": \"singUP-loop\"", "\"anim\": \"singRIGHT-loop\""]

live = read(CHAR_LIVE)
hits = sum(live.count(k) for k in OLD_KEYS)
if hits == 4:
    replace(CHAR_LIVE, OLD_KEYS, NEW_KEYS, 'loop names')
elif hits == 0:
    print('  ..  %s already uses -loop' % CHAR_LIVE)
else:
    raise SystemExit('ABORT: unexpected -hold spelling in %s (%d hits)' % (CHAR_LIVE, hits))

for rel in CHAR_MIRRORS:
    if not os.path.isfile(path(rel)):
        print('  --  %s (missing)' % rel)
        continue
    backup(rel)
    shutil.copy2(path(CHAR_LIVE), path(rel))
    write_ok = hashlib.md5(open(path(rel), 'rb').read()).hexdigest()
    src_ok = hashlib.md5(open(path(CHAR_LIVE), 'rb').read()).hexdigest()
    print('  ok  %-62s mirrored (%s)' % (rel, 'md5 ' + write_ok[:8] if write_ok == src_ok else 'MD5 MISMATCH'))
    if write_ok != src_ok:
        raise SystemExit('ABORT: mirror differs from live definition')

print('[4] stale Darnell atlas in example_mods/weekend1')
for ext in ('png', 'xml'):
    src = path(ATLAS_SRC + ext)
    for dst_base in ATLAS_DST:
        rel = dst_base + ext
        if not os.path.isdir(path(os.path.dirname(rel))):
            print('  --  %s (dir missing)' % rel)
            continue
        backup(rel)
        shutil.copy2(src, path(rel))
        same = (hashlib.md5(open(src, 'rb').read()).hexdigest() ==
                hashlib.md5(open(path(rel), 'rb').read()).hexdigest())
        print('  ok  %-62s %s' % (rel, 'atlas refreshed' if same else 'MD5 MISMATCH'))
        if not same:
            raise SystemExit('ABORT: atlas copy failed')

print()
print('backups : %s' % os.path.relpath(BACKUP, ROOT))
print('patched : %d files' % len(report))
