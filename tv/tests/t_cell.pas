program t_cell;
{$I ../src/tvdefs.inc}
uses TvColors, TvCell;
{$I testlib.inc}

const
  EAcute: array[0..1] of Byte = ($C3, $A9);
  Combining: array[0..1] of Byte = ($CC, $81);       { U+0301 }
  Cjk: array[0..2] of Byte = ($E4, $B8, $AD);        { U+4E2D }
  Zwj: array[0..2] of Byte = ($E2, $80, $8D);        { U+200D }

var
  C, D: TScreenCharacter;
  A, B: TScreenCell;
  I: Integer;
begin
  Check(SizeOf(TScreenCharacter) = 16, 'TScreenCharacter is 16 bytes');
  Check(SizeOf(TScreenCell) = 24, 'TScreenCell is 24 bytes');

  { single byte }
  ScInitChar(C, Ord('A'));
  Check((ScLength(C) = 1) and (ScText(C) = 'A'), 'init with a byte');
  Check(not ScIsWide(C) and not ScIsWideTrail(C), 'a byte is narrow, not a trail');

  { multi-byte, narrow and wide }
  ScInitText(C, @EAcute[0], 2, False);
  Check((ScLength(C) = 2) and (ScText(C) = #$C3#$A9) and not ScIsWide(C), 'init with UTF-8 text');
  ScInitText(C, @Cjk[0], 3, True);
  Check((ScLength(C) = 3) and ScIsWide(C) and not ScIsWideTrail(C), 'wide text');

  { out of range lengths leave an empty character }
  ScInitText(C, @Cjk[0], 0, False);
  Check((ScLength(C) = 1) and (C.Text[0] = 0), 'length 0 leaves an empty character');
  ScInitText(C, @Cjk[0], 5, False);
  Check((ScLength(C) = 1) and (C.Text[0] = 0), 'length 5 leaves an empty character');

  { wide character trail }
  ScInitWideTrail(C);
  Check(ScIsWideTrail(C) and not ScIsWide(C), 'wide character trail');

  { zero-width characters are appended }
  ScInitChar(C, Ord('e'));
  ScAppendZeroWidth(C, @Combining[0], 2);
  Check((ScLength(C) = 3) and (ScText(C) = 'e'#$CC#$81), 'append a combining mark');
  ScAppendZeroWidth(C, @Zwj[0], 3);
  Check(ScLength(C) = 6, 'append another zero-width character');

  { a NUL base character becomes a space }
  ScInitChar(C, 0);
  ScAppendZeroWidth(C, @Combining[0], 2);
  Check(ScText(C) = ' '#$CC#$81, 'NUL base becomes a space');

  { overflow: 15 bytes at most, then the flag sticks and the text stays }
  ScInitChar(C, Ord('a'));
  for I := 1 to 7 do
    ScAppendZeroWidth(C, @Combining[0], 2);          { 1 + 14 = 15 bytes }
  Check(ScLength(C) = 15, 'filled to 15 bytes');
  D := C;
  ScAppendZeroWidth(C, @Combining[0], 2);
  Check(CompareByte(C.Text, D.Text, 15) = 0, 'overflowing append keeps the text');
  Check(C.Meta <> D.Meta, 'overflow sets a flag');
  D := C;
  ScAppendZeroWidth(C, @Combining[0], 2);
  Check(CompareByte(C, D, SizeOf(C)) = 0, 'overflow flag is sticky');

  { all zero bytes is a valid cell }
  FillChar(A, SizeOf(A), 0);
  Check((ScLength(A.Character) = 1) and (A.Character.Text[0] = 0), 'zeroed cell: one NUL');
  Check(ColorIsDefault(AttrFg(A.Attribute)) and ColorIsDefault(AttrBg(A.Attribute)), 'zeroed cell: default colors');

  { cells from DOS words }
  A := CellFromBIOS($1F41);
  Check((ScText(A.Character) = 'A') and (AttrAsBIOSByte(A.Attribute) = $1F), 'CellFromBIOS');

  { equality }
  B := CellFromBIOS($1F41);
  Check(CellEq(A, B), 'equal cells');
  B := CellFromBIOS($1F42);
  Check(not CellEq(A, B), 'different characters');
  B := CellFromBIOS($2F41);
  Check(not CellEq(A, B), 'different attributes');
  ScInitText(C, @Cjk[0], 3, True);
  A := CellMake(C, AttrFromBIOS($07));
  B := CellMake(C, AttrFromBIOS($07));
  Check(CellEq(A, B), 'CellMake equal');
  ScInitText(D, @Cjk[0], 3, False);
  B := CellMake(D, AttrFromBIOS($07));
  Check(not CellEq(A, B), 'wide flag counts in equality');

  Finish;
end.
