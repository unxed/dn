{ TvText: measuring and drawing text made of UTF-8 (with a code page fallback)
  in screen cells.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/ttext.h, source/platform/ttext.cpp (TText)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Text is Len bytes at a PByte. Invalid UTF-8 bytes count as one character of
  width 1 and are shown through the current code page (TvCodePg).
  A cell holds one printable character (width 1 or 2) and the zero-width
  characters appended to it. A double-width character takes a cell and a trail
  cell after it (when there is room for the trail).
  Not translated yet: equalsIgnoreCase (needs case tables), the UTF-32 variants,
  drawStrEx with a callback (Attr: PColorAttr, nil = keep the attributes). }
unit TvText;

{$I tvdefs.inc}

interface

uses
  TvColors, TvCell;

{ Length and width of the character at Text (Len bytes available). False when
  Len = 0. Width is 0 for combining and format characters. }
function TextNext(Text: PByte; Len: Integer; out CharLen, CharWidth: Integer): Boolean;

function TextWidth(Text: PByte; Len: Integer): Integer;
function TextWidthS(const S: ShortString): Integer;

{ Length in bytes of the character that ends at Index (Index > 0), 0 for Index = 0.
  Tolerates invalid characters. }
function TextPrev(Text: PByte; Index: Integer): Integer;

{ Skips characters worth Count columns: Length is the number of bytes skipped,
  Width the columns they take. With IncludeIncomplete, a double-width character
  that does not fit entirely is skipped too (Width > Count then). }
procedure TextScroll(Text: PByte; Len, Count: Integer; IncludeIncomplete: Boolean;
  out Length, Width: Integer);

{ Writes one character of Text at Text[J] into Cells[I] (CellCount cells). I and J
  advance by the cells and bytes used. A zero-width character is appended to the
  previous cell and I does not advance. Attr, when not nil, is set in the cells
  written. False when nothing was consumed. }
function TextDrawOne(Cells: PScreenCell; CellCount: Integer; var I: Integer;
  Text: PByte; TextLen: Integer; var J: Integer; Attr: PColorAttr): Boolean;

{ Writes Text starting at Cells[Indent], skipping the first TextIndent columns of
  the text (a double-width character cut in the middle becomes a space). Returns
  the number of cells filled. }
function TextDrawStr(Cells: PScreenCell; CellCount, Indent: Integer;
  Text: PByte; TextLen, TextIndent: Integer; Attr: PColorAttr): Integer;
function TextDrawStrS(Cells: PScreenCell; CellCount, Indent: Integer;
  const S: ShortString; TextIndent: Integer; Attr: PColorAttr): Integer;

{ Fills Cells with a byte character, setting Attr when not nil. }
procedure TextDrawChar(Cells: PScreenCell; CellCount: Integer; Ch: Byte; Attr: PColorAttr);

{ Code page conversion of the first character of Text: the byte for ASCII, else the
  byte of the current code page (0 if there is none). }
function TextToCodePage(Text: PByte; Len: Integer): Byte;

implementation

uses
  TvUtf8, TvCodePg;

type
  TCellArray = array[0..MaxInt div SizeOf(TScreenCell) - 1] of TScreenCell;
  PCellArray = ^TCellArray;

{ length and width, as in ttext.cpp mbstat/nextImpl: only valid multi-byte
  characters get their own width; everything else is one column. }
function TextNext(Text: PByte; Len: Integer; out CharLen, CharWidth: Integer): Boolean;
var
  CP: LongWord;
  Used, W: Integer;
begin
  CharLen := 0;
  CharWidth := 0;
  if Len <= 0 then
    Exit(False);
  Result := True;
  if Utf8Decode(Text, Len, CP, Used) and (Used > 1) then
  begin
    W := TvUtf8.CharWidth(CP);
    CharLen := Used;
    if W = 0 then
      CharWidth := 0
    else if W < 1 then
      CharWidth := 1
    else
      CharWidth := W;
  end
  else
  begin
    CharLen := 1;
    CharWidth := 1;
  end;
end;

function TextWidth(Text: PByte; Len: Integer): Integer;
var
  I, L, W: Integer;
begin
  Result := 0;
  I := 0;
  while TextNext(Text + I, Len - I, L, W) do
  begin
    Inc(I, L);
    Inc(Result, W);
  end;
end;

function TextWidthS(const S: ShortString): Integer;
begin
  if Length(S) = 0 then
    Exit(0);
  Result := TextWidth(@S[1], Length(S));
end;

function TextPrev(Text: PByte; Index: Integer): Integer;
var
  Lead, I, Used: Integer;
  CP: LongWord;
begin
  if Index <= 0 then
    Exit(0);
  { read backwards until a valid character that ends exactly at Index is found;
    this tolerates invalid characters }
  Lead := Index;
  if Lead > MaxCharSize then
    Lead := MaxCharSize;
  for I := 1 to Lead do
    if Utf8Decode(Text + Index - I, I, CP, Used) then
    begin
      if Used = I then
        Exit(I)
      else
        Exit(1);
    end;
  Result := 1;
end;

procedure TextScroll(Text: PByte; Len, Count: Integer; IncludeIncomplete: Boolean;
  out Length, Width: Integer);
var
  I, W, I2, W2, L, CW: Integer;
