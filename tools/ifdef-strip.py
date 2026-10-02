#!/usr/bin/env python3
"""Evaluates the conditional compilation of Pascal sources ({$IFDEF}, {$IFNDEF}, {$ELSE}, {$ENDIF},
{$DEFINE}, {$UNDEF}, also the (*$...*) form) for a given set of defined symbols and writes the sources
with the inactive branches removed. Used to see what a platform (e.g. DPMI32, the DOS target of DN)
really compiles. Other directives ({$I file}, {$IF expr}) are left alone; {$I} files are not
included.

usage: tools/ifdef-strip.py SRC_DIR OUT_DIR SYMBOL [SYMBOL...]
"""
import os, re, sys

src, out = sys.argv[1], sys.argv[2]
defined0 = set(s.upper() for s in sys.argv[3:])
os.makedirs(out, exist_ok=True)
D = re.compile(r'(\{\$|\(\*\$)\s*(IFDEF|IFNDEF|IFOPT|ELSE|ENDIF|DEFINE|UNDEF)\b\s*([A-Za-z0-9_+\-]*)[^}*]*(\}|\*\))', re.I)

def process(text):
    defined = set(defined0)
    stack = []                       # (parent_active, this_branch_taken_before, now_active)
    active = True
    res = []
    pos = 0
    for m in D.finditer(text):
        if active:
            res.append(text[pos:m.start()])
        pos = m.end()
        kw, sym = m.group(2).upper(), m.group(3).upper()
        if kw in ('IFDEF', 'IFNDEF', 'IFOPT'):
            cond = (sym in defined) if kw == 'IFDEF' else ((sym not in defined) if kw == 'IFNDEF' else True)
            stack.append((active, cond))
            active = active and cond
            continue
        if kw == 'ELSE':
            if stack:
                parent, taken = stack[-1]
                active = parent and not taken
                stack[-1] = (parent, True)
            continue
        if kw == 'ENDIF':
            if stack:
                parent, _ = stack.pop()
                active = parent
            continue
        if active and kw == 'DEFINE':
            defined.add(sym)
        if active and kw == 'UNDEF':
            defined.discard(sym)
    if active:
        res.append(text[pos:])
    return ''.join(res)

for f in sorted(os.listdir(src)):
    p = os.path.join(src, f)
    if os.path.isfile(p) and f.lower().endswith(('.pas', '.inc')):
        t = open(p, encoding='cp866', errors='replace').read()
        open(os.path.join(out, f), 'w', encoding='cp866', errors='replace').write(process(t))
