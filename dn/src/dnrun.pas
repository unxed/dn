{ DNRun: runs an external program from DN (an own unit; it replaces the DN.COM loader of the DPMI32 build, which shuts the
  application down, lets the loader run the command and starts DN again with the saved desktop). Here the application stays
  alive: the screen goes to the text mode with the user screen of Drivers (what the previous programs left; after the run the video memory is copied back there), the program runs through COMMAND.COM, a key returns to DN and the caller
  redraws the application. On Linux the command runs on a pty on the whole screen through the emulator of tv/ (TvVtRun: the keys go to the command, the screen
  stays as the user screen, Ctrl-O shows it: UserScr); DN_EMBED_TERM=0 gives the terminal to /bin/sh -c as before (SysRunShell), Enter returns. DN_RUN_PAUSE: what
  happens when the command ends: 1 (default) "Press Enter", 0 back to the panels at once, 2 the pause only when the status is not 0. }
{$mode objfpc}{$H-}
unit DNRun;

interface

{$IFDEF LINUX}
uses
  TvVt;

{ A command line of DN for the shell of the system: the paths C:\dir\name become /dir/name, the other bytes UTF-8 (the code of DN: see CmdToOs in the unit). }
function CmdToOs(const S: string): string;

var
  UserScr: TVtEmu;             { the screen of the user: what the commands drew (zeroed until the first command) }
{$ENDIF}

procedure RunExternal(const CmdLine: String);
var
  QuietRun: Boolean = False;         { set for the calls of DN itself (an archiver asked for a list: ExecStringRR with RR = False): the pause "Process ended" only when the status is not 0 }
  RestartPending: Boolean = False;   { set by the command that restarts DN (change of the language, Restart): the program starts itself again after the shutdown }
{ Starts DN again (the same program, the same parameters): Unix replaces the process (exec), else the new one runs and the old one ends after it. Called by dn.pas after the shutdown. }
procedure RestartSelf;
{$IFDEF GO32V2}
{ Ctrl-O: shows the user screen (what the programs left) until a key is pressed; the caller redraws DN. }
procedure ShowUserScreenDos;
{$ENDIF}

implementation

uses
  SysUtils, Dos{$IFDEF UNIX}, BaseUnix{$ENDIF}{$IFDEF GO32V2}, go32, Drivers{$ENDIF}, osdep, DNErrLog{$IFDEF LINUX}, TvVtRun{$ENDIF};

{$IFDEF LINUX}
function CurDir: AnsiString;
begin
  Result := GetCurrentDir;
end;

{ The command line of DN goes to the shell of the system: the paths of DN (C:\dir\name, after a blank, a quote or a sign of the shell; up to the closing
  quote if there is one) become the paths of the system, the other bytes the text of the system (UTF-8). Without it an archiver got
  "7z l C:\tmp\a.7z >C:\tmp\!!!DN!!!.TMP" and the shell ate the backslashes. }
