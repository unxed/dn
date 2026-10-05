#!/usr/bin/env python3
"""reason: (d) the modern compiler. Hex8Lo of advance1.pas is a routine in the assembler of VP (`mov dx,[word ptr L+2]`: parameters
by name inside brackets), which FPC does not take. The same in Pascal: 8 hexadecimal digits of a LongInt.
usage: 110-hex8.py FILE...   (all the .pas of the tree)"""
import re, sys, os
NEW = '''procedure Hex8Lo(L: LongInt; var HexLo);
  const
    Digits = '0123456789ABCDEF';
  var
    I: Integer;
    P: PChar;
  begin
  P := @HexLo;
  for I := 0 to 7 do
    P[I] := Digits[1+((LongWord(L) shr (28-4*I)) and $F)];
  end;
'''
for p in sys.argv[1:]:
    if os.path.basename(p).lower() != 'advance1.pas':
        continue
    raw = open(p, 'rb').read().decode('latin-1')
    nl = '\r\n' if '\r\n' in raw else '\n'
    s, k = re.subn(r'^procedure Hex8Lo\(L: LongInt; var HexLo\);[ \t]*\r?\n(?:[ \t]*\r?\n)*[ \t]*assembler;.*?@@LEnd:[ \t]*\r?\n[ \t]*end;[ \t]*\r?\n',
                   lambda m: NEW.replace('\n', nl), raw, count=1, flags=re.S | re.M)
    print('110-hex8: %s' % ('replaced' if k else 'NOT found'))
    open(p, 'wb').write(s.encode('latin-1'))
