{ TvUtil: helpers for hot keys and "control strings" (strings with ~hot~ parts).

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/util.h, source/tvision/tvtext2.cpp (getAltChar, getAltCode,
    getAltCharStr, getCtrlChar, getCtrlCode, tables), tinputli.cpp (hotKey, hotKeyStr),
    drivers2.cpp (cstrlen), source/platform/ttext.cpp (equalsIgnoreCase)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - strings are ShortStrings;
    - EqualsIgnoreCase lowercases code points with a small built-in table (Latin-1,
      Latin Extended-A, Greek, Cyrillic) instead of the platform's tables; invalid
      UTF-8 bytes are taken as code page bytes, like the original does. }
unit TvUtil;

{$I tvdefs.inc}

interface

uses
  TvUtf8, TvCodePg, TvKeys, TvEvents, TvText;

type
  PStr = ^ShortString;

{ A heap copy of S sized to its length; DisposeStr frees it (nil stays nil). }
function NewStr(const S: ShortString): PStr;
procedure DisposeStr(P: PStr);

{ The part of S between the first two '~' ('' when there is none); an unclosed
  '~' runs to the end of S. }
function HotKeyStr(const S: ShortString): ShortString;
{ The upper-cased first byte of HotKeyStr(S), or #0. }
function HotKey(const S: ShortString): Char;
{ Displayed length of S without its '~' characters (in bytes, like the original). }
function CStrLen(const S: ShortString): Integer;

{ Alt+letter, Alt+digit, Alt+Space, ... Key codes and the characters they stand for. }
function GetAltCode(C: Char): Word;
function GetAltChar(KeyCode: Word): Char;
{ The text of an Alt+key event: the typed text if there is one, otherwise the
  character the scan code stands for ('' when none). }
function GetAltCharStr(const Event: TEvent): ShortString;
function GetCtrlCode(C: Char): Word;
function GetCtrlChar(KeyCode: Word): Char;
function GetCtrlCharStr(const Event: TEvent): ShortString;

{ Compares two UTF-8 strings ignoring case. }
function EqualsIgnoreCase(const A, B: ShortString): Boolean;

implementation

const
  AltCodes1: array[0..$32 - $10] of Char = 'QWERTYUIOP'#0#0#0#0'ASDFGHJKL'#0#0#0#0#0'ZXCVBNM';
  AltCodes2: array[0..$83 - $78] of Char = '1234567890-=';
  AltSpaceChar = #$F0;             { '≡' in CP437 }
  CtrlCodes = #0'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

function NewStr(const S: ShortString): PStr;
begin
  GetMem(Result, Length(S) + 1);
  Move(S, Result^, Length(S) + 1);
end;

procedure DisposeStr(P: PStr);
begin
  if P <> nil then
    FreeMem(P, Length(P^) + 1);
end;

function HotKeyStr(const S: ShortString): ShortString;
var
  I, J: Integer;
begin
  Result := '';
  I := Pos('~', S);
  if I = 0 then
    Exit;
  Inc(I);
  J := I;
  while (J <= Length(S)) and (S[J] <> '~') do
    Inc(J);
  Result := Copy(S, I, J - I);
end;

function HotKey(const S: ShortString): Char;
var
  P: ShortString;
begin
  P := HotKeyStr(S);
  if P = '' then
    Result := #0
  else
    Result := UpCase(P[1]);
end;

function CStrLen(const S: ShortString): Integer;
var
  I: Integer;
  T: ShortString;
begin
  if Utf8Enabled then
  begin
    { columns, not bytes: the text without the marks of the hot key }
    T := '';
    for I := 1 to Length(S) do
      if S[I] <> '~' then
        T := T + S[I];
    Exit(TextWidthS(T));
  end;
  Result := 0;
  for I := 1 to Length(S) do
    if S[I] <> '~' then
      Inc(Result);
end;

function GetAltCode(C: Char): Word;
var
  I: Integer;
begin
  Result := 0;
  if C = #0 then
    Exit;
  C := UpCase(C);
  if C = AltSpaceChar then
    Exit(kbAltSpace);
  for I := 0 to High(AltCodes1) do
    if AltCodes1[I] = C then
      Exit((I + $10) shl 8);
  for I := 0 to High(AltCodes2) do
    if AltCodes2[I] = C then
      Exit((I + $78) shl 8);
end;

function GetAltCharStr(const Event: TEvent): ShortString;
var
  ScanCode: Integer;
begin
  Result := '';
  if ((Event.ControlKeyState and kbAltShift) <> 0) and (Event.TextLength > 0) then
    Exit(EventText(Event));
  if Event.CharCode = 0 then
  begin
    ScanCode := Event.ScanCode;
    if Event.KeyCode = kbAltSpace then
      Result := AltSpaceChar
    else if (ScanCode >= $10) and (ScanCode <= $32) then
    begin
      if AltCodes1[ScanCode - $10] <> #0 then
        Result := AltCodes1[ScanCode - $10];
    end
    else if (ScanCode >= $78) and (ScanCode <= $83) then
      Result := AltCodes2[ScanCode - $78];
  end;
end;

function GetAltChar(KeyCode: Word): Char;
var
  E: TEvent;
  S: ShortString;
begin
  FillChar(E, SizeOf(E), 0);
  E.KeyCode := KeyCode;
  S := GetAltCharStr(E);
  if S = '' then
    Result := #0
  else
    Result := S[1];
end;

function GetCtrlCharStr(const Event: TEvent): ShortString;
var
  C: Integer;
begin
  Result := '';
  if ((Event.ControlKeyState and kbAltShift) = 0) and
    ((Event.ControlKeyState and kbCtrlShift) <> 0) and (Event.TextLength > 0) then
    Exit(EventText(Event));
  C := Event.CharCode;
  if (C > 0) and (C <= Ord('Z') - Ord('A') + 1) then
    Result := CtrlCodes[C + 1];
end;

function GetCtrlChar(KeyCode: Word): Char;
var
  E: TEvent;
  S: ShortString;
begin
  FillChar(E, SizeOf(E), 0);
  E.KeyCode := KeyCode;
  S := GetCtrlCharStr(E);
  if S = '' then
    Result := #0
  else
    Result := S[1];
end;

function GetCtrlCode(C: Char): Word;
begin
  if (C >= 'a') and (C <= 'z') then
    C := Chr(Ord(C) and not $20);
  Result := GetAltCode(C) or (Ord(C) - Ord('A') + 1);
end;

function Lower(C: LongWord): LongWord;
begin
  Result := C;
  case C of
    Ord('A')..Ord('Z'): Result := C + 32;
    $C0..$DE: if C <> $D7 then Result := C + 32;
    $100..$137, $14A..$177: if (C and 1) = 0 then Result := C + 1;
    $139..$148, $179..$17E: if (C and 1) = 1 then Result := C + 1;
    $178: Result := $FF;
    $391..$3A9: if C <> $3A2 then Result := C + 32;
    $400..$40F: Result := C + 80;
    $410..$42F: Result := C + 32;
  end;
end;

{ one character: UTF-8 when valid, otherwise a code page byte }
function NextChar(const S: ShortString; var I: Integer): LongWord;
var
  Used: Integer;
begin
  if Utf8Enabled and Utf8Decode(@S[I], Length(S) - I + 1, Result, Used) then
    Inc(I, Used)
  else
  begin
    Result := CpToUnicode(Byte(S[I]));
    Inc(I);
  end;
end;

function EqualsIgnoreCase(const A, B: ShortString): Boolean;
var
  I, J: Integer;
begin
  I := 1;
  J := 1;
  while (I <= Length(A)) and (J <= Length(B)) do
    if Lower(NextChar(A, I)) <> Lower(NextChar(B, J)) then
      Exit(False);
  Result := (I > Length(A)) and (J > Length(B));
end;

end.