function CmdToOs(const S: string): string;
var
  I, J: Integer;
  Q: Boolean;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if (I + 2 <= Length(S)) and (UpCase(S[I]) in ['A'..'Z']) and (S[I + 1] = ':') and (S[I + 2] in ['\', '/'])
      and ((I = 1) or (S[I - 1] in [' ', '"', '''', '>', '<', '=', '|', ';', '(', '&'])) then
    begin
      Q := (I > 1) and (S[I - 1] = '"');
      J := I + 2;
      while (J <= Length(S)) and (not Q or (S[J] <> '"')) and (Q or not (S[J] in [' ', '"', '''', '>', '<', '|', ';', '&', ')'])) do
        Inc(J);
      Result := Result + SysOsPath(Copy(S, I, J - I));
      I := J;
    end
    else
    begin
      Result := Result + SysNameToOs(S[I]);
      Inc(I);
    end;
  end;
end;
{$ENDIF}

{$IFDEF GO32V2}
var
  UserCur: Word = $FFFF;       { the cursor of the user screen (BIOS 0040:0050: low byte the column, high the row); $FFFF: not known yet }

{ The size of the text screen by the BIOS (0040:004A the columns, 0040:0084 the rows - 1); False when the values make no sense. }
function BiosScreen(var Cols, Rows: Word): Boolean;
var
  B: Byte;
begin
  dosmemget($40, $4A, Cols, 2);
  dosmemget($40, $84, B, 1);
  Rows := B + 1;
  Result := (Cols > 0) and (Cols <= 255) and (Rows >= 2) and (Rows <= 100);
end;

{ The user screen (UserScreen of Drivers: the screen that started DN, then what the programs left) goes back to the video memory,
  the cursor to its place: the program goes on where the previous one ended (as in DN for DOS), not on a cleared screen. }
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

{ What the program left on the screen becomes the user screen (Ctrl-O shows it), with the cursor. }
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
{$ENDIF}

{$IFDEF GO32V2}
{ A test aid (DNDUMP is set: the key is not waited for): the lines of the user screen that are not empty go to the trace. }
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

procedure ShowUserScreenDos;
var
  R: Registers;
begin
  PutUserScreen;
  if GetEnv('DNDUMP') <> '' then
    TraceUserScreen
  else
  begin
    R.ax := $0000;
    Intr($16, R);
  end;
end;
{$ENDIF}

procedure RunExternal(const CmdLine: String);
{$IFDEF GO32V2}
var
  R: Registers;
{$ENDIF}
{$IFDEF LINUX}
var
  P: Integer;
{$ENDIF}
begin
{$IFDEF GO32V2}
  R.ax := $0003;                  { the text mode 80x25 (it clears the screen), then the user screen comes back }
  Intr($10, R);
  PutUserScreen;
  Writeln(CmdLine);
  DNTrace('RunExternal: exec ' + CmdLine);
  SwapVectors;
  Exec(GetEnv('COMSPEC'), '/c ' + CmdLine);
  SwapVectors;
  DNTrace('RunExternal: back, DosError ' + IntToStr(DosError));
  GetUserScreen;                  { before the line about the key: it is not a part of the output of the program }
  Writeln;
  Write('Press any key to return to DN...');
  { INT 16h, AH = 0: wait for a key (not in the test runs with DNDUMP: no one presses it, the keys of DNKEYS are put in by the
    idle loop that does not run here) }
  if GetEnv('DNDUMP') = '' then
  begin
    R.ax := $0000;
    Intr($16, R);
  end;
{$ELSE}
{$IFDEF LINUX}
  if GetEnvironmentVariable('DN_EMBED_TERM') <> '0' then
  begin
    { the pause: DN_RUN_PAUSE 0 never, 1 always (default), 2 when the status is not 0 }
    P := 1;
    if QuietRun then
      P := 2;
    if GetEnvironmentVariable('DN_RUN_PAUSE') = '0' then P := 0
    else if GetEnvironmentVariable('DN_RUN_PAUSE') = '1' then P := 1
    else if GetEnvironmentVariable('DN_RUN_PAUSE') = '2' then P := 2;
    VtRunScreen(UserScr, '/bin/sh', ['sh', '-c', CmdToOs(CmdLine)], '', CurDir + '$ ' + CmdToOs(CmdLine), P);
    Exit;
  end;
{$ENDIF}
  SysRunShell(CmdLine);      { Unix: the terminal is given to the shell for the command }
{$ENDIF}
end;

procedure RestartSelf;
var
  Strs: array of AnsiString;
  I: Integer;
{$IFDEF UNIX}
  Args: array of PAnsiChar;
{$ENDIF}
begin
  DNTrace('RestartSelf: ' + ParamStr(0));
{$IFDEF UNIX}
  SetLength(Strs, ParamCount + 1);
  SetLength(Args, ParamCount + 2);
  for I := 0 to ParamCount do
  begin
    Strs[I] := ParamStr(I);
    Args[I] := PAnsiChar(Strs[I]);
  end;
  Args[ParamCount + 1] := nil;
  fpExecve(PAnsiChar(Strs[0]), @Args[0], envp);
  DNTrace('RestartSelf: exec failed, errno ' + IntToStr(fpGetErrno));
{$ELSE}
  SetLength(Strs, ParamCount);
  for I := 1 to ParamCount do
    Strs[I - 1] := ParamStr(I);
  ExecuteProcess(ParamStr(0), Strs);
{$ENDIF}
end;

end.
