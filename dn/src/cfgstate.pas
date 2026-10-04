{ cfgstate: the state of the dialogs of DN (the records that dn.cfg used to hold: the setup of the system, the panels, the colors...)
  is kept in dn.ini, in the section [Saved] (or [Saved<suffix>] for the environment variable DNCFG=<suffix>, as dn<suffix>.cfg
  was). One binary image of the records is cut into pieces of 96 bytes written as hex: Size=<bytes>, S0000=..., S0001=... DN writes
  the section at the exit, nobody edits it; the rest of dn.ini (the comments, the settings of the people) is not touched, the
  files are read and written by the Profile unit as before. Our own code (MIT, see LICENSE). }
unit cfgstate;

{$mode objfpc}
{$H-}

interface

{ Writes the image into the section of the file; False if the file could not be written. }
function SaveState(const IniFile, Suffix: String; const Data; Size: LongInt): Boolean;

{ Reads the image: Data is allocated by GetMem (the caller frees it with FreeMem(Data, Size)); False if the section is not
  there or damaged (Data is nil then). }
function LoadState(const IniFile, Suffix: String; var Data: Pointer; var Size: LongInt): Boolean;

implementation

uses
  SysUtils, Strings, Profile;

const
  PieceBytes = 96;
  Hex: array[0..15] of Char = '0123456789ABCDEF';

function SectionName(const Suffix: String; var Buf: array of Char): PChar;
begin
  StrPCopy(PChar(@Buf[0]), 'Saved' + Suffix);
  Result := PChar(@Buf[0]);
end;

function PieceKey(N: LongInt; var Buf: array of Char): PChar;
begin
  StrPCopy(PChar(@Buf[0]), 'S' + IntToHex(N, 4));
  Result := PChar(@Buf[0]);
end;

function ReadSize(Section, FileName: PChar): LongInt;
var
  V: array[0..31] of Char;
begin
  V[0] := #0;
  GetPrivateProfileString(Section, 'Size', '', V, SizeOf(V), FileName);
  Result := StrToIntDef(StrPas(V), -1);
end;

function SaveState(const IniFile, Suffix: String; const Data; Size: LongInt): Boolean;
var
  F: array[0..259] of Char;
  Sec: array[0..63] of Char;
  Key: array[0..15] of Char;
  V: array[0..2 * PieceBytes + 1] of Char;
  P: PByte;
  I, N, J, L: LongInt;
begin
  StrPCopy(F, IniFile);
  SectionName(Suffix, Sec);
  WritePrivateProfileString(Sec, nil, nil, F);          { the old pieces go away }
  P := PByte(@Data);
  N := (Size + PieceBytes - 1) div PieceBytes;
  { every write puts the line at the top of the section: from the last piece to the first, so that the file reads in order }
  for I := N - 1 downto 0 do
  begin
    L := Size - I * PieceBytes;
    if L > PieceBytes then
      L := PieceBytes;
    for J := 0 to L - 1 do
    begin
      V[2 * J] := Hex[P[I * PieceBytes + J] shr 4];
      V[2 * J + 1] := Hex[P[I * PieceBytes + J] and 15];
    end;
    V[2 * L] := #0;
    WritePrivateProfileString(Sec, PieceKey(I, Key), V, F);
  end;
  StrPCopy(V, IntToStr(Size));
  WritePrivateProfileString(Sec, 'Size', V, F);
  CloseProfile;
  Result := ReadSize(Sec, F) = Size;                    { it is there: the file could be written }
  CloseProfile;
end;

function LoadState(const IniFile, Suffix: String; var Data: Pointer; var Size: LongInt): Boolean;
var
  F: array[0..259] of Char;
  Sec: array[0..63] of Char;
  Key: array[0..15] of Char;
  V: array[0..2 * PieceBytes + 1] of Char;
  P: PByte;
  I, N, J, L: LongInt;

  function Nibble(C: Char): Integer;
  begin
    case C of
      '0'..'9': Result := Ord(C) - 48;
      'A'..'F': Result := Ord(C) - 55;
      'a'..'f': Result := Ord(C) - 87;
    else
      Result := -1;
    end;
  end;

begin
  Data := nil;
  Size := 0;
  Result := False;
  StrPCopy(F, IniFile);
  SectionName(Suffix, Sec);
  Size := ReadSize(Sec, F);
  if (Size <= 0) or (Size > 1 shl 20) then
  begin
    Size := 0;
    CloseProfile;
    Exit;
  end;
  GetMem(Data, Size);
  P := PByte(Data);
  N := (Size + PieceBytes - 1) div PieceBytes;
  for I := 0 to N - 1 do
  begin
    L := Size - I * PieceBytes;
    if L > PieceBytes then
      L := PieceBytes;
    V[0] := #0;
    GetPrivateProfileString(Sec, PieceKey(I, Key), '', V, SizeOf(V), F);
    if StrLen(V) <> 2 * L then
    begin
      FreeMem(Data, Size);
      Data := nil;
      Size := 0;
      CloseProfile;
      Exit;
    end;
    for J := 0 to L - 1 do
    begin
      if (Nibble(V[2 * J]) < 0) or (Nibble(V[2 * J + 1]) < 0) then
      begin
        FreeMem(Data, Size);
        Data := nil;
        Size := 0;
        CloseProfile;
        Exit;
      end;
      P[I * PieceBytes + J] := Nibble(V[2 * J]) shl 4 or Nibble(V[2 * J + 1]);
    end;
  end;
  CloseProfile;
  Result := True;
end;

end.
