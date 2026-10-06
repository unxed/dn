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

var
  UserScr: TVtEmu;             { the screen of the user: what the commands drew (zeroed until the first command) }
{$ENDIF}

procedure RunExternal(const CmdLine: String);
var
  QuietRun: Boolean = False;         { set for the calls of DN itself (an archiver asked for a list: ExecStringRR with RR = False): the pause "Process ended" only when the status is not 0 }
  RestartPending: Boolean = False;   { set by the command that restarts DN (change of the language, Restart): the program starts itself again after the shutdown }
{ Starts DN again (the same program, the same parameters): Unix replaces the process (exec), else the new one runs and the old one ends after it. Called by dn.pas after the shutdown. }
procedure RestartSelf;

implementation

uses
  SysUtils, Dos, osdep, DNErrLog{$IFDEF GO32V2}, DNUserScreenDos{$ENDIF}{$IFDEF LINUX}, TvVtRun{$ENDIF};

{$IFDEF LINUX}
function CurDir: AnsiString;
begin
  Result := GetCurrentDir;
end;

{ The command line of DN goes to the shell of the system: the paths of DN (C:\dir\name, after a blank, a quote or a sign of the shell; up to the closing
  quote if there is one) become the paths of the system, the other bytes the text of the system (UTF-8). Without it an archiver got
  "7z l C:\tmp\a.7z >C:\tmp\!!!DN!!!.TMP" and the shell ate the backslashes. }
{$ENDIF}

procedure RunExternal(const CmdLine: String);
{$IFDEF GO32V2}
var
  Shell, Args: AnsiString;
{$ENDIF}
{$IFDEF LINUX}
var
  P: Integer;
{$ENDIF}
begin
{$IFDEF GO32V2}
  DNUserScreenDos.PrepareUserScreenForExternal;
  Writeln(CmdLine);
  DNTrace('RunExternal: exec ' + CmdLine);
  Shell := GetEnv('COMSPEC');
  Args := '/c ' + CmdLine;
  SwapVectors;
  SysExecute(PChar(Shell), PChar(Args), nil, False, nil, 0, 0, 0);
  SwapVectors;
  DNTrace('RunExternal: back, DosError ' + IntToStr(DosError));
  DNUserScreenDos.CaptureUserScreenAfterExternal; { before the line about the key: it is not part of program output }
  Writeln;
  Write('Press any key to return to DN...');
  { INT 16h, AH = 0: wait for a key (not in the test runs with DNDUMP: no one presses it, the keys of DNKEYS are put in by the
    idle loop that does not run here) }
  if GetEnv('DNDUMP') = '' then
    DNUserScreenDos.WaitForUserKeyDos;
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
    VtRunScreen(UserScr, '/bin/sh', ['sh', '-c', SysCommandLineToOs(CmdLine)], '', CurDir + '$ ' + SysCommandLineToOs(CmdLine), P);
    Exit;
  end;
{$ENDIF}
  SysRunShell(CmdLine);      { Unix: the terminal is given to the shell for the command }
{$ENDIF}
end;

procedure RestartSelf;
begin
  osdep.SysRestartSelf;
end;

end.
