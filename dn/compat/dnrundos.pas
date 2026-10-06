{ DNRunDos: running an external program from DN on DOS (the backend of the facade DNRun).
  Moved from DNRun (platform separation, stage 3): the code is the same, only the place is new. The screen goes to the text mode with the user screen
  of Drivers (what the previous programs left; after the run the video memory is copied back there), the program runs through COMMAND.COM, a key returns to DN.
  MIT (see LICENSE). }
{$mode objfpc}{$H-}
unit DNRunDos;

interface

{ Runs the command line through COMSPEC and waits for a key; Quiet is not used on DOS (the pause is always there). }
procedure BackendRunExternal(const CmdLine: String; Quiet: Boolean);
{ Is there a screen of the programs that DN ran? Always on DOS (the video memory keeps it). }
function BackendHasCommandScreen: Boolean;
{ Shows the screen of the programs until a key; the caller draws DN again. }
procedure BackendShowCommandScreen;

implementation

uses
  SysUtils, Dos, osdep, DNErrLog, DNUserScreenDos;

procedure BackendRunExternal(const CmdLine: String; Quiet: Boolean);
var
  Shell, Args: AnsiString;
begin
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
end;

function BackendHasCommandScreen: Boolean;
begin
  Result := True;
end;

procedure BackendShowCommandScreen;
begin
  { the screen of the programs that DN ran (and before that of the one that started DN) }
  ShowUserScreenDos;
end;

end.
