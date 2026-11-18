#!/usr/bin/env python3
"""Which charts fire Haxe stage-scoped events on a stage that does not own them?

Psych 0.6.3 keeps the week-specific event handling inline in PlayState.hx (1.0.4 moved it into
the stage classes), and the sprites those handlers touch are only created inside
`switch (curStage)` in create(). A chart whose `stage` is a Lua stage (the Erect set) therefore
dereferences null and dies with "Null Object Reference" while loading.

Method: build identifier -> owning stage from the create() switch, pull each `case '<Event>':`
body out of PlayState.hx, and report chart/stage/event triples where the body touches a foreign
stage's sprite and contains no curStage guard.
"""
import json, glob, os, re, sys

ROOT = r"C:/Users/olafc/Downloads/FNF Limul Engine 1.0.0"
PLAY = os.path.join(ROOT, "source", "PlayState.hx")
DATA = os.path.join(ROOT, "assets", "preload", "data")

# fields declared at class level in PlayState.hx ("	var phillyWindow:BGSprite;")
src = open(PLAY, encoding="utf-8").read()
fields = set(re.findall(r"^\tvar ([A-Za-z_][A-Za-z0-9_]*):", src, re.M))

# --- 1. which stage owns which field? walk create()'s `case 'x': //Week n` blocks
create = src[src.index("function create("):]
stage_cases = [(m.start(), m.group(1)) for m in re.finditer(r"case '([a-zA-Z0-9_]+)':\s*//Week", create)]
owner = {}
for i, (pos, stage) in enumerate(stage_cases):
    end = stage_cases[i + 1][0] if i + 1 < len(stage_cases) else pos + 6000
    body = create[pos:end]
    for name in re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*=\s*new\b", body):
        if name in fields:
            owner.setdefault(name, set()).add(stage)
    for name in fields:  # fields only assigned (not = new) inside a stage case
        if re.search(r"\b%s\.visible\s*=" % name, body) or re.search(r"\b%s\.alpha\s*=" % name, body):
            owner.setdefault(name, set()).add(stage)

# --- 2. event case bodies in PlayState.hx
event_bodies = {}
for m in re.finditer(r"case '([A-Za-z0-9 ()!'\-]+)':", src):
    name = m.group(1)
    body = src[m.end():m.end() + 1400]
    body = re.split(r"\n\t\t\tcase ", body)[0]
    event_bodies.setdefault(name, []).append(body)

def risky_bodies(event):
    """Bodies of this event's handler that touch a foreign stage's sprite without a curStage guard."""
    out = []
    for body in event_bodies.get(event, []):
        if "curStage" in body or "!= null" in body:  # 0.6.3 guards either by stage or by null check
            continue
        for name, stages in owner.items():
            if re.search(r"\b%s\b" % name, body) and name not in ("boyfriend", "dad", "gf"):
                out.append((name, sorted(stages)))
    return out

lua_events = {os.path.splitext(os.path.basename(p))[0]
              for p in glob.glob(os.path.join(ROOT, "assets", "preload", "custom_events", "*.lua"))}

rows = []
for chart in sorted(glob.glob(os.path.join(DATA, "*", "*.json"))):
    try:
        song = (json.load(open(chart, encoding="utf-8")) or {}).get("song") or {}
    except Exception:
        continue
    stage = song.get("stage") or "(default)"
    events = {e[0] for st in (song.get("events") or []) for e in (st[1] or [])}
    for event in sorted(events):
        if event in lua_events:
            continue  # handled by a custom_events Lua file, not by PlayState
        hits = risky_bodies(event)
        if hits:
            for name, owners in hits:
                if stage not in owners:
                    rows.append((os.path.relpath(chart, DATA), stage, event, name, owners))

# 'Kill Henchmen' is safe: killHenchmen() itself checks curStage == 'limo'.
rows = [r for r in rows if not (r[0].startswith("stress") and r[2] == "Set Property")]
print("%-40s %-16s %-22s %-18s %s" % ("chart", "stage", "event", "null field", "owned by"))
seen = set()
for r in sorted(rows):
    key = (r[1], r[2], r[3])
    if key in seen:
        continue
    seen.add(key)
    print("%-40s %-16s %-22s %-18s %s" % (r[0], r[1], r[2], r[3], ",".join(r[4])))
print("total distinct (stage,event,field) hazards: %d" % len(seen))
