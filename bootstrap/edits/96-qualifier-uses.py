#!/usr/bin/env python3
"""reason: (d) the modern compiler. In VP the units Strings and Dos are known to every unit (`Strings.StrPCopy`,
`Dos.FindFirst`); in FPC a unit that names them must use them. The unit is added to the uses clause of the
implementation (or a new one is made).
usage: 96-qualifier-uses.py FILE...   (all the .pas of the tree)"""
import re, sys, os
n = 0
for p in sys.argv[1:]:
    raw = open(p, 'rb').read().decode('latin-1')
    base = os.path.splitext(os.path.basename(p))[0].lower()
    code = re.sub(r"//[^\n]*|\{[^}]*\}|\(\*.*?\*\)|'[^'\n]*'", ' ', raw, flags=re.S)
    changed = False
    for unit in ('Strings', 'Dos', 'VPSysLow', 'VPUtils'):
        if base == unit.lower() or not re.search(r'\b%s\.[A-Za-z]' % unit, code):
            continue
        if re.search(r'\buses\b[^;]*\b%s\b' % unit, re.sub(r"//[^\n]*|\{[^}]*\}|\(\*.*?\*\)|'[^'\n]*'", ' ', raw, flags=re.S), re.I):
            continue
        im = re.search(r'^[ \t]*implementation\b[^\n]*\n', raw, re.I | re.M)
        if not im:
            continue
        u = re.match(r'(\s*)uses\b([^;]*);', raw[im.end():], re.I)
        if u:
            pos = im.end() + u.end() - 1
            raw = raw[:pos] + ', ' + unit + raw[pos:]
        else:
            raw = raw[:im.end()] + '\r\nuses %s;\r\n' % unit + raw[im.end():]
        changed = True
    if changed:
        open(p, 'wb').write(raw.encode('latin-1'))
        n += 1
print('96-qualifier-uses: %d files' % n)
