#!/usr/bin/env python3
"""reason: (д) the modern compiler. VP lets a for loop change its variable (`Inc(j); Break;`); FPC does not.
In filediz.pas the changed value is never read (j is assigned again before it is used), so the statement goes.
In fbb.pas the loop that repeats an item by `Dec(i)` becomes a while loop.
usage: 70-forloop.py FILE...   (all the .pas of the tree)"""
import re, sys, os
for p in sys.argv[1:]:
    b = os.path.basename(p).lower()
    if b not in ('filediz.pas', 'fbb.pas'):
        continue
    s = open(p, 'rb').read().decode('latin-1')
    if b == 'filediz.pas':
        s2 = re.sub(r'(NameEnd := j;\r?\n)[ \t]*Inc\(j\);\r?\n([ \t]*Break;)', r'\1\2', s, count=1)
    else:
        # fbb.pas MaxWrite: `for i := 1 to NBf do begin ... Dec(i); end` repeats the item: a while loop
        s2 = re.sub(r'(Rep:[ \t]*\r?\n[ \t]*if Abort or CopyCancelled then[ \t]*\r?\n[ \t]*Exit;[ \t]*\r?\n[ \t]*)for i := 1 to NBf do',
                    r'\1i := 0;\r\n    while i < NBf do\r\n      begin\r\n      Inc(i);', s, count=1)
        s2 = re.sub(r'(\r?\n)([ \t]*end \{ MaxWrite \};)', r'\1      end;\1\2', s2, count=1)
    print('70-forloop: %s %s' % (b, 'changed' if s2 != s else 'NOT changed'))
    open(p, 'wb').write(s2.encode('latin-1'))
