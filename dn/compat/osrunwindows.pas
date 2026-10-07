{ OSRunWindows: starting programs and restarting DN on Windows (the backend of the facade OSRun).
  Moved from OSDep (platform separation, stage 3): the code is the same, only the place is new.
  MIT (see LICENSE). }
unit OSRunWindows;

{$mode objfpc}
{$H-}

interface

{ Runs a command line in the shell and waits; Pause: wait for Enter after it (the user runs a command and wants to see its output). The status of waitpid
  (the exit code is in the second byte), -1 if it could not be run. }
function BackendRunShell(const CmdLine: string; Pause: Boolean): LongInt;
{ DOS error code of running a program (0 = it was run). }
{ Runs a command line in the shell and waits; no screen, no pause. The status as BackendRunShell, -1 if it could not be run. }
function BackendRunQuiet(const CmdLine: string): LongInt;
function BackendExecute(Path, Args: PChar): LongInt;
procedure BackendRestartSelf;

implementation

uses
  SysUtils, TvProc, DNErrLog;

{ TvProc gives the exit code; DN keeps the status of waitpid (the exit code in the second byte), -1 if the command could not be run }
function ToStatus(Code: LongInt): LongInt;
begin
  if Code < 0 then
    Result := -1
  else
    Result := Code shl 8;
end;

function BackendRunShell(const CmdLine: string; Pause: Boolean): LongInt;
begin
  Result := ToStatus(RunShell(CmdLine, Pause, '[DN] Press Enter to return...'));
end;

function BackendRunQuiet(const CmdLine: string): LongInt;
begin
  Result := ToStatus(RunQuiet(CmdLine));
end;

function BackendExecute(Path, Args: PChar): LongInt;
var
  R: LongInt;
begin
  { through the shell (COMSPEC), with the terminal: the program may write to it and read from it }
  R := BackendRunShell('"' + StrPas(Path) + '" ' + StrPas(Args), True);
  Result := 0;
  if (R < 0) or ((R shr 8) = 127) or (R = 9009) then
    Result := 2;                   { the shell could not run it: DOS "file not found" }
end;

procedure BackendRestartSelf;
begin
  DNTrace('RestartSelf: ' + ParamStr(0));
  RestartSelf;
end;

end.
