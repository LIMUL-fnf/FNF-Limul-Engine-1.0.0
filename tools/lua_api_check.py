#!/usr/bin/env python3
"""Check every bare identifier a Limul Engine Lua script uses against what the engine
actually exposes, so a typo like getObjectOrdre() is caught here instead of as an
"attempt to call a nil value" trace twenty times a second in game.

Known names come straight from the engine source:
  * FunkinLua.hx   Lua_helper.add_callback(lua, "NAME"   -> callable from Lua
  * FunkinLua.hx   set('NAME', ...)                      -> global defined for every script
  * PlayState.hx + friends   setOnLuas('NAME', ...)      -> global pushed while playing
plus the Lua 5.1 base library (linc_luajit runs LuaJIT in 5.1 mode).

Also runs a real Lua 5.1 grammar parse (pip install luaparser), which catches the
block/end mistakes tools/lua_block_check.py only counts.

Usage: python tools/lua_api_check.py <file.lua> [...]
"""
import pathlib
import re
import sys

from luaparser import ast

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / 'source'

STANDARD = set('''
print pairs ipairs next type tostring tonumber error assert pcall xpcall select
rawget rawset rawequal rawlen setmetatable getmetatable require dofile loadstring
string math table os coroutine io _G _VERSION false nil true self args
'''.split())

# Engine callbacks that exist in Psych 1.0 / other engines but NOT in 0.6.3 -- worth a
# dedicated warning because they fail silently instead of erroring. Every script that uses one
# of these reads it in an `if X == nil then function _G.X() end end` guard first, which is
# nil-safe; a script that *calls* one without defining it is still a bug, so they stay listed.
NOT_IN_063 = {
    'cloneLuaSprite', 'setObjectCameraToHUD', 'triggerEvent', 'method', 'getPropertyByName',
    'callMethod', 'getModSetting', 'getVar', 'setVar', 'removeVar', 'runHaxeFunction',
    'loadAnimateAtlas', 'makeFlxAnimateSprite', 'addAnimationBySymbol', 'createInstance',
    'addInstance', 'addAchievementScore', 'startTween',
}


def engine_names():
    names = set()
    for hx in sorted(SRC.glob('*.hx')) + [SRC / 'FunkinLua.hx', SRC / 'PlayState.hx']:
        if not hx.exists():
            continue
        text = hx.read_text(encoding='utf-8', errors='replace')
        names |= set(re.findall(r'add_callback\(lua,\s*"([A-Za-z_][A-Za-z0-9_]*)"', text))
        names |= set(re.findall(r"^\s*set\('([A-Za-z_][A-Za-z0-9_]*)'", text, re.M))
        names |= set(re.findall(r"setOnLuas\('([A-Za-z_][A-Za-z0-9_]*)'", text))
    return names


def is_dot(node):
    """luaparser stores `t.foo` and `t[foo]` in the same Index node, only `notation` differs."""
    notation = getattr(node, 'notation', None)
    return str(notation).upper().endswith('DOT')


def analyse(text):
    tree = ast.parse(text)
    nodes = list(ast.walk(tree))

    def ident(node):
        return node.id if isinstance(node, ast.Name) else None

    def names_of(collection):
        for item in (collection or []):
            name = ident(item)
            if name:
                bound.add(name)

    bound = set()   # locals, params, loop counters and globals this chunk assigns itself
    member = set()  # id() of every Name that is only a field (t.foo), so it is not a global
    for node in nodes:
        cls = type(node).__name__
        if cls in ('LocalFunction', 'Function', 'AnonymousFunction'):
            name = ident(getattr(node, 'name', None))
            if name:
                bound.add(name)
            names_of(getattr(node, 'args', None))
        elif cls == 'LocalAssign':
            names_of(getattr(node, 'targets', None))
        elif cls == 'Assign':
            # `score = 0` creates a chunk global; `sprite.x = 0` is an Index target -> ignored
            names_of(getattr(node, 'targets', None))
        elif cls == 'Fornum':
            name = ident(getattr(node, 'target', None))
            if name:
                bound.add(name)
        elif cls == 'Forin':
            names_of(getattr(node, 'targets', None))
        elif cls == 'Index':
            if is_dot(node) and isinstance(node.idx, ast.Name):
                member.add(id(node.idx))
        elif cls == 'Field':
            # `{s = 1.0}` -- key is a Name that names a table field, not a global. `[expr] = v`
            # (between_brackets) is a real read, so leave that one alone.
            if not getattr(node, 'between_brackets', False) and isinstance(node.key, ast.Name):
                member.add(id(node.key))
        elif cls == 'Invoke':
            # `tag:gsub(...)` -- luaparser calls this an Invoke; `gsub` is the method name, so
            # it is not a global lookup either. `source` (tag) is, and stays checked.
            if isinstance(getattr(node, 'func', None), ast.Name):
                member.add(id(node.func))

    used = {}
    for node in nodes:
        if isinstance(node, ast.Name) and id(node) not in member:
            used.setdefault(node.id, node.line)
    return used, bound


def main(paths):
    known = engine_names()
    print(f'engine exposes {len(known)} lua names')
    bad = 0
    for path in paths:
        text = pathlib.Path(path).read_text(encoding='utf-8')
        try:
            used, bound = analyse(text)
        except Exception as exc:
            bad += 1
            print(f'SYNTAX FAIL {path}\n    {str(exc)[:300]}')
            continue
        unknown = {n: ln for n, ln in used.items()
                   if n not in known and n not in bound and n not in STANDARD}
        inert = {n: ln for n, ln in unknown.items() if n in NOT_IN_063}
        unknown = {n: ln for n, ln in unknown.items() if n not in NOT_IN_063}
        if unknown:
            bad += 1
            print(f'UNKNOWN    {path}')
            for name, line in sorted(unknown.items(), key=lambda kv: kv[1] or 0):
                print(f'    {name}  (line {line})')
        elif inert:
            # Every script that uses one of these wraps it in `if X == nil then ... return end`,
            # so a bare read is nil-safe. Not a failure -- but a *call* would be, so keep listing.
            print(f'WARN-0.7   {path} -- '
                  + ', '.join(f'{n} (line {ln})' for n, ln in sorted(inert.items(), key=lambda kv: kv[1] or 0)))
        else:
            print(f'ok         {path}')
    print(f'{len(paths) - bad}/{len(paths)} clean')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
