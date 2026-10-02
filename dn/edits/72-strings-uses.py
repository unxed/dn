#!/usr/bin/env python3
"""reason: (д) the modern compiler. In VP the unit Strings is known to every unit (`Strings.StrPCopy`); in FPC a
unit that names it must use it. The unit is added to the uses clause of the implementation (or of the interface
if there is no implementation uses).
usage: 72-strings-uses.py FILE...   (all the .pas of the tree)"""
import re, sys
n = 0
for p in sys.argv[1:]:
    raw = open(p, 'rb').read().decode('latin-1')
    code = re.sub(r"//[^\n]*|\{[^}]*\}|\(\*.*?\*\)|'[^'\n]*'", ' ', raw, flags=re.S)
    if not re.search(r'\bStrings\.[A-Za-z]', code):
        continue
    if re.search(r'\buses\b[^;]*\bStrings\b', code, re.I):
        continue
    im = re.search(r'^[ \t]*implementation\b[^\n]*\n', raw, re.I | re.M)
    if im:
        u = re.match(r'(\s*)uses\b([^;]*);', raw[im.end():], re.I)
        if u:
            pos = im.end() + u.end() - 1
            raw = raw[:pos] + ', Strings' + raw[pos:]
        else:
            raw = raw[:im.end()] + '\r\nuses Strings;\r\n' + raw[im.end():]
        open(p, 'wb').write(raw.encode('latin-1'))
        n += 1
print('72-strings-uses: %d files' % n)
