#!/usr/bin/env python3
"""reason: (д) the modern compiler. VP lets a for loop change its variable (`Inc(j); Break;`); FPC does not.
In filediz.pas the changed value is never read (j is assigned again before it is used), so the statement goes.
usage: 70-forloop.py FILE...   (all the .pas of the tree)"""
import re, sys, os
for p in sys.argv[1:]:
    if os.path.basename(p).lower() != 'filediz.pas':
        continue
    s = open(p, 'rb').read().decode('latin-1')
    s2 = re.sub(r'(NameEnd := j;\r?\n)[ \t]*Inc\(j\);\r?\n([ \t]*Break;)', r'\1\2', s, count=1)
    print('70-forloop: %s' % ('changed' if s2 != s else 'NOT changed'))
    open(p, 'wb').write(s2.encode('latin-1'))
