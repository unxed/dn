{ DNRunLinux: running an external program from DN on Linux (the backend of the facade DNRun).
  Moved from DNRun (platform separation, stage 3): the code is the same, only the place is new. The command runs on a pty on the whole screen through the
  emulator of tv/ (TvVtRun: the keys go to the command, the screen stays as the user screen, Ctrl-O shows it); DN_EMBED_TERM=0 gives the terminal to
  /bin/sh -c as before (SysRunShell), Enter returns. DN_RUN_PAUSE: what happens when the command ends: 1 (default) "Press Enter", 0 back to the panels at once,
  2 the pause only when the status is not 0. The mini build (DN_MINI) has no emulator: the command always gets the terminal.
  MIT, see LICENSE. }
{$mode objfpc}{$H-}
unit DNRunLinux;

interface

procedure BackendRunExternal(const CmdLine: String; Quiet: Boolean);
{ Has a command been run on the pty (is there a screen of the commands to show)? }
function BackendHasCommandScreen: Boolean;
{ Shows the screen of the commands until a key; the caller draws DN again. }
procedure BackendShowCommandScreen;

implementation

{$IFDEF DN_MINI}
uses
  osdep;

procedure BackendRunExternal(const CmdLine: String; Quiet: Boolean);
begin
  SysRunShell(CmdLine);      { the terminal is given to the shell for the command }
end;

function BackendHasCommandScreen: Boolean;
begin
  Result := False;
end;

procedure BackendShowCommandScreen;
begin
end;

{$ELSE}
uses
  SysUtils, osdep, TvVt, TvVtRun;

var
  UserScr: TVtEmu;             { the screen of the user: what the commands drew (zeroed until the first command) }

procedure BackendRunExternal(const CmdLine: String; Quiet: Boolean);
var
  P: Integer;
begin
  if GetEnvironmentVariable('DN_EMBED_TERM') <> '0' then
  begin
    { the pause: DN_RUN_PAUSE 0 never, 1 always (default), 2 when the status is not 0 }
    P := 1;
    if Quiet then
      P := 2;
    if GetEnvironmentVariable('DN_RUN_PAUSE') = '0' then P := 0
    else if GetEnvironmentVariable('DN_RUN_PAUSE') = '1' then P := 1
    else if GetEnvironmentVariable('DN_RUN_PAUSE') = '2' then P := 2;
    VtRunScreen(UserScr, '/bin/sh', ['sh', '-c', SysCommandLineToOs(CmdLine)], '', GetCurrentDir + '$ ' + SysCommandLineToOs(CmdLine), P);
    Exit;
  end;
  SysRunShell(CmdLine);      { the terminal is given to the shell for the command }
end;

function BackendHasCommandScreen: Boolean;
begin
  Result := (UserScr <> nil) and (UserScr.Cols > 0);
end;

procedure BackendShowCommandScreen;
begin
  VtShowScreen(UserScr);
end;
{$ENDIF}

end.
