#!/usr/bin/env python3
"""reason: (d) the modern compiler. VP accepts a doubled plus in a string constant (`'text'+` at the end of a
line and `+#3'more'` at the start of the next); FPC does not. The second plus is dropped (a unary plus changes nothing, so this is the same in every file).
usage: 71-constplus.py FILE...   (all the .pas of the tree)"""
import re, sys, os
n = 0
for p in sys.argv[1:]:
    s = open(p, 'rb').read().decode('latin-1')
    s2 = re.sub(r'\+[ \t]*(\r?\n(?:[ \t]*\r?\n)*)[ \t]*\+', r'+\1  ', s)
    if s2 != s:
        n += 1
        open(p, 'wb').write(s2.encode('latin-1'))
print('71-constplus: %d files' % n)
