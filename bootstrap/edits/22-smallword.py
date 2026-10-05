#!/usr/bin/env python3
"""reason: (d) the modern compiler. In Virtual Pascal the types SmallWord, SmallInt... of the system layer are
visible in every unit; in FPC they come with our VPSysLow. A unit that names SmallWord and does not use
VPSysLow gets it in the uses clause of its interface.
usage: 22-smallword.py FILE...   (all the .pas of the tree)"""
import re, sys

n = 0
for p in sys.argv[1:]:
    raw = open(p, 'rb').read().decode('latin-1')
    code = re.sub(r'//[^\n]*|\{[^}]*\}|\(\*.*?\*\)', ' ', raw, flags=re.S)
    if not re.search(r'\bSmallWord\b', code, re.I):
        continue
    cl = code.lower()
    iface = code[:cl.find('implementation')] if 'implementation' in cl else code
    if re.search(r'\b(VPSysLow|Defines)\b', iface, re.I):
        continue
    m = re.search(r'^[ \t]*interface\b[^\n]*\n', raw, re.I | re.M)
    if not m:
        continue
    u = re.match(r'(\s*)uses\b([^;]*);', raw[m.end():], re.I)
    if u:
        pos = m.end() + u.end() - 1
        raw = raw[:pos] + ', VPSysLow' + raw[pos:]
    else:
        raw = raw[:m.end()] + '\nuses VPSysLow;\n' + raw[m.end():]
    # a unit may not use another one in both sections: drop it from the implementation
    im = re.search(r'^[ \t]*implementation\b', raw, re.I | re.M)
    if im:
        head, tail = raw[:im.end()], raw[im.end():]
        tail = re.sub(r'(\buses\b[^;]*?)(?:,[ \t\r\n]*VPSysLow\b|\bVPSysLow\b[ \t\r\n]*,)([^;]*;)', r'\1\2', tail, count=1, flags=re.I)
        tail = re.sub(r'\buses[ \t\r\n]*VPSysLow[ \t\r\n]*;', '', tail, count=1, flags=re.I)
        raw = head + tail
    open(p, 'wb').write(raw.encode('latin-1'))
    n += 1
print('22-smallword: %d files' % n)
