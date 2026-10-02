#!/usr/bin/env python3
"""Evaluates the conditional compilation of Pascal sources ({$IFDEF}, {$IFNDEF}, {$ELSE}, {$ENDIF},
{$DEFINE}, {$UNDEF}, also the (*$...*) form) for a given set of defined symbols and writes the sources
with the inactive branches removed. Used to make the tree of one target (DPMI32: the DOS target of DN)
and to see what that target really compiles. The files that {$I name} includes are read to learn the
symbols they define (the include directive itself stays). Other directives ({$IF expr}, {$IFOPT}) are
left alone.

usage: tools/ifdef-strip.py SRC_DIR OUT_DIR SYMBOL [SYMBOL...]     (OUT_DIR = SRC_DIR: in place)
"""
import os, re, sys

src, out = sys.argv[1], sys.argv[2]
defined0 = set(s.upper() for s in sys.argv[3:])
os.makedirs(out, exist_ok=True)
# comments and strings: a directive inside them is not a directive (`(* old code {$ELSE} !! *) new code` in DN)
TOK = re.compile(r"\(\*\$.*?\*\)|\(\*.*?\*\)|\{\$[^}]*\}|\{[^}]*\}|//[^\r\n]*|'[^'\r\n]*'", re.S)
D = re.compile(r'(\{\$|\(\*\$)\s*(IFDEF|IFNDEF|ELSE|ENDIF|DEFINE|UNDEF|I)\b\s*([^}*\s]*)[^}*]*(\}|\*\))', re.I)
files = {f.lower(): f for f in os.listdir(src)}

def read(f):
    return open(os.path.join(src, f), 'rb').read().decode('latin-1')

class _Shift:
    """the match of a directive with the positions in the whole text"""
    def __init__(self, m, base):
        self.m, self.base = m, base
    def start(self): return self.base + self.m.start()
    def end(self): return self.base + self.m.end()
    def group(self, i): return self.m.group(i)


def process(text, defined, depth=0):
    stack = []
    active = True
    res = []
    pos = 0
    for tk in TOK.finditer(text):
        m = D.fullmatch(tk.group(0))
        if m is None:
            continue                # a comment or a string
        m = _Shift(m, tk.start())
        if active:
            res.append(text[pos:m.start()])
        pos = m.end()
        kw, sym = m.group(2).upper(), m.group(3)
        if kw == 'I':
            if active:
                res.append(m.group(0))
                name = sym.strip("'\"").lower()
                if depth < 8 and name in files:
                    process(read(files[name]), defined, depth + 1)     # only its defines matter
            continue
        sym = sym.upper()
        if kw in ('IFDEF', 'IFNDEF'):
            cond = (sym in defined) if kw == 'IFDEF' else (sym not in defined)
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
        if active:
            res.append(m.group(0))      # DEFINE and UNDEF stay: the compiler sees them too
            if kw == 'DEFINE':
                defined.add(sym)
            else:
                defined.discard(sym)
    if active:
        res.append(text[pos:])
    return ''.join(res)

for f in sorted(os.listdir(src)):
    p = os.path.join(src, f)
    if os.path.isfile(p) and f.lower().endswith(('.pas', '.inc')):
        t = process(read(f), set(defined0))
        open(os.path.join(out, f), 'wb').write(t.encode('latin-1'))
