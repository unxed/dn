#!/usr/bin/env python3
"""reason: (a) the new TV. In DN the code of a key is a LongInt: scan code, character and the state of the shift keys
(Event.KeyCode = kbShiftLeft = $034B00). In tv/ KeyCode is a Word and the state is in ControlKeyState. DN reads the
code by DNKeyCode(Event) and sets it by SetDNKeyCode(Event, Code) (dn/new/drivers.pas). Also: CharCode is a Byte in tv/
(a Char in DN), the double click of the mouse is a flag in EventFlags.
usage: 80-keycode.py FILE...   (all the .pas of the tree)"""
import re, sys, os

REF = r'([A-Za-z_][A-Za-z_0-9]*(?:\^|\[[^\]\n]*\]|\.[A-Za-z_][A-Za-z_0-9]*)*)'
WRITE = re.compile(REF + r'\.KeyCode[ \t]*:=[ \t]*([^;\r\n]+?)[ \t]*(;|\r?\n)')
READ = re.compile(REF + r'\.KeyCode\b(?![ \t]*:=)')
CHAR_W = re.compile(REF + r'\.CharCode[ \t]*:=[ \t]*([^;\r\n]+?)[ \t]*(;|\r?\n)')
CHAR_R = re.compile(REF + r'\.CharCode\b(?![ \t]*:=)')
DBL = re.compile(REF + r'\.Double\b')
n = files = 0
for p in sys.argv[1:]:
    raw = open(p, 'rb').read().decode('latin-1')
    if 'KeyCode' not in raw and 'CharCode' not in raw and '.Double' not in raw:
        continue
    out = WRITE.sub(lambda m: 'SetDNKeyCode(%s, %s)%s' % (m.group(1), m.group(2), m.group(3)), raw)
    out = READ.sub(lambda m: 'DNKeyCode(%s)' % m.group(1), out)
    # the character of a key: Char in DN, Byte in tv/; a double click: a flag of the mouse event in tv/
    out = CHAR_W.sub(lambda m: '%s.CharCode := Byte(%s)%s' % (m.group(1), m.group(2), m.group(3)), out)
    out = CHAR_R.sub(lambda m: 'Char(%s.CharCode)' % m.group(1), out)
    out = DBL.sub(lambda m: '((%s.EventFlags and 2) <> 0)' % m.group(1), out)
    if out != raw:
        open(p, 'wb').write(out.encode('latin-1'))
        files += 1
        n += len(WRITE.findall(raw)) + len(READ.findall(raw)) + len(CHAR_R.findall(raw)) + len(DBL.findall(raw))
print('80-keycode: %d places in %d files' % (n, files))
