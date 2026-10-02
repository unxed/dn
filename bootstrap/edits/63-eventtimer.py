#!/usr/bin/env python3
"""reason: (a) the new TV. The views of DN have the field UpTmr of the type TEventTimer; the type is that of tv/
(TvViews), so xtime.pas, which declared it, takes it from there.
usage: 63-eventtimer.py FILE...   (all the .pas of the tree)"""
import re, sys, os
for p in sys.argv[1:]:
    if os.path.basename(p).lower() != 'xtime.pas':
        continue
    s = open(p, 'rb').read().decode('latin-1')
    s2 = re.sub(r'TEventTimer = record\s+StartMSecs: LongInt;\s+ExpireMSecs: LongInt;\s+end;', 'TEventTimer = TvViews.TEventTimer;', s, count=1)
    s2 = re.sub(r'(\r?\ninterface[ \t]*\r?\n)', r'\1\r\nuses TvViews;\r\n', s2, count=1, flags=re.I)
    print('63-eventtimer: %s' % ('changed' if s2 != s else 'NOT changed'))
    open(p, 'wb').write(s2.encode('latin-1'))
