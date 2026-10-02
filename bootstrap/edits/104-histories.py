#!/usr/bin/env python3
"""reason: (a) the new TV. The history of tv/ is a list of records, not the block of bytes of Borland TV that DN saves and
loads as it is (HistoryBlock, HistoryUsed). LoadHistories/SaveHistories of histries.pas use HistoryLoad/HistoryStore
of tv/ (the file format of the history is ours).
usage: 104-histories.py FILE...   (all the .pas of the tree)"""
import re, sys, os
for p in sys.argv[1:]:
    if os.path.basename(p).lower() != 'histries.pas':
        continue
    raw = open(p, 'rb').read().decode('latin-1')
    s, a = re.subn(r'S\.Read\(A, SizeOf\(A\)\);\s*if HistorySize < A\+256 then.*?S\.Read\(HistoryBlock\^, A\);', 'HistoryLoad(S);', raw, count=1, flags=re.S)
    s, b = re.subn(r'A := HistoryUsed-Word\(HistoryBlock\);\s*S\.Write\(A, SizeOf\(A\)\);\s*S\.Write\(HistoryBlock\^, A\);', 'HistoryStore(S);', s, count=1)
    # ClearHistories: the strings that end with a blank are dropped from the history
    s, c = re.subn(r'  if HistoryBlock = nil then\r?\n\s*Exit;\r?\n.*?HistoryUsed := Word\(HistoryBlock\);\r?\n  I := 0;', '  HistoryRemoveEndingWith(\' \');\r\n  I := 0;', s, count=1, flags=re.S)
    print('104-histories: clear %s' % ('ok' if c else 'NOT found'))
    print('104-histories: load %s, save %s' % ('ok' if a else 'NOT found', 'ok' if b else 'NOT found'))
    open(p, 'wb').write(s.encode('latin-1'))
