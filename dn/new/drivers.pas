{ Drivers: the helpers of DN that lie between its sources and the units of tv/ (our unit; it replaces
  drivers.pas of the archive, which was the event manager and the screen of DN, based on Borland TV).

  Events, the mouse and the screen are done by tv/ (TvSys, TvScreen): the routines of the old event manager
  are here only because DN calls them, and do nothing (marked TODO where DN's logic may be needed). What
  is real here: the string and cell routines of 16-bit cells (Move*, FormatStr), the keys (GetAltChar...).
  The names and the initial values are those of the sources of DN. }
{$mode objfpc}{$H-}
unit Drivers;

interface

uses
  SysUtils, TvGeom, TvEvents, TvScreen, TvUtil;

type
  TEvent = TvEvents.TEvent;
  PEvent = ^TEvent;
  CharDef = array[0..15] of Byte;

const
  ButtonCount: Byte = 0;
  MouseEvents: Boolean = False;
  MouseReverse: Boolean = False;
  MouseButtons: Byte = 0;
  DoubleDelay: Word = 8;
  RepeatDelay: Word = 8;
  AutoRepeat: Word = 1;
  UserScreen: Pointer = nil;
  CharHeight: Byte = 16;
  ScreenSaved: Boolean = False;
  NeedAbort: Boolean = False;
  StdMouse: Boolean = False;
  XSens: Byte = 11;
  YSens: Byte = 11;
  CLSAct: Boolean = True;
  CurrentBlink: Boolean = False;
  MouseWhere: TPoint = (X: 0; Y: 0);
  WheelEvent: Boolean = False;
  StartupMode: Word = $FFFF;
  SkyEnabled: Integer = 0;
  TottalExit: Boolean = False;
  Exiting: Boolean = False;
  MouseVisible: Boolean = True;
  ScreenMode: Word = $92;

var
  OldBlink: Boolean;
  MouseIntFlag: Byte;
  UserScreenSize: Word;
  UserScreenWidth: Word;
  MouseX, MouseY, OldMouseX, OldMouseY: Word;
  ShowMouseProc, HideMouseProc: Pointer;
  HiResScreen: Boolean;
  CheckSnow: Boolean;
  OldCursorShape: Word;
  OldCursorPos: Word;
  DownButtons: Byte;
  { the size of the screen: the low halves of the variables of TvScreen (little endian) }
  ScreenWidth: Word absolute TvScreen.ScreenWidth;
  ScreenHeight: Word absolute TvScreen.ScreenHeight;
  { TODO: DN reads and writes the screen as an array of 16-bit cells; the buffer of tv/ has other cells }
  ScreenBuffer: Pointer absolute TvScreen.ScreenBuffer;
  CursorLines: Word absolute TvScreen.CursorLines;

procedure InitDrivers;
procedure DoneDrivers;
procedure InitEvents;
procedure DoneEvents;
procedure ShowMouse;
procedure HideMouse;
procedure UpdateMouseWhere;
procedure GetMouseEvent(var Event: TEvent);
procedure GetKeyEvent(var Event: TEvent);
procedure SetMouseSpeed(XS, YS: Byte);

type
  TSysErrorFunc = function(ErrorCode: Integer; Drive: Byte): Integer;

{ The red dialog of a system error: 3 (Abort), no dialog yet. TODO }
function SystemError(ErrorCode: Integer; Drive: Byte): Integer;

const
  SysErrorFunc: TSysErrorFunc = @SystemError;
  SysColorAttr: Word = $4E4F;
  SysColorButtonAttr: Word = $0E0F;
  SysMonoAttr: Word = $7070;
  CtrlBreakHit: Boolean = False;
  SaveCtrlBreak: Boolean = False;
  SysErrActive: Boolean = False;
  SysErrStopButton: Boolean = False;

procedure InitSysError;
procedure DoneSysError;

function GetAltChar(KeyCode: Word): Char;
function GetAltCode(Ch: Char): Word;
function GetCtrlChar(KeyCode: Word): Char;
function GetCtrlCode(Ch: Char): Word;

{ Result := Format with %s (a pointer to a string), %d (a LongInt), %u, %x, %c, %% and a width (%-8s, %5d)
  filled from Params: an array of 4-byte values, one per % item. }
procedure FormatStr(var Result: String; const Format: String; var Params);
procedure PrintStr(const S: String);

{ Cells of 16 bits: the low byte is the character, the high byte is the attribute (0 = leave as it is). }
procedure MoveColor(var Buf; Num: Word; Attr: Byte);
procedure MoveBuf(var Dest; var Source; Attr: Byte; Count: Word);
procedure MoveChar(var Dest; C: Char; Attr: Byte; Count: Word);
procedure MoveCStr(var Dest; const Str: String; Attrs: Word);
procedure MoveStr(var Dest; const Str: String; Attr: Byte);
function CStrLen(const S: String): Integer;

implementation

type
  PWordArr = ^TWordArr;
  TWordArr = array[0..65534] of Word;
  PLongArr = ^TLongArr;
  TLongArr = array[0..255] of LongInt;

procedure InitDrivers;
begin
end;

procedure DoneDrivers;
begin
end;

procedure InitEvents;
begin
end;

procedure DoneEvents;
begin
end;

procedure ShowMouse;
begin
end;

procedure HideMouse;
begin
end;

procedure UpdateMouseWhere;
begin
end;

procedure GetMouseEvent(var Event: TEvent);
begin
  Event.What := evNothing;
end;

procedure GetKeyEvent(var Event: TEvent);
begin
  Event.What := evNothing;
end;

procedure SetMouseSpeed(XS, YS: Byte);
begin
  XSens := XS;
  YSens := YS;
end;

function SystemError(ErrorCode: Integer; Drive: Byte): Integer;
begin
  Result := 3;
end;

procedure InitSysError;
begin
end;

procedure DoneSysError;
begin
end;

{ --- keys --------------------------------------------------------------------- }

function GetAltChar(KeyCode: Word): Char;
begin
  Result := TvUtil.GetAltChar(KeyCode);
end;

function GetAltCode(Ch: Char): Word;
begin
  Result := TvUtil.GetAltCode(Ch);
end;

function GetCtrlChar(KeyCode: Word): Char;
begin
  Result := TvUtil.GetCtrlChar(KeyCode);
end;

function GetCtrlCode(Ch: Char): Word;
begin
  Result := TvUtil.GetCtrlCode(Ch);
end;

{ --- strings ------------------------------------------------------------------ }

procedure FormatStr(var Result: String; const Format: String; var Params);
var
  P: PLongArr;
  N, I, W, Len: Integer;
  Left: Boolean;
  S: String;
  C: Char;
begin
  P := @Params;
  N := 0;
  Result := '';
  I := 1;
  Len := Length(Format);
  while I <= Len do
  begin
    if Format[I] <> '%' then
    begin
      Result := Result + Format[I];
      Inc(I);
      Continue;
    end;
    Inc(I);
    if I > Len then
      Break;
    if Format[I] = '%' then
    begin
      Result := Result + '%';
      Inc(I);
      Continue;
    end;
    Left := False;
    W := 0;
    if (I <= Len) and (Format[I] = '-') then
    begin
      Left := True;
      Inc(I);
    end;
    while (I <= Len) and (Format[I] in ['0'..'9']) do
    begin
      W := W * 10 + Ord(Format[I]) - 48;
      Inc(I);
    end;
    if I > Len then
      Break;
    C := Format[I];
    Inc(I);
    case C of
      's': begin
             if PtrUInt(P^[N]) = 0 then S := '' else S := PString(PtrUInt(P^[N]))^;
             Inc(N);
           end;
      'd': begin Str(P^[N], S); Inc(N); end;
      'u': begin Str(Cardinal(P^[N]), S); Inc(N); end;
      'x': begin S := LowerCase(IntToHex(Cardinal(P^[N]), 1)); Inc(N); end;
      'X': begin S := IntToHex(Cardinal(P^[N]), 1); Inc(N); end;
      'c': begin S := Chr(Byte(P^[N])); Inc(N); end;
    else
      S := '%' + C;
    end;
    while Length(S) < W do
      if Left then S := S + ' ' else S := ' ' + S;
    Result := Result + S;
  end;
end;

procedure PrintStr(const S: String);
begin
  Write(S);
end;

{ --- cells -------------------------------------------------------------------- }

procedure MoveColor(var Buf; Num: Word; Attr: Byte);
var
  I: Integer;
begin
  for I := 0 to Num - 1 do
    PWordArr(@Buf)^[I] := (PWordArr(@Buf)^[I] and $FF) or (Word(Attr) shl 8);
end;

procedure MoveBuf(var Dest; var Source; Attr: Byte; Count: Word);
var
  I: Integer;
begin
  if Attr = 0 then
    Move(Source, Dest, Count * 2)
  else
    for I := 0 to Count - 1 do
      PWordArr(@Dest)^[I] := PByte(@Source)[I] or (Word(Attr) shl 8);
end;

procedure MoveChar(var Dest; C: Char; Attr: Byte; Count: Word);
var
  I: Integer;
  W: PWordArr;
begin
  W := @Dest;
  for I := 0 to Count - 1 do
    if C = #0 then
      W^[I] := (W^[I] and $FF) or (Word(Attr) shl 8)
    else if Attr = 0 then
      W^[I] := (W^[I] and $FF00) or Ord(C)
    else
      W^[I] := Ord(C) or (Word(Attr) shl 8);
end;

procedure MoveStr(var Dest; const Str: String; Attr: Byte);
var
  I: Integer;
  W: PWordArr;
begin
  W := @Dest;
  for I := 1 to Length(Str) do
    if Attr = 0 then
      W^[I - 1] := (W^[I - 1] and $FF00) or Ord(Str[I])
    else
      W^[I - 1] := Ord(Str[I]) or (Word(Attr) shl 8);
end;

procedure MoveCStr(var Dest; const Str: String; Attrs: Word);
var
  I, J: Integer;
  W: PWordArr;
  Hi: Boolean;
  A: Byte;
begin
  W := @Dest;
  J := 0;
  Hi := False;
  for I := 1 to Length(Str) do
    if Str[I] = '~' then
      Hi := not Hi
    else
    begin
      if Hi then A := Attrs shr 8 else A := Attrs and $FF;
      W^[J] := Ord(Str[I]) or (Word(A) shl 8);
      Inc(J);
    end;
end;

function CStrLen(const S: String): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(S) do
    if S[I] <> '~' then
      Inc(Result);
end;

end.
