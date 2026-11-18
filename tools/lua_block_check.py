#!/usr/bin/env python3
"""Structural Lua checker for the Limul Engine mod scripts.

No lua/luajit binary is installed here, so this is a token-level sanity check rather than a
real parse: comments and string literals are stripped, then the block grammar is counted
(function / if / for / while openers vs end closers) and (), [], {} are balanced.
It catches the mistakes that actually kill a Psych Lua script at load time -- a missing
`end`, an unbalanced table constructor, a stray quote inside a sprite name.

usage: python tools/lua_block_check.py <file-or-glob> [...]
"""
import re
import sys
from pathlib import Path

OPENER = re.compile(r'\b(function|if|for|while)\b')
CLOSER = re.compile(r'\bend\b')
THENLESS_IF = re.compile(r'\bif\b')


def strip_source(src: str) -> str:
    out = []
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        # long comment / long string: --[[ ... ]] or [[ ... ]]
        if c == '-' and src[i + 1:i + 2] == '-':
            if src[i + 2:i + 4] == '[[':
                close = src.find(']]', i + 4)
                i = n if close < 0 else close + 2
                continue
            nl = src.find('\n', i)
            i = n if nl < 0 else nl
            continue
        if src[i:i + 2] == '[[':
            close = src.find(']]', i + 2)
            i = n if close < 0 else close + 2
            continue
        if c in ('"', "'"):
            quote = c
            i += 1
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if src[i] == quote:
                    i += 1
                    break
                if src[i] == '\n':
                    return '\n'.join(out) + '\n<<UNTERMINATED STRING>>'
                i += 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def check(path: Path):
    raw = path.read_text(encoding='utf-8', errors='replace')
    src = strip_source(raw)
    if '<<UNTERMINATED STRING>>' in src:
        return ['unterminated string literal']

    problems = []
    openers = len(OPENER.findall(src))
    closers = len(CLOSER.findall(src))
    if openers != closers:
        problems.append(f'block balance: {openers} openers (function/if/for/while) vs {closers} "end"')

    depth = {'(': 0, '[': 0, '{': 0}
    pairs = {')': '(', ']': '[', '}': '{'}
    line = 1
    for ch in src:
        if ch == '\n':
            line += 1
        elif ch in depth:
            depth[ch] += 1
        elif ch in pairs:
            depth[pairs[ch]] -= 1
            if depth[pairs[ch]] < 0:
                problems.append(f'stray "{ch}" on line {line}')
                depth[pairs[ch]] = 0
    for ch, count in depth.items():
        if count != 0:
            problems.append(f'unbalanced "{ch}" x{count}')

    if re.search(r'\bfunction\s+\w*\s*\([^)]*$', src, re.M):
        problems.append('function header with an unclosed parameter list')
    return problems


def main(argv):
    files = []
    for arg in argv:
        p = Path(arg)
        if p.is_dir():
            files += sorted(p.rglob('*.lua'))
        elif any(ch in arg for ch in '*?['):
            files += sorted(Path().glob(arg))
        else:
            files.append(p)
    if not files:
        print('no files matched')
        return 1
    bad = 0
    for f in files:
        if not f.exists():
            print(f'MISSING  {f}')
            bad += 1
            continue
        problems = check(f)
        if problems:
            bad += 1
            print(f'FAIL     {f}')
            for p in problems:
                print(f'          - {p}')
        else:
            print(f'ok       {f}')
    print(f'\n{len(files) - bad}/{len(files)} clean')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
