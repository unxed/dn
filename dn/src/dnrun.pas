{ DNRun: runs an external program from DN (an own unit; it replaces the DN.COM loader of the DPMI32 build, which shuts the
  application down, lets the loader run the command and starts DN again with the saved desktop). Here the application stays
  alive and the caller redraws it after the run. The facade is portable; what happens on a target is in DNRunDos (the user screen of DOS, COMMAND.COM),
  DNRunLinux (a pty on the whole screen through the emulator of tv/, the screen of the commands for Ctrl-O) and DNRunOther (the terminal goes to the shell). }
{$mode objfpc}{$H-}
unit DNRun;

interface

procedure RunExternal(const CmdLine: String);
var
  QuietRun: Boolean = False;         { set for the calls of DN itself (an archiver asked for a list: ExecStringRR with RR = False): the pause "Process ended" only when the status is not 0 }
  RestartPending: Boolean = False;   { set by the command that restarts DN (change of the language, Restart): the program starts itself again after the shutdown }
{ Is there a screen of the commands that DN ran, to show (Ctrl-O)? }
function HasCommandScreen: Boolean;
{ Shows it until a key; the caller draws DN again. }
procedure ShowCommandScreen;
{ Starts DN again (the same program, the same parameters): Unix replaces the process (exec), else the new one runs and the old one ends after it. Called by dn.pas after the shutdown. }
procedure RestartSelf;

implementation

uses
  osdep
{$IFDEF GO32V2}
  , DNRunDos
{$ELSE}
{$IFDEF LINUX}
  , DNRunLinux
{$ELSE}
  , DNRunOther
{$ENDIF}
{$ENDIF}
  ;

procedure RunExternal(const CmdLine: String);
begin
  BackendRunExternal(CmdLine, QuietRun);
end;

function HasCommandScreen: Boolean;
begin
  Result := BackendHasCommandScreen;
end;

procedure ShowCommandScreen;
begin
  BackendShowCommandScreen;
end;

procedure RestartSelf;
begin
  osdep.SysRestartSelf;
end;

end.