begin
  Length := 0;
  Width := 0;
  if Count <= 0 then
    Exit;
  I := 0;
  W := 0;
  while True do
  begin
    I2 := I;
    W2 := W;
    if not TextNext(Text + I, Len - I, L, CW) then
      Break;
    Inc(I, L);
    Inc(W, CW);
    if W = Count then
      Break;
    if W > Count then
    begin
      if not IncludeIncomplete then
      begin
        I := I2;
        W := W2;
      end;
      Break;
    end;
  end;
  Length := I;
  Width := W;
end;

function IsZeroWidthJoiner(P: PByte; Len: Integer): Boolean;
begin
  Result := (Len = 3) and (P[0] = $E2) and (P[1] = $80) and (P[2] = $8D);
end;

{ ttext.cpp drawOneImpl: returns the bytes consumed and the cells advanced }
procedure DrawOneImpl(Cells: PCellArray; CellCount, I: Integer;
  Text: PByte; TextLen, J: Integer; out Len, Width: Integer);
var
  CP: LongWord;
  Used, W, K: Integer;
  Buf: array[0..3] of Byte;
  N: Integer;
  Wide, Trail: Boolean;
begin
  Len := 0;
  Width := 0;
  if J >= TextLen then
    Exit;
  Text := Text + J;
  if Utf8Decode(Text, TextLen - J, CP, Used) and (Used > 1) then
  begin
    W := CharWidth(CP);
    if W < 0 then
    begin
      if I < CellCount then
      begin
        Buf[0] := $EF; Buf[1] := $BF; Buf[2] := $BD;      { U+FFFD }
        ScInitText(Cells^[I].Character, @Buf[0], 3, False);
        Len := Used;
        Width := 1;
      end;
    end
    else if W = 0 then
    begin
      { append to the previous cell, if present }
      if (I > 0) and not IsZeroWidthJoiner(Text, Used) then
      begin
        K := I - 1;
        while ScIsWideTrail(Cells^[K].Character) and (K > 0) do
          Dec(K);
        ScAppendZeroWidth(Cells^[K].Character, Text, Used);
      end;
      Len := Used;
      Width := 0;
    end
    else if I < CellCount then
    begin
      Wide := W > 1;
      ScInitText(Cells^[I].Character, Text, Used, Wide);
      Trail := Wide and (I + 1 < CellCount);
      if Trail then
        ScInitWideTrail(Cells^[I + 1].Character);
      Len := Used;
      Width := 1;
      if Trail then
        Inc(Width);
    end;
  end
  else if I < CellCount then
  begin
    { one byte: ASCII, or invalid UTF-8 shown through the code page. Control
      characters are converted here since combining characters may be appended
      to them later. }
    if (Text[0] < $20) or (Text[0] >= $7F) then
    begin
      N := CpToUtf8(Text[0], @Buf[0]);
      ScInitText(Cells^[I].Character, @Buf[0], N, False);
    end
    else
      ScInitChar(Cells^[I].Character, Text[0]);
    Len := 1;
    Width := 1;
  end;
end;

function TextDrawOne(Cells: PScreenCell; CellCount: Integer; var I: Integer;
  Text: PByte; TextLen: Integer; var J: Integer; Attr: PColorAttr): Boolean;
var
  Len, Width: Integer;
begin
  DrawOneImpl(PCellArray(Cells), CellCount, I, Text, TextLen, J, Len, Width);
  if (Width > 0) and (Attr <> nil) then
    PCellArray(Cells)^[I].Attribute := Attr^;
  if (Width > 1) and (Attr <> nil) then
    PCellArray(Cells)^[I + 1].Attribute := Attr^;
  Inc(I, Width);
  Inc(J, Len);
  Result := Len <> 0;
end;

function TextDrawStr(Cells: PScreenCell; CellCount, Indent: Integer;
  Text: PByte; TextLen, TextIndent: Integer; Attr: PColorAttr): Integer;
var
  I, J, LeadWidth, Skipped: Integer;
begin
  I := Indent;
  J := 0;
  if TextIndent > 0 then
  begin
    TextScroll(Text, TextLen, TextIndent, True, Skipped, LeadWidth);
    J := Skipped;
    if (LeadWidth > TextIndent) and (I < CellCount) then
    begin
      ScInitChar(PCellArray(Cells)^[I].Character, Ord(' '));
      if Attr <> nil then
        PCellArray(Cells)^[I].Attribute := Attr^;
      Inc(I);
    end;
  end;
  while TextDrawOne(Cells, CellCount, I, Text, TextLen, J, Attr) do ;
  Result := I - Indent;
end;

function TextDrawStrS(Cells: PScreenCell; CellCount, Indent: Integer;
  const S: ShortString; TextIndent: Integer; Attr: PColorAttr): Integer;
begin
  if Length(S) = 0 then
    Exit(0);
  Result := TextDrawStr(Cells, CellCount, Indent, @S[1], Length(S), TextIndent, Attr);
end;

procedure TextDrawChar(Cells: PScreenCell; CellCount: Integer; Ch: Byte; Attr: PColorAttr);
var
  I: Integer;
begin
  for I := 0 to CellCount - 1 do
  begin
    ScInitChar(PCellArray(Cells)^[I].Character, Ch);
    if Attr <> nil then
      PCellArray(Cells)^[I].Attribute := Attr^;
  end;
end;

function TextToCodePage(Text: PByte; Len: Integer): Byte;
var
  CP: LongWord;
  Used: Integer;
begin
  if Len <= 0 then
    Exit(0);
  { ASCII is not converted }
  if Text[0] <= $7F then
    Exit(Text[0]);
  if Utf8Decode(Text, Len, CP, Used) then
    Result := CpFromUnicode(CP)
  else
    Result := 0;
end;

end.
