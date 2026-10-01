program t_drawbu;
{$I ../src/tvdefs.inc}
uses TvColors, TvCell, TvText, TvDrawBuf;
{$I testlib.inc}

const
  Cjk = #$E4#$B8#$AD;           { width 2 }
  Acute = #$CC#$81;             { width 0 }

var
  B: TDrawBuffer;
  A1, A2, Keep: TColorAttr;
  Pair: TAttrPair;
  N: Integer;

function Txt(Idx: Integer): ShortString;
begin
  Result := ScText(PScreenCell(PtrUInt(B.Data) + Idx * SizeOf(TScreenCell))^.Character);
end;

function At(Idx: Integer): Byte;
begin
  Result := AttrAsBIOSByte(PScreenCell(PtrUInt(B.Data) + Idx * SizeOf(TScreenCell))^.Attribute);
end;

function Untouched(Idx: Integer): Boolean;
begin
  Result := PScreenCell(PtrUInt(B.Data) + Idx * SizeOf(TScreenCell))^.Attribute.Data = 0;
end;

function Cell(Idx: Integer): PScreenCell;
begin
  Result := PScreenCell(PtrUInt(B.Data) + Idx * SizeOf(TScreenCell));
end;

procedure Reset;
begin
  FillChar(B.Data^, B.Capacity * SizeOf(TScreenCell), 0);
end;

