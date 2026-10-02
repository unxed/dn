#!/usr/bin/env python3
"""reason: (a) the new TV. TNotepadFrame.FrameLine (carved into dndlgs.pas) wrote the characters of the frame into the
cells of the old 16-bit buffer; FrameLine of tv/ takes the draw buffer of tv/ and an attribute. The method is written
over that buffer (the same picture: the corner of the bookmarks column, then blanks to the right edge).
usage: 99-notepadframe.py FILE...   (all the .pas of the tree)"""
import re, sys, os
NEW = '''procedure TNotepadFrame.FrameLine(var FrameBuf: TvDrawBuf.TDrawBuffer; Y, N: Integer; Color: TColorAttr);
  var
    BMStart: Integer;
    C: Byte;
  begin
  inherited FrameLine(FrameBuf, Y, N, Color);
  BMStart := PNotepad(Owner)^.BookmarkStart;
  if Y = 0 then
    C := 187
  else if Y = Size.Y-1 then
    C := 188
  else
    C := 186;
  FrameBuf.MoveChar(BMStart, C, Color, 1);
  if Size.X-1 > BMStart then
    FrameBuf.MoveChar(BMStart+1, 32, Color, Size.X-1-BMStart);
  end;
'''
for p in sys.argv[1:]:
    if os.path.basename(p).lower() != 'dndlgs.pas':
        continue
    raw = open(p, 'rb').read().decode('latin-1')
    nl = '\r\n' if '\r\n' in raw else '\n'
    s = raw.replace('procedure FrameLine(var FrameBuf; Y, N: Integer; Color: Byte); virtual;',
                    'procedure FrameLine(var FrameBuf: TvDrawBuf.TDrawBuffer; Y, N: Integer; Color: TColorAttr); virtual;')
    s, k = re.subn(r'procedure TNotepadFrame\.FrameLine\(var FrameBuf; Y, N: Integer; Color: Byte\);.*?\r?\n  end;\r?\n',
                   lambda m: NEW.replace('\n', nl), s, count=1, flags=re.S)
    s = s.replace('Result := @COwner;', 'Result := MakePalette(COwner);')
    s = re.sub(r'while Page\[ActivePage\] <> Link do', 'while Pointer(Page[ActivePage]) <> Pointer(Link) do', s)
    print('99-notepadframe: %s' % ('done' if k else 'NOT found'))
    open(p, 'wb').write(s.encode('latin-1'))
