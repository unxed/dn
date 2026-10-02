#!/usr/bin/env python3
"""reason: (a) the new TV. In DN the code of a key is a LongInt: scan code, character and the state of the shift keys
(Event.KeyCode = kbShiftLeft = $034B00). In tv/ KeyCode is a Word and the state is in ControlKeyState. DN reads the
code by DNKeyCode(Event) and sets it by SetDNKeyCode(Event, Code) (dn/new/drivers.pas).
usage: 80-keycode.py FILE...   (all the .pas of the tree)"""
import re, sys, os

REF = r'([A-Za-z_][A-Za-z_0-9]*(?:\^|\[[^\]\n]*\]|\.[A-Za-z_][A-Za-z_0-9]*)*)'
WRITE = re.compile(REF + r'\.KeyCode[ \t]*:=[ \t]*([^;\r\n]+?)[ \t]*(;|\r?\n)')
READ = re.compile(REF + r'\.KeyCode\b(?![ \t]*:=)')
n = files = 0
for p in sys.argv[1:]:
    raw = open(p, 'rb').read().decode('latin-1')
    if 'KeyCode' not in raw:
        continue
    out = WRITE.sub(lambda m: 'SetDNKeyCode(%s, %s)%s' % (m.group(1), m.group(2), m.group(3)), raw)
    out = READ.sub(lambda m: 'DNKeyCode(%s)' % m.group(1), out)
    if out != raw:
        open(p, 'wb').write(out.encode('latin-1'))
        files += 1
        n += len(WRITE.findall(raw)) + len(READ.findall(raw))
print('80-keycode: %d places in %d files' % (n, files))
