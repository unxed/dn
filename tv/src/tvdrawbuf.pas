{ TvDrawBuf: TDrawBuffer, a row (or column) of screen cells that a view draws
  into before the cells are copied to the screen.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/drawbuf.h, source/tvision/drivers.cpp (the "flat" variants of
    moveChar, moveStr, moveCStr, moveBuf)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  The buffer is allocated for a screen of ScreenDim cells in its largest
  dimension (a vertical view draws into it too): Capacity = 8 + Max(ScreenDim, 80).
  "Attribute 0" means "keep the attribute that is already there"; it is the BIOS
  attribute $00 (black on black), which cannot be drawn through these calls.
  Characters >= $80 that are not part of UTF-8 text are stored as they are in a
  cell and are shown through the code page by the backend (see TvCell). }
unit TvDrawBuf;

{$I tvdefs.inc}

interface

uses
  TvColors, TvCell, TvText;

const
  MaxStrWidthAll = $FFFF;     { "no limit" for MaxStrWidth }

type
  TDrawBuffer = object
    Data: PScreenCell;
    Capacity: Integer;
    constructor Init(ScreenDim: Integer);
    destructor Done;
    { Puts Count copies of the character C with attribute Attr from Indent on.
      C = 0 keeps the characters already there, Attr = 0 keeps the attributes. }
    procedure MoveChar(Indent: Integer; C: Byte; Attr: TColorAttr; Count: Integer);
    { Puts Len bytes of text (UTF-8, or code page bytes) from Indent on; the text
      starts at column StrIndent and at most MaxStrWidth columns are written.
      Returns the columns written. Attr = 0 keeps the attributes. }
    function MoveStr(Indent: Integer; Str: PByte; Len: Integer; Attr: TColorAttr;
      MaxStrWidth: Integer = MaxStrWidthAll; StrIndent: Integer = 0): Integer;
    function MoveStrS(Indent: Integer; const S: ShortString; Attr: TColorAttr;
      MaxStrWidth: Integer = MaxStrWidthAll; StrIndent: Integer = 0): Integer;
    { Like MoveStr, but '~' toggles between the attributes of Attrs: the text
      starts with Attrs.Lo, the first '~' switches to Attrs.Hi, the next back. }
    function MoveCStr(Indent: Integer; Str: PByte; Len: Integer; const Attrs: TAttrPair;
      MaxStrWidth: Integer = MaxStrWidthAll; StrIndent: Integer = 0): Integer;
    function MoveCStrS(Indent: Integer; const S: ShortString; const Attrs: TAttrPair;
      MaxStrWidth: Integer = MaxStrWidthAll; StrIndent: Integer = 0): Integer;
    { Count characters of Source with Attr (Attr = 0 keeps the attributes). }
    procedure MoveBuf(Indent: Integer; Source: PByte; Attr: TColorAttr; Count: Integer);
    procedure PutAttribute(Indent: Integer; Attr: TColorAttr);
    procedure PutChar(Indent: Integer; C: Byte);
  end;

implementation

type
  TCellArray = array[0..MaxInt div SizeOf(TScreenCell) - 1] of TScreenCell;
  PCellArray = ^TCellArray;

function IsKeepAttr(const Attr: TColorAttr): Boolean; inline;
begin
  Result := AttrEq(Attr, AttrFromBIOS(0));
end;

constructor TDrawBuffer.Init(ScreenDim: Integer);
begin
  if ScreenDim < 80 then
    ScreenDim := 80;
  Capacity := 8 + ScreenDim;
  GetMem(Data, Capacity * SizeOf(TScreenCell));
  { a buffer that ends up on screen uninitialized could mess the screen up }
  FillChar(Data^, Capacity * SizeOf(TScreenCell), 0);
end;

destructor TDrawBuffer.Done;
begin
  FreeMem(Data);
  Data := nil;
  Capacity := 0;
end;

procedure TDrawBuffer.MoveChar(Indent: Integer; C: Byte; Attr: TColorAttr; Count: Integer);
var
  Cell: TScreenCell;
  Dest: PScreenCell;
