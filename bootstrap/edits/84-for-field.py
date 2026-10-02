#!/usr/bin/env python3
"""reason: (д) the modern compiler. VP accepts a field of a record as the counter of a for loop (`for R.B.X := ...`);
FPC wants a simple variable. The three loops (arvid.pas, cellscol.pas) become while loops over the same field; the
Break of arvid leaves the field at the value of the loop, as before.
usage: 84-for-field.py FILE...   (all the .pas of the tree)"""
import re, sys, os

ARVID = re.compile(r'([ \t]*)for R\.B\.X := R\.A\.Y downto 0 do(\r?\n)([ \t]*)begin(\r?\n)((?:.*?\r?\n)*?)([ \t]*)end;')
CELLS = re.compile(r'([ \t]*)for SR\.Col := SR1\.Col to SR2\.Col do\r?\n[ \t]*for SR\.Row := SR1\.Row to SR2\.Row do\r?\n[ \t]*RegisterPrev;')
CELLS_NEW = ('{0}begin\r\n{0}  SR.Col := SR1.Col;\r\n{0}  while SR.Col <= SR2.Col do\r\n{0}    begin\r\n{0}    SR.Row := SR1.Row;\r\n'
             '{0}    while SR.Row <= SR2.Row do\r\n{0}      begin\r\n{0}      RegisterPrev;\r\n{0}      Inc(SR.Row);\r\n{0}      end;\r\n'
             '{0}    Inc(SR.Col);\r\n{0}    end;\r\n{0}end;')

def arvid(m):
    ind, nl, bind, nl2, body, eind = m.groups()
    return '%sR.B.X := R.A.Y;%s%swhile R.B.X >= 0 do%s%sbegin%s%s%s  Dec(R.B.X);%s%send;' % (ind, nl, ind, nl, bind, nl2, body, eind, nl, eind)

for p in sys.argv[1:]:
    b = os.path.basename(p).lower()
    if b not in ('arvid.pas', 'cellscol.pas'):
        continue
    s = open(p, 'rb').read().decode('latin-1')
    if b == 'arvid.pas':
        s2, k = ARVID.subn(arvid, s, count=1)
    else:
        s2, k = CELLS.subn(lambda m: CELLS_NEW.format(m.group(1)), s, count=1)
    print('84-for-field: %s %s' % (b, 'changed' if k else 'NOT changed'))
    open(p, 'wb').write(s2.encode('latin-1'))
