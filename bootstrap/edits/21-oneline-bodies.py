#!/usr/bin/env python3
"""reason: (д) building with FPC. A routine with a one-line body in the interface section
(`procedure NotifyInit; inline; begin end;`, VP/Delphi style) is split: the interface keeps the header, the
implementation gets the header and the body (the multi-line bodies are moved by 20-interface-bodies.py).
usage: 21-oneline-bodies.py FILE...   (all the .pas of the tree)"""
import re, sys

ONE = re.compile(r'^(?P<hdr>(?:procedure|function)[ \t]+[^\n;]*(?:\([^)\n]*\))?[^\n;]*;)(?:[ \t\r]*\n)?[ \t]*(?:inline;[ \t]*)?'
                 r'(?P<body>begin\b[^\n]*?\bend;)[ \t\r]*$', re.I | re.M)

n_files = n = 0
for p in sys.argv[1:]:
    raw = open(p, 'rb').read().decode('latin-1')
    low = raw.lower()
    ii = re.search(r'^\s*interface\b', low, re.M)
    im = re.search(r'^\s*implementation\b', low, re.M)
    if not ii or not im or im.start() < ii.start():
        continue
    head, iface, rest = raw[:ii.end()], raw[ii.end():im.start()], raw[im.start():]
    moved = []
    def take(m):
        moved.append(m.group('hdr') + '\n' + m.group('body') + '\n')
        return m.group('hdr')
    iface2 = ONE.sub(take, iface)
    if not moved:
        continue
    # the implementation: after its keyword and its uses clause
    m = re.match(r'(\s*implementation\b[ \t]*\r?\n)(\s*uses\b[^;]*;[ \t]*\r?\n)?', rest, re.I)
    cut = m.end() if m else len(rest)
    rest = rest[:cut] + '\n' + '\n'.join(moved) + '\n' + rest[cut:]
    open(p, 'wb').write((head + iface2 + rest).encode('latin-1'))
    n_files += 1; n += len(moved)
print('21-oneline-bodies: %d bodies in %d files' % (n, n_files))
