{ FormatStr of the Drivers shim: the % items with an array of pointer-sized slots. }
{$mode objfpc}{$H-}
program t_drvfmt;
uses SysUtils, Drivers;
{$I dntest.inc}

var
  P: array[0..7] of PtrInt;
  R: ShortString;
  A, B: ShortString;

function F(const Fmt: ShortString): ShortString;
begin
  FormatStr(R, Fmt, P);
  Result := R;
end;

begin
  A := 'file';
  B := 'abcdefghij';
  P[0] := PtrInt(@A); P[1] := 42; P[2] := PtrInt(@B); P[3] := 7;
  Check(F('name %s, %d items, %s, %d') = 'name file, 42 items, abcdefghij, 7', 'strings and numbers in turn');
  Check(F('no items') = 'no items', 'a format without items');
  Check(F('') = '', 'the empty format');
  P[0] := PtrInt(@A); P[1] := PtrInt(@B); P[2] := PtrInt(@A); P[3] := PtrInt(@B);
  Check(F('[%8s][%-8s][%3s][%-3s]') = '[    file][abcdefghij][file][abcdefghij]', 'widths of strings: a longer text is kept');
  P[0] := 0; P[1] := 0;
  Check(F('[%s][%3s]') = '[][   ]', 'nil is an empty string');
  P[0] := 7; P[1] := 255; P[2] := 255; P[3] := Ord('Z'); P[4] := -5; P[5] := 123456;
  Check(F('[%5d][%-4d][%x][%c][%%][%d][%3d]') = '[    7][255 ][ff][Z][%][-5][123456]', 'widths, %x, %c, %%, a negative number, a long number');
  P[0] := 7; P[1] := 255; P[2] := 255; P[3] := 90; P[4] := -5; P[5] := 123456;
  Check(F('[%05d][%u][%X][%8x][%-8x][%04x]') = '[00007][255][FF][      5a][fffffffb][1e240]', 'zeros, %u, %X, widths of hex');
  P[0] := -42; P[1] := -42;
  Check(F('[%06d]') = '[-00042]', 'zeros go after the sign');
  Check(F('[%6d][%-6d]') = '[   -42][-42   ]', 'the sign goes with the number');
  Check(F('[%-06d]') = '[-42   ]', '- wins over 0');
  P[0] := -1; P[1] := -1;
  Check(F('[%u][%x]') = '[4294967295][ffffffff]', 'a negative LongInt is unsigned 32-bit');
  P[0] := 2026; P[1] := 3; P[2] := 9;
  Check(F('%04d%02d%02d') = '20260309', 'a date with zeros');
  P[0] := 99;
  Check(F('%-3d%%') = '99 %', 'a percentage');
  P[0] := Ord('A'); P[1] := Ord('B');
  Check(F('[%3c][%-3c]') = '[  A][B  ]', 'widths of a character');
  P[0] := Ord('A'); P[1] := $1FF;
  Check(F('%c%c') = 'A'#$FF, 'a character is the low byte');
  P[0] := 1; P[1] := 2; P[2] := 3;
  Check(F('[%d%d%d]') = '[123]', 'items next to each other');
  Check(F('[%q][%d]') = '[%q][1]', 'an unknown item is kept and takes no slot');
  Check(F('[%-5q][%d]') = '[%-5q][1]', 'an unknown item with a width is kept whole');
  Check(F('[%d][abc%') = '[1][abc%', 'a % at the end is kept');
  Check(F('100%% %d') = '100% 1', '%% takes no slot');
  P[0] := PtrInt(@B);
  Check(F('[%300s]') = '[' + StringOfChar(' ', 254), 'the result is cut at 255');
  Check(Length(F('%300s')) = 255, 'the length of a cut result');
  P[0] := PtrInt(@A);
  Check(F('%-300s') = 'file' + StringOfChar(' ', 251), 'a wide item to the left');
  P[0] := 5; P[1] := -5;
  Check(F('%0300d') = StringOfChar('0', 255), 'a wide item with zeros');
  Check(F('%d%0300d') = '5-' + StringOfChar('0', 253), 'a wide negative item with zeros');
  P[0] := 255; P[1] := 255;
  Check(F('%0300X') = StringOfChar('0', 255), 'a wide hex item with zeros');
  Check(F('[%08x][%-6X]') = '[000000ff][FF    ]', 'hex with zeros and to the left');
{$IFDEF CPU64}
  P[0] := PtrInt($7F5B00000000); P[1] := P[0] or 5; P[2] := P[0] or 255; P[3] := P[0] or $FFFFFFFF; P[4] := P[0] or 65;
  Check(F('%d %d %x %d %c') = '0 5 ff -1 A', 'only the low 32 bits of a slot count');
{$ENDIF}
  P[0] := Low(LongInt);
  Check(F('%d') = IntToStr(Low(LongInt)), 'the lowest number');
  Finish;
end.
