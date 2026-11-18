"""Audit every runHaxeCode block in the Limul Engine Lua tree.

Why this exists: FunkinLua.runHaxeCode is hscript (FunkinLua.hx:898 -> HScript.execute), and two
hscript properties make whole blocks silently useless in this engine:

  * hscript cannot parse `import`, so a block that starts with one throws EUnexpected and never
    declares anything that follows it - the classic "characters are flat yellow" bug, because
    the dropShadow uniforms were pushed from inside such a block.
  * the interp only knows the classes HScript.new() registers plus whatever addHaxeLibrary()
    calls added, so `new FlxTrail(...)` or a bare `dad` reference resolves to null and aborts.
  * runHaxeFunction is not registered in this engine at all, so calls to it are nil calls that
    cut the rest of the Lua callback.

runHaxeCode also re-parses its source on every call (HScript.execute -> parser.parseString), so a
block inside onUpdate/onUpdatePost/onBeatHit costs a parse per frame - the thing to hunt when a
spam chart slows down.

Usage:  python tools/hscript_block_audit.py [--tree assets/preload]
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Names HScript.new() puts into interp.variables (source/FunkinLua.hx, class HScript).
REGISTERED = {
    "FlxG", "FlxSprite", "FlxCamera", "FlxTimer", "FlxTween", "FlxEase", "PlayState", "game",
    "Paths", "Conductor", "ClientPrefs", "Character", "Alphabet", "CustomSubstate",
    "FlxRuntimeShader", "ShaderFilter", "StringTools", "setVar", "getVar", "removeVar",
}

# Lua callbacks that run every frame (or every step of a spam chart).
HOT_FUNCTIONS = ("onUpdate", "onUpdatePost", "onBeatHit", "onStep", "onAnimationUpdate",
                 "onLoad", "postUpdate", "preUpdate")

LONG_BLOCK = re.compile(r"runHaxeCode\(\s*\[\[(?P<body>.*?)\]\]", re.S)
SHORT_BLOCK = re.compile(r"runHaxeCode\(\s*[\"'](?P<body>[^\"']*)[\"']\s*\)")
FUNC_DEF = re.compile(r"^function\s+(\w+)", re.M)


def add_haxe_libraries(text):
    """Every class a script opts into with addHaxeLibrary('Name', 'pkg')."""
    return set(re.findall(r"addHaxeLibrary\(\s*['\"](\w+)['\"]", text))


def enclosing_function(lines, index):
    for i in range(index, -1, -1):
        match = FUNC_DEF.match(lines[i])
        if match:
            return match.group(1)
    return "<top level>"


def identifiers(body, known):
    """Bare capitalized/known-name identifiers the hscript interp has never heard of."""
    found = []
    for token in set(re.findall(r"\b([A-Za-z_]\w*)\b", body)):
        if token in known or token in ("function", "var", "if", "else", "return", "true", "false",
                                       "null", "new", "for", "while", "switch", "case", "default",
                                       "break", "continue", "this", "String", "Int", "Float", "Bool",
                                       "Array", "Void", "Dynamic", "Map"):
            continue
        if re.match(r"^[A-Z]", token) and "." not in token:
            found.append(token)
    return sorted(found)


def audit_file(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    if "runHaxeCode" not in text:
        return []

    known = REGISTERED | add_haxe_libraries(text)
    lines = text.split("\n")
    problems = []

    for match in LONG_BLOCK.finditer(text) :
        line_no = text[:match.start()].count("\n") + 1
        body = match.group("body")
        where = enclosing_function(lines, line_no - 1)
        if re.search(r"^\s*import\s", body, re.M):
            problems.append((line_no, where, "import -> hscript parse fails, block is dead"))
        unknown = [name for name in identifiers(body, known) if name not in ("Std", "Type", "Math")]
        if unknown:
            problems.append((line_no, where, "unregistered hscript names: " + ", ".join(unknown)))
        if where in HOT_FUNCTIONS:
            problems.append((line_no, where, "per-frame runHaxeCode (re-parses every call)"))

    for match in SHORT_BLOCK.finditer(text):
        line_no = text[:match.start()].count("\n") + 1
        where = enclosing_function(lines, line_no - 1)
        if where in HOT_FUNCTIONS and "setShaderFrameInfo" not in match.group("body"):
            problems.append((line_no, where, "per-frame runHaxeCode (re-parses every call)"))

    for line_no, line in enumerate(lines, start=1):
        if re.search(r"\brunHaxeFunction\s*\(\s*['\"]", line):
            problems.append((line_no, enclosing_function(lines, line_no - 1),
                             "runHaxeFunction is not registered in this engine"))
    return problems


def main():
    tree = sys.argv[2] if len(sys.argv) > 1 and sys.argv[1] == "--tree" else "assets/preload"
    total = 0
    for dirpath, _, filenames in os.walk(os.path.join(ROOT, tree)):
        for name in sorted(filenames):
            if not name.endswith(".lua"):
                continue
            path = os.path.join(dirpath, name)
            problems = audit_file(path)
            if not problems:
                continue
            total += len(problems)
            print(os.path.relpath(path, ROOT))
            for line_no, where, message in problems:
                print("    %4d  %-20s %s" % (line_no, where, message))
    print("\nrunHaxeCode hazards found: %d" % total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
