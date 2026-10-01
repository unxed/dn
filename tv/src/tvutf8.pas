{ TvUtf8: UTF-8 decoding/encoding and display width of code points.

  Translated from magiblot/tvision @ b4831e2 (the parts of):
    include/tvision/internal/utf8.h   (Utf8BytesLeft, utf8To32, utf32To8)
    source/platform/ttext.cpp         (validating decoder: own implementation)
  Display width: magiblot asks the C library (wcwidth) or the console; here it
  comes from tables generated from the Unicode database (tools/gen-width.py,
  tvwidth.inc), so it works the same on every platform, DOS included.
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Width of a code point: -1 for control characters, 0 for combining marks and
  format characters, 2 for East Asian Wide/Fullwidth, 1 otherwise. }
unit TvUtf8;

{$I tvdefs.inc}

interface

const
  MaxCharSize = 4;       { longest UTF-8 sequence }

{ Number of continuation bytes announced by a first byte (0 for ASCII and for
  bytes that cannot start a sequence). }
function Utf8BytesLeft(FirstByte: Byte): Integer; inline;

{ Decodes one character at P (at most Len bytes available). Returns True and
  sets CodePoint/Used when the bytes form a valid, shortest-form, non-surrogate
  sequence of at most U+10FFFF; otherwise False (Used := 1 for resynchronization,
  or the number of bytes that were present when the sequence is truncated). }
function Utf8Decode(P: PByte; Len: Integer; out CodePoint: LongWord; out Used: Integer): Boolean;

{ Encodes CodePoint; Buf must have room for MaxCharSize bytes. Returns the length. }
function Utf8Encode(CodePoint: LongWord; Buf: PByte): Integer;

function CharWidth(CodePoint: LongWord): Integer;

implementation

type
  TUnicodeRange = record
    Lo, Hi: LongWord;
  end;

{$I tvwidth.inc}

function Utf8BytesLeft(FirstByte: Byte): Integer;
begin
  if (FirstByte and $E0) = $C0 then
    Result := 1
  else if (FirstByte and $F0) = $E0 then
    Result := 2
  else if (FirstByte and $F8) = $F0 then
    Result := 3
  else
    Result := 0;
end;

function Utf8Decode(P: PByte; Len: Integer; out CodePoint: LongWord; out Used: Integer): Boolean;
var
  Left, I: Integer;
  CP, Min: LongWord;
begin
  CodePoint := 0;
  Used := 1;
  Result := False;
  if Len < 1 then
  begin
    Used := 0;
    Exit;
  end;
  if P[0] < $80 then
  begin
    CodePoint := P[0];
    Exit(True);
  end;
  Left := Utf8BytesLeft(P[0]);
  if Left = 0 then
    Exit;                                   { continuation byte or invalid lead }
  case Left of
    1: begin CP := P[0] and $1F; Min := $80; end;
    2: begin CP := P[0] and $0F; Min := $800; end;
  else
    begin CP := P[0] and $07; Min := $10000; end;
  end;
  for I := 1 to Left do
  begin
    if I >= Len then
    begin
      Used := Len;                          { truncated sequence }
      Exit;
    end;
    if (P[I] and $C0) <> $80 then
    begin
      Used := I;                            { bad continuation: resync at it }
      Exit;
    end;
    CP := (CP shl 6) or (P[I] and $3F);
  end;
  if (CP < Min) or (CP > $10FFFF) or ((CP >= $D800) and (CP <= $DFFF)) then
    Exit;                                   { overlong, too large, surrogate }
  CodePoint := CP;
  Used := Left + 1;
  Result := True;
end;

function Utf8Encode(CodePoint: LongWord; Buf: PByte): Integer;
begin
  if CodePoint <= $7F then
  begin
    Buf[0] := CodePoint;
    Result := 1;
  end
  else if CodePoint <= $7FF then
  begin
    Buf[0] := $C0 or (CodePoint shr 6);
    Buf[1] := $80 or (CodePoint and $3F);
    Result := 2;
  end
  else if CodePoint <= $FFFF then
  begin
    Buf[0] := $E0 or (CodePoint shr 12);
    Buf[1] := $80 or ((CodePoint shr 6) and $3F);
    Buf[2] := $80 or (CodePoint and $3F);
    Result := 3;
  end
  else
  begin
    Buf[0] := $F0 or ((CodePoint shr 18) and $07);
    Buf[1] := $80 or ((CodePoint shr 12) and $3F);
    Buf[2] := $80 or ((CodePoint shr 6) and $3F);
    Buf[3] := $80 or (CodePoint and $3F);
    Result := 4;
  end;
end;

{ Binary search in a sorted table of disjoint ranges. }
function InRanges(const Table: array of TUnicodeRange; CP: LongWord): Boolean;
var
  Lo, Hi, Mid: Integer;
begin
  Lo := 0;
  Hi := High(Table);
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) shr 1;
    if CP < Table[Mid].Lo then
      Hi := Mid - 1
    else if CP > Table[Mid].Hi then
      Lo := Mid + 1
    else
      Exit(True);
  end;
  Result := False;
end;

function CharWidth(CodePoint: LongWord): Integer;
begin
  if (CodePoint < $20) or ((CodePoint >= $7F) and (CodePoint < $A0)) then
    Exit(-1);
  if CodePoint < $300 then
    Exit(1);                                { fast path: Latin }
  if InRanges(ZeroWidthRanges, CodePoint) then
    Exit(0);
  if InRanges(WideRanges, CodePoint) then
    Exit(2);
  Result := 1;
end;

end.
