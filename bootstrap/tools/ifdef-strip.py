#!/usr/bin/env python3
"""Evaluates the conditional compilation of Pascal sources ({$IFDEF}, {$IFNDEF}, {$ELSE}, {$ENDIF},
{$DEFINE}, {$UNDEF}, also the (*$...*) form) for a given set of defined symbols and writes the sources
with the inactive branches removed. Used to make the tree of one target (DPMI32: the DOS target of DN)
and to see what that target really compiles. The files that {$I name} includes are read to learn the
symbols they define (the include directive itself stays). Other directives ({$IF expr}, {$IFOPT}) are
left alone.

usage: tools/ifdef-strip.py SRC_DIR OUT_DIR SYMBOL [SYMBOL...] [--keep SYMBOL...]     (OUT_DIR = SRC_DIR: in place)
  --keep: the conditionals on these symbols are not evaluated: the directives and both branches stay (the compiler decides, with
  -dSYMBOL), so one tree serves several builds (LINUX, NOASM, ...).
"""
import os, re, sys

src, out = sys.argv[1], sys.argv[2]
args = sys.argv[3:]
keep = set(s.upper() for s in args[args.index('--keep') + 1:]) if '--keep' in args else set()
defined0 = set(s.upper() for s in (args[:args.index('--keep')] if '--keep' in args else args))
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
        if kw in ('IFDEF', 'IFNDEF') and sym in keep:
            # not evaluated: the directive and both branches stay
            if active:
                res.append(m.group(0))
            stack.append((active, True, True))
            continue
        if kw == 'ELSE' and stack and stack[-1][2]:
            if active:
                res.append(m.group(0))
            continue
        if kw == 'ENDIF' and stack and stack[-1][2]:
            if active:
                res.append(m.group(0))
            active = stack.pop()[0]
            continue
        if kw in ('IFDEF', 'IFNDEF'):
            cond = (sym in defined) if kw == 'IFDEF' else (sym not in defined)
            stack.append((active, cond, False))
            active = active and cond
            continue
        if kw == 'ELSE':
            if stack:
                parent, taken, _ = stack[-1]
                active = parent and not taken
                stack[-1] = (parent, True, False)
            continue
        if kw == 'ENDIF':
            if stack:
                parent = stack.pop()[0]
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
