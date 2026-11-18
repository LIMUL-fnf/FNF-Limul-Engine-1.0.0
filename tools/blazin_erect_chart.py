#!/usr/bin/env python3
"""
Blazin' Erect chart generator (task #122).

Base = blazin-nightmare.json. Every nightmare note is kept as an anchor so the vocal
phrasing, the call/answer pairs and the section grid (84 sections, ends 103578 ms) stay
identical; the Erect pass only inserts extra player notes on free 16th steps, which is
what makes it denser without breaking the song.

Choreography contract = assets/stages/phillyBlazin.lua (port of the 1.0.4 handlers
PicoBlazinHandler.hx / DarnellBlazinHandler.hx). Rules that actually matter, taken from
the 1.0.4 sources:

  * the note TYPE alone drives both fighters, the lane is decoration. `punchhighblocked`
    means "Pico punches high, Darnell blocks" - one note, both animations. So a defence
    note must never be paired with an attack note to look right.
  * an attack that lands on Pico is block*/dodge* (blockable) or hit* (forced damage);
    forced damage + darnelluppercut* + idle only go on the opponent side (lanes 4-7).
  * picouppercutprep must be HIT and be followed by picouppercut 1-2 steps later with
    nothing in between: a missed prep sets Pico's cantUppercut, which turns the *next*
    note into a block regardless of its type.
  * taunt only taunts while Pico's anim is still 'fakeout' (and Darnell's 'pissed' only
    while his anim is 'cringe'), so taunt needs a clean fakeout right before it.
  * animations: Pico's atlas runs at 24 fps -> punches/hits are 4 frames (0.167 s = 2
    steps), block/dodge/prep 5 (0.208 s), uppercutHit 9 (0.375 s). Two notes closer than
    that overwrite each other, so inserted notes respect a per-family cooldown.
  * sustainLength stays 0: Psych re-fires goodNoteHit on every sustain tick, which the
    stage Lua skips but the Haxe did not - no sustains, no double animation.

Density ceiling: at most MAX_NPS player notes inside any sliding 1 second window. The
engine caps note splashes at NoteSplash.MAX_PER_SECOND = 16/s, so a chart under 16 NPS
still splashes every single note.
"""

import hashlib
import json
import os
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(r"C:/Users/olafc/Downloads/FNF Limul Engine 1.0.0")
BIN = ROOT / "export/release/windows/bin/assets/data/blazin"
PRELOAD = ROOT / "assets/preload/data/blazin"
MOD = ROOT / "mods/Weekend 1/data/blazin"
BASE = BIN / "blazin-nightmare.json"
OUT_NAME = "blazin-erect.json"

BPM = 180
SECTION_MS = 60000.0 / BPM * 4          # 1333.333... ms, 4 beats
STEP_MS = SECTION_MS / 16               # 83.333... ms, one sixteenth
MAX_NPS = 16                            # hard ceiling, matches the splash cap
UPPERCUT_CHAIN_GAP = 2                  # prep -> strike, in steps (166.7 ms)
FAKEOUT_CHAIN_GAP = 4                   # fakeout -> taunt, in steps (333 ms)
SEED = 0xB1441                            # deterministic chart

# Families by note type, exactly the strings the stage Lua dispatches on.
PLAYER_FAMILIES = {
    "punch": ["punchhigh", "punchhighblocked", "punchhighdodged", "punchhighspin",
              "punchlow", "punchlowblocked", "punchlowdodged", "punchlowspin"],
    "block": ["blockhigh", "blocklow", "blockspin"],
    "dodge": ["dodgehigh", "dodgelow", "dodgespin"],
}
DAD_ONLY = {"hithigh", "hitlow", "hitspin", "darnelluppercutprep", "darnelluppercut", "idle"}
VALID = set(sum(PLAYER_FAMILIES.values(), [])) | DAD_ONLY | {
    "picouppercutprep", "picouppercut", "fakeout", "reversefakeout", "taunt", "tauntforce"}

# Cooldown per family in steps: how long until the same fighter can show another move.
COOLDOWN = {"punch": 2, "block": 2, "dodge": 2, "upper": 5, "fake": 8, "hit": 2, "dupper": 5, "idle": 8}
PRIORITY = {"picouppercut": 6, "picouppercutprep": 6, "taunt": 5, "fakeout": 5, "reversefakeout": 5}


def fam(t):
    if t.startswith("punch"):
        return "punch"
    if t.startswith("block"):
        return "block"
    if t.startswith("dodge"):
        return "dodge"
    if t in ("picouppercut", "picouppercutprep"):
        return "upper"
    if t in ("fakeout", "reversefakeout", "taunt", "tauntforce"):
        return "fake"
    if t.startswith("hit"):
        return "hit"
    if t.startswith("darnelluppercut"):
        return "dupper"
    return "idle"


