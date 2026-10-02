{ Tests of dn/new/drivers.pas }
{$mode objfpc}{$H-}
program t_drivrs;
uses Drivers, TvEvents;
{$I dntest.inc}
var
  Buf: array[0..9] of Word;
  Ev: TEvent;
  S: String;
{$IFDEF CPU32}
  T: String;
{$ENDIF}
  P: array[0..3] of LongInt;
begin
  { cells of 16 bits }
  FillChar(Buf, SizeOf(Buf), 0);
  MoveChar(Buf, 'x', $1F, 3);
  Check((Buf[0] = $1F78) and (Buf[2] = $1F78) and (Buf[3] = 0), 'MoveChar fills the characters and the attributes');
  MoveChar(Buf, 'y', 0, 2);
  Check((Buf[0] = $1F79) and (Buf[1] = $1F79), 'MoveChar with attribute 0 keeps the attributes');
  MoveChar(Buf, #0, $07, 1);
  Check(Buf[0] = $0779, 'MoveChar with character 0 changes the attributes only');
  MoveStr(Buf, 'ab', $2E);
  Check((Buf[0] = $2E61) and (Buf[1] = $2E62), 'MoveStr');
  MoveCStr(Buf, 'a~b~c', $4F1E);
  Check((Buf[0] = $1E61) and (Buf[1] = $4F62) and (Buf[2] = $1E63), 'MoveCStr: ~ switches the attribute');
  MoveColor(Buf, 3, $70);
  Check((Buf[0] = $7061) and (Buf[2] = $7063), 'MoveColor keeps the characters');
  S := 'AB';
  MoveBuf(Buf, S[1], $0A, 2);
  Check((Buf[0] = $0A41) and (Buf[1] = $0A42), 'MoveBuf from characters');
  Check(CStrLen('~F~ile') = 4, 'CStrLen skips the tildes');
  { keys }
  Check(GetAltChar(GetAltCode('Q')) = 'Q', 'Alt-Q and back');
  Check(GetAltChar(GetAltCode('5')) = '5', 'Alt-5 and back');
  { the key codes of DN: the shift state in bits 16..19 }
  FillChar(Ev, SizeOf(Ev), 0);
  Ev.What := evKeyDown;
  Ev.KeyCode := $4B00;
  Check(DNKeyCode(Ev) = $004B00, 'DNKeyCode: Left');
  Ev.ControlKeyState := 2;
  Check(DNKeyCode(Ev) = $034B00, 'DNKeyCode: Shift-Left (any shift is 3)');
  Ev.ControlKeyState := 4;
  Ev.KeyCode := $7300;
  Check(DNKeyCode(Ev) = $047300, 'DNKeyCode: Ctrl-Left');
  Ev.ControlKeyState := 8 or $40;
  Ev.KeyCode := $9B00;
  Check(DNKeyCode(Ev) = $089B00, 'DNKeyCode: Alt-Left (the other flags do not count)');
  SetDNKeyCode(Ev, $034B00);
  Check((Ev.KeyCode = $4B00) and ((Ev.ControlKeyState and 15) = 3), 'SetDNKeyCode');
  Check(DNKeyCode(Ev) = $034B00, 'SetDNKeyCode and DNKeyCode are reverse to each other');
  { FormatStr }
  { the parameters are 4-byte slots (as in Borland TV): a pointer fits only in a 32-bit program }
{$IFDEF CPU32}
  T := 'file';
  P[0] := PtrInt(@T);
  P[1] := 42;
  FormatStr(S, 'name %s, %d items', P);
  Check(S = 'name file, 42 items', 'FormatStr %s %d');
{$ENDIF}
  P[0] := 42;
  FormatStr(S, 'items %d', P);
  Check(S = 'items 42', 'FormatStr %d');
  P[0] := 7; P[1] := 255; P[2] := 255; P[3] := Ord('Z');
  FormatStr(S, '[%5d][%-4d][%x][%c][%%]', P);
  Check(S = '[    7][255 ][ff][Z][%]', 'FormatStr widths, %x, %c, %%');
  Finish;
end.
