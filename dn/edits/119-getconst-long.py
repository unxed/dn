#!/usr/bin/env python3
"""reason: (д) the modern compiler. Virtual Pascal's Word has 32 bits: getconst.pas (the constants of Commands.pas for the
resource compiler) keeps and sums the values in Word, and the key codes (kbAltX = $082D00) must not be cut to 16 bits
(see 118-keycode-long.sed). LongInt for the values. usage: 119-getconst-long.py FILE...   (acts on getconst.pas only)"""
import sys, os, re
for p in sys.argv[1:]:
    if os.path.basename(p).lower() != 'getconst.pas':
        continue
    s = open(p, 'rb').read().decode('latin-1')
    n = 0
    for old, new in [('    l: Word;', '    l: LongInt;'),
                     ('constructor Init(AL: Word;', 'constructor Init(AL: LongInt;'),
                     ('constructor TLngWord.Init(AL: Word;', 'constructor TLngWord.Init(AL: LongInt;'),
                     ('l := Word(AL);', 'l := AL;'),
                     ('GetValue(S: String; var Complete: Boolean): Word', 'GetValue(S: String; var Complete: Boolean): LongInt'),
                     ('function CalcValue(var S: String): Word;', 'function CalcValue(var S: String): LongInt;'),
                     ('      W: Word;\n      V: String;', '      W: LongInt;\n      V: String;')]:
        s2 = s.replace(old, new) if '\r\n' not in s else s.replace(old, new).replace(old.replace('\n', '\r\n'), new.replace('\n', '\r\n'))
        n += s2 != s
        s = s2
    open(p, 'wb').write(s.encode('latin-1'))
    print('119-getconst-long: %d of 7 replaced' % n)