def strip_type(t):
    return t[len("weekend-1-"):] if t and t.startswith("weekend-1-") else t


def main():
    import random
    rng = random.Random(SEED)

    song = json.loads(BASE.read_text(encoding="utf-8"))["song"]
    sections = song["notes"]

    # ---- 1. anchors: one pass per step, no sustains, no same-owner stacks -------------
    # player[sec] = {step: type}, dad[sec] = {step: type}
    player, dad = [dict() for _ in sections], [dict() for _ in sections]
    lanes = {}  # (section, step, side) -> lane, side is 'p' or 'd'
    dropped = Counter()
    for si, sec in enumerate(sections):
        # mustHitSection decides WHO owns lanes 0-3: true = the player sings (0.6.3 convention,
        # 80 of these 84 sections), false = the opponent does. Everything below works on an
        # abstract lane 0-3 per side and only converts to a physical lane when writing JSON.
        mhs = bool(sec["mustHitSection"])
        for nt in sec["sectionNotes"]:
            if len(nt) < 4 or not nt[3]:
                dropped["malformed"] += 1
                continue
            t = strip_type(nt[3])
            if t not in VALID:
                dropped["unknown:" + t] += 1
                continue
            step = int(round((nt[0] - si * SECTION_MS) / STEP_MS))
            if not (0 <= step < 16):
                dropped["off-grid"] += 1
                continue
            if nt[2]:
                dropped["sustain-flattened"] += 1
            side = "p" if (nt[1] < 4) == mhs else "d"
            if t in DAD_ONLY and side == "p":
                # nightmare has 12 forced-damage/uppercut-prep notes on the player strum. The official
                # charts never do: those types animate identically on hit and on miss, so on the player
                # side they only add chip damage (a press heals 0.02, a miss costs 0.10). Move them to
                # the opponent strum - same choreography, honest health.
                dropped["moved-to-opponent"] += 1
                side = "d"
            bucket = player[si] if side == "p" else dad[si]
            prev = bucket.get(step)
            if prev is not None:
                # two notes on the same step drive the same fighter twice - keep the
                # stronger animation (chains first, otherwise the first one wins).
                dropped["stack"] += 1
                if PRIORITY.get(t, 0) <= PRIORITY.get(prev, 0):
                    continue
            bucket[step] = t
            lanes[(si, step, side)] = nt[1] % 4

    # ---- 2. reserve the steps a chain needs ------------------------------------------
    reserved = [set() for _ in sections]
    for si in range(len(sections)):
        for step, t in list(player[si].items()):
            if t == "picouppercutprep":
                for k in range(step + 1, min(step + UPPERCUT_CHAIN_GAP + 1, 16)):
                    reserved[si].add(k)   # the strike lives here, nothing else gets in
            if t == "fakeout":
                for k in range(step + 1, min(step + FAKEOUT_CHAIN_GAP + 1, 16)):
                    reserved[si].add(k)   # keep Pico in 'fakeout' until the taunt

    # ---- 3. insert pass ---------------------------------------------------------------
    # Sections that nightmare left empty are the song's own rests (25-31, 78-83); filling
    # them would contradict the vocal, so a section with no anchor note stays untouched.
    filled = 0
    per_section = {}
    # sixteenth order: downbeats, then 8ths, then the 16ths - a fill that reads musically
    ORDER = [0, 8, 4, 12, 2, 6, 10, 14, 1, 3, 5, 7, 9, 11, 13, 15]
    last_family = None
    family_run = 0
    chains = 0
    fakes = 0

    def last_note_step(si, step):
        """the closest earlier player note (as (sec, step, type)) on the global grid."""
        for g in range(1, 20):
            gs = si * 16 + step - g
            if gs < 0:
                return None
            bs, bp = divmod(gs, 16)
            t = player[bs].get(bp)
            if t:
                return (bs, bp, t)
        return None

    for si in range(len(sections)):
        anchors = len(player[si]) + len(dad[si])
        if anchors == 0:
            per_section[si] = 0
            continue
        if anchors >= 8:
            budget = 3
        elif anchors >= 5:
            budget = 4
        elif anchors >= 3:
            budget = 5
        else:
            budget = 4

        added = 0
        for step in ORDER:
            if added >= budget:
                break
            if step in player[si] or step in reserved[si]:
                continue

            prev = last_note_step(si, step)
            if prev is not None:
                gap = (si * 16 + step) - (prev[0] * 16 + prev[1])
                if gap < COOLDOWN[fam(prev[2])]:
                    continue

            # what is coming at Pico right now? nearest dad note within 3 steps
            ctx = None
            for g in range(0, 4):
                d = dad[si].get(step - g) if step - g >= 0 else None
                if d:
                    ctx = d
                    break

            choice = None
            if ctx == "darnelluppercut":
                # Darnell just uppercut: only a defence reads correctly
                choice = rng.choice(["dodgehigh", "dodgelow", "blockhigh", "blocklow"])
            elif ctx in ("hithigh", "hitlow"):
                h = "high" if ctx == "hithigh" else "low"
                choice = rng.choice(["block" + h, "dodge" + h])
            else:
                fams = list(PLAYER_FAMILIES) + ["punch", "punch"]  # punches weightier
                pick = rng.choice(fams)
                if pick == last_family:
                    family_run += 1
                    if family_run >= 3:
                        pick = rng.choice([f for f in PLAYER_FAMILIES if f != pick])
                else:
                    family_run = 0
                if pick == "punch":
                    h = rng.choice(["high", "low"])
                    suffix = rng.choices(["", "blocked", "dodged", "spin"], weights=[46, 24, 24, 6])[0]
                    choice = "punch" + h + suffix
                else:
                    h = rng.choices(["high", "low", "spin"], weights=[42, 42, 16])[0]
                    choice = pick + h

            # one uppercut chain and one fakeout/taunt per handful of sections
            want_chain = (chains < 1 + si // 12) and (step <= 16 - UPPERCUT_CHAIN_GAP - 1)
            want_fake = (fakes < 1 + si // 16) and (step <= 16 - FAKEOUT_CHAIN_GAP - 1)
            if want_chain and step % 4 == 0 and si % 3 == 1:
                nxt = step + UPPERCUT_CHAIN_GAP
                if all(k not in player[si] and k not in reserved[si] for k in range(step, nxt + 1)):
                    player[si][step] = "picouppercutprep"
                    player[si][nxt] = "picouppercut"
                    lanes.setdefault((si, step, "p"), step % 4)
                    lanes.setdefault((si, nxt, "p"), (step + 1) % 4)
                    reserved[si].update(range(step + 1, nxt))
                    added += 2
                    chains += 1
                    last_family, family_run = "upper", 0
                    continue
            if want_fake and step % 8 == 4 and si % 4 == 2:
                nxt = step + FAKEOUT_CHAIN_GAP
                if all(k not in player[si] and k not in reserved[si] for k in range(step, nxt + 1)) \
                        and "taunt" not in player[si].values():
                    player[si][step] = "fakeout"
                    player[si][nxt] = "taunt"
                    lanes.setdefault((si, step, "p"), step % 4)
                    lanes.setdefault((si, nxt, "p"), (step + 2) % 4)
                    reserved[si].update(range(step + 1, nxt))
                    added += 2
                    fakes += 1
                    last_family, family_run = "fake", 0
                    continue

            if choice in ("blockspin", "dodgespin") and rng.random() < 0.7:
                choice = "blockhigh" if choice == "blockspin" else "dodgehigh"
            player[si][step] = choice
            prev_lane = lanes.get((si, step - 1, "p"))
            if prev_lane is None:
                near = last_note_step(si, step)
                prev_lane = lanes.get((near[0], near[1], "p"), 1) if near else 1
            step_dir = 1 if rng.random() < 0.5 else -1
            lane = (prev_lane + rng.choice([1, 2, 3]) * step_dir) % 4
            lanes[(si, step, "p")] = lane
            added += 1
            filled += 1
            last_family = fam(choice)

        per_section[si] = added

    # ---- 4. rebuild the JSON ----------------------------------------------------------
    out_notes = []
    emitted = []          # (section, side, step, physical lane, type) for validation
    total = 0
    for si, sec in enumerate(sections):
        mhs = bool(sec["mustHitSection"])
        rows = []
        local = []
        for step in sorted(set(list(player[si].keys()) + list(dad[si].keys()))):
            for side in ("p", "d"):
                t = (player[si] if side == "p" else dad[si]).get(step)
                if not t:
                    continue
                abstract = lanes.get((si, step, side), step % 4)
                if side == "p":
                    phys = abstract if mhs else abstract + 4
                else:
                    phys = abstract + 4 if mhs else abstract
                rows.append([round(si * SECTION_MS + step * STEP_MS, 12), phys, 0, "weekend-1-" + t])
                local.append((si, side, step, phys, t))
        row = dict(sec)
        row["sectionNotes"] = rows
        out_notes.append(row)
        emitted.extend(local)
        total += len(rows)

    song["speed"] = 3.7
    song["chartedBy"] = "Limul Engine"
    song["generatedBy"] = ("blazin_erect_chart.py - anchors: nightmare chart, inserts: phillyBlazin.lua "
                           "choreography (Pico/DarnellBlazinHandler)")
    doc = {"song": song}
    doc["song"]["notes"] = out_notes

    # ---- 5. validation ----------------------------------------------------------------
    errors = []
    psteps = []
    types = Counter()
    seen = set()
    for (si, side, step, phys, t) in emitted:
        types[t] += 1
        if t not in VALID:
            errors.append("bad type %r @%d" % (t, si))
        if not (0 <= step < 16):
            errors.append("off grid @%d step %s" % (si, step))
        if not (0 <= phys <= 7):
            errors.append("lane out of range @%d" % si)
        if (side, si, step) in seen:
            errors.append("stack @%d step %d %s" % (si, step, side))
        seen.add((side, si, step))
        if side == "p":
            psteps.append(si * 16 + step)
            if t in DAD_ONLY:
                errors.append("dad-only type %r on the player side @%d" % (t, si))

    for si, row in enumerate(out_notes):
        if len(row["sectionNotes"]) > 2 * MAX_NPS:
            errors.append("section %d over %d notes" % (si, 2 * MAX_NPS))
        for nt in row["sectionNotes"]:
            if nt[2] != 0 or len(nt) != 4:
                errors.append("sustain/malformed row @%d: %r" % (si, nt))

    # sliding 1 s window over player notes
    psteps.sort()
    peak = 0
    j = 0
    for i in range(len(psteps)):
        while psteps[i] - psteps[j] > 12:  # 12 steps ~ 1000 ms at 180 bpm
            j += 1
        peak = max(peak, i - j + 1)

    if peak > MAX_NPS:
        errors.append("peak player NPS %d > %d" % (peak, MAX_NPS))

    # Chain readability: an uppercut prep needs its strike soon after, and a taunt needs a
    # recent fakeout before it. Fakeout notes do not themselves require a following taunt.
    def next_player(si, step):
        """the very next player note on the global 16th grid - anything else in between
        would already have overwritten the fighter's animation."""
        gs = si * 16 + step
        best = (99, None)
        for (s2, side2, st2, _p, t2) in emitted:
            gap = (s2 * 16 + st2) - gs
            if side2 == "p" and 0 < gap < best[0]:
                best = (gap, t2)
        return best

    def previous_player(si, step):
        """the closest earlier player note on the global 16th grid."""
        gs = si * 16 + step
        best = (99, None)
        for (s2, side2, st2, _p, t2) in emitted:
            gap = gs - (s2 * 16 + st2)
            if side2 == "p" and 0 < gap < best[0]:
                best = (gap, t2)
        return best

    broken = []
    for (si, side, step, phys, t) in emitted:
        if side != "p":
            continue
        # the stage Lua keeps the last animation name it played, so what matters is that nothing
        # else drives the fighter in between - the distance itself is only a visual budget.
        if t == "picouppercutprep":
            gap, nxt = next_player(si, step)
            if nxt not in ("picouppercut", "picouppercutprep"):
                broken.append("prep @%d/%d -> %s +%d" % (si, step, nxt, gap))
        if t in ("taunt", "tauntforce"):
            gap, prev = previous_player(si, step)
            if prev not in ("fakeout", "reversefakeout") or gap > COOLDOWN["fake"]:
                broken.append("taunt @%d/%d <- %s -%d" % (si, step, prev, gap))
    print("broken chains   :", len(broken), broken[:6])

    print("sections        :", len(out_notes))
    print("total notes     :", total, "(nightmare 494)")
    print("player notes    :", len(psteps), "  dad notes:", total - len(psteps))
    print("added           :", filled, " chains:", chains, " fakeouts:", fakes)
    print("peak NPS        :", peak, "(cap %d)" % MAX_NPS)
    print("avg NPS         :", round(len(psteps) / (103.578), 2))
    print("dropped anchors :", dict(dropped))
    print("types           :", dict(types.most_common()))

    if errors:
        print("\nVALIDATION FAILED (%d):" % len(errors))
        for e in errors[:20]:
            print("  ", e)
        return 1

    blob = json.dumps(doc, separators=(",", ":"))
    targets = (BIN / OUT_NAME, PRELOAD / OUT_NAME, MOD / OUT_NAME)
    for target in targets:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(blob, encoding="utf-8")
        print("wrote", target, len(blob), "bytes")

    digests = [hashlib.md5(target.read_bytes()).hexdigest() for target in targets]
    print("md5", digests, "IDENTICAL" if len(set(digests)) == 1 else "MISMATCH")
    return 0 if len(set(digests)) == 1 else 1


if __name__ == "__main__":
    sys.exit(main())
