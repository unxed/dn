#!/usr/bin/env python3
"""reason: (a) the new TV. ChangeBounds takes its rectangle as const in tv/ (var in Borland TV), and some overrides of DN
change it (`Dec(Bounds.B.Y, H)`). A local variable NewBounds is a copy of the parameter and the body works with it.
usage: 91-changebounds-copy.py FILE...   (all the .pas of the tree)"""
import re, sys
SIG = re.compile(r'^(procedure\s+[A-Za-z_.]*ChangeBounds\()const Bounds(: TRect\);[^\n]*\n)', re.I | re.M)
MODIF = re.compile(r'\bBounds\.\w+(\.\w+)*\s*:=|\b(Inc|Dec)\(\s*Bounds\b|\bBounds\s*:=|\bBounds\.(Move|Grow|Intersect|Union)\(', re.I)
n = 0
for p in sys.argv[1:]:
    raw = open(p, 'rb').read().decode('latin-1')
    out, pos, changed = [], 0, False
    for m in SIG.finditer(raw):
        # the body: up to the next top-level routine
        nxt = re.search(r'^(procedure|function|constructor|destructor)\s', raw[m.end():], re.I | re.M)
        end = m.end() + (nxt.start() if nxt else len(raw) - m.end())
        body = raw[m.end():end]
        if not MODIF.search(body):
            continue
        nl = '\r\n' if '\r\n' in body else '\n'
        b = re.search(r'^  begin\b[^\n]*\n', body, re.M)
        if not b:
            continue
        before, after = body[:b.end()], body[b.end():]
        after = re.sub(r'\bBounds\b', 'NewBounds', after)
        v = re.search(r'^  var\b[^\n]*\n', before, re.M)
        if v:
            before = before[:v.end()] + '    NewBounds: TRect;' + nl + before[v.end():]
        else:
            bb = re.search(r'^  begin\b', before, re.M)
            before = before[:bb.start()] + '  var' + nl + '    NewBounds: TRect;' + nl + before[bb.start():]
        body2 = before + '  NewBounds := Bounds;' + nl + after
        out.append(raw[pos:m.start()] + m.group(0) + body2)
        pos = end
        changed = True
        n += 1
    if changed:
        out.append(raw[pos:])
        open(p, 'wb').write(''.join(out).encode('latin-1'))
print('91-changebounds-copy: %d routines' % n)
