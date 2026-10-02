{ VPUtils: the helpers of the Virtual Pascal RTL that DN calls (our unit; the names and the use are in
  spec/vp-api-vputils.md). TODO: SetVideoMode does not change the size of the screen. }
{$mode objfpc}{$H-}
unit VPUtils;

interface

function Min(A, B: LongInt): LongInt; inline;
function Max(A, B: LongInt): LongInt; inline;

{ The hexadecimal text of Number with at least N digits (zeros in front). }
function Int2Hex(Number: LongInt; N: Byte): String;

{ The time since the start of the system in milliseconds. }
function GetTimeMSec: LongInt;

{ The label of the volume of the drive ('' if there is none). }
function GetVolumeLabel(Drive: Char): String;

{ The name in FileRec/TextRec (wide characters in FPC) as a string. }
function NameOfRec(const Name: array of WideChar): String;

{ Dos.GetDate with the day of the week in a LongInt (in VP Word is 32 bit and the variables of DN are LongInt). }
procedure GetDateDow(var Year, Month, Day: Word; var DayOfWeek: LongInt);

{ The scrambling of the table of the records of the game (tetris.pas): every byte xor ($AA xor the number of the bytes
  that are left, as a byte). }
procedure XorScramble(var B; Count: LongInt);

{ The address as hexadecimal digits (VP: Ptr2Hex). }
function Ptr2Hex(P: Pointer): String;

{ The text cursor: the size in lines (0 = hidden), show, hide. }
function GetCursorSize: Word;
procedure ShowCursor;
procedure HideCursor;

{ The size of the screen in characters; True when it is as asked. TODO: it is not changed. }
function SetVideoMode(Cols, Rows: Word): Boolean;

implementation

uses
  SysUtils, Dos, TvScreen, VPSysLow;

function Min(A, B: LongInt): LongInt;
begin
  if A < B then Result := A else Result := B;
end;

function Max(A, B: LongInt): LongInt;
begin
  if A > B then Result := A else Result := B;
end;

function Int2Hex(Number: LongInt; N: Byte): String;
begin
  Result := IntToHex(Cardinal(Number), N);
end;

function GetTimeMSec: LongInt;
begin
  Result := LongInt(Cardinal(GetTickCount64 and $FFFFFFFF));
end;

procedure GetDateDow(var Year, Month, Day: Word; var DayOfWeek: LongInt);
var
  W: Word;
begin
  Dos.GetDate(Year, Month, Day, W);
  DayOfWeek := W;
end;

procedure XorScramble(var B; Count: LongInt);
var
  P: PByte;
  Left: LongInt;
begin
  P := @B;
  Left := Count;
  while Left > 0 do
  begin
    P^ := P^ xor (Byte(Left) xor $AA);
    Inc(P);
    Dec(Left);
  end;
end;

function Ptr2Hex(P: Pointer): String;
begin
  Result := IntToHex(PtrUInt(P), 8);
end;

function NameOfRec(const Name: array of WideChar): String;
var
  I: Integer;
begin
  Result := '';
  I := 0;
  while (I <= High(Name)) and (Name[I] <> #0) and (Length(Result) < 255) do
  begin
    Result := Result + Char(Ord(Name[I]) and $FF);
    Inc(I);
  end;
end;

function GetVolumeLabel(Drive: Char): String;
begin
  Result := SysGetVolumeLabel(Drive);
end;

function GetCursorSize: Word;
begin
  Result := CaretSize;
end;

procedure ShowCursor;
begin
  SetCaretSize(CursorLines);
end;

procedure HideCursor;
begin
  SetCaretSize(0);
end;

function SetVideoMode(Cols, Rows: Word): Boolean;
begin
  Result := (ScreenWidth = Cols) and (ScreenHeight = Rows);
end;

end.
