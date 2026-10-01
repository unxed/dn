program t_text;
{$I ../src/tvdefs.inc}
uses TvColors, TvCell, TvText, TvCodePg;
{$I testlib.inc}

const
  Cjk = #$E4#$B8#$AD;           { U+4E2D, width 2 }
  Acute = #$CC#$81;             { U+0301, width 0 }
  Eacute = #$C3#$A9;            { U+00E9 }
  Zwj = #$E2#$80#$8D;           { U+200D }
  C1Ctl = #$C2#$85;             { U+0085, a control character }

var
  Cells: array[0..15] of TScreenCell;
  Attr: TColorAttr;
  N, L, W, J, I, Skipped, LeadW: Integer;

procedure Clear;
begin
  FillChar(Cells, SizeOf(Cells), 0);
end;

function Txt(Idx: Integer): ShortString;
begin
  Result := ScText(Cells[Idx].Character);
end;

function ToCp(const S: ShortString): Byte;
begin
  Result := TextToCodePage(@S[1], Length(S));
end;

function Draw(Count: Integer; const S: ShortString; Indent: Integer = 0; TextIndent: Integer = 0): Integer;
begin
  Result := TextDrawStrS(@Cells[0], Count, Indent, S, TextIndent, @Attr);
end;

begin
  Attr := AttrFromBIOS($1F);

  { widths }
  Check(TextWidthS('abc') = 3, 'width ASCII');
  Check(TextWidthS(Eacute) = 1, 'width e-acute');
  Check(TextWidthS('a' + Acute) = 1, 'width of base + combining mark');
  Check(TextWidthS(Cjk) = 2, 'width CJK');
  Check(TextWidthS('a' + Cjk + 'b') = 4, 'width mixed');
  Check(TextWidthS(#$FF) = 1, 'width of an invalid byte');
  Check(TextWidthS(#$C3) = 1, 'width of a truncated sequence');
  Check(TextWidthS(#$C3'A') = 2, 'width of invalid byte + ASCII');
  Check(TextWidthS(C1Ctl) = 1, 'width of a multi-byte control is 1');
  Check(TextWidthS('') = 0, 'width of empty text');

  { next }
  Check(TextNext(@Eacute[1], 2, L, W) and (L = 2) and (W = 1), 'next: e-acute');
  Check(TextNext(@Cjk[1], 3, L, W) and (L = 3) and (W = 2), 'next: CJK');
  Check(TextNext(@Acute[1], 2, L, W) and (L = 2) and (W = 0), 'next: combining mark');
  Check(TextNext(@Eacute[1], 1, L, W) and (L = 1) and (W = 1), 'next: truncated input');
  Check(not TextNext(@Eacute[1], 0, L, W), 'next: no input');

  { prev }
  Check(TextPrev(@('a' + Eacute)[1], 3) = 2, 'prev over a 2-byte character');
  Check(TextPrev(@('a' + Eacute)[1], 1) = 1, 'prev over ASCII');
  Check(TextPrev(@('a' + Eacute)[1], 0) = 0, 'prev at the start');
  Check(TextPrev(@(#$80#$80)[1], 2) = 1, 'prev over an invalid byte');
  Check(TextPrev(@(Cjk)[1], 3) = 3, 'prev over a 3-byte character');

  { scroll over 'a', CJK, 'b' (widths 1, 2, 1) }
  TextScroll(@('a' + Cjk + 'b')[1], 5, 1, False, L, W);
  Check((L = 1) and (W = 1), 'scroll 1');
  TextScroll(@('a' + Cjk + 'b')[1], 5, 2, False, L, W);
  Check((L = 1) and (W = 1), 'scroll 2 stops before the wide character');
  TextScroll(@('a' + Cjk + 'b')[1], 5, 2, True, L, W);
  Check((L = 4) and (W = 3), 'scroll 2 including the incomplete wide character');
  TextScroll(@('a' + Cjk + 'b')[1], 5, 3, False, L, W);
  Check((L = 4) and (W = 3), 'scroll 3');
  TextScroll(@('a' + Cjk + 'b')[1], 5, 10, False, L, W);
  Check((L = 5) and (W = 4), 'scroll beyond the end');
  TextScroll(@('a' + Cjk + 'b')[1], 5, 0, False, L, W);
  Check((L = 0) and (W = 0), 'scroll 0');

  { drawing ASCII with an attribute }
  Clear;
  Check(Draw(8, 'Hi') = 2, 'draw ASCII returns the cells used');
  Check((Txt(0) = 'H') and (Txt(1) = 'i'), 'draw ASCII text');
  Check(AttrAsBIOSByte(Cells[0].Attribute) = $1F, 'draw sets the attribute');
  Check((Cells[2].Character.Text[0] = 0) and (Cells[2].Attribute.Data = 0), 'draw leaves the rest alone');

  { indent, and text cut at the cell count }
  Clear;
  Check(Draw(4, 'abcdef', 1) = 3, 'draw with an indent is cut at the end');
  Check((Txt(0) = #0) and (Txt(1) = 'a') and (Txt(3) = 'c'), 'draw with an indent: cells');

  { double-width characters }
  Clear;
  Check(Draw(4, Cjk + 'b') = 3, 'draw wide + ASCII');
  Check(ScIsWide(Cells[0].Character) and (Txt(0) = Cjk), 'wide character in its cell');
  Check(ScIsWideTrail(Cells[1].Character), 'trail after the wide character');
  Check(Txt(2) = 'b', 'text continues after the trail');
  Check((AttrAsBIOSByte(Cells[0].Attribute) = $1F) and (AttrAsBIOSByte(Cells[1].Attribute) = $1F),
    'attribute set in the character and its trail');

  Clear;
  Check(Draw(1, Cjk) = 1, 'wide character in the last cell takes one cell');
  Check(ScIsWide(Cells[0].Character), 'wide flag stays without the trail');
  Check(not ScIsWideTrail(Cells[1].Character), 'no trail beyond the cells');

  { combining characters join the previous cell }
  Clear;
  Check(Draw(4, 'e' + Acute + 'x') = 2, 'combining mark takes no cell');
  Check(Txt(0) = 'e' + Acute, 'combining mark is appended');
  Clear;
  Check(Draw(4, Cjk + Acute) = 2, 'combining mark after a wide character');
  Check(Txt(0) = Cjk + Acute, 'appended to the wide cell, not to the trail');
  Clear;
  Check(Draw(4, Acute) = 0, 'combining mark at the start is dropped');
  Clear;
  Check(Draw(4, 'a' + Zwj) = 1, 'zero width joiner takes no cell');
  Check(Txt(0) = 'a', 'zero width joiner is not appended');

  { control characters and invalid bytes are shown through the code page }
  Clear;
  Check(Draw(4, #1#$7F) = 2, 'control characters take one cell each');
  Check((Txt(0) = #$E2#$98#$BA) and (Txt(1) = #$E2#$8C#$82), 'controls shown as IBM PC symbols');
  Clear;
  Check(CpCurrent = 866, 'default code page is 866');
  Draw(4, #$80);
  Check(Txt(0) = #$D0#$90, 'byte 80h in CP866 is Cyrillic A');
  Check(CpSelect(437) and (CpCurrent = 437), 'select CP437');
  Clear;
  Draw(4, #$80);
  Check(Txt(0) = #$C3#$87, 'byte 80h in CP437 is C-cedilla');
  Check(not CpSelect(1), 'unknown code page is refused');
  Check(CpCurrent = 437, 'a refused selection keeps the page');
  Clear;
  Draw(4, C1Ctl);
  Check(Txt(0) = #$EF#$BF#$BD, 'multi-byte control shown as U+FFFD');

  { text starting inside a wide character }
  Clear;
  Check(Draw(4, Cjk + 'b', 0, 1) = 2, 'cut wide character: cells');
  Check((Txt(0) = ' ') and (Txt(1) = 'b'), 'cut wide character becomes a space');
  Clear;
  Check(Draw(4, Cjk + 'b', 0, 2) = 1, 'text indent on a character boundary');
  Check(Txt(0) = 'b', 'text indent skips whole characters');

  { code page conversion }
  Check(ToCp('A') = Ord('A'), 'ASCII passes through');
  Check(ToCp(Eacute) = $82, 'e-acute in CP437');
  CpSelect(866);
  Check(ToCp(Eacute) = 0, 'e-acute is not in CP866');
  Check(ToCp(#$D0#$90) = $80, 'Cyrillic A in CP866');
  Check(ToCp(#$FF) = 0, 'invalid UTF-8 has no code page byte');

  J := 0;
  for I := 1 to 255 do
    if CpFromUnicode(CpToUnicode(I)) <> I then
      Inc(J);
  Check(J = 0, 'CP866 round trip for bytes 1..255');
  CpSelect(437);
  J := 0;
  for I := 1 to 255 do
    if CpFromUnicode(CpToUnicode(I)) <> I then
      Inc(J);
  Check(J = 0, 'CP437 round trip for bytes 1..255');
  CpSelect(866);

  { fill }
  Clear;
  TextDrawChar(@Cells[0], 3, Ord('='), @Attr);
  Check((Txt(0) = '=') and (Txt(2) = '=') and (AttrAsBIOSByte(Cells[1].Attribute) = $1F), 'DrawChar fills cells');
  Check(Cells[3].Character.Text[0] = 0, 'DrawChar stops at the count');

  Finish;
end.
