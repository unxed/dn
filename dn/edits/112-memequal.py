#!/usr/bin/env python3
"""reason: (д) the modern compiler. MemEqual of advance1.pas is a routine in the assembler of VP (the parameters by name in the
instructions, the registers of the frame); the same in Pascal.
usage: 112-memequal.py FILE...   (all the .pas of the tree)"""
import re, sys, os
NEW = '''function MemEqual(var Buf1; var Buf2; Len: Word): Boolean;
  begin
  Result := CompareByte(Buf1, Buf2, Len) = 0;
  end;
'''
for p in sys.argv[1:]:
    if os.path.basename(p).lower() != 'advance1.pas':
        continue
    raw = open(p, 'rb').read().decode('latin-1')
    nl = '\r\n' if '\r\n' in raw else '\n'
    s, k = re.subn(r'^function MemEqual\(var Buf1; var Buf2; Len: Word\): Boolean;[ \t]*\r?\n[ \t]*assembler;.*?^@@1:[ \t]*\r?\nend;[ \t]*\r?\n',
                   lambda m: NEW.replace('\n', nl), raw, count=1, flags=re.S | re.M)
    print('112-memequal: %s' % ('replaced' if k else 'NOT found'))
    open(p, 'wb').write(s.encode('latin-1'))
