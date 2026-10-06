{ DOS user-screen preservation for DNRun and Ctrl-O. BIOS mode, cursor and
  video-memory details stay in this GO32V2 compatibility unit. }
{$mode objfpc}{$H-}
unit DNUserScreenDos;

interface

procedure PrepareUserScreenForExternal;
procedure CaptureUserScreenAfterExternal;
procedure WaitForUserKeyDos;
procedure ShowUserScreenDos;

implementation

uses
  SysUtils, Dos, go32, Drivers, osdep, OSStartScreen, DNErrLog;

var
  UserCur: Word = $FFFF;       { BIOS 0040:0050: low byte column, high byte row }

{ The text-screen size by BIOS (0040:004A columns, 0040:0084 rows minus 1). }
function BiosScreen(var Cols, Rows: Word): Boolean;
var
  B: Byte;
begin
  dosmemget($40, $4A, Cols, 2);
  dosmemget($40, $84, B, 1);
  Rows := B + 1;
  Result := (Cols > 0) and (Cols <= 255) and (Rows >= 2) and (Rows <= 100);
end;

{ Restore the screen that started DN or was left by the previous program. }
procedure PutUserScreen;
var
  Cols, Rows, N: Word;
  R: Registers;
begin
  if (UserScreen = nil) or not BiosScreen(Cols, Rows) or (Cols <> UserScreenWidth) then
    Exit;
  N := Cols * Rows * 2;
  if N > UserScreenSize then
    N := UserScreenSize;
  dosmemput($B800, 0, UserScreen^, N);
  if UserCur = $FFFF then
    UserCur := SysStartCursor;
  R.ah := $02; R.bh := 0;
  R.dl := Lo(UserCur);
  R.dh := Hi(UserCur);
  if R.dh >= Rows then
    R.dh := Rows - 1;
  Intr($10, R);
end;

{ Capture the program's screen and cursor into DN's persistent user screen. }
procedure GetUserScreen;
var
  Cols, Rows, N: Word;
begin
  if (UserScreen = nil) or not BiosScreen(Cols, Rows) or (Cols <> UserScreenWidth) then
    Exit;
  N := Cols * Rows * 2;
  if N > UserScreenSize then
    N := UserScreenSize;
  dosmemget($B800, 0, UserScreen^, N);
  dosmemget($40, $50, UserCur, 2);
end;

{ DNDUMP is a test aid: record non-empty user-screen rows instead of waiting. }
procedure TraceUserScreen;
var
  Cols, Rows, Y, X: Word;
  Line: String;
begin
  if (UserScreen = nil) or not BiosScreen(Cols, Rows) or (Cols <> UserScreenWidth) then
    Exit;
  for Y := 0 to Rows - 1 do
  begin
    Line := '';
    for X := 0 to Cols - 1 do
      Line := Line + Chr(PByteArray(UserScreen)^[(Y * Cols + X) * 2]);
    while (Length(Line) > 0) and (Line[Length(Line)] in [#0, ' ']) do
      SetLength(Line, Length(Line) - 1);
    if Line <> '' then
      DNTrace('UserScreen ' + IntToStr(Y) + ': ' + Line);
  end;
end;

procedure PrepareUserScreenForExternal;
var
  R: Registers;
begin
  R.ax := $0003;                  { text mode 80x25; restore DN's user screen after BIOS clears }
  Intr($10, R);
  PutUserScreen;
end;

procedure CaptureUserScreenAfterExternal;
begin
  GetUserScreen;
end;

procedure WaitForUserKeyDos;
var
  R: Registers;
begin
  R.ax := $0000;
  Intr($16, R);
end;

procedure ShowUserScreenDos;
begin
  PutUserScreen;
  if GetEnv('DNDUMP') <> '' then
    TraceUserScreen
  else
    WaitForUserKeyDos;
end;

end.