begin
  A1 := AttrFromBIOS($1F);
  A2 := AttrFromBIOS($2E);
  Keep := AttrFromBIOS(0);
  Pair := AttrPair(A1, A2);                 { Lo = normal, Hi = highlighted }

  B.Init(80);
  Check(B.Capacity = 88, 'capacity for an 80-column screen');
  B.Done;
  B.Init(40);
  Check(B.Capacity = 88, 'capacity is at least for 80 columns');
  B.Done;
  B.Init(132);
  Check(B.Capacity = 140, 'capacity for a 132-column screen');
  Check((Cell(0)^.Character.Text[0] = 0) and (Cell(0)^.Attribute.Data = 0), 'a new buffer is zeroed');

  { MoveChar }
  B.MoveChar(2, Ord('='), A1, 5);
  Check((Txt(1) = #0) and (Txt(2) = '=') and (Txt(6) = '=') and (Txt(7) = #0), 'MoveChar fills the range');
  Check((At(2) = $1F) and (At(6) = $1F) and Untouched(7) and Untouched(1), 'MoveChar sets the attribute');
  B.MoveChar(2, Ord('x'), Keep, 2);
  Check((Txt(2) = 'x') and (Txt(3) = 'x') and (Txt(4) = '=') and (At(2) = $1F), 'MoveChar with attribute 0 keeps attributes');
  B.MoveChar(4, 0, A2, 2);
  Check((Txt(4) = '=') and (At(4) = $2E) and (At(5) = $2E) and (At(6) = $1F), 'MoveChar with character 0 keeps characters');
  B.MoveChar(0, 0, Keep, 1);
  Check((Txt(0) = #0) and Untouched(0), 'MoveChar with both 0');
  Reset;
  B.MoveChar(B.Capacity - 2, Ord('z'), A1, 10);
  Check((Txt(B.Capacity - 1) = 'z') and (Txt(B.Capacity - 3) = #0), 'MoveChar is cut at the capacity');
  B.MoveChar(B.Capacity, Ord('z'), A1, 3);
  B.MoveChar(5, Ord('z'), A1, 0);
  B.MoveChar(5, Ord('z'), A1, -3);
  Check(Txt(5) = #0, 'MoveChar beyond the capacity or with count <= 0 does nothing');

  { MoveStr }
  Reset;
  N := B.MoveStrS(1, 'Hello', A1);
  Check(N = 5, 'MoveStr returns the columns');
  Check((Txt(1) = 'H') and (Txt(5) = 'o') and (Txt(6) = #0) and (At(1) = $1F), 'MoveStr text and attribute');
  Reset;
  Check(B.MoveStrS(0, 'Hello', A1, 3) = 3, 'MoveStr with MaxStrWidth');
  Check((Txt(2) = 'l') and (Txt(3) = #0), 'MoveStr stops at MaxStrWidth');
  Reset;
  Check(B.MoveStrS(0, 'Hello', A1, MaxStrWidthAll, 2) = 3, 'MoveStr with StrIndent');
  Check((Txt(0) = 'l') and (Txt(2) = 'o'), 'MoveStr skips StrIndent columns');
  Reset;
  B.MoveChar(0, Ord('.'), A2, 6);
  B.MoveStrS(1, 'ab', Keep);
  Check((Txt(1) = 'a') and (Txt(2) = 'b') and (At(1) = $2E), 'MoveStr with attribute 0 keeps attributes');
  Reset;
  Check(B.MoveStrS(0, '', A1) = 0, 'MoveStr of an empty string');
  Check(B.MoveStrS(B.Capacity, 'x', A1) = 0, 'MoveStr beyond the capacity');
  Check(B.MoveStrS(0, 'x', A1, 0) = 0, 'MoveStr with MaxStrWidth 0');
  Check(B.MoveStrS(B.Capacity - 2, 'abcdef', A1) = 2, 'MoveStr is cut at the capacity');

  { double-width characters and combining marks }
  Reset;
  Check(B.MoveStrS(0, Cjk + 'b', A1) = 3, 'MoveStr of a wide character');
  Check(ScIsWide(Cell(0)^.Character) and ScIsWideTrail(Cell(1)^.Character) and (Txt(2) = 'b'), 'wide character, trail and next');
  Reset;
  Check(B.MoveStrS(0, 'e' + Acute + 'x', A1) = 2, 'MoveStr with a combining mark');
  Check((Txt(0) = 'e' + Acute) and (Txt(1) = 'x'), 'the mark joins the previous cell');
  Reset;
  Check(B.MoveStrS(0, Cjk + 'b', A1, MaxStrWidthAll, 1) = 2, 'MoveStr starting inside a wide character');
  Check((Txt(0) = ' ') and (Txt(1) = 'b'), 'a cut wide character becomes a space');

  { MoveBuf }
  Reset;
  B.MoveBuf(3, @('abc')[1], A2, 3);
  Check((Txt(3) = 'a') and (Txt(5) = 'c') and (At(4) = $2E), 'MoveBuf');

  { MoveCStr: '~' toggles highlight }
  Reset;
  Check(B.MoveCStrS(0, '~H~ello', Pair) = 5, 'MoveCStr returns the columns without the tildes');
  Check((Txt(0) = 'H') and (Txt(1) = 'e') and (Txt(4) = 'o'), 'MoveCStr text');
  Check((At(0) = $2E) and (At(1) = $1F) and (At(4) = $1F), 'MoveCStr: the marked character is highlighted');
  Reset;
  B.MoveCStrS(0, 'a~b', Pair);
  Check((At(0) = $1F) and (At(1) = $2E), 'MoveCStr: an unbalanced tilde highlights the rest');
  Reset;
  B.MoveCStrS(0, 'a~b~c~d', Pair);
  Check((At(0) = $1F) and (At(1) = $2E) and (At(2) = $1F) and (At(3) = $2E), 'MoveCStr: tildes keep toggling');
  Reset;
  Check(B.MoveCStrS(0, '~H~ello', Pair, MaxStrWidthAll, 1) = 4, 'MoveCStr with StrIndent');
  Check((Txt(0) = 'e') and (At(0) = $1F), 'MoveCStr skips the text but follows the tildes');
  Reset;
  Check(B.MoveCStrS(0, '~H~ello', Pair, 2) = 2, 'MoveCStr with MaxStrWidth');
  Check(Txt(2) = #0, 'MoveCStr stops at MaxStrWidth');
  Reset;
  Check(B.MoveCStrS(0, '~~', Pair) = 0, 'MoveCStr of tildes only');
  Check(B.MoveCStrS(0, '', Pair) = 0, 'MoveCStr of an empty string');
  Reset;
  Check(B.MoveCStrS(0, Cjk + 'x', Pair, MaxStrWidthAll, 1) = 2, 'MoveCStr starting inside a wide character');
  Check((Txt(0) = ' ') and (Txt(1) = 'x'), 'MoveCStr: a cut wide character becomes a space');

  { PutAttribute, PutChar }
  Reset;
  B.PutChar(4, Ord('Q'));
  B.PutAttribute(4, A2);
  Check((Txt(4) = 'Q') and (At(4) = $2E), 'PutChar and PutAttribute');
  B.PutChar(B.Capacity, Ord('Q'));
  B.PutAttribute(B.Capacity, A1);
  B.PutChar(-1, Ord('Q'));
  Check(Txt(0) = #0, 'out of range PutChar/PutAttribute change nothing');

  B.Done;
  Finish;
end.
