#!/usr/bin/env python3
"""reason: (д) the modern compiler. VP accepts a doubled plus in a string constant (`'text'+` at the end of a
line and `+#3'more'` at the start of the next); FPC does not. In dnutil.pas the second plus is dropped.
usage: 71-constplus.py FILE...   (all the .pas of the tree)"""
import re, sys, os
for p in sys.argv[1:]:
    if os.path.basename(p).lower() != 'dnutil.pas':
        continue
    s = open(p, 'rb').read().decode('latin-1')
    s2 = re.sub(r'\+[ \t]*(\r?\n(?:[ \t]*\r?\n)*)[ \t]*\+', r'+\1  ', s)
    print('71-constplus: %d places' % len(re.findall(r'\+[ \t]*\r?\n[ \t]*\+', s)))
    open(p, 'wb').write(s2.encode('latin-1'))
