#!/usr/bin/env python3
"""reason: (a) the new TV, DOS target. videoman.pas compares the wanted mode with the BIOS data area
(MemL[seg0040+...]: the rows and the columns of the screen); the screen is the business of tv/ now, so the
comparison is with the size of the screen of tv/ (Drivers.ScreenHeight, ScreenWidth).
usage: 51-videoman.py FILE...   (all the .pas of the tree)"""
import re, sys, os
for p in sys.argv[1:]:
    if os.path.basename(p).lower() != 'videoman.pas':
        continue
    s = open(p, 'rb').read().decode('latin-1')
    s2 = re.sub(r'\(Rows = Byte\(MemL\[seg0040\+\$84\] \+ 1\)\)\s+and\s+\(Cols = Byte\(MemL\[seg0040\+\$4A\]\)\)',
                '(Rows = ScreenHeight) and (Cols = ScreenWidth)', s)
    print('51-videoman: %s' % ('changed' if s2 != s else 'NOT changed'))
    open(p, 'wb').write(s2.encode('latin-1'))
