{ DNRunOther: running an external program from DN where DN has no screen of its own for the commands (Windows, the Unix systems other than Linux):
  the backend of the facade DNRun. The terminal is given to the shell for the command (SysRunShell), Enter returns.
  This unit is our own code (MIT, see LICENSE). }
{$mode objfpc}{$H-}
unit DNRunOther;

interface

procedure BackendRunExternal(const CmdLine: String; Quiet: Boolean);
function BackendHasCommandScreen: Boolean;
procedure BackendShowCommandScreen;

implementation

uses
  osdep;

procedure BackendRunExternal(const CmdLine: String; Quiet: Boolean);
begin
  SysRunShell(CmdLine);
end;

function BackendHasCommandScreen: Boolean;
begin
  Result := False;
end;

procedure BackendShowCommandScreen;
begin
end;

end.
