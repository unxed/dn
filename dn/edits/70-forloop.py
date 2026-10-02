#!/usr/bin/env python3
"""reason: (д) the modern compiler. VP lets a for loop change its variable (`Inc(j); Break;`); FPC does not.
In filediz.pas the changed value is never read (j is assigned again before it is used), so the statement goes.
In decoder.pas (IPrefixes) `i := 255` restarts the scan (the Byte counter wraps to 0): a while loop with Inc(i).
In tetris.pas the loop that looks for a bad entry of the table of scores (and then resets all of them in an inner loop
over the same variable) is a search and an `if`.
In fbb.pas the loop that repeats an item by `Dec(i)` becomes a while loop.
usage: 70-forloop.py FILE...   (all the .pas of the tree)"""
import re, sys, os
for p in sys.argv[1:]:
    b = os.path.basename(p).lower()
    if b not in ('filediz.pas', 'fbb.pas', 'decoder.pas', 'tetris.pas', 'calc.pas'):
        continue
    s = open(p, 'rb').read().decode('latin-1')
    if b == 'calc.pas':
        # the export to CSV: `for I := 0 to Maxr do begin ... Inc(I) ... end` skips empty columns by changing I: a while loop
        m = re.search(r'^([ \t]*)for I := 0 to Maxr do(\r?\n)\1  begin\r?\n', s, re.M)
        s2, k = s, 0
        if m:
            ind = m.group(1)
            e = re.compile(r'^' + ind + r'  end;[ \t]*\r?\n', re.M).search(s, m.end())
            if e:
                nl = m.group(2)
                s2 = (s[:m.start()] + ind + 'I := 0;' + nl + ind + 'while I <= Maxr do' + nl + ind + '  begin' + nl + s[m.end():e.start()]
                      + ind + '  Inc(I);' + nl + s[e.start():])
                k = 1
    elif b == 'tetris.pas':
        s2, k = re.subn(r'([ \t]*)for I := 1 to 20 do(\r?\n)[ \t]*if not \(HiScores\[I\]\.StLv in \[1\.\.10\]\) then(\r?\n)',
                        lambda m: '%sI := 1;%s%swhile (I <= 20) and (HiScores[I].StLv in [1..10]) do%s%s  Inc(I);%s%sif I <= 20 then%s' % (
                            m.group(1), m.group(2), m.group(1), m.group(2), m.group(1), m.group(2), m.group(1), m.group(3)), s, count=1)
        if not k:
            s2 = s
        else:
            # the Break that left the outer loop
            s2 = re.sub(r'(Dispose\(S, Done\);\r?\n)[ \t]*Break;\r?\n(\s*end;\r?\n\s*NewGame;)', r'\1\2', s2, count=1)
    elif b == 'decoder.pas':
        s2 = re.sub(r'(procedure IPrefixes;.*?)for i := 0 to PrefN do(\r?\n)', r'\1i := 0;\2    while i <= PrefN do\2      begin', s, count=1, flags=re.S)
        s2 = re.sub(r'(        i := 255;\r?\n        end;\r?\n)(    end \{ IPrefixes \};)', r'\1      Inc(i);\n      end;\n\2', s2, count=1)
    elif b == 'filediz.pas':
        s2 = re.sub(r'(NameEnd := j;\r?\n)[ \t]*Inc\(j\);\r?\n([ \t]*Break;)', r'\1\2', s, count=1)
    else:
        # fbb.pas MaxWrite: `for i := 1 to NBf do begin ... Dec(i); end` repeats the item: a while loop
        s2 = re.sub(r'(Rep:[ \t]*\r?\n[ \t]*if Abort or CopyCancelled then[ \t]*\r?\n[ \t]*Exit;[ \t]*\r?\n[ \t]*)for i := 1 to NBf do',
                    r'\1i := 0;\r\n    while i < NBf do\r\n      begin\r\n      Inc(i);', s, count=1)
        s2 = re.sub(r'(\r?\n)([ \t]*end \{ MaxWrite \};)', r'\1      end;\1\2', s2, count=1)
    print('70-forloop: %s %s' % (b, 'changed' if s2 != s else 'NOT changed'))
    open(p, 'wb').write(s2.encode('latin-1'))