begin
  if (Count <= 0) or (Indent >= Capacity) then
    Exit;
  if Indent + Count >= Capacity then
    Count := Capacity - Indent;
  Dest := Data + Indent;
  if not IsKeepAttr(Attr) then
  begin
    if C <> 0 then
    begin
      ScInitChar(Cell.Character, C);
      Cell.Attribute := Attr;
      while Count > 0 do
      begin
        Dest^ := Cell;
        Inc(Dest);
        Dec(Count);
      end;
    end
    else
      while Count > 0 do
      begin
        Dest^.Attribute := Attr;
        Inc(Dest);
        Dec(Count);
      end;
  end
  else
    while Count > 0 do
    begin
      ScInitChar(Dest^.Character, C);
      Inc(Dest);
      Dec(Count);
    end;
end;

function TDrawBuffer.MoveStr(Indent: Integer; Str: PByte; Len: Integer; Attr: TColorAttr;
  MaxStrWidth: Integer; StrIndent: Integer): Integer;
var
  A: TColorAttr;
begin
  if (Indent >= Capacity) or (Len <= 0) or (MaxStrWidth <= 0) then
    Exit(0);
  if Indent + MaxStrWidth >= Capacity then
    MaxStrWidth := Capacity - Indent;
  if not IsKeepAttr(Attr) then
  begin
    A := Attr;
    Result := TextDrawStr(Data, Indent + MaxStrWidth, Indent, Str, Len, StrIndent, @A);
  end
  else
    Result := TextDrawStr(Data, Indent + MaxStrWidth, Indent, Str, Len, StrIndent, nil);
end;

function TDrawBuffer.MoveStrS(Indent: Integer; const S: ShortString; Attr: TColorAttr;
  MaxStrWidth: Integer; StrIndent: Integer): Integer;
begin
  if Length(S) = 0 then
    Exit(0);
  Result := MoveStr(Indent, @S[1], Length(S), Attr, MaxStrWidth, StrIndent);
end;

function TDrawBuffer.MoveCStr(Indent: Integer; Str: PByte; Len: Integer; const Attrs: TAttrPair;
  MaxStrWidth: Integer; StrIndent: Integer): Integer;
var
  I, J, W, CellCount, L, CW, Toggle: Integer;
  Cur: TColorAttr;
  Cells: PCellArray;
begin
  if (Indent >= Capacity) or (Len <= 0) or (MaxStrWidth <= 0) then
    Exit(0);
  if Indent + MaxStrWidth >= Capacity then
    MaxStrWidth := Capacity - Indent;
  Cells := PCellArray(Data);
  CellCount := Indent + MaxStrWidth;
  I := Indent;
  J := 0;
  W := 0;
  Toggle := 1;
  Cur := Attrs.Lo;
  while J < Len do
    if Str[J] = Ord('~') then
    begin
      if Toggle = 1 then Cur := Attrs.Hi else Cur := Attrs.Lo;
      Toggle := 1 - Toggle;
      Inc(J);
    end
    else if StrIndent <= W then
    begin
      if not TextDrawOne(Data, CellCount, I, Str, Len, J, @Cur) then
        Break;
    end
    else
    begin
      if not TextNext(Str + J, Len - J, L, CW) then
        Break;
      Inc(J, L);
      Inc(W, CW);
      if (StrIndent < W) and (I < CellCount) then
      begin
        { StrIndent is in the middle of a double-width character }
        ScInitChar(Cells^[I].Character, Ord(' '));
        Cells^[I].Attribute := Cur;
        Inc(I);
      end;
    end;
  Result := I - Indent;
end;

function TDrawBuffer.MoveCStrS(Indent: Integer; const S: ShortString; const Attrs: TAttrPair;
  MaxStrWidth: Integer; StrIndent: Integer): Integer;
begin
  if Length(S) = 0 then
    Exit(0);
  Result := MoveCStr(Indent, @S[1], Length(S), Attrs, MaxStrWidth, StrIndent);
end;

procedure TDrawBuffer.MoveBuf(Indent: Integer; Source: PByte; Attr: TColorAttr; Count: Integer);
begin
  MoveStr(Indent, Source, Count, Attr, MaxStrWidthAll, 0);
end;

procedure TDrawBuffer.PutAttribute(Indent: Integer; Attr: TColorAttr);
begin
  if (Indent >= 0) and (Indent < Capacity) then
    PCellArray(Data)^[Indent].Attribute := Attr;
end;

procedure TDrawBuffer.PutChar(Indent: Integer; C: Byte);
begin
  if (Indent >= 0) and (Indent < Capacity) then
    ScInitChar(PCellArray(Data)^[Indent].Character, C);
end;

end.
