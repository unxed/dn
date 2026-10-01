{ TvCell: the screen cell. A cell holds the text of one column group (up to 15
  bytes of UTF-8, 1 or 2 columns wide) plus its color attribute.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/scrncell.h (TScreenCharacter, TScreenCell; the non-Borland variant)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  A TScreenCharacter stores one of:
    1. a single byte of ASCII or "extended ASCII" text (1 column);
    2. up to 15 bytes of UTF-8 text (1 or 2 columns in total, so it cannot
       consist of zero-width characters only);
    3. a marker for the trail of a double-width character: a double-width
       character occupies a cell followed by a cell holding the trail. If the
       trail is missing, or a trail is not preceded by a double-width character,
       the double-width character is being partially overlapped.
  Cells are plain data: all-zero bytes is a valid, empty cell (default colors,
  one NUL character), and cells can be moved and compared as raw memory. }
unit TvCell;

{$I tvdefs.inc}

interface

uses
  TvColors;

const
  MaxCellTextSize = 15;

type
  TScreenCharacter = packed record
    Text: array[0..MaxCellTextSize - 1] of Byte;
    { low nibble: text length - 1 (there is always at least one byte, possibly NUL);
      high nibble: flags (see sc* below) }
    Meta: Byte;
  end;

  TScreenCell = packed record
    Character: TScreenCharacter;
    Attribute: TColorAttr;
  end;

const
  { flags, stored in the high nibble of Meta }
  scWide     = $1;
  scTrail    = $2;
  scOverflow = $4;

{ --- TScreenCharacter -------------------------------------------------------- }
procedure ScInitChar(out C: TScreenCharacter; Ch: Byte);
{ Text is Len bytes of UTF-8 (1..4); anything else leaves an empty character. }
procedure ScInitText(out C: TScreenCharacter; Text: PByte; Len: Integer; Wide: Boolean);
procedure ScInitWideTrail(out C: TScreenCharacter);
function ScIsWide(const C: TScreenCharacter): Boolean; inline;
function ScIsWideTrail(const C: TScreenCharacter): Boolean; inline;
function ScLength(const C: TScreenCharacter): Integer; inline;
{ The text, as a string. Precondition: not a wide character trail. }
function ScText(const C: TScreenCharacter): ShortString;
{ Appends a zero-width character (UTF-8, Len bytes); when it does not fit, the
  overflow flag is set and the text is left unchanged. Precondition: the text is
  valid UTF-8. A NUL base character becomes a space first. }
procedure ScAppendZeroWidth(var C: TScreenCharacter; Text: PByte; Len: Integer);

{ --- TScreenCell ------------------------------------------------------------- }
function CellMake(const Ch: TScreenCharacter; const Attr: TColorAttr): TScreenCell;
{ From a DOS text mode word: character in the low byte, BIOS attribute above. }
function CellFromBIOS(Value: Word): TScreenCell;
function CellEq(const A, B: TScreenCell): Boolean;

implementation

function Flags(const C: TScreenCharacter): Byte; inline;
begin
  Result := C.Meta shr 4;
end;

procedure ScInitChar(out C: TScreenCharacter; Ch: Byte);
begin
  FillChar(C, SizeOf(C), 0);
  C.Text[0] := Ch;
end;

procedure ScInitText(out C: TScreenCharacter; Text: PByte; Len: Integer; Wide: Boolean);
var
  Flg: Byte;
begin
  FillChar(C, SizeOf(C), 0);
  if (Len > 0) and (Len <= 4) then
  begin
    Move(Text^, C.Text[0], Len);
    Flg := 0;
    if Wide then Flg := scWide;
    C.Meta := (Flg shl 4) or (Len - 1);
  end;
end;

procedure ScInitWideTrail(out C: TScreenCharacter);
begin
  FillChar(C, SizeOf(C), 0);
  C.Meta := scTrail shl 4;
end;

function ScIsWide(const C: TScreenCharacter): Boolean;
begin
  Result := (Flags(C) and scWide) <> 0;
end;

function ScIsWideTrail(const C: TScreenCharacter): Boolean;
begin
  Result := (Flags(C) and scTrail) <> 0;
end;

function ScLength(const C: TScreenCharacter): Integer;
begin
  Result := (C.Meta and $0F) + 1;
end;

function ScText(const C: TScreenCharacter): ShortString;
var
  N: Integer;
begin
  N := ScLength(C);
  SetLength(Result, N);
  Move(C.Text[0], Result[1], N);
end;

procedure ScAppendZeroWidth(var C: TScreenCharacter; Text: PByte; Len: Integer);
var
  Size: Integer;
begin
  if (Flags(C) and scOverflow) <> 0 then
    Exit;
  Size := ScLength(C);
  if (Len >= 1) and (Len <= MaxCellTextSize - Size) then
  begin
    if C.Text[0] = 0 then
      C.Text[0] := Ord(' ');
    Move(Text^, C.Text[Size], Len);
    C.Meta := (C.Meta and $F0) or (Size - 1 + Len);
  end
  else
    C.Meta := C.Meta or (scOverflow shl 4);
end;

function CellMake(const Ch: TScreenCharacter; const Attr: TColorAttr): TScreenCell;
begin
  Result.Character := Ch;
  Result.Attribute := Attr;
end;

function CellFromBIOS(Value: Word): TScreenCell;
begin
  ScInitChar(Result.Character, Byte(Value));
  Result.Attribute := AttrFromBIOS(Byte(Value shr 8));
end;

function CellEq(const A, B: TScreenCell): Boolean;
begin
  Result := CompareByte(A, B, SizeOf(TScreenCell)) = 0;
end;

end.
