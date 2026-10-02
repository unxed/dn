{ VPUtils: the helpers of the Virtual Pascal RTL that DN calls (our unit; the names and the use are in
  spec/vp-api-vputils.md, no code of VP is used). TODO: SetVideoMode does not change the size of the screen. }
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

{ The text cursor: the size in lines (0 = hidden), show, hide. }
function GetCursorSize: Word;
procedure ShowCursor;
procedure HideCursor;

{ The size of the screen in characters; True when it is as asked. TODO: it is not changed. }
function SetVideoMode(Cols, Rows: Word): Boolean;

implementation

uses
  SysUtils, TvScreen
{$IFDEF GO32V2}
  , Dos
{$ENDIF}
  ;

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

function GetVolumeLabel(Drive: Char): String;
{$IFDEF GO32V2}
var
  SR: SearchRec;
begin
  Result := '';
  FindFirst(UpCase(Drive) + ':\*.*', VolumeID, SR);
  if DosError = 0 then
  begin
    Result := SR.Name;
    FindClose(SR);
  end;
end;
{$ELSE}
begin
  Result := '';
end;
{$ENDIF}

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
